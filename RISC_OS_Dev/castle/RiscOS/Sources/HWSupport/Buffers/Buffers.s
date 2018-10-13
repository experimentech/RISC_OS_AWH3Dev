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
; > Buffers

; **********************
; ***  Changes List  ***
; **********************
;
; 08-Dec-90 0.00 DDV Created, including module bits.
; 08-Dec-90      DDV Added SWI despatch and Register call.
; 08-Dec-90      DDV Added DeRegister, Info, ModifyFlags.
; 09-Dec-90      DDV Added finalisation code.
; 10-Dec-90      DDV Added insert funtion and shells for link/unlink.
; 10-Dec-90      DDV Made block insert function public (for testing).
; 11-Dec-90      DDV Host debugging and complete control over it!
; 11-Dec-90      DDV BlockInsert finished, tested.
; 11-Dec-90      DDV BlockRemove added.
; 11-Dec-90      DDV Link/UnLinkDevice added.
; 12-Dec-90      DDV Vector interception setup, reset handling + finalise.
; 12-Dec-90      DDV Workspace handling changed, handle block not claimed
;                    until actually required.
; 12-Dec-90      DDV Invalid buffer detatching changed.
; 12-Dec-90      DDV Finalise errors when object refuses to unlink.
; 12-Dec-90      DDV Service_BufferStarting, issued on startup.
; 12-Dec-90      DDV BlockInsert/Remove SWIs removed from public.
; 12-Dec-90      DDV Examine feature added to block remove SWI.
; 13-Dec-90      DDV Fixed cnpV and added single character insert/remove.
; 13-Dec-90      DDV Bug fix; C flag setup after block insert/remove.
; 13-Dec-90      DDV Events generted by block insert/remove functions now
;                    return buffer handles with bit 31 set as documented.
; 13-Dec-90      DDV Changed Service_BufferStarting parameters, all moved
;                    up two registers.
; 13-Dec-90      DDV Made deregister call the detatch function.
; 17-Dec-90      DDV When Event_Empty sent, buffer marked as dormant.
; 18-Dec-90      DDV Bug fix; SWI despatcher now preserves SVC_LR correctly.
; 19-Dec-90      DDV Bug fix; Single character inserts work correctly.
; 20-Dec-90      DDV Changed SWI chunk, no longer OS one.
; 20-Dec-90 0.01 DDV Changed to use address rather than SWIs to talk to owners.
; 14-Jan-91      DDV Added Create/Remove SWIs + re-ordered.
; 20-Jan-91      DDV Changed to use Hdr:.
; 25-Jan-91      DDV Bug fix: Stack in-balance on link call.
; 04-Feb-91      DDV Added create buffers with set handles, gives error if handle in
;                    use.
; 04-Feb-91 0.02 DDV Changed registers to allow room for expansion (ie. uses r8, r9).
; 04-Mar-91      DDV Added Buffer_Threshold SWI.
; 04-Mar-91      DDV Added UpCall generation + state managing of threshold passing.
; 06-Mar-91 0.10 DDV Tweek to stop multiple UpCalls being issued and not handled correctly.
; 08-Mar-91 0.11 DDV Changed ServiceCall to issue CallBack.
; 11-Mar-91      DDV Fixed some register/flags corruption.
; 11-Mar-91      DDV Improved buffer handle recycling.
; 11-Mar-91 0.12 DDV Release for 2.09 build.
; 12-Apr-91 0.13 DDV Internationalised.
; 18-Apr-91      DDV Tightened up internationalisation.
; 18-Apr-91 0.14 DDV Never trusted 13 anyway!
; 06-Jun-91 0.15 TMD Optimised and fixed bug in service code, general messing about
;                    Fixed failure in vector claim bug
;                    Fixed failure to claim vectors on soft reset
;                    Fixed insertion into buffers not wrapping correctly
;                    Fixed zero page corruption on failure to claim/extend buffer block
;                    Fixed buffer threshold problems
; 18-Jun-91      TMD Finished recoding most of it, esp. insv, remv, cnpv
; 16-Jul-91      TMD Made unknown SWI use global message
; 22-Jul-91 0.16 TMD Fixed block insertion not undormantising buffer
; 19-Aug-91 0.17 TMD Fixed error handling (excess of 'DoError's)
;                    Disable IRQs round critical bits of InsV, RemV and CnpV
; 18-Dec-91 0.18 LVR Reorganise findbuffer and findbufferR1 so that InsV/RemV etc. test
;                      for buffer owner with fewer subroutine calls (hence faster)
; 21-Jan-92 0.19 LVR Fix block insert and release code to be
;                      non-interruptible in its critical section
; 03-Feb-92 0.20 JSR Adjust service call entry for changed Service_MessageFileClosed
; 06-Mar-92 0.21 TMD Fix bug RP-1607 (SWI Buffer_Threshold causing exception
;                      on bad buffer)
; 14-Apr-92 0.22 TMD Fix bug RP-2342 (Block insertion buffer full event
;                      clearing top bit of buffer handle)
;                    Fix block insert always setting carry on exit
; 03-Jun-93 0.23 SMC Added new direct call interface.  InsV and RemV can still be used
;                      but the new interface is much faster.
;
; 22-May-96 0.25 RWB Clear buffer NotDormant flag on removal of last byte/block from buffer.
; 05-Aug-99 0.28 KJB Service call table added.

                GET     Hdr:ListOpts
                GET     Hdr:Macros
                GET     Hdr:System
                GET     Hdr:ModHand
                GET     Hdr:FSNumbers
                GET     Hdr:NewErrors
                GET     Hdr:Services
                GET     Hdr:Symbols
                GET     Hdr:NdrDebug
                GET     Hdr:DDVMacros
                GET     Hdr:UpCall
                GET     Hdr:MsgTrans
                GET     Hdr:Proc
                GET     Hdr:ResourceFS
                GET     Hdr:HostFS

                GBLL    hostvdu
                GBLL    debug
                GBLL    stopdeath
                GBLL    international
		GBLL	dormant_on_last_byte

                GBLL    standalonemessages
 [ :DEF: standalone
standalonemessages SETL standalone
 |
standalonemessages SETL {FALSE}
 ]

hostvdu         SETL    true
debug           SETL    false
stopdeath       SETL    true
international   SETL    true
dormant_on_last_byte SETL true

init            SETD    false
final           SETD    true;false
service         SETD    false
register        SETD    true
deregister      SETD    false
getinfo         SETD    false
modflags        SETD    false
link            SETD    false
unlink          SETD    false
blkinsert       SETD    true
blkremove       SETD    false
findhandle      SETD    false
cnpv            SETD    false
insv            SETD    true;false
remv            SETD    false
makebuffer      SETD    false
zapbuffer       SETD    false
calling         SETD    false
threshold       SETD    false
inter           SETD    false

                GET     VersionASM
                GET     Errors.s

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                MACRO
$label          Call    $base, $routine
                Push    "r8, wp"                ; NB default detach code assumes that wp is at [sp, #4]

                ADD     r8, $base, #buffer_ClientR8
                LDMIA   r8, {r8, wp}

        [ debugcalling

                LDR     lr, [$base, #$routine]
                Debug   calling, "calling: r8, wp, routine:", r8, wp, lr

        ]
                MOV     lr, pc                  ; call routine at base+routine
                LDR     pc, [$base ,#$routine]
                Pull    "r8, wp"                ; preserve r8, wp
                MEND

; IntOff saves the PSR in the register provided and disables interrupts
                MACRO
$label          IntOff  $reg
$label          SavePSR $reg                    ; save PSR in $reg
        [ No32bitCode
                TST     $reg, #I_bit            ; if interrupts on (bit clear) (26-bit version)
                TEQEQP  $reg, #I_bit            ; then disable them
        |
                TST     $reg, #I32_bit          ; if interrupts on (bit clear) (32-bit version)
                ORREQ   $reg, $reg, #I32_bit
                MSREQ   CPSR_c, $reg            ; disable interrupts if necessary
                BICEQ   $reg, $reg, #I32_bit    ; clear I32 bit again if was clear originally
        ]

                MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;

; Define global constants, these are stored in the first block of RMA claimed,
; the workspace is split into two chunks.  The first contains the global
; variables and is pointed at by the private word.
;
; The second holds the list of buffers and their information.
;
                        ^ 0, wp
BufferBlockAt           # 4     ; -> start of buffer list
BufferBlockSize         # 4     ;  = size of buffer block

Flags                   # 4     ;  = global flags word:
                                ;       bit 0 = 1 => vectors have been claimed
                                ;       bit 1 = 1 => callback still pending
                                ;       bit 2 = 1 => messages block loaded.

                      [ international
MessagesWorkspace       # 16    ;  = area used by MessageTrans
                      ]

workspacerequired       * :INDEX: @

;
; Now define buffer records, these are stored in the second floating area
; of memory held in the RMA.
;
                        ^ 0
buffer_Handle           # 4     ;  = unique handle (bit 31 clear)
buffer_Flags            # 4     ;  = flags for buffer
                                ;       bit 0 = 0 => buffer dormant
                                ;       bit 1 = 1 => buffer generates "output buffer empty" events
                                ;       bit 2 = 1 => buffer generates "input buffer full" events
                                ;       bit 3 = 1 => buffer generates threshold upcalls
                                ;       bit 4 = 1 => word-aligned data buffer

                                ;       bit 8 = 1 => threshold currently exceeded

buffer_Start            # 4     ; -> start of buffer in memory
buffer_Size             # 4     ;  = total size of buffer
buffer_InsertIndex      # 4     ;  = index to insert characters at
buffer_RemoveIndex      # 4     ;  = index to remove characters at
buffer_WakeUpCode       # 4     ; -> routine for wake up
buffer_DetachCode       # 4     ; -> routine for detaching
buffer_ClientR8         # 4     ;  = clients r8
buffer_ClientWP         # 4     ;  = clients WP (r12)
buffer_Threshold        # 4     ;  = threshold for buffer
buffer_SIZE             # 0

;
; Now define any flags required by the module, ie. global flags and buffer
; related flags.
;

f_CallBackPending       * 1:SHL:0 ; =0 serviced, =1 pending
f_WeHaveMessages        * 1:SHL:1 ; =0 messages not loaded, =1 loaded.

; *** NB. If the publicly accessible bits are changed, be sure to update Hdr:Buffer ***

b_NotDormant            * 1:SHL:0 ; 0 => dormant, 1 => awake
b_GenerateOutputEmpty   * 1:SHL:1 ; 1 => generate OutputEmpty events
b_GenerateInputFull     * 1:SHL:2 ; 1 => generate InputFull events
b_SendThresholdUpCalls  * 1:SHL:3 ; 1 => send upcalls when free goes above or below threshold
b_WordAligned           * 1:SHL:4 ; 1 => word-aligned data buffer

b_ThresholdExceeded     * 1:SHL:8 ; =0 free >= threshold, =1 free < threshold (only maintained if bit 2 set)

r_ExamineOnly           * 1:SHL:0 ; =1 => examine contents, =0 => remove

;
; Some more constants (not global variables though!)
;

bufferbasenumber        * 256   ; all buffer numbers range from here.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Now a module header, this describes the entry points given by the module.
;
                AREA      |BufferManager$$Code|, CODE, READONLY, PIC

                ENTRY

ModuleStart     & 0                     ; not application
                & init-ModuleStart      ; init code
                & final-ModuleStart     ; close down code
                & service-ModuleStart   ; service event handler

                & title-ModuleStart     ; title string
                & help-ModuleStart      ; help string pointer
                & 0

                & Module_SWISystemBase + BufferManagerSWI * Module_SWIChunkSize
                & swijump-ModuleStart
                & switable-ModuleStart
                & 0                     ; no special decoding
                & 0                     ; no international messages file
        [ :LNOT: No32bitCode
                & Module_Flags-ModuleStart
        ]

title           = "BufferManager",0
help            = "Buffer Manager",9,"$Module_MajorVersion ($Module_Date.)"
        [ Module_MinorVersion <> ""
                = " $Module_MinorVersion"
        ]
        [ debug
                = " Development version"
        ]
                = 0
                ALIGN

switable        = "Buffer",0
                = "Create",0
                = "Remove",0
                = "Register",0
                = "Deregister",0
                = "ModifyFlags",0
                = "LinkDevice",0
                = "UnlinkDevice",0
                = "GetInfo",0
                = "Threshold",0
                = "InternalInfo",0
                = 0

              [ international
                ! 0,"Internationalised version"
resource_file   = "Resources:$.Resources.Buffers.Messages", 0
              ]

                ALIGN

        [ :LNOT: No32bitCode
Module_Flags
                DCD     ModuleFlag_32bit       ; 32-bit compatible
        ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: init
;
; in:   r12 -> private word
;
; out:  -
;
; This call allows the module to initialise itself, we need to grab some
; workspace from the RMA and clear out the variables.
;
; The module also claims another block of memory to place the list of buffers
; into, this saves having to claim it when we append to the buffer.
;

init            Entry

                LDR     r2, [wp]
                TEQ     r2, #0                  ; any workspace?
                BNE     %FT10

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =workspacerequired
                SWI     XOS_Module              ; claim, r2 -> block
                EXIT    VS                      ; return if errored

                STR     r2, [wp]
10
                MOV     wp, r2                  ; wp -> workspace

 [ standalonemessages
                ADR     r0, resourcefsfiles
                SWI     XResourceFS_RegisterFiles   ; ignore errors (starts on Service_ResourceFSStarting)
 ]

                BL      ClaimVectors            ; if failed, returns VS but may still have vectors claimed

                ADRVC   r0, CallBackRoutine
                MOVVC   r1, wp                  ; r1 -> workspace
                SWIVC   XOS_AddCallBack

                BLVS    ReleaseVectors
                EXIT    VS

                MOV     r0, #0
                STR     r0, BufferBlockAt
                STR     r0, BufferBlockSize     ; reset information about block

                MOV     r0, #f_CallBackPending
                STR     r0, Flags               ; mark as callback still pending
                EXIT

ClaimVectors    Entry
                MOV     r0, #INSV               ; grab insert vector
                ADRL    r1, InsVHandler
                MOV     r2, wp
                SWI     XOS_Claim

                MOVVC   r0, #REMV               ; grab remove vector
                ADRVCL  r1, RemVHandler
                SWIVC   XOS_Claim

                MOVVC   r0, #CNPV               ; grab count/purge vector
                ADRVCL  r1, CnpVHandler
                SWIVC   XOS_Claim
                EXIT

ReleaseVectors  Entry   "r0,r8"
                MVNVS   r8, #&80000000
                MOVVC   r8, #0
                MOV     r0, #INSV               ; release remove vector
                ADRL    r1, InsVHandler
                MOV     r2, wp
                SWI     XOS_Release             ; ignore any error

                MOV     r0, #REMV               ; release remove vector
                ADRL    r1, RemVHandler
                SWI     XOS_Release             ; ignore any error

                MOV     r0, #CNPV               ; release count/purge vector
                ADRL    r1, CnpVHandler
                SWI     XOS_Release             ; ignore any error
                ADDS    r8, r8, #1              ; restore V to entry state
                EXIT                            ; preserves V flag

; This call back is granted to allow modules to issue SWIs to the module.  During the init
; of the module it has not been linked into the module chain so I then issue a callback
; so that SWIs can be issued.
;

CallBackRoutine Entry   "r1"                    ; issue the service call

                LDR     r1, Flags
                BIC     r1, r1, #f_CallBackPending
                STR     r1, Flags               ; zonk the callback pending flag

                MOV     r1, #Service_BufferStarting
                SWI     XOS_ServiceCall
                EXIT

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: final
;
; in:   r10  = 0 then fatal finalisation.
;       r12 -> private word.
;
; out:  all preserved.
;
; This entry is called when the module is about to be closed down.  The
; function must scan all buffers and attempt to detach themselfs from
; the list.
;
; A buffer handler may refuse to die and then the module will report
; "Buffer manager in use".
;
; The routine must also kill off the second block of RMA (used for the
; buffer list) as this will not be removed by the kernel.
;

final           Entry

                LDR     wp, [wp]                ; wp -> workspace

        [ stopdeath

        ; This code now needs to check the list of buffer handlers,
        ; this is done by scanning the list and calling each function
        ; in turn, if any should error then we report that the buffer
        ; manager is in use and cannot be killed.
        ;
                ADR     r0, BufferBlockAt
                LDMIA   r0, {r2, r3}            ; r2,r3 -> list, =size
                ADD     r3, r3, r2              ; r3 -> end of list

                Debug   final, "final: scan to unattach buffers"

00
                TEQ     r2, r3                  ; end of list yet?
                BEQ     %FT01

                LDR     r0, [r2, #buffer_Handle]
                CMP     r0, #-1                 ; tiz valid?
                BEQ     %FT02

                Debug   final, "final: detach handle, record:", r0, r2

                Call    r2, buffer_DetachCode
                BVS     %FT03                   ; call current owner for detach

                MOV     r0, #-1                 ; invalidate handleo.
                STR     r0, [r2, #buffer_Handle]
02
                ADD     r2, r2, #buffer_SIZE
                B       %BT00                   ;  loop til all done
03
                ADR     r0, ErrorBlock_BufferManager_InUse
                SETV
                PullEnv
                DoError

        ]

01
        ; This function tidies up the system, it removes our ownership
        ; of various vectors and releases any seperate blocks of memory
        ; that we may own.
        ;
                LDR     r3, Flags
                TST     r3, #f_CallBackPending  ; is a callback still pending?
                BICNE   r3, r3, #f_CallBackPending
                ADRNE   r0, CallBackRoutine     ; r0 -> callback routine
                MOVNE   r1, wp
                SWINE   XOS_RemoveCallBack

                STR     r3, Flags               ; update and store flags

                LDR     r2, BufferBlockAt       ; r2 -> secondary block

                CMP     r2, #0                  ; buffer block allocated?
                MOVNE   r0, #ModHandReason_Free
                SWINE   XOS_Module              ; yes, so release it

                MOV     r0, #0
                STR     r0, BufferBlockAt
                STR     r0, BufferBlockSize     ; zap buffer block

                BL      ReleaseVectors

              [ international
                BL      CloseMessages           ; attempt to remove messages
              ]

 [ standalonemessages
                ADR     R0, resourcefsfiles
                SWI     XResourceFS_DeregisterFiles
 ]

                CLRV                            ; never complain if we get to this stage
                EXIT

              [ stopdeath
                MakeErrorBlock BufferManager_InUse
              ]

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call:         service
;
; in:           r1  = service code.
;               wp -> private word.
;
; out:          r1  = preserved, then all other registers preserved.
;               or, = Serivce_Serviced and only documented registers
;                     should and will be corrupted.
;
; This handles service codes that can be received by the module.  The module needs
; to look at service reset to know when its workspace and vectors have been
; released.
;

                ASSERT  Service_Reset < Service_ResourceFSStarting

servicetable    DCD     0
                DCD     serviceentry - ModuleStart
                DCD     Service_Reset
 [ standalonemessages
                DCD     Service_ResourceFSStarting
 ]
                DCD     0

                DCD     servicetable - ModuleStart
service         ROUT
                MOV     r0, r0
                TEQ     r1, #Service_Reset

 [ standalonemessages
                TEQNE   r1, #Service_ResourceFSStarting
 ]
                MOVNE   pc, lr

serviceentry    LDR     wp, [wp]

                Debug   service, "service: reason code:",r1

 [ standalonemessages
                TEQ     r1, #Service_ResourceFSStarting
                BNE     %FT10
                Push    "r0-r3,lr"
                ADR     r0, resourcefsfiles
                MOV     lr, pc
                MOV     pc, r2
                Pull    "r0-r3,pc"
10
 ]
                TEQ     r1, #Service_Reset      ; the one we want?
                MOVNE   pc, lr                  ; no, so return

                Push    "r0-r3, lr"

                MOV     r0, #&FD                ; read last reset type
                MOV     r1, #0
                MOV     r2, #&FF
                SWI     XOS_Byte
                TEQ     r1, #0
                Pull    "r0-r3, pc",NE          ; if hard reset, do nothing

                Debug   service, "service: soft reset occured"

                LDR     r0, Flags               ; messages no longer owned
                BIC     r0, r0, #f_WeHaveMessages
                STR     r0, Flags

                LDR     r2, BufferBlockAt
                CMP     r2, #0                  ; is buffer list allocated?

                Debug   service, "service: buffer list at", r2

                MOVNE   r0, #ModHandReason_Free
                SWINE   XOS_Module              ; release it (can't do anything sensible if error, so carry on)

                MOV     r0, #0
                STR     r0, BufferBlockAt
                STR     r0, BufferBlockSize     ; reset buffer information

                BL      ClaimVectors
                BLVS    ReleaseVectors          ; can't indicate error to outside world, but we can release vectors

                ADRVC   r0, CallBackRoutine     ; only bother doing this if we managed to claim vectors
                MOVVC   r1, wp                  ; r1 -> workspace
                SWIVC   XOS_AddCallBack
                LDRVC   r3, Flags
                ORRVC   r3, r3, #f_CallBackPending
                STRVC   r3, Flags               ; mark as callback still pending

                Debug   service, "service: all tidied, can return"

                Pull    "r0-r3, pc"

                GBLS    conditionalgetbodge
 [ standalonemessages
                GBLS    ApplicationName
ApplicationName SETS    "Buffers"
conditionalgetbodge SETS "GET s.ResFiles"
resourcefsfiles
 |
conditionalgetbodge SETS ""
 ]
                $conditionalgetbodge
 [ standalonemessages
                DCD     0
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: swijump
;
; in:   r10  = swi chunk
;       r11  = modol swi number
;       r12 -> private word
;
; out:  -
;
; This call handles the despatch of SWIs within the module, the value in r11
; is first range checked to ensure we can despatch correctly.
;

swijump         ROUT

                LDR     wp, [wp]

                CMP     r11, #(%00-%99)/4
                ADDCC   pc, pc, r11, ASL #2     ; if valid despatch
                B       %FT00

99
                B       b_Create
                B       b_Remove
                B       b_Register
                B       b_Deregister
                B       b_ModifyFlags
                B       b_Link
                B       b_UnLink
                B       b_GetInfo
                B       b_Threshold
                B       b_InternalInfo

00
                ADR     r0, ErrorBlock_BufferManager_BadSWI     ; return invalid SWI error
 [ international
                B       MakeErrorWithModuleName
 |
                RETURNVS
 ]

                MakeErrorBlock BufferManager_BadSWI

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_Create
;
; in:   r0  = flags for buffer,
;       r1  = size of buffer wanted.
;       r2  = unique buffer handle to be assigned, -1 if to generate one.
;
; out:  as from register.
;
; This call will make and register a buffer with the manager, the routine
; claims the required block from the RMA and then attempts to call
; the internal register function.
;

b_Create        Entry   "r0-r4"

                Debug   makebuffer, "create: flags, size, handle:", r0, r1, r2

                CMP     r1, #0                  ; if size <= 0 then silly
                PullEnv LE
                BLE     BufferTooSmall

                TST     r0, #b_WordAligned
                TSTNE   r1, #3
                PullEnv NE
                BNE     BufferNotAligned

                MOV     r4, r2                  ; r4  = handle to be used

                MOV     r0, #ModHandReason_Claim
                MOV     r3, r1                  ; r3  = size of buffer needed
                SWI     XOS_Module              ; r2 -> area for buffer
                STRVS   r0, [sp]
                EXIT    VS                      ; return if the call failed

                Debug   makebuffer, "create: at: ", r2

                Pull    "r0"                    ; r0  = default flags for buffer
                MOV     r1, r2                  ; r1 -> start of buffer
                ADD     r2, r1, r3              ; r2 -> end of buffer
                MOV     r3, r4                  ; r3  = handle
                BL      b_Register
                Pull    "r1-r4, pc",VC

                Debug   makebuffer, "failed to register it though!"

                Push    "r0"
                MOV     r0, #ModHandReason_Free
                MOV     r2, r1
                SWI     XOS_Module              ; attempt to release if failed to register
                PullEnv                         ; preserve r0 around the free.
                RETURNVS

BufferTooSmall
                ADR     r0, ErrorBlock_BufferManager_BufferTooSmall
                DoError

                MakeErrorBlock BufferManager_BufferTooSmall
BufferNotAligned
                ADR     r0, ErrorBlock_BufferManager_BufferNotAligned
                DoError

                MakeErrorBlock BufferManager_BufferNotAligned

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_Remove
;
; in:   r0  = handle.
;
; out:  if V=0 => all ok, all preserved.
;       if V=1 => r0 -> error block.
;
; This routine attempts attempts to free a buffer and de-register it all in
; one go.  The routine should only be called on buffers that have been created
; using CreateBuffer.
;

b_Remove        Entry   "r0,r2"

                BL      findbuffer              ; r11 -> record if V=0.
                BVS     %FT99

                LDR     r2, [r11, #buffer_Start] ; get address of buffer and save it for freeing later
                LDR     r0, [r11, #buffer_Handle]
                BL      b_Deregister            ; free buffer handle
                                                ; ** NB when b_Deregister is entered, R14 is assumed to have V clear **
                MOVVC   r0, #ModHandReason_Free ; if successfully detached, then free buffer block
                SWIVC   XOS_Module
99
                STRVS   r0, [sp]
                EXIT                            ; return, r0 -> error block if V=1, else preserved.

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_Register
;
; in:   r0  = flags word for buffer
;       r1 -> buffer start
;       r2 -> buffer end of buffer memory (+1)
;       r3  = unique buffer handle to be used, =-1 then generate one.
;
; out:  r0  = handle for buffer.
;
; This call attempts to register a buffer.  This involves filling in a buffer
; record stored in the buffer list.
;
; The routine first scans the buffer list looking for a free slot, if it
; finds one then it will place the information about the buffer into it.  If
; however a slot does not exist then it must extend the buffer memory
; area and copy data into it.
;
; (Called from SWI and from b_Create)

b_Register      Entry   "r0-r3"

                Debug   register, "register: flags, buffer, end, handle:", r0, r1, r2, r3

        ; r0  = flags for buffer
        ; r1 -> buffer
        ; r2 -> buffer end
        ; r3  = handle to be used, =-1 if undefined

                TST     r0, #b_WordAligned
                BEQ     %FT05

                TST     r1, #3
                PullEnv NE
                BNE     BufferNotAligned

                TST     r2, #3
                PullEnv NE
                BNE     BufferNotAligned
05
                SUBS    lr, r2, r1              ; lr = size of buffer
                PullEnv LE                      ; if size <= 0 then silly
                BLE     BufferTooSmall

                CMP     r3, #-1                 ; unique handle specified?
                BEQ     %FT10

                MOV     r0, r3                  ; r0  = buffer handle
                BL      findbuffer
                BVS     %FT10                   ; yes, it's unique so we can ignore

                PullEnv
                ADR     r0, ErrorBlock_BufferManager_HandleAlreadyUsed
                DoError                         ; error, r0 -> blk, V set.

                MakeErrorBlock BufferManager_HandleAlreadyUsed

10
                MOV     r10, #bufferbasenumber  ; r10 = base number for buffers
                MOV     r0, #0                  ; r0  = 0, have not found an empty slot yet

20
                ADR     r11, BufferBlockAt
                LDMIA   r11, {r11, lr}          ; r11 -> block
                ADD     r1, r11, lr             ; r1 -> block end

30
                TEQ     r11, r1                 ; finished buffer scan?
                BEQ     %FT40                   ; yes, so create it

                LDR     lr, [r11, #buffer_Handle]
                CMP     lr, r10                 ; have we used this handle yet?
                ADDEQ   r10, r10, #1
                BEQ     %20                     ; we have a match so try the next one

                CMP     lr, #-1                 ; is it an empty slot?
                TEQEQ   r0, #0                  ; and have found one yet?
                MOVEQ   r0, r11                 ; yes and no so setup a new index

                ADD     r11, r11, #buffer_SIZE
                B       %30                     ; loop until finished checking

40
                MOVS    r11, r0                 ; recycle a handle?
                BEQ     %60                     ; no, so we must attempt create a new slot

50
                Pull    "r0-r3, lr"             ; restore entry parameters
                CMP     r3, #-1                 ; if user specified handle
                MOVNE   r10, r3                 ; then use that
                STR     r10, [r11, #buffer_Handle]

                SUB     r2, r2, r1              ; lr = buffer size
                AND     r0, r0, #&1F            ; set high-up (internal) flag bits to zero

                ASSERT  buffer_Flags = 4
                ASSERT  buffer_Start = buffer_Flags +4
                ASSERT  buffer_Size = buffer_Flags +8
                STMIB   r11, {r0-r2}            ; stash data about buffer

                ADD     r2, r2, r1              ; put back original r2

                MOV     r0, #0                  ; reset insert/remove index
                STR     r0, [r11, #buffer_InsertIndex]
                STR     r0, [r11, #buffer_RemoveIndex]
                STR     r0, [r11, #buffer_ClientR8]
                STR     r0, [r11, #buffer_ClientWP]
                STR     r0, [r11, #buffer_Threshold] ; no threshold

                ADR     r0, defaultHANDLER
                STR     r0, [r11, #buffer_WakeUpCode]
                STR     r0, [r11, #buffer_DetachCode]

                MOV     r0, r10                 ; r0 = buffer handle

; and drop thru to ...

defaultHANDLER  RETURNVC                        ; return V clear

60
        ; We have been unable to find a suitable gap within the buffer list,
        ; this is either because the list has not been setup yet, or that the
        ; block is too small and all current nodes are full.
        ;
        ; This call simply attempts to extend or allocate a block, if the
        ; current pointer is zero then the call will allocate, otherwise
        ; it will simply extend.
        ;

                Debug   register, "register: allocating more memory for block"

                LDR     r2, BufferBlockAt       ; r2 -> buffer
                TEQ     r2, #0                  ; is a buffer block allocated?
                MOVEQ   r0, #ModHandReason_Claim
                MOVNE   r0, #ModHandReason_ExtendBlock

                MOV     r3, #buffer_SIZE        ; r3  = extension / size
                SWI     XOS_Module

                STRVC   r2, BufferBlockAt       ; reset my internal pointer

                LDRVC   r0, BufferBlockSize     ; r0 =size of list block
                ADDVC   r1, r0, #buffer_SIZE
                STRVC   r1, BufferBlockSize

                Debug   register, "register: old size, new size, at:", r0, r1, r2

                ADDVC   r11, r2, r0             ; r11 -> record point
                BVC     %BT50                   ; now make record!

                ADR     r0, ErrorBlock_BufferManager_TooManyBuffers
                STR     r0, [sp]
                PullEnv                         ; return error
                DoError                         ; ensure V set.

                MakeErrorBlock BufferManager_TooManyBuffers

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_Deregister
;
; in:   r0  = buffer number to de-register.
;
; out:  r0 -> error block if V=1, else preserved.
;
; This routine marks a buffer as not being used anymore.  When called it will
; remove the buffer from the active list.  This is done by finding the
; buffer record and setting the buffer handle =-1.
;
; (Called from SWI and from b_Remove)

b_Deregister    Entry   "r0"

                Debug   deregister, "deregister: handle:",r0
                BL      findbuffer
                BVS     %FT99                   ; if went bang so return

                Debug   deregister, "deregister: about to detach the device"

                LDR     r0, [r11, #buffer_Handle]
                Call    r11, buffer_DetachCode
                BVS     %FT99                   ; return an error

                Debug   deregister, "deregister: back from call"

                MOV     r0, #-1                 ; scrap handle
                STR     r0, [r11, #buffer_Handle]

                EXIT                            ; (V must be clear because of that BVS above)

99
        ; Return an error from the device, this involves unstacking the
        ; registers and returning home.  V must be set when jumping here
        ;
                ADD     sp, sp, #4              ; skip r0 in return frame
                Pull    "lr"                    ; and return V set, r0 intact!
                RETURNVS

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call:         b_ModifyFlags
;
; in:           r0  =buffer handle
;               r1  =EOR mask
;               r2  =AND mask
;
; out:          r0 preserved, unless error.
;               r1  =old value
;               r2  =new value
;
; This call will modify the flags and return their new state to the caller,
; the caller supplies a set EOR and AND word which get applied in the
; following way:
;
;       new = (old AND r2) EOR r1
;

b_ModifyFlags   Entry

                Debug   modflags, "modifyflags: handle, EOR, AND:", r0, r1, r2

                BL      findbuffer
                BVS     %FT99

                PHPSEI  lr, r10                         ; disable IRQs to do atomic update of flags

                LDR     r10, [r11, #buffer_Flags]       ; only allow user to modify bottom 8 bits
                AND     r2, r10, r2
                EOR     r2, r1, r2                      ; r2  = (flags AND r2) EOR r1
                MOV     r1, r10                         ; r1  = old value
                STR     r2, [r11, #buffer_Flags]

                PLP     lr                              ; restore old IRQ status

                Debug   modflags, "modifyflags: old, new:", r1, r2

                EXIT                                    ; V must be clear to get here

99
                PullEnv
                RETURNVS                                ; V must be set anyway to get here

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_Link
;
; in:   r0  = buffer number
;       r1  = address of routine used to wake up device
;        or = 0 for none (ie. don't wakup)
;
;       r2  = address of routine used to detach device
;        or = 0 for none (ie. cannot be requested to detach)
;
;       r3  = special word passed in r8 to above calls
;       r4 -> workspace for calls, or private word.
;
; out:  r0-r4 preserved, although error may be generated if current owner
;             cannot or refuses to be un-linked.
;
; This routine links the specified addresses to the buffer.  The routine
; will first call the current owner and ask it to detach, if this fails then
; an error will be generated.
;
; The routine first scans for the buffer handle, calls the current owner
; and then re-writes the control block.
;
; If r1 is equal to 0 on entry then the code is replaced with a non-destructive
; return, if r2 =0 on entry then the code is replaced with the address of a
; routine to return an error.
;
; r3 is a value which whenever the device is called will be passed in r8,
; and r4 is the same except it is passed in r12.
;

b_Link          Entry   "r0-r2"

                Debug   link, "link: buffer, wake up, detach, private, wp:",r0, r1, r2, r3, r4

                BL      findbuffer
                BVS     %FT99                   ; exit if errored

                Call    r11, buffer_DetachCode
                BVS     %FT99                   ; return if failed to detach

                TEQ     r1, #0                  ; did they specify some wake up code?
                addr    r1, defaultHANDLER, EQ  ; no, then use default

                TEQ     r2, #0                  ; did they specify any detach code?
                ADREQ   r2, DetachErrorHandler  ; no, then use default

                ADD     r0, r11, #buffer_WakeUpCode
                ASSERT  buffer_DetachCode = buffer_WakeUpCode + 4
                ASSERT  buffer_ClientR8   = buffer_WakeUpCode + 8
                ASSERT  buffer_ClientWP   = buffer_WakeUpCode + 12
                STMIA   r0, {r1-r4}             ; store all parameters

                Debug   link, "link: wake up instr, detach instr:", r1, r2

        ; Reset buffer variables, ie. flush the buffer so that the new
        ; owner does not receive lots of data.
        ;
                LDR     r0, [r11, #buffer_Flags]
                BIC     r0, r0, #b_NotDormant           ; mark buffer as dormant
                BIC     r0, r0, #b_ThresholdExceeded    ; indicate space >= threshold
                STR     r0, [r11, #buffer_Flags]

                SUBS    r0, r0, r0                      ; zap the two index points (R0=0, V cleared)
                STR     r0, [r11, #buffer_InsertIndex]
                STR     r0, [r11, #buffer_RemoveIndex]

                EXIT

99
                STR     r0, [sp]
                PullEnv
                RETURNVS

        ; default handler if r2 =0 on entry.
        ;
DetachErrorHandler
                LDR     wp, [sp, #4]            ; the wp passed in is the user's one (which may be used for
                                                ; wake up code), so reload our wp in order to look up errors
                ADR     r0, ErrorBlock_BufferManager_UnableToDetach
                DoError

                MakeErrorBlock BufferManager_UnableToDetach

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_UnLink
;
; in:   r0 =buffer number.
;
; out:  -
;
; This call unlinks the given buffer from any device, no warning is given of
; this for example the detach SWI is not issued.
;
; This is used by device drivers when they have decided that they no longer
; want to use the buffer, or when their detach SWI has been received.
;

b_UnLink        Entry   "r0-r2"

                Debug   unlink, "unlink: handle", r0

                BL      findbuffer              ; locate handle in r0
                BVS     %FT99

        ; Time to un-link a buffer, the current owner is not informed
        ; of this it just happens.
        ;
                addr    r0, defaultHANDLER
                STR     r0, [r11, #buffer_WakeUpCode]
                STR     r0, [r11, #buffer_DetachCode]

                LDR     r0, [r11, #buffer_Flags]
                BIC     r0, r0, #b_NotDormant           ; mark buffer as dormant
                BIC     r0, r0, #b_ThresholdExceeded    ; indicate space >= threshold
                STR     r0, [r11, #buffer_Flags]

                SUBS    r0, r0, r0                      ; zap the two index points (R0=0, clears V)
                STR     r0, [r11, #buffer_InsertIndex]
                STR     r0, [r11, #buffer_RemoveIndex]

                EXIT

; come here when error, because buffer not found

99
                STR     r0, [sp]
                PullEnv
                RETURNVS

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_GetInfo
;
; in:   r0  = buffer handle
; out:  r0  = buffer flags
;       r1  = start address of buffer in memory
;       r2  = end address of buffer in memory (+1)
;       r3  = insert index into buffer
;       r4  = remove index from buffer
;       r5  = amount of free space in buffer
;       r6  = number of characters in buffer
;
; This call can be used to enquire about the buffer and where it is.  The
; first three parameters returned relate to the ones passed into the
; register buffer call.
;
; r3,r4 are used to insert/remove characters into the buffer by the InsV,
; RemV and CnpV calls.  They cannot be altered because they are stored with
; the buffer record.
;

b_GetInfo       Entry

                Debug   getinfo, "getinfo: handle:", r0

                BL      findbuffer
                BVS     %FT99

                ASSERT  buffer_Flags = 4
                ASSERT  buffer_Start = buffer_Flags +4
                ASSERT  buffer_Size = buffer_Flags +8
                ASSERT  buffer_InsertIndex = buffer_Flags +12
                ASSERT  buffer_RemoveIndex = buffer_Flags +16
                LDMIB   r11, {r0-r4}            ; skip handle, load flags, start, size, insertindex, removeindex
                TST     r0, #b_WordAligned
                SUBNE   r5, r4, #4              ; r5 = rem-4 or
                SUBEQ   r5, r4, #1              ; r5 = rem-1
                SUBS    r5, r5, r3              ; r5 = rem-ins-[1|4] (note free space of empty buffer is less than size)
                ADDLT   r5, r5, r2              ; if negative then add size in, ie r5 = rem-ins+size-[1|4]
                SUBS    r6, r3, r4              ; r6 = ins - rem = used space
                ADDLT   r6, r6, r2              ; if negative then add size in, ie r6 = ins-rem+size
                ADD     r2, r2, r1              ; make r2 -> end of buffer +1

                Debug   getinfo, "getinfo: flags, start, end, insert, remove, free, chars:", r0,r1,r2,r3,r4,r5,r6

                CLRV
                EXIT

99
                PullEnv                         ; V and r0 set by call above.
                RETURNVS

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_Threshold
;
; in:   r0  = buffer handle
;       r1  = threshold to use / =0 for none / -1 to read
;
; out:  r1  = previous value
;
; This call can be used to read/modify the threshold value being used.
;

b_Threshold     Entry   "r4-r8"

                Debug   threshold, "threshold: buffer handle, threshold:", r0, r1

                SavePSR r8

                BL      findbuffer
                BVS     %FT99

                LDR     lr, [r11, #buffer_Threshold]
                CMP     r1, #-1                         ; if not just reading
                STRNE   r1, [r11, #buffer_Threshold]    ; then store new value

                LDRNE   r4, [r11, #buffer_Flags]        ; if setting value
                TSTNE   r4, #b_SendThresholdUpCalls     ; and threshold upcalls enabled
                BNE     %FT05
                MOV     r1, lr                          ; put old value in r1
                RestPSR r8,,f
                EXIT                                    ; then check for threshold crossing else exit now

05
                ASSERT  buffer_InsertIndex = buffer_Size +4
                ASSERT  buffer_RemoveIndex = buffer_Size +8
                ADD     r5, r11, #buffer_Size
                LDMIA   r5, {r5-r7}                     ; r5 = size, r6 = ins, r7 = rem

                CLC                                     ; clear carry for subtract in order to subtract an extra 1
                SBCS    r6, r7, r6                      ; r6 = rem-ins-1 (note free space of empty buffer is one less than size)
                ADDCC   r6, r6, r5                      ; if negative then add size in, ie r6 = rem-ins+size-1

                CMP     r6, r1                          ; if free space >= new threshold then emptying
                Push    "lr"                            ; save old threshold value
                BCS     %FT10                           ; so check if already emptying

; free space < threshold, ie buffer filling

                TST     r4, #b_ThresholdExceeded        ; if threshold not already exceeded
                BLEQ    SendFillingUpCall               ; then send filling upcall (this updates flags)
                CLRV
                Pull    "r1, r4-r8,pc"                  ; then exit

; free space >= threshold, ie buffer emptying

10
                TST     r4, #b_ThresholdExceeded        ; if threshold currently exceeded
                BLNE    SendEmptyingUpCall              ; then send emptying upcall (this updates flags)
                CLRV
                Pull    "r1, r4-r8,pc"

99
                Pull    "r4-r8, lr"
                RETURNVS

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: b_InternalInfo
;
; in:   r0  = buffer handle
; out:  r0  = buffer managers internal buffer id (offset to start of buffer block)
;       r1  = address of buffer manager service routine
;       r2  = buffer manager workspace pointer
;
;       This call returns the internal buffer id for the given buffer along
;       with the address of the buffer manager service routine and its workspace
;       pointer.  The service routine can be called directly quoting the
;       internal buffer id and with the workspace pointer in r12.
;
b_InternalInfo
        Entry

        ADR     r1, ServiceRoutine              ; return service routine address
        MOV     r2, wp                          ; and workspace pointer
        BL      findbuffer                      ; find the buffer
        LDRVC   r0, BufferBlockAt               ; if found then return the
        SUBVC   r0, r11, r0                     ; offset to start of buffer block

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Buffer manager service routine.  Called externally to buffer bytes etc.
;
; in:   r0    = reason code
;       r1    = internal buffer id (offset to buffer block)
;       r2-r3 = parameters
;       r12  -> buffer manager workspace
;
ServiceRoutine  ROUT
        Push    "r11,lr"

        Debug   service,"Service routine called, id = ",r1

        LDR     r11, BufferBlockAt
        ADD     r11, r11, r1                    ; r11 now points to buffer block

        CMP     r0, #(%10-%00)/4
        ADDCC   pc, pc, r0, ASL #2
        B       %FT10
00
        B       s_InsertByte
        B       s_InsertBlock
        B       s_RemoveByte
        B       s_RemoveBlock
        B       s_ExamineByte
        B       s_ExamineBlock
        B       s_UsedSpace
        B       s_FreeSpace
        B       s_PurgeBuffer
        B       s_NextBlock
10
        Pull    "r11,lr"
        ADR     r0, ErrorBlock_BufferManager_BadParm
        DoError

        MakeErrorBlock  BufferManager_BadParm


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: InsVHandler
;
; Called in IRQ or SVC mode
;
; either:
;
;       in:
;               r0 = character to insert
;               r1 = buffer handle
;       out:
;               r0,r1 preserved
;               r2 corrupted
;
;               C=1 => failed to insert
;
; or:
;       in:     r1 = buffer handle + 1:SHL:31
;               r2 -> block
;               r3 = number of bytes
;       out:
;               r0,r1 preserved.
;               r2 -> first byte of block not inserted
;               r3 = number of bytes not transfered, or =0 if all.
;
;               C=1 => failed to insert all (ie. r3<>0).
;
; This code is the InsV handler, which inserts data into buffers.
;
; When called we decode the buffer number held in r1, if it is one
; of ours then we handle insertion of the data otherwise it just gets
; passed on down the skip chain.
;
; If we are handling the insertion of data then we must ensure that
; we issue all the correct events and other such bits.
;

InsVHandler
        Push    "r11,lr"
        SavePSR lr
        Push    "lr"
        BL      findbufferR1            ; find buffer (r11 -> buffer block)
        Pull    "lr"
        BVC     %FT10
        TEQ     pc, pc                  ; EQ if this is a 32-bit mode
        Pull    "r11,pc",NE,^           ; 26-bit mode exit - call is not our one
        MSR     CPSR_cf, lr
        Pull    "r11,pc"                ; 32-bit mode exit - call is not out one
10
        RestPSR lr

        Debug   insv,"InsV called"

        Pull    "lr"                    ; Set up stack for return from service routine
        STR     lr, [sp]                ;   (overwrite lr we stacked with r11 we stacked).
        TST     r1, #1:SHL:31           ; if block insert
        BNE     s_InsertBlock           ; then go and do it

        MOV     r2, r0                  ; otherwise, move byte into r2 (allowed to corrupt this)
        ; drop through to s_InsertByte

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_InsertByte
;
; in:   r0  = 0
;       r2  = byte to insert
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  all registers preserved
;       C=1 => failed to insert byte
;
s_InsertByte    ROUT                            ; r11 and return address already stacked
        Push    "r0,r1,r4-r9"

        Debug   insv,"Insert byte into buffer",r11

        IntOff  r9                              ; interrupts off, old PSR in r9

        ASSERT  buffer_Flags = 4
        ASSERT  buffer_Start = buffer_Flags +4
        ASSERT  buffer_Size = buffer_Flags +8
        ASSERT  buffer_InsertIndex = buffer_Flags +12
        ASSERT  buffer_RemoveIndex = buffer_Flags +16
        LDMIB   r11, {r4-r8}                    ; r4=flags, r5->start, r6=size, r7=ins, r8=rem

        Debug   insv,"start = ",r5
        Debug   insv,"ins = ",r7
        STRB    r2, [r5, r7]                    ; store byte
        ADD     r7, r7, #1
        CMP     r7, r6
        MOVEQ   r7, #0                          ; wrap if necessary
        CMP     r7, r8                          ; if buffer full then
        BEQ     %FT40                           ; insertion failed

        STR     r7, [r11, #buffer_InsertIndex]

        EOR     r5, r4, #b_SendThresholdUpCalls                         ; if UpCalls disabled
        TST     r5, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)  ; or threshold already exceeded
        BNE     %FT20                                                   ; then skip buffer filling check

        CLC
        SBCS    lr, r8, r7                      ; lr = rem-ins-1
        ADDLO   lr, lr, r6                      ; wrap if -ve (lr = free space)
        LDR     r6, [r11, #buffer_Threshold]
        CMP     lr, r6                          ; if free space < threshold
        BLLO    SendFillingUpCall               ; then issue UpCall
20
        TST     r4, #b_NotDormant               ; if buffer not dormant
        BNE     %FT30                           ; then no need to wake up

        ORR     r4, r4, #b_NotDormant           ; not dormant now
        STR     r4, [r11, #buffer_Flags]
        LDR     r0, [r11, #buffer_Handle]
        Call    r11, buffer_WakeUpCode
30
        BIC     r9, r9, #C_bit                  ; clear C => successful insert
        RestPSR r9,,cf                          ; restore old PSR
        Pull    "r0,r1,r4-r9,r11,pc"

; insertion when buffer full
40
        ORR     r9, r9, #C_bit                  ; set C => insert failed
        TST     r4, #b_GenerateInputFull        ; if not generating input full events
        BEQ     %FT50                           ; then skip

        ASSERT (IRQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (FIQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (USR_mode :AND: :NOT: SVC_mode) = 0

        ORR     r6, r9, #SVC_mode               ; make mode bits be SVC (IRQ32/IRQ26->SVC32/SVC26)
        RestPSR r6,,cf                          ; set SVC mode, restore interrupt state

        MOV     r0, #Event_InputFull            ; acts as NOP for mode change (ARM2)
        Push    "lr"                            ; save SVC_lr
        LDR     r1, [r11, #buffer_Handle]
        SWI     XOS_GenerateEvent               ; r2 = character that failed
        Pull    "lr"                            ; restore SVC_lr
50
        RestPSR r9,,cf                          ; restore old mode/IRQs/set C
        Pull    "r0,r1,r4-r9,r11,pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_InsertBlock
;
; in:   r0  = 1
;       r2  ->block to insert
;       r3  = number of bytes to insert
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  ->first byte of block not inserted
;       r3  = number of bytes not inserted
;       all other registers preserved
;       C=1 => failed to insert all data (r3<>0)
;
s_InsertBlock                                   ; r11 and return address already stacked
        CMP     r3, #1                          ; C=0 => number of bytes = 0
        Pull    "r11,pc",CC                     ; none to insert so exit with C=0

        Push    "r0,r1,r4-r9"

        Debug   insv,"Insert block into buffer",r11

        IntOff  r9                              ; interrupts off, old PSR in r9

        ASSERT  buffer_Flags = 4
        ASSERT  buffer_Start = buffer_Flags +4
        ASSERT  buffer_Size = buffer_Flags +8
        ASSERT  buffer_InsertIndex = buffer_Flags +12
        ASSERT  buffer_RemoveIndex = buffer_Flags +16
        LDMIB   r11, {r4-r8}                    ; r4=flags, r5->start, r6=size, r7=ins, r8=rem

        TST     r4, #b_WordAligned
        BNE     %FT20

        SUBS    r8, r8, #1                      ; real insert limit
        SUBLO   r8, r6, #1                      ; if -ve then wrap to end of buffer
        B       %FT30

20
        Debug   insv,"word-aligned insert"

        SUBS    r8, r8, #4                      ; real insert limit
        SUBLO   r8, r6, #4                      ; if -ve then wrap to end of buffer
30
        TEQ     r7, r8                          ; if ins=rem-1
        BEQ     %FT80                           ; then buffer full

        MOV     r1, r2                          ; r1 ->source
        ADD     lr, r6, r5                      ; lr ->end
        ADD     r2, r7, r5                      ; r2 ->ins (dest)
        ADD     r8, r8, r5                      ; r8 ->rem-1

        CMP     r8, r2                          ; if rem-1 > ins then only use [ins..rem-2]
        BHI     %FT60

        ; ins >= rem-1, so use [ins..end-1, 0..rem-2]

        SUB     r0, lr, r2                      ; r0 = size of [ins..end-1]
        SUBS    r3, r3, r0                      ; r3 = bytes to do - size of first chunk
        ADDCC   r0, r0, r3                      ; if bytes to do < size of chunk then adjust bytes to do
        BL      MoveBytes                       ; preserves flags
        ADDCC   r2, r2, r0                      ; move on ins^ if not at end of buffer
        MOVCS   r2, r5                          ; reached end of buffer so set ins^ to start
        BLS     %FT70                           ; done it
        ADD     r1, r1, r0                      ; more to do so move on source^
60
        SUB     r0, r8, r2                      ; r0 = size of [start..rem-2] or [ins..rem-2]
        SUBS    r3, r3, r0                      ; r3 = bytes to do - size of chunk
        ADDCC   r0, r0, r3                      ; if bytes to do < size of chunk then adjust bytes to do
        BL      MoveBytes                       ; preserves flags
        ADD     r2, r2, r0                      ; move on ins^
70
        MOVCC   r3, #0                          ; return r3=0 if done, otherwise r3=bytes left
        MOV     lr, r2                          ; save new ins^ for below
        SUB     r7, r2, r5                      ; work out new ins offset
        ADD     r2, r1, r0                      ; return r2=updated source^

        STR     r7, [r11, #buffer_InsertIndex]

        EOR     r5, r4, #b_SendThresholdUpCalls                         ; if UpCalls disabled
        TST     r5, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)  ; or threshold already exceeded
        BNE     %FT75                                                   ; then skip buffer filling check

        SUBS    lr, r8, lr                      ; lr = rem-1-ins (uses pointers from above)
        ADDCC   lr, lr, r6                      ; if -ve then lr+=size => lr = free space
        LDR     r6, [r11, #buffer_Threshold]
        CMP     lr, r6                          ; if free space < threshold
        BLCC    SendFillingUpCall               ; then issue UpCall
75
        TST     r4, #b_NotDormant               ; if the buffer is not dormant
        BNE     %FT80                           ; then no need to wake up

        ORR     r4, r4, #b_NotDormant           ; not dormant now
        STR     r4, [r11, #buffer_Flags]
        LDR     r0, [r11, #buffer_Handle]
        Call    r11, buffer_WakeUpCode
80
        CMP     r3, #1                          ; if all transferred
        BLO     %FT85                           ; then can't be full so exit

        TST     r4, #b_GenerateInputFull        ; if not generating input full events
        BEQ     %FT85                           ; then skip

        ASSERT (IRQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (FIQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (USR_mode :AND: :NOT: SVC_mode) = 0

        ORR     r6, r9, #SVC_mode               ; make mode bits be SVC (IRQ32/IRQ26->SVC32/SVC26)
        RestPSR r6,,cf                          ; set SVC mode, restore interrupt state

        MOV     r0, #Event_InputFull            ; acts as NOP for mode change (ARM2)
        Push    "lr"                            ; save SVC_lr
        LDR     r1, [r11, #buffer_Handle]
        SWI     XOS_GenerateEvent               ; r2->data left, r3=no. bytes left
        Pull    "lr"                            ; restore SVC_lr
85
        RestPSR r9,,cf                          ; restore old CPU mode/IRQs
        CMP     r3, #1                          ; C=0 if all done, otherwise C=1

        Pull    "r0,r1,r4-r9,r11,pc"



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: RemVHandler
;
; Called in IRQ or SVC mode
;
; either:
;
;       in:
;               r1 = buffer to remove from
;               V=0 => remove from buffer, V=1 => examine buffer
;       out:
;               r0 = r2 = character removed (for remove) or next byte to be removed (for examine)
;               r1 preserved.
;
;               C=1 => unable to get character
; or:
;
;       in:
;               r1 = buffer + 1:SHL:31
;               r2 -> destination area for data to move
;               r3 = number of bytes to transfer
;               V=0 => remove from buffer, V=1 => examine buffer
;
;       out:
;               r1 preserved.
;               r2 -> byte after last character transfered
;               r3 = number of characters remaining for transfer or 0.
;
;               C=1 => unable to transfer all data, r3 <>0.
;
; This code is the RemV handler, which removes data from buffers or examines buffers.
;
; The difference is that when extracting, the code will remove the
; character(s), whereas an examine will copy the data out without marking it
; as removed.
;

ExamineHandler ROUT
        Push    "r11,lr"
        SavePSR lr
        Push    "lr"
        BL      findbufferR1            ; find buffer (r11 -> buffer block)
        Pull    "lr"
        BVC     %FT10
        TEQ     pc, pc                  ; EQ if this is a 32-bit mode
        Pull    "r11,pc",NE,^           ; 26-bit mode exit - call is not our one
        MSR     CPSR_cf, lr
        Pull    "r11,pc"                ; 32-bit mode exit - call is not out one
10
        RestPSR lr

        TST     r1, #1:SHL:31
        ADREQ   lr, RemVClaim           ; if byte examine then set up stack so that the result
        STREQ   lr, [sp, #4]            ;   is returned in r2 AND r0
        Pull    "lr",NE                 ; else block examine so set up stack to return to caller
        STRNE   lr, [sp]
        BEQ     s_ExamineByte
        B       s_ExamineBlock

RemVClaim
        MOVCC   r0, r2                  ; if succeeded then return byte in r0 as well as r2
        Pull    "pc"                    ; claim vector call

RemVHandler ROUT
        BVS     ExamineHandler

        Push    "r11,lr"
        SavePSR lr
        Push    "lr"
        BL      findbufferR1            ; find buffer (r11 -> buffer block)
        Pull    "lr"
        BVC     %FT10
        TEQ     pc, pc                  ; EQ if this is a 32-bit mode
        Pull    "r11,pc",NE,^           ; 26-bit mode exit - call is not our one
        MSR     CPSR_cf, lr
        Pull    "r11,pc"                ; 32-bit mode exit - call is not out one
10
        RestPSR lr

        Debug   remv,"RemV called"

        TST     r1, #1:SHL:31
        ADREQ   lr, RemVClaim           ; if byte remove then set up stack so that the result
        STREQ   lr, [sp, #4]            ;   is returned in r2 AND r0
        Pull    "lr",NE                 ; else block remove so set up stack to return to caller
        STRNE   lr, [sp]
        BNE     s_RemoveBlock

        ; otherwise, drop through to s_RemoveByte

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_RemoveByte
;
; in:   r0  = 2
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  = byte removed
;       all other registers preserved
;       C=1 => failed to remove byte
;
s_RemoveByte    ROUT                            ; r11 and return address already stacked
        Push    "r1,r4-r10"
        MOV     r9, #1                          ; indicate remove, not examine

RemExByteCommon
        Debug   remv,"Remove byte from buffer",r11

        IntOff  r10                             ; interrupts off, old PSR in r10

        ASSERT  buffer_Flags = 4
        ASSERT  buffer_Start = buffer_Flags +4
        ASSERT  buffer_Size = buffer_Flags +8
        ASSERT  buffer_InsertIndex = buffer_Flags +12
        ASSERT  buffer_RemoveIndex = buffer_Flags +16
        LDMIB   r11, {r4-r8}                    ; r4=flags, r5->start, r6=size, r7=ins, r8=rem

        CMP     r7, r8                          ; if ins=rem
        BEQ     %FT40                           ; then no bytes in buffer

        LDRB    r2, [r5, r8]                    ; get a character
        TEQ     r9, #0                          ; if examine
        BEQ     %FT30                           ; then exit now

        ADD     r8, r8, #1                      ; increment rem
        CMP     r8, r6
        MOVEQ   r8, #0                          ; wrap if necessary
        STR     r8, [r11, #buffer_RemoveIndex]

        EOR     r5, r4, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)      ; if UpCalls disabled
        TST     r5, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)          ; or threshold not already exceeded
        BNE     %FT20                                                           ; then skip buffer emptying check

        CLC
        SBCS    lr, r8, r7                      ; lr = rem-ins-1
        ADDLO   lr, lr, r6                      ; wrap if -ve, lr now = free space
        LDR     r6, [r11, #buffer_Threshold]
        CMP     lr, r6                          ; if free space >= threshold
        BLCS    SendEmptyingUpCall              ; then issue UpCall
20
        TEQ     r7, r8                          ; if ins<>rem
        BNE     %FT30                           ; then not empty

 [ dormant_on_last_byte
        BICEQ   r4, r4, #b_NotDormant
        STREQ   r4, [r11, #buffer_Flags]        ; then mark as dormant
 ]

        TST     r4, #b_GenerateOutputEmpty      ; if buffer empty events disabled
        BEQ     %FT30                           ; then skip

        ASSERT (IRQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (FIQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (USR_mode :AND: :NOT: SVC_mode) = 0

        SETPSR  SVC_mode, r6                    ; make mode bits be SVC (IRQ32/IRQ26->SVC32/SVC26)

        MOV     r0, #Event_OutputEmpty          ; acts as NOP for potential TEQP
        Push    "lr"                            ; save SVC_lr
        LDR     r1, [r11, #buffer_Handle]
        SWI     XOS_GenerateEvent
        Pull    "lr"                            ; restore SVC_lr
30
        RestPSR r10                             ; restore old CPU mode/IRQ state
        CLC                                     ; C=0 => remove successful
        Pull    "r1,r4-r11,pc"

; buffer empty
40
        TEQ     r9, #1                          ; if removing
        BICEQ   r4, r4, #b_NotDormant
        STREQ   r4, [r11, #buffer_Flags]        ; then mark as dormant

        RestPSR r10                             ; restore old CPU mode/IRQ state
        SEC                                     ; C=1 => remove failed
        Pull    "r1,r4-r11,pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_RemoveBlock
;
; in:   r0  = 3
;       r2  ->destination area
;       r3  = number of bytes to remove
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  -> next free byte in destination area
;       r3  = number of free bytes left in destination area
;       all other registers preserved
;       C=1 => failed to remove all data (r3<>0)
;
s_RemoveBlock                                   ; r11 and return address already stacked
        CMP     r3, #1                          ; C=0 => number of bytes = 0
        Pull    "r11,pc",CC

        Push    "r0,r1,r4-r10"
        MOV     r9, #1                          ; indicate remove, not examine

RemExBlockCommon
        Debug   remv,"Remove block from buffer",r11

        IntOff  r10                             ; interrupts off, old PSR in r10

        ASSERT  buffer_Flags = 4
        ASSERT  buffer_Start = buffer_Flags +4
        ASSERT  buffer_Size = buffer_Flags +8
        ASSERT  buffer_InsertIndex = buffer_Flags +12
        ASSERT  buffer_RemoveIndex = buffer_Flags +16
        LDMIB   r11, {r4-r8}                    ; r4=flags, r5->start, r6=size, r7=ins, r8=rem

        CMP     r7, r8
        BEQ     %FT80                           ; if buffer is empty then exit
        ADD     lr, r6, r5                      ; lr -> end
        ADD     r7, r7, r5                      ; r7 -> ins
        ADD     r1, r8, r5                      ; r1 -> rem
        BGT     %FT60                           ; if ins>rem then can only use [rem..ins-1]

; ins < rem so can use [rem..end-1, 0..ins-1]
        SUB     r0, lr, r1                      ; r0 = size of [rem..end-1]
        SUBS    r3, r3, r0                      ; r3 = bytes to do - size of first chunk
        ADDCC   r0, r0, r3                      ; if bytes to do < size of chunk then adjust bytes to do
        BL      MoveBytes                       ; preserves flags
        ADDCC   r1, r1, r0                      ; move on rem^ if not at end of buffer
        MOVCS   r1, r5                          ; reached end of buffer so set rem^ to start
        BLS     %FT70                           ; done it
        ADD     r2, r2, r0                      ; more to do so move on dest^
60
        SUB     r0, r7, r1                      ; r0 = size of [start..ins-1] or [rem..ins-1]
        SUBS    r3, r3, r0                      ; r3 = bytes to do - size of chunk
        ADDCC   r0, r0, r3                      ; if bytes to do < size of chunk then adjust bytes to do
        BL      MoveBytes                       ; preserves flags
        ADD     r1, r1, r0                      ; move on rem^
70
        MOVCC   r3, #0                          ; return r3=0 if done, otherwise r3=bytes left
        ADD     r2, r2, r0                      ; return r2=updated dest^

        TEQ     r9, #0                          ; if examine only
        BEQ     %FT90                           ; then exit

        MOV     r8, r1                          ; save new rem^ for below
        SUB     lr, r1, r5                      ; lr = new rem offset
        STR     lr, [r11, #buffer_RemoveIndex]

        EOR     r5, r4, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)      ; if UpCalls disabled
        TST     r5, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)          ; or threshold not exceeded
        BNE     %FT75                                                           ; then skip check

        CLC
        SBCS    lr, r8, r7                      ; lr = rem-ins-1 (uses pointers from above)
        ADDCC   lr, lr, r6                      ; if -ve then add size, lr now = free space
        LDR     r6, [r11, #buffer_Threshold]
        CMP     lr, r6                          ; if free space >= threshold
        BLCS    SendEmptyingUpCall              ; then issue UpCall
75
        TEQ     r7, r8                          ; if ins^<>rem^ (buffer not empty)
        BNE     %FT90                           ; then exit

 [ dormant_on_last_byte
        BICEQ   r4, r4, #b_NotDormant
        STREQ   r4, [r11, #buffer_Flags]        ; then mark as dormant
 ]
        TST     r4, #b_GenerateOutputEmpty      ; if output empty events disabled
        BEQ     %FT80                           ; then exit

        ASSERT (IRQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (FIQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (USR_mode :AND: :NOT: SVC_mode) = 0

        SETPSR  SVC_mode, r6                    ; make mode bits be SVC (IRQ32/IRQ26->SVC32/SVC26)

        MOV     r0, #Event_OutputEmpty          ; acts as NOP for potential TEQP
        Push    "lr"                            ; save SVC_lr
        LDR     r1, [r11, #buffer_Handle]
        SWI     XOS_GenerateEvent
        Pull    "lr"                            ; restore SVC_lr
80
        CMP     r9, #1                          ; if removing
        CMPHS   r3, #1                          ; and remove failed
        BICHS   r4, r4, #b_NotDormant
        STRHS   r4, [r11, #buffer_Flags]        ; then mark as dormant
90
        RestPSR r10                             ; restore old CPU mode/IRQ state
        CMP     r3, #1                          ; C=0 if all done, otherwise C=1
        Pull    "r0,r1,r4-r11,pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_ExamineByte
;
; in:   r0  = 4
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  = next byte to be removed
;       all other registers preserved
;       C=1 => failed to examine byte
;
s_ExamineByte                                   ; r11 and return address already stacked
        Push    "r1,r4-r10"
        MOV     r9, #0                          ; indicate examine, not remove
        B       RemExByteCommon

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_ExamineBlock
;
; in:   r0  = 5
;       r1  = buffer handle
;       r2  ->destination area
;       r3  = number of bytes to examine
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  -> next free byte in destination area
;       r3  = number of free bytes left in destination area
;       all other registers preserved
;       C=1 => failed to examine all data (r3<>0)
;
s_ExamineBlock                                  ; r11 and return address already stacked
        CMP     r3, #1                          ; C=0 => number of bytes = 0
        Pull    "r11,pc",CC

        Push    "r0,r1,r4-r10"
        MOV     r9, #0                          ; indicate examine, not remove
        B       RemExBlockCommon



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: CnpVHandler
;
; in:   r1 =handle
;               V =0 => count entries in a buffer
;                 =1 => purge the buffer
;
;               C =0 => return number of entries in the buffer
;                 =1 => return amount of free space.
;
; out:  r0 corrupted!
;       r1 =least significant 8 bits of count, if V flag =0 on entry.
;       r2 =most significant 24 bits of count, if V flag =0 on entry.
;
;       r1, r2 preserved if V =1 on entry.
;
; This call can be used to count/purge a vector.  The code will
; return the characteristics of a buffer to the outside world.
;

CnpVClaim
                AND     r1, r2, #&FF            ; r1 = lower 8 bits of count
                MOV     r2, r2, LSR #8          ; r2 = upper 24 bits of count
                Pull    "pc"

CnpVHandler     ROUT
                Push    "r10,r11,lr"
                SavePSR r10                     ; save PSR
                BL      findbufferR1            ; find buffer (r11 -> buffer block)
                BVC     %FT10
                TEQ     pc, pc
                Pull    "r10,r11,pc",NE,^       ; 26-bit mode exit. pass on call if not our one
                RestPSR r10,,f
                Pull    "r10,r11,pc"            ; 32-bit mode exit
10
                Debug   cnpv,"CnpV called"

                RestPSR r10,,f                  ; restore PSR (need original V and C)
                Pull    "r10"                   ; and r10
                ADRVC   lr, CnpVClaim           ; if free/used space then set up stack to munge output on return
                STRVC   lr, [sp, #4]
                Pull    "lr",VS                 ; if purge then set up stack to return to caller
                STRVS   lr, [sp]
                BVS     s_PurgeBuffer
                BCS     s_FreeSpace

                ; must be used space so drop through to s_UsedSpace

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_UsedSpace
;
; in:   r0  = 6
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  = number of bytes used in buffer
;       all other registers preserved
;
s_UsedSpace                                     ; r11 and return address already stacked
        Push    "r0,r1"

        Debug   cnpv,"Returning used space in buffer",r11

        ASSERT  buffer_InsertIndex = buffer_Size +4
        ASSERT  buffer_RemoveIndex = buffer_Size +8
        ADD     r11, r11, #buffer_Size
        LDMIA   r11, {r0-r2}                    ; r0=size, r1=ins, r2=rem
        SUBS    r2, r1, r2                      ; r2=ins-rem
        ADDCC   r2, r2, r0                      ; if -ve then add size

        Pull    "r0,r1,r11,pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_FreeSpace
;
; in:   r0  = 7
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  = number of bytes free in buffer
;       all other registers preserved
;
s_FreeSpace                                     ; r11 and return address already stacked
        Push    "r4-r8"

        Debug   cnpv,"Returning free space in buffer",r11

        ASSERT  buffer_Flags = 4
        ASSERT  buffer_Start = buffer_Flags +4
        ASSERT  buffer_Size = buffer_Flags +8
        ASSERT  buffer_InsertIndex = buffer_Flags +12
        ASSERT  buffer_RemoveIndex = buffer_Flags +16
        LDMIB   r11, {r4-r8}                    ; r4=flags, r5->start, r6=size, r7=ins, r8=rem

        TST     r4, #b_WordAligned
        SUBNE   r2, r8, #4
        SUBEQ   r2, r8, #1
        SUBS    r2, r2, r7                      ; r2=rem-ins-unit size
        ADDLT   r2, r2, r6                      ; if -ve then add size

        Pull    "r4-r8,r11,pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_PurgeBuffer
;
; in:   r0  = 8
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  all registers preserved
;
s_PurgeBuffer   ROUT                            ; r11 and return address already stacked
        Push    "r4-r6"

        Debug   cnpv,"Purging buffer",r11

        IntOff  r6                              ; interrupts off, old PSR in r6
        BIC     r6, r6, #V_bit                  ; V could still be set if came through CnpV

        ASSERT  buffer_RemoveIndex = buffer_InsertIndex +4
        ADD     lr, r11, #buffer_InsertIndex
        MOV     r4, #0
        MOV     r5, #0
        STMIA   lr, {r4,r5}                     ; zero ins and rem offsets

        LDR     r4, [r11, #buffer_Flags]
        EOR     r5, r4, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)      ; if UpCalls disabled
        TST     r5, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)          ; or threshold not already exceeded
        BNE     %FT10                                                           ; then skip buffer emptying check

        LDR     r5, [r11, #buffer_Threshold]
        LDR     lr, [r11, #buffer_Size]         ; lr = space in buffer + 1
        CMP     lr, r5                          ; if space >= threshold
        BLHI    SendEmptyingUpCall              ; then issue UpCall
10

 [ dormant_on_last_byte
        BIC	r4, r4, #b_NotDormant
        STR	r4, [r11, #buffer_Flags]        ; then mark as dormant
 ]

        RestPSR r6,,cf                          ; restore old IRQ state
        Pull    "r4-r6,r11,pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: s_NextBlock
;
; in:   r0  = 9
;       r3  = number of bytes to purge before next block
;       r11 ->buffer block
;       r12 ->buffer manager workspace
; out:  r2  ->next byte to be removed
;       r3  = number of bytes in block
;       all other registers preserved
;       C=1 => buffer empty
;
s_NextBlock                                     ; r11 and return address already stacked
        Push    "r4-r9"

        IntOff  r9

        ASSERT  buffer_Flags = 4
        ASSERT  buffer_Start = buffer_Flags +4
        ASSERT  buffer_Size = buffer_Flags +8
        ASSERT  buffer_InsertIndex = buffer_Flags +12
        ASSERT  buffer_RemoveIndex = buffer_Flags +16
        LDMIB   r11, {r4-r8}                    ; r4=flags, r5->start, r6=size, r7=ins, r8=rem

        SUBS    r2, r7, r8                      ; r2 = ins-rem (used space)
        ADDCC   r2, r2, r6
        SUBS    lr, r2, r3                      ; lr = used space left after purge
        MOVCC   lr, #0                          ; if -ve then used space left = 0

        ADDCS   r8, r8, r3                      ; move on rem by amount to purge
        ADDCC   r8, r8, r2                      ;   or by amount in buffer
        CMP     r8, r6                          ; wrap if necessary
        SUBGE   r8, r8, r6
        STR     r8, [r11, #buffer_RemoveIndex]

        EOR     r2, r4, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)      ; if UpCalls disabled
        TST     r2, #(b_SendThresholdUpCalls :OR: b_ThresholdExceeded)          ; or threshold not exceeded
        BNE     %FT10                                                           ; then skip check

        CLC
        SBC     lr, r6, lr                      ; lr = size - used space left - 1 (free space)
        LDR     r2, [r11, #buffer_Threshold]
        CMP     lr, r2                          ; if free space >= threshold
        BLCS    SendEmptyingUpCall              ; then issue UpCall
10
        ADD     r2, r5, r8                      ; return pointer to rem
        CMP     r7, r8
        SUBGE   r3, r7, r8                      ; if ins>=rem then return block [rem..ins-1] (or 0)
        SUBLT   r3, r6, r8                      ;   else return block [rem..size-1]
        BNE     %FT20                           ; if ins<>rem then buffer not empty so return

        CMP     r3, #1                          ; C=0 if no block to return, otherwise C=1
        BICCC   r4, r4, #b_NotDormant           ; if nothing to return
        STRCC   r4, [r11, #buffer_Flags]        ;   then mark as dormant

        TST     r4, #b_GenerateOutputEmpty      ; if output empty events disabled
        BEQ     %FT20                           ;   then exit

        ASSERT (IRQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (FIQ_mode :AND: :NOT: SVC_mode) = 0
        ASSERT (USR_mode :AND: :NOT: SVC_mode) = 0

        ORR     r6, r9, #SVC_mode               ; make mode bits be SVC (IRQ32/IRQ26->SVC32/SVC26)
        RestPSR r6,,cf                          ; set SVC mode, restore interrupt state


        MOV     r0, #Event_OutputEmpty          ; acts as NOP for potential TEQP
        Push    "lr"                            ; save SVC_lr
        LDR     r1, [r11, #buffer_Handle]
        SWI     XOS_GenerateEvent
        Pull    "lr"                            ; restore SVC_lr
20
        RestPSR r9,,cf                          ; restore old CPU mode/IRQ state
        RSBS    r4, r3, #0                      ; C=1 if no block to return, otherwise C=0
        Pull    "r4-r9,r11,pc"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SendFillingUpCall - Generate upcall indicating buffer space is below threshold
;
; in:   r4 = buffer flags
;       r11 -> buffer record
;
; out:  r4 has b_ThresholdExceeded bit set

SendFillingUpCall Entry "r0-r3, r9"
                ORR     r4, r4, #b_ThresholdExceeded
                STR     r4, [r11, #buffer_Flags]
                MOV     r0, #UpCall_BufferFilling
                LDR     r1, [r11, #buffer_Handle]
                WritePSRc I_bit :OR: SVC_mode, r2,,r3
                MOV     r2, #0                  ; indicate filling in r2 as well as in r0 (acts as NOP)
                MOV     r9, #UpCallV
                Push    "lr"
                SWI     XOS_CallAVector         ; issue UpCall
                Pull    "lr"
                RestPSR r3,,cf
                NOP
                EXIT



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SendEmptyingUpCall - Generate upcall indicating buffer space is above or equal to threshold
;
; in:   r4 = buffer flags
;       r11 -> buffer record
;
; out:  r4 has b_ThresholdExceeded bit clear

SendEmptyingUpCall Entry "r0-r3, r9"
                BIC     r4, r4, #b_ThresholdExceeded
                STR     r4, [r11, #buffer_Flags]
                MOV     r0, #UpCall_BufferEmptying
                LDR     r1, [r11, #buffer_Handle]
                WritePSRc I_bit :OR: SVC_mode, r9,,r3
                MOV     r2, #-1                 ; indicate emptying in r2 as well as in r0 (acts as NOP)
                MOV     r9, #UpCallV
                Push    "lr"
                SWI     XOS_CallAVector         ; issue UpCall
                Pull    "lr"
                RestPSR r3,,cf
                NOP
                EXIT



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: findbuffer
;
; in:   r0  = handle of buffer
;
; out:  r0 -> error block if V=1, else preserved.
;       r11-> buffer record.
;
; This call will locate a buffer record within our workspace.  The routine
; scans the list until the current pointer is equal to the end pointer.
;
; The routine clears b31 (block transfer bit) when searching so this need
; not be done by the caller.
;
findbuffer      ROUT
                Push    "r1,lr"
                MOV     r1, r0
                BL      findbufferR1
                Pull    "r1,lr"
                MOVVC   pc, lr                  ; Buffer found, return no error

                ADR     r0, ErrorBlock_BufferManager_BadBuffer
                DoError

                MakeErrorBlock BufferManager_BadBuffer


; findbufferR1
; Test if buffer handle is recognized
;
; In:
; R1 = buffer handle (bit31 may be set)
;
; Out:
; VC = buffer known, VS = unknown
; R11 -> buffer block if VC, else trashed
;
findbufferR1    ROUT
                SavePSR r11
                BICVS   r11, r11, #V_bit        ; set the state of the V bit to a known quantity (clear)
                Push    "r1, r10, r11, lr"
                BIC     r1, r1, #1:SHL:31       ; r1  = true buffer handle

                LDR     r11, BufferBlockAt      ; r11 -> buffer block
                LDR     r10, BufferBlockSize
10
                SUBS    r10, r10, #buffer_SIZE  ; one less buffer
                ASSERT  buffer_Handle = 0
                LDRHS   lr, [r11], #buffer_SIZE ; if one to do, then load handle, and increment pointer
                TEQHS   r1, lr                  ; check for equality
                BHI     %BT10                   ; only loop if CS from SUBS and NE from TEQ

                Pull    "r1, r10, lr"           ; restore r1 and r10, lr = stacked CPSR
                ORRCC   lr, lr, #V_bit          ; Return VS if not found
                SUBCS   r11, r11, #buffer_SIZE  ; Matched, so correct for overshoot
                RestPSR lr,,f                   ; Reset the flags to the desired state
                Pull    "pc"

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Generalised internationalisation routines, these ensure that messages files
; are correctly opened and then return the relevant data.
;
              [ international


; Attempt to open the messages file.

; Must exit with Z set if messages are not there and Z clear+V set on error
OpenMessages    ROUT

                Push    "r0-r3, lr"

                LDR     r3, Flags
                TST     r3, #f_WeHaveMessages                   ; do we have an open messages block?
                Pull    "r0-r3, pc", NE                         ; yes, so don't bother again

                ADR     r0, MessagesWorkspace
                ADRL    r1, resource_file                       ; -> path to be opened
                MOV     r2, #0                                  ; allocate some wacky space in RMA
                SWI     XMessageTrans_OpenFile
                LDRVC   r3, Flags
                ORRVCS  r3, r3, #f_WeHaveMessages               ; clear Z
                STRVC   r3, Flags                               ; assuming it worked mark as having messages
                TEQVS   r0, r0                                  ; set Z on error

                Pull    "r0-r3, pc"                             ; returning VC, VS from XSWI!


; Attempt to close the messages file.

CloseMessages   ROUT

                Push    "r0, lr"

                LDR     r0, Flags
                TST     r0, #f_WeHaveMessages                   ; do we have any messages?
                Pull    "r0, pc", EQ                            ; and return if not!

                ADR     r0, MessagesWorkspace
                SWI     XMessageTrans_CloseFile                 ; yes, so close the file
                LDRVC   r0, Flags
                BICVC   r0, r0, #f_WeHaveMessages
                STRVC   r0, Flags                               ; mark as we don't have them

                Pull    "r0, pc"


; Generate an error based on the error token given.  Does not assume that
; the messages file is open.  Will attempt to open it, then look it up.

MakeErrorWithModuleName Entry "r1-r7"
                ADRL    r4, title
                B       MakeErrorEntry

MakeError       ALTENTRY
                MOV     r4, #0
MakeErrorEntry
                BL      OpenMessages                            ; reopen file if necessary
                PullEnv EQ
                RETURNVS EQ

                ADR     r1, MessagesWorkspace                   ; -> message control block
                MOV     r2, #0
                MOV     r3, #0
                MOV     r5, #0
                MOV     r6, #0
                MOV     r7, #0                                  ; no substitution + use internal buffers
                SWI     XMessageTrans_ErrorLookup

                BL      CloseMessages                           ; attempt to close the doofer

                SETV
                EXIT                                            ; return, r0 -> block, V set

              ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                GET     MoveBlock.s

        [ debug
                InsertNDRDebugRoutines
        ]

                END

