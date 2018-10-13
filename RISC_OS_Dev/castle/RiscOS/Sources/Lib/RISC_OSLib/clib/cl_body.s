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
; -*- Mode: Assembler -*-
;* Lastedit: 27 Mar 90 12:50:15 by Harry Meekings *
; body of shared C library (to sit on top of shared library kernel)
;
; Copyright (C) Acorn Computers Ltd., 1988.
;
; 23-Sep-94 AMcC  __rt_ symbols defined and exported (compatible with cc vsn 5 etc)
;

        GET     h_Stack.s

        GET     Hdr:Wimp
        GET     Hdr:TaskWindow

        GBLL    FloatingPointArgsInRegs
FloatingPointArgsInRegs SETL {FALSE}
        [ FloatingPointArgsInRegs
        ! 0, "WARNING: Floating point arguments ARE being passed in FP registers"
        ]

SIGFPE  *       2
SIGILL  *       3
SIGINT  *       4
SIGSEGV *       5
SIGSTAK *       7
SIGOSERROR *    10

ERANGE  *       2
EDOM    *       1

        EXPORT  TrapHandler
        EXPORT  UncaughtTrapHandler
        EXPORT  EventHandler
        EXPORT  UnhandledEventHandler

        MACRO
$Label  DisableFPInterrupts
        ; Disables all FP traps, remembering the trap mask in ip
        ; for subsequent reinstatement by ReEnableFPInterrupts.  (ip must
        ; therefore be left alone by the FP procedures which call this macro).
$Label  MOV     r1, #0
        RFS     ip
        WFS     r1
        MEND

        MACRO
$Label  CheckFPInterrupts $nocheck
        ; Sets r1 to the current fp flags.
        RFS     r1
        MEND

        MACRO
$Label  ReEnableFPInterrupts $nocheck
        ; Reinstates the exception mask state which prevailed before the call
        ; to DisableFPInterrupts; sets r1 to the current fp flags.
$Label
      [ "$nocheck"=""
        RFS     r1
      ]
        WFS     ip
        MEND

        IMPORT  |_signal_real_handler|
        IMPORT  |_armsys_lib_init|
        IMPORT  |_sys_msg|
        IMPORT  |_sys_msg_1|

        IMPORT  |_kernel_fpavailable|
        IMPORT  |_kernel_exittraphandler|
        IMPORT  |_kernel_setreturncode|

        IMPORT  |_kernel_exit|
        IMPORT  |_kernel_osbyte|
        IMPORT  |_kernel_osrdch|
        IMPORT  |_kernel_oswrch|
        IMPORT  |_kernel_osbget|
        IMPORT  |_kernel_osbput|
        IMPORT  |_kernel_osgbpb|
        IMPORT  |_kernel_osword|
        IMPORT  |_kernel_osfind|
        IMPORT  |_kernel_osfile|
        IMPORT  |_kernel_osargs|
        IMPORT  |_kernel_oscli|
        IMPORT  |_kernel_last_oserror|
        IMPORT  |_kernel_system|
        IMPORT  |_kernel_raise_error|

        IMPORT  |_kernel_udiv|
        IMPORT  |_kernel_urem|
        IMPORT  |_kernel_sdiv|
        IMPORT  |_kernel_srem|

        IMPORT  |_ll_sdiv|

        IMPORT  |_kernel_stkovf_split_0frame|
        IMPORT  |_kernel_stkovf_split|

        IMPORT  |_kernel_getmessage|

        EXPORT  |_clib_initialise|
        EXPORT  |x$stack_overflow|
        EXPORT  |x$stack_overflow_1|
        EXPORT  |_raise_stacked_interrupts|
        EXPORT  |x$divtest|
        EXPORT  |x$multiply|
        EXPORT  |_rd1chk|
        EXPORT  |_rd2chk|
        EXPORT  |_rd4chk|
        EXPORT  |_wr1chk|
        EXPORT  |_wr2chk|
        EXPORT  |_wr4chk|
        EXPORT  |_memcpy|
        EXPORT  |_memset|
        EXPORT  |_postmortem|
        EXPORT  |setjmp|
        EXPORT  |longjmp|
        EXPORT  |_exit|
        EXPORT  |_oswrch|
        EXPORT  |_osbget|
        EXPORT  |_osbput|
        EXPORT  |_osgbpb|
        EXPORT  |_osgbpb1|
        EXPORT  |_osrdch|
        EXPORT  |_osfind|
        EXPORT  |_osword|
        EXPORT  |_osfile|
        EXPORT  |_osfile1|
        EXPORT  |_osargs|
        EXPORT  |_oscli|
        EXPORT  |_osbyte|
        EXPORT  |_count|
        EXPORT  |_count1|
        EXPORT  |_default_sigstak_handler|
        EXPORT  |_SignalNumber|

        EXPORT  |_ldfp|
        EXPORT  |_stfp|

        EXPORT  |__fpclassifyf| [FPREGARGS]
        EXPORT  |__fpclassifyd| [FPREGARGS]
        EXPORT  |__signbitf| [FPREGARGS]
        EXPORT  |__signbitd| [FPREGARGS]
        EXPORT  |__copysignf| [FPREGARGS]
        EXPORT  |__copysignd| [FPREGARGS]
        EXPORT  copysign
        EXPORT  copysignf
        EXPORT  nextafter
        EXPORT  nextafterf
        EXPORT  nexttoward
        EXPORT  nexttowardf

        EXPORT  |__rt_stkovf_split_small|
        EXPORT  |__rt_stkovf_split_big|
        EXPORT  |__rt_divtest|
        EXPORT  |__rt_rd1chk|
        EXPORT  |__rt_rd2chk|
        EXPORT  |__rt_rd4chk|
        EXPORT  |__rt_wr1chk|
        EXPORT  |__rt_wr2chk|
        EXPORT  |__rt_wr4chk|

        EXPORT  div
        EXPORT  ldiv
        EXPORT  lldiv
        EXPORT  imaxdiv
        EXPORT  llabs
        EXPORT  imaxabs

        EXPORT  fmin
        EXPORT  fminf
        EXPORT  fmax
        EXPORT  fmaxf

        EXPORT  nearbyint
        EXPORT  nearbyintf
        EXPORT  round
        EXPORT  roundf
        EXPORT  lround
        EXPORT  lroundf
        EXPORT  remainder
        EXPORT  remainderf
        EXPORT  exp
        EXPORT  exp2
        EXPORT  exp2f
        EXPORT  log10
        EXPORT  log
        EXPORT  log2
        EXPORT  log2f
        EXPORT  sqrt
        EXPORT  cbrt
        EXPORT  cbrtf
        EXPORT  cos
        EXPORT  sin
        EXPORT  tan
        EXPORT  asin
        EXPORT  acos
        EXPORT  pow
        EXPORT  powf
        EXPORT  hypot
        EXPORT  hypotf

        GET     clib.s.h_signal

|_clib_initialise|
        FunctionEntry "r1,r2"
        LoadStaticBase ip, a4
        MOV     r0, #-1                 ; read max app space size
        SWI     XOS_ReadDynamicArea
        ADDVC   r2, r2, r0              ; if call works then get end of app space
        MOVVS   r2, #&01000000          ; if call fails then assume 16M
        STR     r2, [ip, #O_app_space_end]
        MOV     a4, #0
        STRB    a4, [ip, #O_inSignalHandler]
        BL      |_armsys_lib_init|
        MOV     a1, #0
        Return  "r1,r2"

 [ ModeMayBeNonUser
        IMPORT  |_lib_shutdown|
        EXPORT  |_clib_finalisemodule|
|_clib_finalisemodule|
        FunctionEntry "a1"
        BL      |_lib_shutdown|
        MOV     a1, #0
        BL      |_exit|
        LDR     r1, [sp], #4            ; free the RMA block addressed by
        MOV     r0, #Module_Free        ; our private word.
        LDR     r2, [r1]
        MOV     r3, #0
        STR     r3, [r1]
        SWI     Module
        [ {CONFIG}<>26
        CLRV    VS                      ; explicitly clear V for 32-bit call case
        ]
        Return
 ]

EventHandler Keep
        CMP     a1, #-1
        MOVNE   a1, #0          ; not interested in events other than escape
        Return  ,LinkNotStacked, NE

        STMFD   sp!, {a2, r14}
        MOV     a1, #SIGINT
        BL      |_signal_real_handler|
        LDMFD   sp!, {a2, r14}
        CMP     a1, #0
        Return  ,LinkNotStacked, EQ

        LoadStaticBase ip, a1
        LDR     a1, [ip, #O__interrupts_off]
        CMP     a1, #0
        MOV     a1, #SIGINT
        STRNE   a1, [ip, #O__saved_interrupt]
        BNE     %FT01
        STR     r14, [sp, #-4]!
        BL      raise
        LDR     r14, [sp], #4
01      MOV     a1, #1          ; we wish to handle it, but not just yet
        Return  ,LinkNotStacked

UnhandledEventHandler Keep
        CMP     a1, #-1
        MOVNE   a1, #0          ; not interested in events other than escape
        Return  ,LinkNotStacked, NE

        LoadStaticBase ip, a1
        LDR     a1, [ip, #O__interrupts_off]
        CMP     a1, #0
        MOV     a1, #SIGINT
        STRNE   a1, [ip, #O__saved_interrupt]
        BNE     %FT02
        STR     r14, [sp, #-4]!
        BL      raise
        LDR     r14, [sp], #4
02      MOV     a1, #1          ; we wish to handle it, but not just yet
        Return  ,LinkNotStacked

|_SignalNumber|
SignalNumber Keep
        ; nb required not to disturb a4
        MOV     a2, #SIGOSERROR
        CMP     a1, #Error_IllegalInstruction
        CMPNE   a1, #Error_PrefetchAbort
        CMPNE   a1, #Error_BranchThroughZero
        MOVEQ   a2, #SIGILL
        CMP     a1, #Error_DataAbort
        CMPNE   a1, #Error_AddressException
        MOVEQ   a2, #SIGSEGV
        LDR     a3, =Error_FPBase
        CMP     a1, a3
        ADD     a3, a3, #Error_FPLimit-Error_FPBase-1
        CMPHS   a3, a1
        MOVHS   a2, #SIGFPE
        CMP     a1, #Error_DivideByZero
        MOVEQ   a2, #SIGFPE
        CMP     a1, #Error_StackOverflow
        MOVEQ   a2, #SIGSTAK
        LDR     a3, =Error_ReadFail
        SUBS    a3, a1, a3
        CMPNE   a3, #Error_WriteFail-Error_ReadFail
        MOVEQ   a2, #SIGSEGV
        MOV     a1, a2
        Return  ,LinkNotStacked

UncaughtTrapHandler Keep
        STMFD   sp!, {a2, r14}
        MOV     a4, a1
        BL      SignalNumber
        LDMFD   sp!, {a2, r14}
        B       RaiseIt

|_raise_stacked_interrupts|            ; called by CLIB.
        LoadStaticBase ip, a1
        MOV     a2, #0
        STR     a2, [ip, #O__interrupts_off]
        LDR     a1, [ip, #O__saved_interrupt]
        CMPS    a1, #0
        Return  ,LinkNotStacked, EQ
        STR     a2, [ip, #O__saved_interrupt]
        B       raise

Finalise Keep
; (There'd better be a stack set up).
        IMPORT  |_lib_shutdown|
        B       |_lib_shutdown|

TrapHandler Keep
        MOV     a4, a1
        STMFD   sp!, {a2, a4, r14}
        BL      SignalNumber
        STR     a1, [sp, #-4]!
        BL      |_signal_real_handler|
        CMP     a1, #0
        LDMFD   sp!, {a1, a2, a4, r14}
        MOVEQ   a1, #0
        Return  ,LinkNotStacked, EQ

RaiseIt
        LoadStaticBase ip, a3
        MOV     a3, #1
        STRB    a3, [ip, #O_inSignalHandler]
        STMFD   sp!, {a2, a4}
        LDMIB   a2, {a2-v6}
        BL      raise               ; raise desired signal
Raised
        B       |_postmortem|       ; and if user insists on returning from
                                    ; signal handler, complain loudly!

div
ldiv
        FunctionEntry "a1"
        MOV     a1, a3
        BL      _kernel_sdiv        ; a1 := a2 / a1, a2 := a2 % a1
        Pull    "ip,lr"
        STMIA   ip, {a1,a2}
        Return  ,LinkNotStacked

imaxdiv NOP                     ; addresses have to be distinct :(
lldiv                           ; a1 -> result, a2 = num.l, a3=num.h, a4=den.l, den.h on stack
        FunctionEntry "a1"
        MOV     a1, a2
        MOV     a2, a3
        MOV     a3, a4
        LDR     a4, [sp, #8]
        BL      _ll_sdiv        ; (a1,a2) := (a1,a2) / (a3,a4), (a3,a4) := (a1,a2) % (a3,a4)
        Pull    "ip,lr"
        STMIA   ip, {a1-a4}
        Return  ,LinkNotStacked

imaxabs NOP                     ; addresses have to be distinct :(
llabs
        TEQ     a2, #0
        Return  ,LinkNotStacked,PL
        RSBS    a1, a1, #0
        RSC     a2, a2, #0
        Return  ,LinkNotStacked

|x$multiply|
; a1 := a2 * a1.
; a2, a3 can be scrambled.
        MUL     a1, a2, a1
        Return  ,LinkNotStacked

        IMPORT  |_kernel_copyerror|
        IMPORT  |_kernel_fault|
|__rt_divtest|
|x$divtest|
; test for division by zero (used when division is voided)
        TEQS    a1, #0
        Return  ,LinkNotStacked, NE
        STR     r0, [sp, #-4]!
        ADR     r0, E_DivideByZero
        B       |_kernel_fault|


|__rt_rd1chk|
|_rd1chk|
        FunctionEntry
        CMP     a1, #&8000
        BLT     readfail
        LoadStaticBase ip, lr
        LDR     lr, [ip, #O_app_space_end]
        CMP     a1, lr                ; max app space size now read at initialisation
        Return  ,,CC
        B       readfail

|__rt_rd2chk|
|_rd2chk|
        FunctionEntry
        CMP     a1, #&8000
        BLT     readfail
        TST     a1, #1
        BNE     readfail
        LoadStaticBase ip, lr
        LDR     lr, [ip, #O_app_space_end]
        CMP     a1, lr                ; max app space size now read at initialisation
        Return  ,,CC
        B       readfail

|__rt_rd4chk|
|_rd4chk|
        FunctionEntry
        CMP     a1, #&8000
        BLT     readfail
        TST     a1, #3
        BNE     readfail
        LoadStaticBase ip, lr
        LDR     lr, [ip, #O_app_space_end]
        CMP     a1, lr                ; max app space size now read at initialisation
        Return  ,,CC
        B       readfail

|__rt_wr1chk|
|_wr1chk|
        FunctionEntry
        CMP     a1, #&8000
        BLT     writefail
        LoadStaticBase ip, lr
        LDR     lr, [ip, #O_app_space_end]
        CMP     a1, lr                ; max app space size now read at initialisation
        Return  ,,CC
        B       writefail

|__rt_wr2chk|
|_wr2chk|
        FunctionEntry
        CMP     a1, #&8000
        BLT     writefail
        TST     a1, #1
        BNE     writefail
        LoadStaticBase ip, lr
        LDR     lr, [ip, #O_app_space_end]
        CMP     a1, lr                ; max app space size now read at initialisation
        Return  ,,CC
        B       writefail

|__rt_wr4chk|
|_wr4chk|
        FunctionEntry
        CMP     a1, #&8000
        BLT     writefail
        TST     a1, #3
        BNE     writefail
        LoadStaticBase ip, lr
        LDR     lr, [ip, #O_app_space_end]
        CMP     a1, lr                ; max app space size now read at initialisation
        Return  ,,CC
        ; and drop into writefail
writefail
        LDR     lr, [sp], #4
        STR     r0, [sp, #-4]!
        ADR     r0, E_WriteFail
        B       |_kernel_fault|

readfail
        LDR     lr, [sp], #4
        STR     r0, [sp, #-4]!
        ADR     r0, E_ReadFail
        B       |_kernel_fault|

        ErrorBlock DivideByZero, "Divide by zero", C06
        ErrorBlock ReadFail, "Illegal read", C07
        ErrorBlock WriteFail, "Illegal write", C08

        MACRO
        NOOP
        & 0
        MEND

; Note that the number of instructions is critical for the SUBLT, hence the NOOPs
|_memcpy|
        FunctionEntry "v1"
01      SUBS    a3, a3, #16
        SUBLT   pc, pc, a3, ASL #2
        LDMIA   a2!, {a4, v1, ip, lr}
        STMIA   a1!, {a4, v1, ip, lr}
        BGT     %B01
        Return  "v1"
        NOOP

        LDMIA   a2!, {a4, v1, ip}
        STMIA   a1!, {a4, v1, ip}
        Return  "v1"
        NOOP

        LDMIA   a2!, {a4, v1}
        STMIA   a1!, {a4, v1}
        Return  "v1"
        NOOP

        LDR     a4, [a2], #4
        STR     a4, [a1], #4
        Return  "v1"

; Note that the number of instructions is critical for the SUBLT
|_memset|
        FunctionEntry
        MOV     a4, a2
        MOV     ip, a2
        MOV     lr, a2
01      SUBS    a3, a3, #16
        SUBLT   pc, pc, a3, ASL #1
        STMIA   a1!, {a2, a4, ip, lr}
        BGT     %B01
        Return

        STMIA   a1!, {a2, a4, ip}
        Return

        STMIA   a1!, {a2, a4}
        Return

        STR     a4, [a1], #4
        Return

mesg    DCB     "mesg"
      [ :DEF:DEFAULT_TEXT
postmortem_title
        DCB     "Postmortem", 0
      ]
postmortem_tag
        DCB     "C65", 0
        ALIGN

        IMPORT  |_desktop_task|
        IMPORT  |_kernel_unwind|
        IMPORT  exit
|_postmortem|
        ; Prepare window manager for output
        ; First check this is a wimp task
        STMFD   sp!, {r0-r5, r14}
        [ :DEF:DEFAULT_TEXT
        ADR     r0, postmortem_title
        ADR     r1, postmortem_tag
        |
        ADR     r0, postmortem_tag
        ]
        BL      |_kernel_getmessage|
        MOV     r5, r0
postmortem0
        LDMFD   sp, {a1-a2}
        LDR     a3, mesg                ; if magic arg2 != "mesg"
        CMP     a2, a3                  ; then go straight onto postmortem
        BNE     postmortem1
        MOV     a2, r5                  ; if so, offer postmortem
        BL      |_sys_msg_1|
        TEQ     r4, #1
        TEQ     a1, #0                  ; if didn't display the button
        TEQNE   a1, #3                  ; or if he selected it, then carry on with postmortem
        MOVNE   a1, #1                  ; otherwise exit(EXIT_FAILURE)
        BNE     exit
postmortem1
        BL      _desktop_task
        TEQ     a1, #0
        BEQ     postmortem2
        LoadStaticAddress __iob + 2 * 40, a2, a3 ; a2 -> stderr
        LDR     r4, [a2, #20]           ; a2 = stderr->__file
        TEQ     r4, #0                  ; istty(stderr->__file)?
        BNE     postmortem2
        MOV     r0, r5                  ; if desktop, and stderr = tty
        SWI     XWimp_CommandWindow     ; then open command window,
        SWI     XOS_WriteI + 14         ; page mode on
postmortem2
        LDMFD   sp!, {r0-r5}
        BL      |_kernel_fpavailable|
        LDR     r14, [sp], #4
        CMP     a1, #0
        MOV     ip, sp
        SUBEQ   sp, sp, #12*4
        BEQ     postmortem_nofp
        STFE    f7, [sp, #-12]!
        STFE    f6, [sp, #-12]!
        STFE    f5, [sp, #-12]!
        STFE    f4, [sp, #-12]!
postmortem_nofp
        STR     sl, [sp, #-4]!
        STMFD   sp!, {v1-v6, fp, ip, r14}
        ADD     a4, sp, #21*4
        LDMDB   a4!, {v1-v6, ip}
        STMFD   sp!, {v1-v6, ip}
        LDMDB   a4!, {v1-v6, ip}
        STMFD   sp!, {v1-v6, ip}
        LDMDB   a4!, {v1-v6, ip}
        STMFD   sp!, {v1-v6, ip}
        SUB     sp, sp, #4
        MOV     v1, #4
02      SUBS    v1, v1, #1
        BLT     %F01
        ADD     a2, sp, #0
        ADD     a1, sp, #4
        BL      |_kernel_unwind|
        CMP     a1, #0
        BLE     %F01
        LDR     a1, [sp, #4+8*4]
        RemovePSRFromReg a1, a2         ; Remove PSR bits safely if necessary
        ADR     a2, Raised
        CMP     a1, a2
        BNE     %B02

        LDR     a1, [sp, #4+7*4]
        ADD     a2, sp, #4
        ADD     a3, sp, #4+21*4
        LDMIA   a3, {v1-v6}
        STMFD   sp!, {v1-v6}
        LDR     a4, [a1]
        LDMFD   a2!, {v1-v6, ip}
        STMIA   a3!, {v1-v6, ip}
        LDMFD   a2!, {v1-v6, ip}
        LDR     r14, [a3, #4]
        LDR     v2, [a4, #pc*4]
        STMIA   a3!, {v1-v6, ip}
        LDMFD   a2!, {v1-v6, ip}
        STMIA   a3!, {v1-v6, ip}
        LDR     a2, [a4, #r0*4]
        LDR     a1, [a1, #4]
        LDMFD   sp!, {v1-v6}
        B       %F02

01
        LDR     v1, [sp, #4+21*4]
        LDR     r14, [sp, #4+(21+8)*4]
        MOV     a1, #-1
        MOV     a2, #0
02
        ADD     sp, sp, #22*4
        MOV     a3, sp
        B       |_backtrace|
        ;MOV     a1, #&4000
        ;MOV     a2, #&4000
        ;MOV     a3, #&20
        ;MOV     a4, #&FF
        ;SWI     XOS_ReadLine
        ;MOVCS   a1, #124
        ;SWICS   XOS_Byte
        ;SWI     XWimp_CloseDown
        ;ADR     a1, debug_cmd
        ;SWI     XOS_CLI
        ;MOVVC   a1, #0
        ;LDRVS   a1, [a1]
        ;TEQ     a1, #0
        ;TEQNE   a1, #&11
        ;MOVEQ   a1, #-1
        ;SWIEQ   XWimp_CommandWindow
        ;MOV     a1, #1
        ;B       exit

debug_cmd
        DCB     "Debug", 0
        ALIGN

|__rt_stkovf_split_small|
|x$stack_overflow|
        B       |_kernel_stkovf_split_0frame|

|__rt_stkovf_split_big|
|x$stack_overflow_1|
        B       |_kernel_stkovf_split|

|_exit|
        [ No32bitCode
        TST     r14, #3
        |
        MRS     a4, CPSR
        TST     a4, #2_01111             ; EQ if USR26 or USR32
        ]
        BLEQ    |_kernel_setreturncode|  ; BL<cond> 32-bit OK
        B       |_kernel_exit|


        ^ 0
sj_v1   #       4
sj_v2   #       4
sj_v3   #       4
sj_v4   #       4
sj_v5   #       4
sj_v6   #       4
  [ {CONFIG}=26
sj_fp   #       4       ; Old APCS-A ordering, which we retain
sj_sp   #       4       ; for compatibility in the 26-bit case
sj_sl   #       4       ; (someone might poke jmp_bufs)
  |
sj_sl   #       4
sj_fp   #       4
sj_sp   #       4
 ]
sj_pc   #       4
sj_f4   #       3*4
sj_f5   #       3*4
sj_f6   #       3*4
sj_f7   #       3*4

|setjmp|
; save everything that might count as a register variable value.
  [ {CONFIG}=26
        STMIA   a1!, {v1-v6, fp, sp}
        STMIA   a1, {sl, lr}
        SUB     v1, a1, #sj_sl
  |
      [ {FALSE} ; this instruction is now deprecated
        STMIA   a1, {v1-v6, sl, fp, sp, lr}
      |
        STMIA   a1!, {v1-v6, sl, fp}
        STR     lr, [a1, #sj_pc - sj_sp]
        STR     sp, [a1], #-sj_sp
      ]
        MOV     v1, a1
  ]
        MOV     v2, lr
        BL      |_kernel_fpavailable|
        CMP     a1, #0
  [ {CONFIG}=26
        STFNEE  f4, [v1, #sj_f4]
        STFNEE  f5, [v1, #sj_f5]
        STFNEE  f6, [v1, #sj_f6]
        STFNEE  f7, [v1, #sj_f7]
  |
        SFMNE   f4, 4, [v1, #sj_f4]
  ]
        MOV     a1, #0
        MOV     lr, v2
        LDMIA   v1, {v1, v2}
        Return  ,LinkNotStacked

|longjmp|
        ADD     v1, a1, #sj_f4
        MOVS    v6, a2
        MOVEQ   v6, #1   ; result of setjmp == 1 on longjmp(env, 0)

        LoadStaticBase ip, a1
        LDRB    a1, [ip, #O_inSignalHandler]
        CMP     a1, #0
        MOVNE   a1, #0
        STRNEB  a1, [ip, #O_inSignalHandler]
        BLNE    |_kernel_exittraphandler|       ; BL<cond> 32-bit OK

        BL      |_kernel_fpavailable|
        CMP     a1, #0
 [ {CONFIG}=26
        LDFNEE  f7, [v1, #sj_f7-sj_f4]
        LDFNEE  f6, [v1, #sj_f6-sj_f4]
        LDFNEE  f5, [v1, #sj_f5-sj_f4]
        LDFNEE  f4, [v1, #sj_f4-sj_f4]
        LDMDB   v1!, {v2-v5}                    ; fudge for atomic {sp,sl,fp} update
        STMFD   sp!, {v2, v3}                   ; push fp, sp
        STR     v4, [sp, #-4]!                  ; push sl
        LDMFD   sp, {sl, fp, sp}
 |
        LFMNE   f4, 4, [v1, #sj_f4-sj_f4]
      [ {FALSE} ; this instruction is now deprecated
        LDMDB   v1!, {sl, fp, sp, lr}
      |
        LDR     lr, [v1, #sj_pc - sj_f4]!
        LDR     sp, [v1, #sj_sp - sj_pc]!
        LDMDB   v1!, {sl, fp}
      ]
        MOV     v5, lr
 ]

 [ ModeMayBeNonUser
   [ {CONFIG}=26
        MOV     a1, pc
        TST     a1, #3
   |
        MRS     a1, CPSR
        MOVS    a1, a1, LSL #28
        TEQHI   a1, #&F0000000                  ; EQ if USR26, USR32 or SYS32
   ]
        BNE     chunks_deallocated
 ]

        ; Now discard all unwanted stack chunks which are deallocatable.
        LDR     v2, [sl, #SC_next-SC_SLOffset]  ; first extension chunk
        ADD     v4, sl, #SC_next-SC_SLOffset    ; base of extension chain
        CMP     v2, #0
        BEQ     chunks_deallocated
deallocate_chunks
        LDR     ip, [v2, #SC_deallocate]
        LDR     v3, [v2, #SC_next]              ; chunk after next
        CMPS    ip, #0
        ADDEQ   v4, v2, #SC_next                ; if it can't be deallocated
        BEQ     deallocate_next_chunk           ; retain it
        MOV     a1, v2
        MOV     lr, pc                          ;) deallocate it if it can be
        MOV     pc, ip                          ;) deallocated, and update the
        STR     v3, [v4]                        ;) chain.
deallocate_next_chunk
        MOVS    v2, v3
        BNE     deallocate_chunks

chunks_deallocated
        MOV     lr, v5
        MOV     a1, v6
        LDMDB   v1, {v1-v6}

        Return  ,LinkNotStacked


|_oswrch|
        B       |_kernel_oswrch|

|_osbget|
        B       |_kernel_osbget|

|_osbput|
        B       |_kernel_osbput|

|_osgbpb|
        STMFD   sp!, {a3, a4, v1, v2, v3} ; v1-v3 just to reserve space
        STR     r14, [sp, #-4]!
        ADD     a3, sp, #4
        BL      |_kernel_osgbpb|
        CMP     a1, #-2
        LDRNE   a1, [sp, #8]            ; new value of len
        LDR     r14, [sp], #4
        ADD     sp, sp, #5*4
        Return  ,LinkNotStacked

|_osgbpb1|
        B       |_kernel_osgbpb|

|_osrdch|
        B       |_kernel_osrdch|

|_osword|
        B       |_kernel_osword|

|_osfind|
        B       |_kernel_osfind|

|_osfile|
        STMFD   sp!, {a3, a4, v1, v2}  ; v1,v2 just to reserve space
        STR     r14, [sp, #-4]!
        ADD     a3, sp, #4
        BL      |_kernel_osfile|
        LDR     r14, [sp], #4
        ADD     sp, sp, #4*4
        Return  ,LinkNotStacked

|_osfile1|
        B       |_kernel_osfile|

|_osargs|
        B       |_kernel_osargs|

|_oscli|
        B       |_kernel_oscli|

|_osbyte|
        B       |_kernel_osbyte|

        LTORG

; double _ldfp(void *x) converts packed decimal at x to a double

|_ldfp| DisableFPInterrupts
        LDFP    f0, [r0, #0]
        MVFD    f0, f0       ; (round to D format)
        ReEnableFPInterrupts
        TST     r1, #&F
        Return  ,LinkNotStacked, EQ
        TST     r1, #&7
        BNE     ldfp_overflow
        B       underflow_error

; void _stfp(double d, void *x) stores packed decimal at x
|_stfp|
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        STFP    f0, [r2, #0]
        |
        STFP    f0, [r0, #0]
        ]
        Return  ,LinkNotStacked

FP_ZERO      * 0
FP_SUBNORMAL * 1
FP_NORMAL    * 2
FP_INFINITE  * 3
FP_NAN       * 4

; These functions always take arguments in registers, to prevent
; signalling NaN problems. The wrapper macros ensure they are
; passed the correct type, so the initial store can't cause an
; exception.
|__fpclassifyf|
        STFS    f0, [sp, #-4]!
        LDR     r0, [sp], #4
        BICS    r0, r0, #&80000000      ; ignore sign; EQ if Exp and M == 0 (and r0 == 0 == FP_ZERO)
        ASSERT  FP_ZERO = 0
        Return  ,LinkNotStacked,EQ
        MOVS    r2, r0, LSR #23         ; R2 := Exp; EQ if Exp == 0
        MOVEQ   r0, #FP_SUBNORMAL
        Return  ,LinkNotStacked,EQ
        TEQ     r2, #&ff
        MOVNE   r0, #FP_NORMAL
        Return  ,LinkNotStacked,NE
        MOVS    r2, r0, LSL #9          ; R2 := M; EQ if M == 0
        MOVEQ   r0, #FP_INFINITE
        MOVNE   r0, #FP_NAN
        Return  ,LinkNotStacked

|__fpclassifyd|
        STFD    f0, [sp, #-8]!
        LDMIA   sp!, {r0, r1}
        BICS    r0, r0, #&80000000      ; ignore sign; EQ if Exp and MHi == 0
        TEQEQS  r1, #0                  ; EQ if Exp and M == 0 (and r0 == 0 == FP_ZERO)
        ASSERT  FP_ZERO = 0
        Return  ,LinkNotStacked,EQ
        MOVS    r2, r0, LSR #20         ; R2 := Exp; EQ if Exp == 0
        MOVEQ   r0, #FP_SUBNORMAL
        Return  ,LinkNotStacked,EQ
        ADDS    r0, r0, #&00100000      ; If Exp = &7FF then R0 := &800xxxxx, so MI
        MOVPL   r0, #FP_NORMAL
        Return  ,LinkNotStacked,PL
        ORRS    r0, r1, r0, LSL #1      ; Look for any non-zero bits (except top bit of R0)
        MOVEQ   r0, #FP_INFINITE
        MOVNE   r0, #FP_NAN
        Return  ,LinkNotStacked

|__signbitf|
        STFS    f0, [sp, #-4]!
        LDR     r0, [sp], #4
        MOV     r0, r0, LSR #31
        Return  ,LinkNotStacked

|__signbitd|
        STFD    f0, [sp, #-8]!
        LDR     r0, [sp], #8
        MOV     r0, r0, LSR #31
        Return  ,LinkNotStacked

        [ FloatingPointArgsInRegs
copysign
        ]
|__copysignd|
        STFD    f1, [sp, #-8]!
        LDR     r0, [sp], #8
        TEQ     r0, #0
        ABSD    f0, f0
        MNFMID  f0, f0
        Return  ,LinkNotStacked

        [ FloatingPointArgsInRegs
copysignf
        ]
|__copysignf|
        STFS    f1, [sp, #-4]!
        LDR     r1, [sp], #4
        TEQ     r1, #0              ; MI if y negative
        ABSS    f0, f0
        MNFMIS  f0, f0
        Return  ,LinkNotStacked

; Back to normal calling conventions

        [ :LNOT:FloatingPointArgsInRegs
copysign
        TEQ     r0, r2
        EORMI   r0, r0, #&80000000
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        Return  ,LinkNotStacked

copysignf
        ; Okay, arguments aren't caller-narrowed. However, narrowing
        ; _always_ preserves sign. Therefore safe to manipulate sign bits
        ; of double forms. If the MVFS triggers a signalling NaN, the
        ; quiet NaN result retains the sign of the (modified) signalling
        ; NaN.
        TEQ     r0, r2
        EORMI   r0, r0, #&80000000
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        MVFS    f0, f0
        Return  ,LinkNotStacked
        ]

nexttoward
        NOP
nextafter
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        CMF     f1, f0
        BEQ     copysign
        BGT     nextup
        BMI     nextdown
        ; unordered
        ADFD    f0, f0, f1              ; do the NaN propagation + exceptions
        Return  ,LinkNotStacked

nextup
        [ FloatingPointArgsInRegs
        STFD    f0, [sp, #-8]!
        LDMFD   sp!, {r0, r1}
        ]
        TEQ     r0, #0
        BPL     nextbigger
        BMI     nextsmaller_neg

nextdown
        [ FloatingPointArgsInRegs
        STFD    f0, [sp, #-8]!
        LDMFD   sp!, {r0, r1}
        ]
        TEQ     r0, #0
        BPL     nextsmaller_pos
        BMI     nextbigger

nextbigger
        CMN     r0, #&00100000
        Return  ,LinkNotStacked,CS      ; catch infinity (NaN already done)
        Return  ,LinkNotStacked,VS

nextbigger_finite
; For all finite cases (both +ve and -ve), it's just a 64-bit +1:
;
; 00000000 00000000 -> 00000000 00000001   0 => smallest subnormal
; 000FFFFF FFFFFFFF -> 00100000 00000000   largest subnormal => smallest normal
; 7FEFFFFF FFFFFFFF -> 7FF00000 00000000   largest normal => infinity
        ADDS    r1, r1, #1
        ADC     r0, r0, #0
        BIC     r2, r0, #&80000000
        CMN     r2, #&00100000
        BVS     nextbigger_ovf
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        CMP     r2, #&00100000
        BLO     nextafter_ufl
        Return  ,LinkNotStacked

nextbigger_ovf
        MUFS    f0,f0,#2                ; generate OVF+INX
        Return  ,LinkNotStacked

nextsmaller_pos
; 7FF00000 00000000 -> 7FEFFFFF FFFFFFFF   +infinity => largest +ve normal
; 00100000 00000000 -> 000FFFFF FFFFFFFF   smallest +ve normal => largest +ve subnormal
; 00000000 00000001 -> 00000000 00000000   smallest +ve subnormal => +0
; 00000000 00000000 -> FFFFFFFF FFFFFFFF      clears carry, so we can catch +0 => -ve case
        SUBS    r1, r1, #1
        SBCS    r0, r0, #0
        STMCSFD sp!, {r0, r1}
        LDFCSD  f0, [sp], #8
        LDFCCD  f0, tiny_neg            ; +0 => smallest -ve subnormal
        CMPCS   r0, #&00100000
        Return  ,LinkNotStacked,CS

nextafter_ufl
        LDFD    f1,tiny_pos             ; generate UFL+INX
        MUFD    f1,f1,#0.5
        Return  ,LinkNotStacked

nextsmaller_neg
; FFF00000 00000000 -> FFEFFFFF FFFFFFFF   -infinity => largest -ve normal
; 80100000 00000000 -> 800FFFFF FFFFFFFF   smallest -ve normal => largest -ve subnormal
; 80000000 00000001 -> 80000000 00000000   smallest -ve subnormal => -0
; 80000000 00000000 -> 7FFFFFFF FFFFFFFF      sets overflow, so we can catch -0 => +ve case
        SUBS    r1, r1, #1
        SBCS    r0, r0, #0
        STMVCFD sp!, {r0, r1}
        LDFVCD  f0, [sp], #8
        LDFVSD  f0, tiny_pos            ; -0 => smallest +ve subnormal
        CMPVC   r0, #&00100000
        Return  ,LinkNotStacked,VC
        B       nextafter_ufl

nextafterf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        MVFS    f1, f1
        [ :LNOT:FloatingPointArgsInRegs
        B       nexttowardf_2
        ]

nexttowardf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
nexttowardf_2
        MVFS    f0, f0
        CMF     f1, f0
        BEQ     copysignf
        BGT     nextupf
        BMI     nextdownf
        ; unordered
        ADFS    f0, f0, f1              ; do the NaN propagation + exceptions
        Return  ,LinkNotStacked

nextupf
        STFS    f0, [sp, #-4]!
        LDR     r0, [sp], #4
        TEQ     r0, #0
        BPL     nextbiggerf
        BMI     nextsmallerf_neg

nextdownf
        STFS    f0, [sp, #-4]!
        LDR     r0, [sp], #4
        TEQ     r0, #0
        BPL     nextsmallerf_pos
        BMI     nextbiggerf

nextbiggerf
        ADD     r1, r0, #&00800000      ; spot infinities - NaNs already
        TEQ     r0, r1                  ; caught in nexttowardf. Return
        Return  ,LinkNotStacked,MI      ; them unchanged (MI if +/-inf)

; For all finite cases (both +ve and -ve), it's just a 32-bit +1:
;
; 00000000 -> 00000001   0 => smallest subnormal
; 007FFFFF -> 00800000   largest subnormal => smallest normal
; 7F7FFFFF -> 7F800000   largest normal => infinity
        ADD     r0, r0, #1
        BIC     r2, r0, #&80000000
        CMN     r2, #&00800000
        BVS     nextbigger_ovf
        STR     r0, [sp, #-4]!
        LDFS    f0, [sp], #4
        CMP     r2, #&00800000
        BCC     nextafter_ufl
        Return  ,LinkNotStacked

nextsmallerf_pos
; 7F800000 -> 7F7FFFFF   +infinity => largest +ve normal
; 00800000 -> 007FFFFF   smallest +ve normal => largest +ve subnormal
; 00000001 -> 00000000   smallest +ve subnormal => +0
; 00000000 -> FFFFFFFF      clears carry, so we can catch +0 => -ve case
        SUBS    r0, r0, #1
        STRCS   r0, [sp, #-4]!
        LDFCSS  f0, [sp], #4
        LDFCCS  f0, tiny_negf           ; -0 => smallest +ve subnormal
        CMPCS   r0, #&00800000
        BCC     nextafter_ufl
        Return  ,LinkNotStacked

nextsmallerf_neg
; FF800000 -> FF7FFFFF   -infinity => largest -ve normal
; 80800000 -> 807FFFFF   smallest -ve normal => largest -ve subnormal
; 80000001 -> 80000000   smallest -ve subnormal => -0
; 80000000 -> 7FFFFFFF      sets overflow, so we can catch -0 => +ve case
        SUBS    r0, r0, #1
        STRVC   r0, [sp, #-4]!
        LDFVCS  f0, [sp], #4
        LDFVSS  f0, tiny_posf           ; -0 => smallest +ve subnormal
        CMPVC   r0, #&00800000
        BVS     nextafter_ufl
        Return  ,LinkNotStacked

tiny_neg
        DCD     &80000000
        DCD     &00000001
tiny_pos
        DCD     &00000000               ; shares next word
tiny_posf
        DCD     &00000001
tiny_negf
        DCD     &80000001

fmax
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        CMF     f1, f0
        MVFGTD  f0, f1
        BVS     fcmpnan
        Return  ,LinkNotStacked,NE
        ; Values are equal. Anding the sign bits will give nice behaviour
        ; for fmax(�0, �0).
        [ FloatingPointArgsInRegs
        STFD    f1, [sp, #-8]!
        STFD    f0, [sp, #-8]!
        LDMIA   sp!, {r0-r3}
        ]
        AND     r0, r0, r2
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        Return  ,LinkNotStacked

fcmpnan CMF     f0, #0
        MVFVSD  f0, f1
        Return  ,LinkNotStacked

fmaxf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        MVFS    f0, f0
        MVFS    f1, f1
        CMF     f1, f0
        MVFGTS  f0, f1
        BVS     fcmpnanf
        Return  ,LinkNotStacked,NE
        [ FloatingPointArgsInRegs
        STFS    f1, [sp, #-4]!
        STFS    f0, [sp, #-4]!
        LDMIA   sp!, {r0-r1}
        ]
        AND     r0, r0, r1
        STR     r0, [sp, #-4]!
        LDFS    f0, [sp], #4
        Return  ,LinkNotStacked

fcmpnanf
        CMF     f0, #0
        MVFVSS  f0, f1
        Return  ,LinkNotStacked

fmin
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        CMF     f1, f0
        MVFMID  f0, f1
        BVS     fcmpnan
        Return  ,LinkNotStacked,NE
        ; Values are equal. Oring the sign bits will give nice behaviour
        ; for fmin(�0, �0).
        [ FloatingPointArgsInRegs
        STFD    f1, [sp, #-8]!
        STFD    f0, [sp, #-8]!
        LDMIA   sp!, {r0-r3}
        ]
        ORR     r0, r0, r2
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        Return  ,LinkNotStacked

fminf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        MVFS    f0, f0
        MVFS    f1, f1
        CMF     f1, f0
        MVFMIS  f0, f1
        BVS     fcmpnanf
        Return  ,LinkNotStacked,NE
        [ FloatingPointArgsInRegs
        STFS    f1, [sp, #-4]!
        STFS    f0, [sp, #-4]!
        LDMIA   sp!, {r0-r1}
        ]
        ORR     r0, r0, r2
        STR     r0, [sp, #-4]!
        LDFS    f0, [sp], #4
        Return  ,LinkNotStacked

nearbyint
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        ]
        DisableFPInterrupts
        RNDD    f0, f0
        ReEnableFPInterrupts nocheck
        Return  ,LinkNotStacked

nearbyintf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        ]
        MVFS    f0, f0
        DisableFPInterrupts
        RNDS    f0, f0
        ReEnableFPInterrupts nocheck
        Return  ,LinkNotStacked

round
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        ]
        CMF     f0, #0
        Return  ,LinkNotStacked,EQ      ; return +/-0 intact
        DisableFPInterrupts             ; just to prevent "inexact"
        ABSMID  f0, f0
        ADFD    f0, f0, #0.5
        RNDDZ   f0, f0
        MNFMID  f0, f0
        ReEnableFPInterrupts nocheck
        Return  ,LinkNotStacked

roundf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        ]
        MVFS    f0, f0
        CMF     f0, #0
        Return  ,LinkNotStacked,EQ      ; return +/-0 intact
        DisableFPInterrupts             ; just to prevent "inexact"
        ABSMIS  f0, f0
        ADFS    f0, f0, #0.5
        RNDSZ   f0, f0
        MNFMIS  f0, f0
        ReEnableFPInterrupts nocheck
        Return  ,LinkNotStacked

lround
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        ]
lround2 RFS     ip
        AND     r2, ip, #&10            ; remember cumulative flag
        BIC     r1, ip, #&10            ; clear cumulative inexact flag
        WFS     r1
        FIX     r0, f0                  ; may trap - that's okay
        RFS     r1
        TST     r1, #&10                ; was inexact?
        BEQ     %FT10
        ; If we get here, we know inexact traps are disabled, and result is inexact
        CMF     f0, #0
        ADFGTD  f0, f0, #0.5            ; no new exceptions possible
        SUFMID  f0, f0, #0.5
        FIXZ    r0, f0
10      ORR     r1, r1, r2              ; re-cumulate inexact flag
        WFS     r1
        Return  ,LinkNotStacked

lroundf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0,r1}
        LDFD    f0, [sp], #8
        ]
        MVFS    f0, f0
        B       lround2

remainder
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        RMFD    f0, f0, f1
        Return  ,LinkNotStacked

remainderf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        MVFS    f0, f0
        MVFS    f1, f1
        RMFS    f0, f0, f1
        Return  ,LinkNotStacked

exp
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        DisableFPInterrupts
        LDFD    f0, [sp], #8
        |
        DisableFPInterrupts
        ]
        EXPD    f0, f0
        ReEnableFPInterrupts
        TST     r1, #&0F
        Return  ,LinkNotStacked, EQ
        TST     r1, #8
        BNE     underflow_error
        B       huge_error

ldfp_overflow
        LDR     r0, [r0, #0]
        CMPS    r0, #0
        BPL     huge_error
huge_negative_result
        MOV     r0, #ERANGE
        LDFD    f0, negative_huge_val   ; @@@@!!!!
Set_errno
        LoadStaticAddress |__errno|, r1
        STR     r0, [r1, #0]
        Return  ,LinkNotStacked
negative_huge_val
        DCD     &FFEFFFFF               ; put constant where it is easy to find
        DCD     &FFFFFFFF

huge_error
        MOV     r0, #ERANGE
        LDFD    f0, huge_val            ; @@@@!!!!
        B       Set_errno
dbl_max
huge_val
        DCD     &7FEFFFFF               ; put constant where it is easy to find
        DCD     &FFFFFFFF
flt_max
        DCD     &7F7FFFFF

negative_error
        MOV     r0, #EDOM
        LDFD    f0, negative_huge_val   ; @@@@!!!!
        B       Set_errno

underflow_error
        MOV     r0, #ERANGE
;        MVFD    f0, #0
        B       Set_errno

log10
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        CMF     f0, #0
        BEQ     huge_negative_result
        BMI     negative_error
        LOGD    f0, f0
        Return  ,LinkNotStacked

log
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        CMF     f0, #0
        BEQ     huge_negative_result
        BMI     negative_error
        LGND    f0, f0
        Return  ,LinkNotStacked

log2
        [ FloatingPointArgsInRegs
        STFD    f0, [sp, #-8]!
        LDMFD   sp!, {r0, r1}
        |
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        ; Now argument is in both {r0,r1} and f0
        CMF     f0, #0
        BLE     log2_calc               ; for <=0 or NaN, just do normal log to get errors
        ; Argument is strictly positive and finite
        MOVS    r2, r0, LSR #20         ; r2 = exponent field
        BNE     %FT30
        ; Subnormal case - normalise
        MOV     r2, #1
10      ADDS    r1, r1, r1
        ADCS    r0, r0, r0
        SUB     r2, r2, #1
        TST     r0, #&00100000
        BEQ     %BT10
30      ORRS    r3, r1, r0, LSL #12     ; EQ if exact power of 2
        ; If exact, just convert exponent field to FP, else
        ; compute log2(e)*log(x)
        BEQ     log2_exact
log2_calc
        LDFE    f1, log2_e
        LGNE    f0, f0
        MUFD    f0, f0, f1
        Return  ,LinkNotStacked
log2_exact
        SUB     r2, r2, #&400
        ADD     r2, r2, #1
        TEQ     r2, #&400               ; EQ if infinity
        FLTNED  f0, r2
        Return  ,LinkNotStacked

log2f
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        MVFS    f0, f0
        STFS    f0, [sp, #-4]!
        LDR     r0, [sp], #4
        ; Now argument is in both r0 and f0
        CMF     f0, #0
        BLE     log2f_calc              ; for <=0 or NaN, just do normal log to get errors
        ; Argument is strictly positive and finite
        MOVS    r2, r0, LSR #23         ; r2 = exponent field
        MOV     r0, r0, LSL #9          ; r0 = fraction
        BNE     %FT30
        ; Subnormal case - normalise
        MOV     r2, #1
10      ADDS    r0, r0, r0
        SUB     r2, r2, #1
        BCC     %BT10
30      TEQ     r0, #0                  ; EQ if exact power of 2
        ; If exact, just convert exponent field to FP, else
        ; compute log2(e)*log(x)
        BEQ     log2f_exact
log2f_calc
        LDFE    f1, log2_e
        LGNE    f0, f0
        MUFS    f0, f0, f1
        Return  ,LinkNotStacked
log2f_exact
        SUB     r2, r2, #&400
        ADD     r2, r2, #1
        TEQ     r2, #&400               ; EQ if infinity
        FLTNES  f0, r2
        Return  ,LinkNotStacked

log2_e  DCD     &00003FFF, &B8AA3B29, &5C17F0BC
loge_2  DCD     &00003FFE, &B17217F7, &D1CF79AC

        IMPORT  scalbln
exp2
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        DisableFPInterrupts
        FIX     r0, f0
        ReEnableFPInterrupts
        ANDS    r1, r1, #&1F            ; inexact or invalid?
        BNE     exp2_inexact
        ; exp2 of an integer - can create an exact result using scalbn
        [ FloatingPointArgsInRegs
        MVFD    f0, #1
        |
        MOV     r2, r0
        ADR     r3, D_one
        LDMIA   r3, {r0,r1}
        ]
        B       scalbln
exp2_inexact
        LDFE    f1, loge_2
        MUFE    f0, f0, f1
        EXPD    f0, f0
        Return  ,LinkNotStacked

        IMPORT  scalblnf
exp2f
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        DisableFPInterrupts
        MVFS    f0, f0
        FIX     r0, f0
        ReEnableFPInterrupts
        ANDS    r1, r1, #&1F            ; inexact or invalid?
        BNE     exp2f_inexact
        ; exp2f of an integer - can create an exact result using scalbn
        [ FloatingPointArgsInRegs
        MVFS    f0, #1
        |
        MOV     r2, r0
        ADR     r3, D_one
        LDMIA   r3, {r0,r1}
        ]
        B       scalblnf
exp2f_inexact
        LDFE    f1, loge_2
        MUFE    f0, f0, f1
        EXPS    f0, f0
        Return  ,LinkNotStacked

D_one   DCFD    1
OneThird
        DCD     &00003FFD, &AAAAAAAA, &AAAAAAAB

sqrt
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        CMF     f0, #0
        BMI     negative_error          ; MI - <
        SQTGED  f0, f0                  ; GE - >=
        Return  ,LinkNotStacked

cbrt
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        CMF     f0, #0
        Return  ,LinkNotStacked,EQ
        LDFVCE  f1, OneThird
        ABSVCE  f0, f0
        POWVCD  f0, f0, f1
        MNFMID  f0, f0
        Return  ,LinkNotStacked

cbrtf
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        LDFD    f0, [sp], #8
        ]
        MVFS    f0, f0
        CMF     f0, #0
        Return  ,LinkNotStacked,EQ
        LDFVCE  f1, OneThird
        ABSVCE  f0, f0
        POWVCS  f0, f0, f1
        MNFMIS  f0, f0
        Return  ,LinkNotStacked

cos
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        DisableFPInterrupts
        LDFD    f0, [sp], #8
        |
        DisableFPInterrupts
        ]
        COSD    f0, f0
        ReEnableFPInterrupts
        ; Only possible error is domain error (due to argument being too
        ; large for range reduction, ie |x| >= 2^31*pi in FPASC 1.13).
        TST     r1, #&07
        Return  ,LinkNotStacked, EQ
        B       negative_error

sin
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        DisableFPInterrupts
        LDFD    f0, [sp], #8
        |
        DisableFPInterrupts
        ]
        SIND    f0, f0
        ReEnableFPInterrupts
        TST     r1, #&07
        Return  ,LinkNotStacked, EQ
        B       negative_error

tan
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        DisableFPInterrupts
        LDFD    f0, [sp], #8
        |
        DisableFPInterrupts
        ]
        TAND    f0, f0
        ReEnableFPInterrupts
        TST     r1, #&07
        Return  ,LinkNotStacked, EQ
        TST     r1, #1
        BNE     negative_error
        B       huge_error

asin
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        DisableFPInterrupts
        LDFD    f0, [sp], #8
        |
        DisableFPInterrupts
        ]
        ASND    f0, f0
        ReEnableFPInterrupts
        ; A range error is not possible; any error must be a domain error.
        ; (And the only plausible error flag is IVO, but I don't check).
        ; Dunno what result is sensible.
        TST     r1, #&07
        Return  ,LinkNotStacked, EQ
        B       negative_error

acos
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1}
        DisableFPInterrupts
        LDFD    f0, [sp], #8
        |
        DisableFPInterrupts
        ]
        ACSD    f0, f0
        ReEnableFPInterrupts
        ; A range error is not possible; any error must be a domain error.
        ; (And the only plausible error flag is IVO, but I don't check).
        ; Dunno what result is sensible.
        TST     r1, #&07
        Return  ,LinkNotStacked, EQ
        B       negative_error


pow
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1, r2, r3}
        DisableFPInterrupts
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        |
        DisableFPInterrupts
        ]
        CMFE    f0, #0
        BEQ     POWFirstArgZero
        POWD    f0, f0, f1
        ReEnableFPInterrupts
        ; Plausibly, there may have been either an overflow or IVO error.
        ; I assume that the former is always a range error, and the latter
        ; corresponds to one of the possible C domain errors (first arg
        ; negative, second non-integer).
        ; (DVZ assumed impossible).
        TST     r1, #&0F
        Return  ,LinkNotStacked, EQ
        TST     r1, #1
        BNE     negative_error
        TST     r1, #8
        BNE     underflow_error
        B       huge_error

POWFirstArgZero
        CMFE    f1, #0
        MVFEQD  f0, #1              ; return 1.0 if both args 0.0
        ReEnableFPInterrupts
        Return  ,LinkNotStacked, GE
        B       negative_error

powf
        [ :LNOT: FloatingPointArgsInRegs
        STMFD   sp!, {r0, r1, r2, r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        MVFS    f0, f0
        MVFS    f1, f1
        POWS    f0, f0, f1
        Return  ,LinkNotStacked

hypot
        [ FloatingPointArgsInRegs
        ABSD    f0, f0
        ABSD    f1, f1
        |
        BIC     r0, r0, #&80000000      ; faster than using ABS, even with FPA
        BIC     r2, r2, #&80000000
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        ADRL    r0, dbl_max             ; use dbl_max not inf to ensure FPA hardware used
        LDFD    f3, [r0]
        CMF     f0, f1
        BVS     hypot_nan
        MVFMID  f2, f0                  ; MI : <
        MVFMID  f0, f1
        MVFMID  f1, f2                  ; ensure f0 >= f1
        CMF     f0, #0                  ; if f0 == 0, then f1 == 0
        Return  ,LinkNotStacked, EQ     ;   divide will be invalid, bail out now
        CMF     f1, f3                  ; if f1 > dbl_max, then f0 == f1 == infinity
        Return  ,LinkNotStacked, GT     ;   divide will be invalid, bail out now
        DVFE    f2, f1, f0              ; 0 <= result <= 1; (only INX possible, not if F0=inf)
        MUFE    f2, f2, f2              ; (only INX possible)
        ADFE    f2, f2, #1              ; 1 <= result <= 2 (only INX possible)
        SQTE    f2, f2                  ; 1 <= result <= sqrt(2) (only INX possible)
        MUFD    f0, f0, f2              ; (OVF/INX possible)
        Return  ,LinkNotStacked
hypot_nan
        CMF     f1, f3
        MVFGTD  f0, f1
        CMFLE   f0, f3
        ADFLED  f0, f0, f1
        Return  ,LinkNotStacked


hypotf
        [ :LNOT:FloatingPointArgsInRegs
        STMFD   sp!, {r0-r3}
        LDFD    f0, [sp], #8
        LDFD    f1, [sp], #8
        ]
        ABSS    f0, f0
        ABSS    f1, f1
        ADRL    r0, flt_max
        LDFS    f3, [r0]
        CMF     f0, f1
        BVS     hypot_nan
        MVFMIS  f2, f0
        MVFMIS  f0, f1
        MVFMIS  f1, f2
        CMF     f0, #0                  ; if f0 == 0, then f1 == 0
        Return  ,LinkNotStacked, EQ     ;   divide will be invalid, bail out now
        CMF     f1, f3                  ; if f1 > flt_max, then f0 == f1 == infinity
        Return  ,LinkNotStacked, GT     ;   divide will be invalid, bail out now
        FDVE    f2, f1, f0
        MUFE    f2, f2, f2
        ADFE    f2, f2, #1
        SQTE    f2, f2
        MUFS    f0, f0, f2
        Return  ,LinkNotStacked
hypotf_nan
        CMF     f1, f3
        MVFGTS  f0, f1
        CMFLE   f0, f3
        ADFLES  f0, f0, f1
        Return  ,LinkNotStacked

|_count|                            ; used when profile option is enabled
        RemovePSRFromReg lr, ip
        LDR     ip, [lr, #0]
        ADD     ip, ip, #1
        STR     ip, [lr, #0]
        ADD     pc, lr, #4          ; condition codes are preserved because
                                    ; nothing in this code changes them!

; What follows is the newer version of support for the profile option,
; using extra space to record the position in the file that this
; count-point corresponds to.
|_count1|                           ; used when profile option is enabled
        RemovePSRFromReg lr, ip
        LDR     ip, [lr, #0]
        ADD     ip, ip, #1
        STR     ip, [lr, #0]
        ADD     pc, lr, #8          ; condition codes are preserved because
                                    ; nothing in this code changes them!


; Default stack overflow handler.

        ErrorBlock StackOverflow, "Stack overflow", C45

|_default_sigstak_handler|
        ADR     r0, E_StackOverflow
        BL      |_kernel_copyerror|
        B       |_kernel_raise_error|

        END
