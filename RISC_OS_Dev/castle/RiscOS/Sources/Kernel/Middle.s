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
        TTL     => Middle

; Compatibility fudgery for OS_ReadLine and ReadLineV with 32-bit addresses

ReadLineSWI
        Push    "r4,lr"
        MOV     r4, #0
        SWI     XOS_ReadLine32
        Pull    "r4,lr"
        ; Pass back NZCV bits
        MRS     r11, CPSR
      [ NoARMT2
        BIC     lr,  lr,  #N_bit+Z_bit+C_bit+V_bit
        AND     r11, r11, #N_bit+Z_bit+C_bit+V_bit
        ORR     lr, lr, r11
      |
        ASSERT (N_bit+Z_bit+C_bit+V_bit)=&F0000000
        MOV     r11, r11, LSR #28
        BFI     lr, r11, #28, #4
      ]
        B       SLVK

ReadLine32SWI
        MOV     r11, #OS_ReadLine
        B       VecSwiDespatch

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; VecRdLine - Read line from input stream (OSWORD 0 equivalent)

; In    r0 -> buffer for characters
;       r1 =  max length of line (excluding carriage return)
;       r2 = lowest character put into buffer
;       r3 = highest character put into buffer
;       r4 = flags
;               bit 31 set means don't reflect characters that don't go in the buffer
;               bit 30 set means reflect with the character in R4
;               bits 7-0 = character to echo if r4 bit 30 is set
;       wp -> OsbyteVars

; Out   r0, r2, r3 corrupted
;       r1 = length of line (excluding carriage return)
;       C=0 => line terminated by return (CR or LF)
;       C=1 => line terminated by ESCAPE

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

VecRdLine ROUT

        Push    "R4-R7"

        MOV     R7, R4                  ; R7 = flags + echo byte
        MOV     R4, R0                  ; R4 -> buffer

        MOV     R6, #0                  ; R6 = index into buffer
        STRB    R6, PageModeLineCount   ; reset page lines

        B       %FT10
        LTORG

05
        SWI     XOS_WriteC
        BVS     ReadLine_Vset
10
        SWI     XOS_ReadC
        BVS     ReadLine_Vset
        BCS     %FT70                   ; ESCAPE

        LDRB    R5, WrchDest            ; does output include VDU ?
        TST     R5, #2
        BNE     %FT30                   ; no, then still buffer

        LDRB    R5, VDUqueueItems       ; is VDU queueing ?
        TEQ     R5, #0
        BNE     %BT05                   ; yes, then just print

30
        TEQ     R0, #127                ; is it DELETE ?
        TEQNE   R0, #8                  ; or backspace?
        BNE     %FT40                   ; no, then skip

        TEQ     R6, #0                  ; yes, then have we any chars ?
        BEQ     %BT10                   ; no, then loop
        SUB     R6, R6, #1              ; go back 1 char
        MOV     R0, #127
        B       %BT05                   ; print DEL and loop

40
        TEQ     R0, #21                 ; is it CTRL-U ?
        BNE     %FT50                   ; no, then skip

        TEQ     R6, #0                  ; yes, then have we any chars ?
        BEQ     %BT10                   ; no, then loop

45
        SWI     XOS_WriteI+127          ; print DELs to start of line
        BVS     ReadLine_Vset
        SUBS    R6, R6, #1
        BNE     %BT45
        B       %BT10                   ; then loop

50
        TEQ     R0, #13                 ; is it CR ?
        TEQNE   R0, #10                 ; or LF ?
        MOVEQ   r0, #13                 ; always store CR if so
        STRB    R0, [R4, R6]            ; store byte in buffer
        BEQ     %FT60                   ; Exit if either

        CMP     R6, R1                  ; is buffer full ?
        MOVCS   R0, #7                  ; if so, beep and loop
        BCS     %BT05

        CMP     R0, R2                  ; is char >= min ?
        CMPCS   R3, R0                  ; and char <= max ?
        ADDCS   R6, R6, #1              ; if so, then inc pointer
        BCS     %FT80
        TST     R7, #&80000000          ; no reflection
        BNE     %BT10                   ; of non-entered chars

80      TST     R7, #&40000000
        ANDNE   R0, R7, #&FF            ; echo char -> R0

        B       %BT05                   ; echo character

60      SWI     XOS_NewLine
        BVS     ReadLine_Vset

; insert code here to call NetVec with R0 = &0D

70
        CLRV
EndReadLine
        MOVVC   R0, R4                  ; restore R0
        LDR     R5, =ZeroPage
        LDRB    R5, [R5, #ESC_Status]
        MOVS    R5, R5, LSL #(32-6)     ; shift esc bit into carry

        MOV     R1, R6                  ; R1 := length
        Pull    "R4-R7, pc"             ; Always claiming vector

ReadLine_Vset
        SETV
        B       EndReadLine

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_Control (deprecated): set handlers

SCTRL   Push    "R0-R3, lr"

        WritePSRc SVC_mode+I_bit, R0    ; need IRQs off to get consistent state
        MOV     R0, #EventHandler
        MOV     R1, R3
        BL      CallCESWI
        STR     R1, [stack, #3*4]

        MOV     R0, #EscapeHandler
        LDR     R1, [stack, #2*4]
        BL      CallCESWI
        STR     R1, [stack, #2*4]

        MOV     R0, #ErrorHandler
        Pull    "R1, R3"
        BL      CallCESWI
        MOV     R0, R1
        MOV     R1, R3

        Pull    "R2, R3, lr"
        ExitSWIHandler


CallCESWI
        Push    lr
        MOV     r2, #0                  ; readonly
        SWI     XOS_ChangeEnvironment
        Pull    pc

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_SetEnv (deprecated): Environment setting

SSTENV  Push    "R0, R1, lr"
        WritePSRc SVC_mode+I_bit, R0    ; no irqs - want consistent set.
        MOV     R0, #AddressExceptionHandler
        MOV     R1, R7
        SWI     XOS_ChangeEnvironment
        MOV     R7, R1

        MOV     R0, #DataAbortHandler
        MOV     R1, R6
        SWI     XOS_ChangeEnvironment
        MOV     R6, R1

        MOV     R0, #PrefetchAbortHandler
        MOV     R1, R5
        SWI     XOS_ChangeEnvironment
        MOV     R5, R1

        MOV     R0, #UndefinedHandler
        MOV     R1, R4
        SWI     XOS_ChangeEnvironment
        MOV     R4, R1

        MOV     R0, #MemoryLimit
        LDR     R1, [stack, #4]
        SWI     XOS_ChangeEnvironment
        STR     R1, [stack, #4]

        MOV     R0, #ExitHandler
        Pull    "R1"
        BL      CallCESWI
        Push    "R1"

        LDR     R12, =ZeroPage
        LDR     R2, [R12, #RAMLIMIT]    ; this is read-only
        MOV     R3, #0                  ; never any Brazil-type buffering
                                        ; m2 tools will complain if there is!
        Pull    "R0, R1, lr"
        ExitSWIHandler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Change user state SWIs
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SINTON  BIC     lr, lr, #I32_bit
        ExitSWIHandler

SINTOFF ORR     lr, lr, #I32_bit
        ExitSWIHandler

SENTERSWI
        TST   lr, #2_11100
        ORREQ lr, lr, #SVC26_mode       ; 26-bit modes -> SVC26
        BICNE lr, lr, #2_11111
        ORRNE lr, lr, #SVC32_mode       ; others -> SVC32
        ExitSWIHandler

SLEAVESWI
        BIC   lr, lr, #2_01111
        ExitSWIHandler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_BreakPt: user breakpoint - unsuitable for debugging SVC mode code!

SBRKPT ROUT

        ADD     sp, sp, #4              ; discard stacked SWI number
        LDR     r10, =ZeroPage
        LDR     r10, [r10, #BrkBf]
        STR     r12, [r10, #16*4]       ; original PSR (with V)
        Pull    r14
        TST     r12, #T32_bit
        SUBEQ   r14, r14, #4
        SUBNE   r14, r14, #2            ; r14 = PC of the SWI
        TST     r12, #2_01111
        STR     r14, [r10, #15*4]       ; PC of the SWI put in.
        BNE     %FT01                   ; NE if not in user mode
        STR     r0, [r10], #4
        MOV     r0, r10
        LDMFD   sp, {r10-r12}

  [ SASTMhatbroken
        STMIA   r0!,{r1-r12}
        STMIA   r0, {r13_usr,r14_usr}^ ; user mode case done.
        SUB     r0, r0, #12*4
  |
        STMIA   r0, {r1-r12, r13_usr, r14_usr}^ ; user mode case done.
        NOP
  ]

10      LDR     stack, =SVCSTK
        LDR     r12, =ZeroPage+BrkAd_ws
        LDMIA   r12, {r12, pc}          ; call breakpoint handler

; Non-user mode case
01      AND     r11, r12, #2_01111      ; SVC26/SVC32 mode?
        TEQ     r11, #SVC_mode
        BEQ     %FT02                   ; [yes]

; Non-user, non-supervisor - must be IRQ, ABT, UND or SYS (no SWIs from FIQ)
        STR     r0, [r10], #4
        MOV     r0, r10
        BIC     r14, r12, #T32_bit      ; don't go into Thumb mode
        LDMFD   sp, {r10-r12}           ; Not banked
        MSR     CPSR_c, R14             ; get at registers r13 and r14
        STMIA   r0, {r1-r12}
        STR     sp, [r0, #12*4]
        STR     r14, [r0, #13*4]
        WritePSRc SVC_mode, r12
        B       %BT10

; Supervisor mode case
02      MOV     r14, r10                ; supervisor mode. R14 in buffer dead
        LDMFD   sp!, {r10-r12}
        STMIA   r14, {r0-r12}
        STR     r13, [r14, #13*4]
        LDR     r12, =&DEADDEAD
        STR     r12, [r14, #14*4]       ; mark R14 as dead
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_UnusedSWI (deprecated): Set the unused SWI handler

SUNUSED Push    "R1, lr"
        MOV     R1, R0
        MOV     R0, #UnusedSWIHandler
        SWI     XOS_ChangeEnvironment
        MOV     R0, R1
        Pull    "R1, lr"
        ExitSWIHandler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_SetCallBack: Set callback flag

SSETCALL ROUT

        MSR     CPSR_c, #I32_bit + SVC32_mode
        LDR     r10, =ZeroPage
        LDRB    r11, [r10, #CallBack_Flag]
        ORR     r11, r11, #CBack_OldStyle
        STRB    r11, [r10, #CallBack_Flag]
        ADD     sp, sp, #4              ; Skip saved R11
        B       back_to_user_irqs_already_off
                                        ; Do NOT exit via normal mechanism

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI read mouse information
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

VecMouse
     WritePSRc SVC_mode+I_bit, R10
     MOV   R10, #MouseV
     Push "lr"
     BL    CallVector
     Pull "lr"
     ExitSWIHandler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_SerialOp when not in kernel
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SerialOp ROUT
        MOV     r10, #SerialV
        Push    lr
        BL      CallVector
        Pull    lr
        BICCC   lr, lr, #C_bit
        ORRCS   lr, lr, #C_bit
        B       SLVK_TestV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Supervisor routines to set default handlers
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; Reset Error and Escape handlers

DEFHAN LDR  R1, =GeneralMOSBuffer         ; decent length error buffer
       ADR  R0, ERRORH
       ADR  R2, ESCAPH
       MOV  R3, #0
       MOV  R4, R14
       SWI  XOS_Control

       MOV  r0, #UpCallHandler
       ADR  r1, DefUpcallHandler
       MOV  r2, #0
       SWI  XOS_ChangeEnvironment

       MOV  PC, R4

; Reset Exception, Event, BreakPoint, UnusedSWI, Exit and CallBack handlers

DEFHN2 MOV  R12, R14
       MOV  R0, #0
       MOV  R1, #0
       MOV  R2, #0
       ADR  R3, EVENTH
       SWI  XOS_Control
       LDR  R0, =ZeroPage+DUMPER
       ADR  R1, NOCALL
       SWI  XOS_CallBack
       ADRL R0, CLIEXIT
       MOV  R1, #0
       MOV  R2, #0
       ADRL R4, UNDEF
       ADRL R5, ABORTP
       ADRL R6, ABORTD
       ADRL R7, ADDREX
       SWI  XOS_SetEnv
       LDR  R0, =ZeroPage+DUMPER
       ADR  R1, DEFBRK
       SWI  XOS_BreakCtrl
       ADRL R0, NoHighSWIHandler
       SWI  XOS_UnusedSWI
       MOV  PC, R12

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; system handlers
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DefUpcallHandler
ESCAPH
EVENTH  MOV     pc, lr


NOCALL  LDR     r0, =ZeroPage               ; default callback routine
        LDR     r14, [r0, #CallBf]
        LDR     r0, [r14, #4*16]
        MSR     SPSR_cxsf, r0
        LDMIA   r14, {r0-r12, r13_usr, r14_usr}^ ; load user's regs
        NOP
        LDR     r14, [r14, #4*15]
        MOVS    pc, r14


ERRORH ROUT

      [ International
        SWI     XOS_EnterOS

        LDR     R0,=ZeroPage+KernelMessagesBlock+4
        ADR     R1,ErrorToken
        MOV     R2,#0
        SWI     XMessageTrans_Lookup
        MOVVC   R12,R2
        ADRVS   R12,ErrorText

01
        LDRB    R0,[R12],#1
        CMP     R0,#32
        BLT     %FT99
        CMP     R0,#"%"
        SWINE   XOS_WriteC
        BVS     %FT99
        BNE     %BT01

        LDRB    R0,[R12],#1              ; Found a %
        CMP     R0,#32
        BLT     %FT99

        CMP     R0,#"0"
        LDREQ   R0,=GeneralMOSBuffer+8
        BEQ     %FT10
        CMP     R0,#"1"
        BNE     %BT01

        LDR     R3,=GeneralMOSBuffer+4
        LDR     R0,[R3]
        LDR     R1,=ZeroPage+MOSConvertBuffer
        MOV     R2,#12
        SWI     XOS_ConvertHex8

02
        LDRB    R1, [R0], #1
        CMP     R1, #"0"
        BEQ     %BT02
        CMP     R1, #0
        SUBEQ   R0, R0, #1
        SUB     R0, R0, #1

10
        SWI     XOS_Write0
        BVC     %BT01

99
        SWI     XOS_NewLine

        LDR     R0, =ZeroPage
        STRB    R0, [R0, #ErrorSemaphore]                 ; Enable error translation, in case we got here in the
                                                        ; middle of looking up an error

        B       GOSUPV                          ; switches back to User mode for us

ErrorToken      =       "Error:"
ErrorText       =       "Error: %0 (Error Number &%1)",0
        ALIGN
      |

        SWI     OS_WriteS
        =       10,13,"Error:",10,13, 0
        ALIGN
        LDR     r0, =GeneralMOSBuffer+4
        BL      PrintError
        B       GOSUPV
      ]


DEFBRK
      [ International
        WritePSRc 0, lr
        MOV     r0, r0
        LDR     r13, =ZeroPage
        LDR     r13, [r13, #BrkBf]
        LDR     r0, [r13, #15*4]
        LDR     r1, =GeneralMOSBuffer
        MOV     r2, #?GeneralMOSBuffer
        SWI     OS_ConvertHex8

; r0 -> address

        MOV     R4,R0
        LDR     R0,=ZeroPage+KernelMessagesBlock+4
        ADR     R1,BreakToken
        LDR     R2,=GeneralMOSBuffer+16
        MOV     R3,#256-16
        SWI     XMessageTrans_Lookup
        MOVVC   R0,R2
        ADRVS   R0,BreakText
        SWI     OS_Write0
        SWI     OS_NewLine

      |
        SWI     OS_WriteS
        = "Stopped at break point at &", 0
        ALIGN
        WritePSRc 0, lr
        MOV     r0, r0
        LDR     r13, =ZeroPage
        LDR     r13, [r13, #BrkBf]
        LDR     r0, [r13, #15*4]
        LDR     r1, =GeneralMOSBuffer
        MOV     r2, #?GeneralMOSBuffer
        SWI     OS_ConvertHex8
        SWI     OS_Write0
        SWI     OS_NewLine
      ]

Quit_Code
        SWI     OS_Exit

      [ International

BreakToken      =       "BreakPt:"
BreakText       =       "Stopped at break point at &%0",0
        ALIGN

      ]

PrintError
        MOV    R12, R14
        LDR    R10, [R0], #4
        SWI    XOS_Write0
        BVS    %FT02
      [ :LNOT: International
        SWI    XOS_WriteS
        =     " (Error number &", 0
        BVS    %FT02
      ]
        LDR    R1,=GeneralMOSBuffer
        MOV    R2, #&E0
        MOV    R0, R10
        SWI    XOS_ConvertHex8       ; can't fail!
01      LDRB   R1, [R0], #1
        CMP    R1, #"0"
        BEQ    %BT01
        CMP    R1, #0
        SUBEQ  R0, R0, #1
      [ International                   ; We might not have any stack so ..
        SUB    R11,R0, #1               ; R11 -> Error number
        LDR    R0, =ZeroPage+KernelMessagesBlock+4
        ADR    R1, PrintErrorString
        MOV    R2,#0                    ; Don't copy message
        SWI    XMessageTrans_Lookup
        ADRVS  R2,PrintErrorString+4    ; If no MessageTrans point at english text.
11
        LDRB   R0,[R2],#1
        CMP    R0,#32
        BLT    %FT13
        CMP    R0,#"%"
        SWINE  XOS_WriteC
        BVS    %FT13
        BNE    %BT11

        LDRB    R0,[R2],#1
        CMP     R0,#32
        BLT     %FT13                   ; Just in case the % is the last character !

        CMP     R0,#"0"                 ; We only know about %0
        BNE     %BT11

12
        LDRB    R0,[R11],#1              ; Print error number.
        CMP     R0,#32
        BLT     %BT11
        SWI     XOS_WriteC
        BVC     %BT12

13
      |
        SUB    R0, R0, #1
        SWI    XOS_Write0
        SWIVC  XOS_WriteI+")"
      ]
        SWIVC  XOS_NewLine
02      MOV    PC, R12

      [ International
PrintErrorString
        =     "Err: (Error number &%0)", 0
        ALIGN
      ]

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Exception handling

DumpyTheRegisters  ROUT
; R0 points at r8 in register dump. r0-r7, PC, PSR saved
; R1 is PSR
; R14 points at error block
; In ABT32 or UND32
        MOV     R7, R14                 ; put error address into unbanked register
        TST     R1, #&0F
  [ SASTMhatbroken
        STMEQIA R0!,{R8-R12}
        STMEQIA R0, {R13,R14}^        ; user mode case done.
        SUBEQ   R0, R0, #5*4
  |
        STMEQIA R0, {R8-R14}^         ; user mode case done.
  ]
        BEQ     UNDEF2

        MRS     R3, CPSR
        AND     R3, R3, #&0F

        ORR     R2, R1, #I32_bit :OR: F32_bit
        BIC     R2, R2, #T32_bit
        MSR     CPSR_c, R2              ; change into original mode
        STMIA   R0, {R8-R12}            ; save the banked registers

        AND     R2, R1, #&0F
        CMP     R2, R3                  ; did abort come from our abort-handling mode?
        MOV     R3, SP
        ADDEQ   R3, R3, #17*4           ; adjust stored SP if so
        LDREQ   R14, =&DEADDEAD         ; and mark R14 as corrupt
        STR     R3, [R0, #5*4]
        EORS    R2, R2, #FIQ_mode       ; Was we in FIQ ? Zero if so
        STR     R14, [R0, #6*4]
        
        BNE     UNDEF2
        MSR     CPSR_c, #I32_bit+F32_bit+ABT32_mode ; into ABT mode so we have a stack (try and preserve SVC stack for any exception dump that's produced)
        Push    "r0"
      [ ZeroPage <> 0
        LDR     R2, =ZeroPage
      ]
        AddressHAL R2
        CallHAL HAL_FIQDisableAll
        Pull    "r0"
UNDEF2
; ... and fall into
UNDEF1
        ; R0 points at R8 in register dump
        ; R7 points at error block
        MSR     CPSR_c, #I32_bit+F32_bit+ABT32_mode ; into ABT mode for exception dump
        SUB     R0, R0, #8*4            ; Make R0 sensible for vector
        MOV     R1, R7
        MOV     R2, #SeriousErrorV_Collect
        MOV     R10, #SeriousErrorV
        BL      CallVector

        MSR     CPSR_c, #I32_bit+F32_bit+SVC32_mode ; into SVC mode
        LDR     sp, =SVCSTK             ; Flatten superstack

        ; Check that ExceptionDump is safe to use
        Push    "R7"                    ; Preserve error ptr
        LDR     R4, =ZeroPage
        MOV     R3, R0
        LDR     R1, [R4, #ExceptionDump]
        MOV     R0, #24
        ADD     R2, R1, #17*4
        ; Must be SVC-writable, user+SVC readable, word aligned
        SWI     XOS_Memory
        AND     r1, r1, #CMA_Completely_UserR+CMA_Completely_PrivR+CMA_Completely_PrivW
        TEQ     r1, #CMA_Completely_UserR+CMA_Completely_PrivR+CMA_Completely_PrivW
        TSTEQ   r2, #3
        BEQ     %FT05
        ; Reset to default location. Unfortunately the Debugger module is a bit
        ; braindead and will only show the contents of the register dump located
        ; within its workspace, so resetting it to the kernel buffer isn't the
        ; best for debugging. But it's better than an infinite abort loop!
        MOV     R0, #ExceptionDumpArea
        LDR     R1, =ZeroPage+DUMPER
        SWI     XOS_ChangeEnvironment
05
        Pull    "R14"                   ; Restore error ptr

        ; Copy the dump from the stack to ExceptionDump
        LDR     R0, [R4, #ExceptionDump]
        LDMIA   R3!, {R1-R2,R4-R9}      ; R0-R7
        STMIA   R0!, {R1-R2,R4-R9}
        LDMIA   R3, {R1-R2,R4-R10}      ; R8-R15, PSR
        STMIA   R0, {R1-R2,R4-R10}

        SUB     R0, R0, #8*4
                                        ; try and put back user R10-R12
        Push    "R4-R6"                 ; for error handler to find on stack
        LDR     R1, [R0, #15*4]
        Push    R1

        LDR     R0, =GeneralMOSBuffer+128 ; so can do deviant sharing !

       [ International
        LDR     r10, =ZeroPage
        LDRB    r10, [r10, #ErrorSemaphore]
        TEQ     r10, #0                 ; if ok to translate error
        MOVEQ   r10, r14
        BEQ     %FT10
       ]

        LDR     r11, [r14], #4          ; Copy error number
        STR     r11, [r0], #4

01      LDRB    r11, [r14], #1          ; Copy error string
        STRB    r11, [r0], #1
        CMP     r11, #"%"               ; Test for "%" near end of string
        BNE     %BT01
10
        SUB     r1, r0, #1              ; point, ready for conversion

        LDR     R2, =GeneralMOSBuffer+?GeneralMOSBuffer
        SUB     r2, r2, r1              ; amount left in buffer

        LDR     R0, =ZeroPage
        LDR     R0, [R0, #ExceptionDump]
        LDR     R0, [R0, #15*4]         ; saved PC
        SWI     XOS_ConvertHex8

      [ International
        LDR     r4, =ZeroPage
        LDRB    r4, [r4, #ErrorSemaphore]
        TEQ     r4, #0
        LDRNE   R0, =GeneralMOSBuffer+128
        BNE     %FT20
        MOV     R4, R0
        MOV     R0, R10
        BL      TranslateError_UseR4
        ; If the exception dump processing takes too long then there's a good
        ; chance the error buffer MessageTrans gave us will get overwritten
        ; before we're able to call OS_GenerateError. Copy the error to the
        ; stack, then copy it back into a MessageTrans block before calling
        ; OS_GenerateError.
        EORS    R4, R0, R10 ; Did TranslateError work?
        BEQ     %FT20
        SUB     SP, SP, #256
        MOV     R4, SP
        MOV     R5, #4
        LDR     R6, [R0]
        STR     R6, [R4]
11
        LDRB    R6, [R0, R5]
        CMP     R6, #0
        STRB    R6, [R4, R5]
        ADD     R5, R5, #1
        BNE     %BT11
        MOV     R0, R4
20
      |
        LDR     R0, =GeneralMOSBuffer+128
      ]

        ; Flatten UND and ABT stacks, jic
        ; Also a convenient way of getting rid of the temp exception dump
        MRS     R2, CPSR
        BIC     R2, R2, #F32_bit + &1F
        ORR     R3, R2, #ABT32_mode
        MSR     CPSR_c, R3                      ; FIQs back on
        LDR     r13_abort, =ABTSTK
        ORR     R3, R2, #UND32_mode
        MSR     CPSR_c, R3
        LDR     r13_undef, =UNDSTK
        ORR     R3, R2, #IRQ32_mode
        MSR     CPSR_c, R3
        LDR     R1, =ZeroPage
      [ ZeroPage = 0
        STR     R1, [R1, #IRQsema]
      |
        MOV     R3, #0
        STR     R3, [R1, #IRQsema]
      ]
        LDR     r13_irq, =IRQSTK

        ; Trigger exception dump processing
        ORR     R3, R2, #SVC32_mode
        MSR     CPSR_c, R3

        ; Let everyone know that the stacks have been reset
        MOV     R2, #SeriousErrorV_Recover
        MOV     R10, #SeriousErrorV
        BL      CallVector

        ; Now enable IRQs and trigger exception dump processing
        MSR     CPSR_c, #SVC32_mode
        MOV     R2, #SeriousErrorV_Report
        MOV     R10, #SeriousErrorV
        BL      CallVector

      [ International
        ; Try and copy error block from stack back to MessageTrans
        LDR     R3, =ZeroPage
        LDRB    R3, [R3, #ErrorSemaphore]
        TEQ     R3, #0
        BNE     %FT30
        CMP     R4, #0 ; Check if original TranslateError call worked (if not, no error block to copy)
        BEQ     %FT30
        SWI     XMessageTrans_CopyError
        ; If TranslateError worked, assume MessageTrans_CopyError worked too
        ADD     SP, SP, #256
30
      ]
        SWI     OS_GenerateError

        LTORG

UNDEF ROUT
        ; In UND32 mode, with a stack
        ; Place exception dump on stack until we can be sure ExceptionDump is safe
        STR     R14, [SP, #-8]!
        SETPSR  F_bit :OR: I_bit, R14
        SUB     SP, SP, #17*4-8
        MOV     R14, SP
        STMIA   R14!, {R0-R7}
        MRS     R1, SPSR
        STR     R1, [R14, #(16-8)*4]            ; save PSR
        MOV     R0, R14
        BL      DumpyTheRegisters
        MakeErrorBlock UndefinedInstruction

ABORTP ROUT
        ; In ABT32 mode, with a stack
        STR     R14, [SP, #-8]!
        SETPSR  F_bit :OR: I_bit, R14
        SUB     SP, SP, #17*4-8
        MOV     R14, SP
        STMIA   R14!, {R0-R7}
        MRS     R1, SPSR
        STR     R1, [R14, #(16-8)*4]            ; save PSR
        MOV     R0, R14
        BL      DumpyTheRegisters
        MakeErrorBlock InstructionAbort

ABORTD ROUT
        ; In ABT32 mode, with a stack
        STR     R14, [SP, #-8]!
        SETPSR  F_bit :OR: I_bit, R14
        SUB     SP, SP, #17*4-8
        MOV     R14, SP
        STMIA   R14!, {R0-R7}
        MRS     R1, SPSR
        STR     R1, [R14, #(16-8)*4]            ; save PSR
        MOV     R0, R14
        BL      DumpyTheRegisters
        MakeErrorBlock DataAbort


ADDREX ROUT
; This really can't happen. Honest
        ; ??? in ABT32 mode, with a stack?
        STR     R14, [SP, #-8]!
        SETPSR  F_bit :OR: I_bit, R14
        SUB     SP, SP, #17*4-8
        MOV     R14, SP
        STMIA   R14!, {R0-R7}
        MRS     R1, SPSR
        STR     R1, [R14, #(16-8)*4]            ; save PSR
        MOV     R0, R14
        BL      DumpyTheRegisters
        MakeErrorBlock AddressException


; Can branch through zero in any mode
; We go through a trampoline which stores R1 and R14 (at R14 on entry)

Branch0_NoTrampoline_DummyRegs
        &       &DEADDEAD, &DEADDEAD
RESET1 ROUT
Branch0_NoTrampoline
        ADR     R14, Branch0_NoTrampoline_DummyRegs
Branch0_FromTrampoline

        LDR     R1, =ZeroPage
        LDR     R1, [R1, #ExceptionDump]
        STMIA   R1, {R0-R12}
        STR     R13, [R1, #13*4]
        LDR     R0, [R14, #0]
        STR     R0, [R1, #1*4]
        LDR     R0, [R14, #4]
        STR     R0, [R1, #14*4]
 [ XScaleJTAGDebug
        MRS     R0, CPSR
        AND     R0, R0, #&1F
        TEQ     R0, #&15        ; Debug mode?
        BNE     %FT20
        LDR     R13, =ZeroPage
        LDR     R0, [R13, #ProcessorFlags]
        ORR     R0, R0, #CPUFlag_XScaleJTAGconnected
        STR     R0, [R13, #ProcessorFlags]
        LDMIA   R1, {R0, R1}
        B       DebugStub
20
 ]
        MOV     R0, #0
        STR     R0, [R1, #15*4]
        MRS     R0, CPSR
        STR     R0, [R1, #16*4]
        SWI     XOS_EnterOS

        LDR     R0, =ZeroPage
        LDR     R0, [R0, #ExceptionDump]
        ADD     R0, R0, #8*4

        ADR     R7, ErrorBlock_BranchThrough0
        B       UNDEF1
        MakeErrorBlock BranchThrough0

 [ XScaleJTAGDebug
        ; Magic from the Multi-ICE User Guide
        ALIGN   32
DebugStub ROUT
        ARM_read_control R13
        AND     R13, R13, #MMUC_I
        ORR     R14, R14, R13, LSR #12
        ARM_read_control R13
        ORR     R13, R13, #MMUC_I
        ARM_write_control R13
        ADR     R13, DebugStubLine2
        MCR     p15, 0, R13, C7, C5, 1
        MCR     p15, 0, R13, C7, C5, 6
10      MRC     p14, 0, R15, C14, C0
        BVS     %BT10
        MOV     R13, #&00B00000
        MCR     p14, 0, R13, C8, C0
20      MRC     p14, 0, R15, C14, C0
        BPL     %BT20
        ARM_read_control R13
        TST     R14, #1
        BICEQ   R13, R13, #MMUC_I
        ARM_write_control R13
        MRC     p14, 0, R13, C9, C0
        MOV     PC, R13
        ALIGN   32
DebugStubLine2
        SPACE   32
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI to call the UpCall vector
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DoAnUpCall ROUT

        Push    lr                  ; better have one of these to pull later !
        MRS     r12, CPSR
      [ NoARMT2
        BIC     r12, r12, #&F0000000
        BIC     r12, r12, #I32_bit:OR:F32_bit
        AND     r10, lr, #&F0000000 ; copy user flags (I bit clear)
        ORR     r10, r10, r12
      |
        MOV     lr, lr, LSR #28
        BIC     r10, r12, #I32_bit:OR:F32_bit
        BFI     r10, lr, #28, #4 ; copy user flags (I bit clear)
      ]
        MSR     CPSR_cf, r10        ; ints on, stay in SVC mode, flags in psr
        MOV     r10, #UpCallV
        BL      CallVector
 [ NoARMT2
        Pull    lr
        BIC     lr, lr, #&F0000000
        MRS     R10, CPSR
        MOV     R10, R10, LSR #(32-4)
        ORR     lr, lr, R10, LSL #(32-4)
 |
        MRS     R10, CPSR
        Pull    lr
        MOV     R10, R10, LSR #28
        BFI     lr, R10, #28, #4
 ]
        ExitSWIHandler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_ChangeEnvironment: Call the environment change vector
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ChangeEnvironment ROUT

        Push    lr
        MOV     R10, #ChangeEnvironmentV
        BL      CallVector
        Pull    lr
        B       SLVK_TestV


; ..... and the default handler .....

AdjustOurSet
        WritePSRc SVC_mode+I_bit, R14
        CMP     R0, #MaxEnvNumber
        BHI     AOS_Silly

  [ {FALSE}
        CMP     r0, #CallBackHandler
        BLEQ    testcallbackpending
  ]

        ADR     R10, AOS_Table
        ADD     R11, R0, R0, LSL #1   ; number * 3
        ADD     R10, R10, R11, LSL #2 ; point at entry

        MOV     R12, R1
        LDR     R11, [R10]
        CMP     R11, #0
        LDRNE   R1,  [R11]
        CMPNE   R12, #0
        STRNE   R12, [R11]

        MOV     R12, R2
        LDR     R11, [R10, #4]
        CMP     R11, #0
        LDRNE   R2,  [R11]
        CMPNE   R12, #0
        STRNE   R12, [R11]

        MOV     R12, R3
        LDR     R11, [R10, #8]
        CMP     R11, #0
        LDRNE   R3,  [R11]
        CMPNE   R12, #0
        STRNE   R12, [R11]

        Pull    pc

AOS_Silly
        ADR     r0, ErrorBlock_BadEnvNumber
      [ International
        BL      TranslateError
      ]
exit_AOS
        SETV
        Pull    "pc"
        MakeErrorBlock BadEnvNumber

AOS_Table
        &  ZeroPage+MemLimit     ;  MemoryLimit
        &  0
        &  0

        &  ZeroPage+UndHan       ; UndefinedHandler
        &  0
        &  0

        &  ZeroPage+PAbHan       ; PrefetchAbortHandler
        &  0
        &  0

        &  ZeroPage+DAbHan       ; DatabortHandler
        &  0
        &  0

        &  ZeroPage+AdXHan       ; AddressExceptionHandler
        &  0
        &  0

        &  0            ; OtherExceptionHandler
        &  0
        &  0

        &  ZeroPage+ErrHan       ; ErrorHandler
        &  ZeroPage+ErrHan_ws
        &  ZeroPage+ErrBuf

        &  ZeroPage+CallAd       ; CallBackHandler
        &  ZeroPage+CallAd_ws
        &  ZeroPage+CallBf

        &  ZeroPage+BrkAd        ; BreakPointHandler
        &  ZeroPage+BrkAd_ws
        &  ZeroPage+BrkBf

        &  ZeroPage+EscHan       ; EscapeHandler
        &  ZeroPage+EscHan_ws
        &  0

        &  ZeroPage+EvtHan       ; EventHandler
        &  ZeroPage+EvtHan_ws
        &  0

        &  ZeroPage+SExitA       ; ExitHandler
        &  ZeroPage+SExitA_ws
        &  0

        &  ZeroPage+HiServ       ; UnusedSWIHandler
        &  ZeroPage+HiServ_ws
        &  0

        &  ZeroPage+ExceptionDump ; ExceptionDumpArea
        &  0
        &  0

        &  ZeroPage+AplWorkSize  ; application space size
        &  0
        &  0

        &  ZeroPage+Curr_Active_Object
        &  0
        &  0

        &  ZeroPage+UpCallHan
        &  ZeroPage+UpCallHan_ws
        &  0

        assert (.-AOS_Table)/12 = MaxEnvNumber

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_ReadDefaultHandler

; In    r0 = environment number

ReadDefaultHandler ROUT

        CMP     r0, #(dhte-defhantab)/12
        MOVHS   r0, #0                  ; return wally value
        ADD     r10, r0, r0, LSL #1     ; *3
        ADD     r10, pc, r10, LSL #2    ; *4 (pc = defhantab-4)
        LDMIB   r10, {r1-r3}            ; gives additional +4
        ExitSWIHandler

defhantab
     & 0                ; wally entry
     & 0
     & 0

     & UNDEF            ; UndefinedHandler
     & 0
     & 0

     & ABORTP           ; PrefetchAbortHandler
     & 0
     & 0

     & ABORTD           ; DataAbortHandler
     & 0
     & 0

     & ADDREX           ; AddressExceptionHandler
     & 0
     & 0

     & 0                ; OtherExceptionHandler
     & 0
     & 0

     & ERRORH           ; ErrorHandler
     & 0
     & GeneralMOSBuffer

     & NOCALL           ; CallBackHandler
     & 0
     & ZeroPage+DUMPER

     & DEFBRK           ; BreakPointHandler
     & 0
     & ZeroPage+DUMPER

     & ESCAPH           ; EscapeHandler
     & 0
     & GeneralMOSBuffer

     & EVENTH           ; EventHandler
     & 0
     & 0

     & CLIEXIT          ; ExitHandler
     & 0
     & 0

     & NoHighSWIHandler ; UnusedSWIHandler
     & 0
     & 0

     & 0                ; exception dump
     & 0
     & 0

     & 0                ; app space size
     & 0
     & 0

     & 0                ; cao pointer
     & 0
     & 0

     & DefUpcallHandler ; upcall handler
     & 0
     & 0

dhte

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = sysinfo handle

; Out   r0 = sysinfo for r0in

ReadSysInfo_Code ROUT
        CMP     r0,#16 ;R0 > 15, so illegal value
        ADDLO   PC, PC, R0,LSL #2
        B       ReadSysInfo_InvalidReason

        B       %FT00
        B       %FT10
        B       %FT20
        B       %FT30
        B       %FT40
        B       %FT50
        B       %FT60
        B       %FT70
        B       %FT80
        B       %FT90
        B       ReadSysInfo_InvalidReason ; ROL's "read OS version" call
        B       %FT110
        B       %FT120
        B       %FT130
        B       %FT140
        B       %FT150

ReadSysInfo_InvalidReason
        ADR     r0, ErrorBlock_BadReadSysInfo
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      ]
        ORR     lr, lr, #V_bit
        ExitSWIHandler

        MakeErrorBlock BadReadSysInfo

; ReadSysInfo(0) - return configured screensize in r0

00
        Push    "r1, r2, lr"
        MOV     r0, #ReadCMOS
        MOV     r1, #ScreenSizeCMOS
        SWI     XOS_Byte
        AND     r0, r2, #&7F            ; top bit is reserved
        LDR     r10, =ZeroPage
        LDR     r10, [r10, #Page_Size]
        MUL     r0, r10, r0
        BL      MassageScreenSize       ; adjust for min and max or default values
        Pull    "r1, r2, lr"
        ExitSWIHandler

; ReadSysInfo(1) - returns configured mode/wimpmode in r0
;                          configured monitortype in r1
;                          configured sync in r2
;                          (all de-autofied)

10
        Push    "r3-r5, lr"
        BL      Read_Configd_Sync
        MOV     r2, r0
        LDR     r1, =ZeroPage+VduDriverWorkSpace+CurrentMonitorType      ; read current monitortype
        LDR     r1, [r1]
        TEQ     r1, #MonitorTypeEDID :SHR: MonitorTypeShift              ; equate EDID=auto in this context
        MOVEQ   r1, #-1
        BL      Read_Configd_Mode
        CMP     r0, #-1                         ; if none of the three are auto, don't bother with translation
        CMPNE   r1, #-1
        CMPNE   r2, #-1
        BNE     %FT15
        BL      TranslateMonitorLeadType        ; issue service or work it out ourselves
        CMP     r0, #-1                         ; if mode auto
        MOVEQ   r0, r3                          ; then replace with default
        CMP     r1, #-1                         ; if monitortype auto
        MOVEQ   r1, r4                          ; then replace with default
        CMP     r2, #-1                         ; if sync auto
        MOVEQ   r2, r5                          ; then replace with default
15
        Pull    "r3-r5, lr"
        ExitSWIHandler

; ReadSysInfo(2)
;
; in:   r0 = 2
;
; out:  r0 = hardware configuration word 0
;               bits 0-7 = special functions chip type
;                               0 => none
;                               1 => IOEB
;               bits 8-15 = I/O control chip type
;                               0 => IOC
;                               1 => IOMD
;                             255 => none
;               bits 16-23 = memory control chip type
;                               0 => MEMC1/MEMC1a
;                               1 => IOMD
;                             255 => none
;               bits 24-31 = video control chip type
;                               0 => VIDC1a
;                               1 => VIDC20
;                             255 => none
;       r1 = hardware configuration word 1
;               bits 0-7 = I/O chip type
;                               0 => absent
;                               1 => 82C710/711 or SMC'665 or similar
;               bits 8-31 reserved (set to 0)
;       r2 = hardware configuration word 2
;               bits 0-7 = LCD controller type
;                               0 => absent
;                               1 => present (type 1) eg A4 portable
;                               2 => present (type 2) eg Stork portable
;               bits 8-15 = IOMD variant (when marked as present in word 0)
;                               0 => IOMD
;                               1 => IOMDL ie ARM7500 (Morris)
;               bits 16-23 = VIDC20 variant (when marked as present in word 0)
;                               0 => VIDC20
;                               1 => VIDC2L ie ARM7500 (Morris)
;               bits 24-31 = miscellaneous flags
;                      bit 24   0 => IIC bus slow (100kHz)
;                               1 => IIC bus fast (400kHz)
;                      bit 25   0 => keep I/O clocks running during idle
;                               1 => stop I/O clocks during idle
;                      bits 26-31 reserved (set to 0)
;       r3 = word 0 of unique machine ID, or 0 if unavailable
;       r4 = word 1 of unique machine ID, or 0 if unavailable

20
        Push    "r9,r14"
        AddressHAL
        SUB     sp, sp, #12
        ADD     a1, sp, #0
        ADD     a2, sp, #4
        ADD     a3, sp, #8
        CallHAL HAL_HardwareInfo
        LDR     r12, =ZeroPage
        LDR     r3, [r12, #RawMachineID+0]
        LDR     r4, [r12, #RawMachineID+4]
        MOV     r3, r3, LSR #8                  ; lose first 8 bits
        ORR     r3, r3, r4, LSL #24             ; and put bits 0..7 of r3 into bits 24..31 of r2
        MOV     r4, r4, LSL #8                  ; lose CRC bits
        MOV     r4, r4, LSR #16                 ; and move the rest down to the bottom
        Pull    "r0-r2,r9,r14"
        ExitSWIHandler

; ReadSysInfo(3)
;
; in:   r0 = 3
;
; out:  r0 = I/O chip base features mask                710     711     665     669     UMC669
;               Bits 0..3   Base IDE type               1       1       1       1       1
;               Bits 4..7   Base FDC type               1       1       1       1       1
;               Bits 8..11  Base parallel type          1       1       1       1       1
;               Bits 12..15 Base 1st serial type        1       1       1       1       1
;               Bits 16..19 Base 2nd serial type        0       1       1       1       1
;               Bits 20..23 Base Config type            1       2       3       4       5
;               Bits 24..31 Reserved                    0       0       0       0       0
;
;       r1 = I/O chip extra features mask               710     711     665     669     UMC669
;               Bits 0..3   IDE extra features          0       0       0       0       0
;               Bits 4..7   FDC extra features          0       0       0       0       0
;               Bits 8..11  parallel extra features     0       0       1       1       1
;               Bits 12..15 1st serial extra features   0       0       1       1       1
;               Bits 16..19 2nd serial extra features   0       0       1       1       1
;               Bits 20..23 config extra features       0       0       0       0       0
;               Bits 24..31 Reserved                    0       0       0       0       0
;
;       r2-r4 undefined (reserved for future expansion)
;

30
        Push    "r9,r14"
        AddressHAL
        SUB     sp, sp, #8
        ADD     a1, sp, #0
        ADD     a2, sp, #4
        CallHAL HAL_SuperIOInfo
        Pull    "a1,a2,r9,r14"
        ExitSWIHandler

; ReadSysInfo(4)
;
; On entry:       r0 = 4 (reason code)
;
; On exit:        r0 = LS32bits of Ethernet Network Address (or 0)
;                 r1 = MS16bits of Ethernet Network Address (or 0)
;
; Use:            Code loaded from the dedicated Network Expansion Card or
;                 from a normal Expansion Card should use the value returned
;                 by this call in preference to a locally provided value.

40
        Push    "r2-r3,r9,r14"
        AddressHAL
        MOV     r0, #0
        CallHAL HAL_ExtMachineID
        Pull    "r2-r3,r9,r14"
        TEQ     r0, #0
        BNE     ExitNoEthernetAddress                   ; Extended machine ID is implemented - don't attempt to extract a MAC from RawMachineID, it's just a hash of the extended ID
        LDR     r0, =ZeroPage
        LDRB    r1, [ r0, #RawMachineID ]               ; The family byte
        TEQ     r1, #&81                                ; Excellent,a custom part - we'll use it
        BNE     ExitNoEthernetAddress
        LDR     r1, [ r0, #RawMachineID+4 ]             ; Acorn's ID and part#
        BIC     r1, r1, #&FF000000                      ; Remove the CRC
        LDR     r0, =&0050A4                            ; Acorn's ID is &005
        TEQ     r1, r0                                  ; Is this an Acorn part?
        LDR     r0, =ZeroPage
        BNE     %FT45
        LDR     r0, [ r0, #RawMachineID ]
        MOV     r0, r0, LSR #8                          ; Lose family byte
        LDR     r1, =&0000A4100000
        ADD     r0, r1, r0                              ; Add Acorn base Ethernet address to number from Dallas
        MOV     r1, #0                                  ; Top 16 bits are zero in Acorn's MAC address allocation
        ExitSWIHandler
45
        MOV     r1, r1, LSR #8                          ; It's unique,but not an Acorn part - extract MAC address verbatim
        Push    "r2"
        LDR     r2, [ r0, #RawMachineID ]
        MOV     r2, r2, LSR #8
        LDRB    r0, [r0, #RawMachineID+4]
        ORR     r0, r2, r0, LSL#24
        Pull    "r2"
        ExitSWIHandler

ExitNoEthernetAddress
        MOV     r0, #0
        MOV     r1, #0
        ExitSWIHandler

; ReadSysInfo(5)
;
; On entry:       r0 = 5 (reason code)
;
; On exit:        r0 = LSW of Raw data from unique id chip
;                 r1 = MSW of Raw data from unique id chip

50
        LDR     r0, =ZeroPage
        LDR     r1, [r0, #RawMachineID+4]
        LDR     r0, [r0, #RawMachineID+0]
        ExitSWIHandler

; ReadSysInfo(6) - read kernel values (Acorn use only; eg. SoftLoad, ROMPatch)
;
; On entry:       r0 =  6 (reason code)
;                 r1 -> input block, 1 word per entry, giving number of value required, terminated by -1
;           OR:   r1 =  0 if just 1 value is required, and this is to beturned in r2
;                 r2 -> output block, 1 word per entry, will be filled in on output
;           OR:   r2 =  number of single value required, if r1 = 0
;
; On exit:
;   if r1 entry != 0:
;         r0,r1,r2 preserved
;         output block filled in, filled in value(s) set to 0 if unrecognised/no longer meaningful value(s)
;   if r1 entry = 0:
;         r0,r1 preserved
;         r2 = single value required, or set to 0 if if unrecognised/no longer meaningful value
;
;  valid value numbers available - see table below
;

60
        Push    "r0-r4"
        ADR     r3,osri6_table
        CMP     r1,#0
        BEQ     %FT64
62
        LDR     r4,[r1],#4
        CMP     r4,#-1
        BEQ     %FT66
        CMP     r4,#osri6_maxvalue
        LDRLS   r0,[r3,r4,LSL #2]
        MOVHI   r0,#0
        ; Fix up the DevicesEnd values
        TEQ     r4,#OSRSI6_Danger_DevicesEnd
        TEQNE   r4,#OSRSI6_DevicesEnd
        STRNE   r0,[r2],#4
        BNE     %BT62
        LDR     r4,=ZeroPage
        LDR     r4,[r4,#IRQMax]
        ADD     r0,r0,r4,LSL #3
        ADD     r0,r0,r4,LSL #2
        STR     r0,[r2],#4
        B       %BT62
64
        CMP     r2,#osri6_maxvalue
        LDRLS   r0,[r3,r2,LSL #2]
        MOVHI   r0,#0
        ; Fix up the DevicesEnd values
        TEQ     r2,#OSRSI6_Danger_DevicesEnd
        TEQNE   r2,#OSRSI6_DevicesEnd
        LDREQ   r1,=ZeroPage
        LDREQ   r1,[r1,#IRQMax]
        ADDEQ   r0,r0,r1,LSL #3
        ADDEQ   r0,r0,r1,LSL #2
        STR     r0,[sp,#2*4]
66
        Pull    "r0-r4"
        ExitSWIHandler

osri6_table
    DCD  ZeroPage+CamEntriesPointer                   ;0
    DCD  ZeroPage+MaxCamEntry                         ;1
    DCD  PageFlags_Unavailable                        ;2
    DCD  ZeroPage+PhysRamTable                        ;3
    DCD  0                                            ;4 (was ARMA_Cleaner_flipflop)
    DCD  ZeroPage+TickNodeChain                       ;5
    DCD  ZeroPage+ROMModuleChain                      ;6
    DCD  ZeroPage+DAList                              ;7
    DCD  ZeroPage+AppSpaceDANode                      ;8
    DCD  ZeroPage+Module_List                         ;9
    DCD  ZeroPage+ModuleSHT_Entries                   ;10
    DCD  ZeroPage+ModuleSWI_HashTab                   ;11
    DCD  0                                            ;12 (was IOSystemType)
    DCD  L1PT                                         ;13
    DCD  L2PT                                         ;14
    DCD  UNDSTK                                       ;15
    DCD  SVCSTK                                       ;16
    DCD  SysHeapStart                                 ;17
    ; **DANGER** - this block conflicts with ROL's allocations
    ; ROL use:
    ; 18 = kernel messagetrans block
    ; 19 = error semaphore
    ; 20 = OS_PrettyPrint dictionary
    ; 21 = Timer 0 latch value
    ; 22 = FastTickerV counts per second
    ; 23 = Vector claimants table
    ; 24 = Number of vectors supported
    ; 25 = IRQSTK
    ; 26 = JTABLE-SWIRelocation
    ; 27 = Address of branch back to OS after SWIs
    DCD  JTABLE-SWIRelocation                         ;18 - relocated base of OS SWI despatch table
    DCD  DefaultIRQ1V+(Devices-DefaultIRQ1Vcode)      ;19 - relocated base of IRQ device head nodes
    DCD  DefaultIRQ1V+(Devices-DefaultIRQ1Vcode)      ;20 - relocated end of IRQ device head nodes. NOTE: Gets fixed up when read
    DCD  IRQSTK                                       ;21 - top of the IRQ stack
    DCD  SoundWorkSpace                               ;22 - workspace (8K) and buffers (2*4K)
    DCD  ZeroPage+IRQsema                             ;23 - the address of the IRQ semaphore
    %    (256-(.-osri6_table))
    ; Use 64+ for a repeat of the danger zone, and our new allocations
    DCD  JTABLE-SWIRelocation                         ;64 - relocated base of OS SWI despatch table
    DCD  DefaultIRQ1V+(Devices-DefaultIRQ1Vcode)      ;65 - relocated base of IRQ device head nodes
    DCD  DefaultIRQ1V+(Devices-DefaultIRQ1Vcode)      ;66 - relocated end of IRQ device head nodes. NOTE: Gets fixed up when read
    DCD  IRQSTK                                       ;67 - top of the IRQ stack
    DCD  SoundWorkSpace                               ;68 - workspace (8K) and buffers (2*4K)
    DCD  ZeroPage+IRQsema                             ;69 - the address of the IRQ semaphore
    ; New allocations
    DCD  ZeroPage+DomainId                            ;70 - current Wimp task handle
    DCD  ZeroPage+OsbyteVars-&A6                      ;71 - OS_Byte vars (previously available via OS_Byte &A6/VarStart)
    DCD  ZeroPage+VduDriverWorkSpace+FgEcfOraEor      ;72
    DCD  ZeroPage+VduDriverWorkSpace+BgEcfOraEor      ;73
    DCD  DebuggerSpace                                ;74
    DCD  DebuggerSpace_Size                           ;75
    DCD  ZeroPage+CannotReset                         ;76
    DCD  ZeroPage+MetroGnome                          ;77 - OS_ReadMonotonicTime
    DCD  ZeroPage+CLibCounter                         ;78
    DCD  ZeroPage+RISCOSLibWord                       ;79
    DCD  ZeroPage+CLibWord                            ;80
    DCD  ZeroPage+FPEAnchor                           ;81
    DCD  ZeroPage+ESC_Status                          ;82
    DCD  ZeroPage+VduDriverWorkSpace+ECFYOffset       ;83
    DCD  ZeroPage+VduDriverWorkSpace+ECFShift         ;84
    DCD  ZeroPage+VecPtrTab                           ;85
    DCD  NVECTORS                                     ;86
    DCD  1                                            ;87 CAM format: 0 = 8 bytes/entry, 1 = 16 bytes/entry
osri6_maxvalue * (.-4-osri6_table) :SHR: 2


; ReadSysInfo(7)  - read 32-bit Abort information for last unexpected abort
;                      (prefetch or data)
;
; On entry:       r0 =  6 (reason code)
;
; On exit:        r1 = 32-bit PC for last abort
;                 r2 = 32-bit PSR for last abort
;                 r3 = fault address for last abort (same as PC for prefetch abort)
;
70
        Push    "r0"
        LDR     r0, =ZeroPage+Abort32_dumparea
        LDMIA   r0, {r2, r3}
        LDR     r1, [r0,#2*4]
        Pull    "r0"
        ExitSWIHandler

; ReadSysInfo(8) - Returns summary information on host platform.
;
; On entry:
;    r0 = 8 (reason code 8)
;
; On exit:
;    r0 = platform class
;         currently defined classes are:
;            0 = unspecified platform (r1,r2 will be 0)
;            1 = Medusa   (currently returned for Risc PC only)
;            2 = Morris   (currently returned for A7000 only)
;            3 = Morris+  (currently returned for A7000+ only)
;            4 = Phoebe   (currently returned for Risc PC 2 only)
;            5 = HAL      (returned for machines running a HAL)
;            all other values currently reserved
;    r1 = 32 additional platform specifier flags (if defined)
;         bits 0..31 = value of flags 0..31 if defined, 0 if undefined
;    r2 = defined status of the 32 flags in r1
;         bits 0..31 = status of flags 0..31
;                      0 = flag is undefined in this OS version
;                      1 = flag is defined in this OS version
;
; The current flag definitions for r1 (1=supported, 0=unsupported) are :
;
;     0     = Podule expansion card(s)
;     1     = PCI expansion card(s)
;     2     = additional processor(s)
;     3     = software power off
;     4     = OS in RAM, else executing in ROM
;     5     = OS uses rotated loads          } If both clear and flagged as
;     6     = OS uses unaligned loads/stores } defined, OS makes no unaligned accesses
;     7..31 reserved (currently undefined)
;
80
        Push    "r9,r14"
        AddressHAL
        SUB     sp, sp, #8
        ADD     a2, sp, #0
        ADD     a3, sp, #4
        CallHAL HAL_PlatformInfo
        Pull    "a2,a3,r9,r14"
        MOV     r0, #5
    [ :LNOT: NoUnaligned
      [ :LNOT: NoARMv6
        ORR     r1, r1, #1:SHL:6 ; ARMv6+
      ELIF :LNOT: SupportARMv6
        ORR     r1, r1, #1:SHL:5 ; <=ARMv5
      ]
    ]
        ORR     r2, r2, #3:SHL:5
        ExitSWIHandler

; OS_ReadSysInfo 9 - Read ROM info
;
; On entry:
;    r0 = 9 (reason code 9)
;    r1 = item number to return
;
; On exit:
;    r0 = pointer to requested string (NULL terminated) or NULL if it wasn't found
;
; Currently defined item numbers are:
;
;    0   = OS name
;    1   = Part number
;    2   = Build date
;    3   = Dealer name
;    4   = User name
;    5   = User address
;    6   = Printable OS description
;    7   = Hardware platform

90
        CMP     R1, #0
        CMPNE   R1, #6
        ADREQ   R0, RSI9_OSname     ; The OS name or description
        BEQ     %FT95
        CMP     R1, #2              ; The build date (dynamically generated)
        BEQ     %FT92
        CMP     R1, #7              ; The hardware platform
        MOVNE   R0, #0              ; Other ones are unimplemented
        BNE     %FT95

        Push    "r1-r3,r9,lr"
        AddressHAL
        MOV     a1,#0               ; Return NULL if HAL doesn't implement it
        CallHAL HAL_PlatformName
        Pull    "r1-r3,r9,lr"
        B       %FT95
92
        LDR     R0, =ROMBuildDate
        LDRB    R1, [R0]
        CMP     R1, #0
        MOVNE   R1, #2              ; Restore R1
        BNE     %FT95
        ; Build date string hasn't been generated yet. Generate it.
        Push    "r0-r3,lr"
        MOV     R0, #ExtROMFooter_BuildDate
        BL      ExtendedROMFooter_FindTag
        CMP     R0, #0              ; Found it?
        STREQ   R0, [R13]
        BEQ     %FT93
        ; For compatability, make this string match the same format as the old
        ; string. Conveniently, this matches the format string used by OS_Word
        ; 14
        LDR     R1, [R13]
        MOV     R2, #?ROMBuildDate
        ADRL    R3, TimeFormat
        SWI     XOS_ConvertDateAndTime
        MOVVS   R0, #0
        STRVS   R0, [R13]
93
        Pull    "r0-r3,lr"
95
        ExitSWIHandler

; OS_ReadSysInfo 11 - Read debug information
;
; On entry:
;    r0 = 11 (reason code 11)
;
; On exit:
;    r0 = pointer to function for debug character output
;    r1 = pointer to function for debug character input
;     

110
        ; Check if both HAL_DebugTX and HAL_DebugRX are available
        Push    "r8-r9,r14"
        MOV     R8, #OSHW_LookupRoutine
        MOV     R9, #EntryNo_HAL_DebugTX
        SWI     XOS_Hardware
        MOVVC   R8, #OSHW_LookupRoutine
        MOVVC   R9, #EntryNo_HAL_DebugRX
        SWIVC   XOS_Hardware
        Pull    "r8-r9,r14"
        BVS     ReadSysInfo_InvalidReason        
        ADR     R0, RSI_DebugTX
        ADR     R1, RSI_DebugRX
        ExitSWIHandler

RSI_DebugTX
        ; In:
        ; R0 = char
        ; Privileged mode
        ; Out:
        ; R0-R3, PSR corrupt
        Push    "r9,r12,r14"
        AddressHAL
        CallHAL HAL_DebugTX
        Pull    "r9,r12,pc"

RSI_DebugRX
        ; In:
        ; Privileged mode
        ; Out:
        ; R0=char read, or -1
        ; R1-R3, PSR corrupt
        Push    "r9,r12,r14"
        AddressHAL
        CallHAL HAL_DebugRX
        Pull    "r9,r12,pc"

; OS_ReadSysInfo 12 - Read extended machine ID
;
; On entry:
;    r0 = 12 (reason code 12)
;    r1 = Pointer to word-aligned buffer, or 0 to read size
;
; On exit:
;    r0 = Size of extended machine ID, or 0 if none/corrupt
;    Buffer in R1 filled, if applicable
;

120
        Push    "r1-r3,r9,r14"
        AddressHAL
        MOV     R0, R1 ; HAL takes the buffer pointer in R0        
        CallHAL HAL_ExtMachineID
        Pull    "r1-r3,r9,r14"
        ExitSWIHandler

; OS_ReadSysInfo 13 - Validate key handler
;
; On entry:
;    r0 = 13 (reason code 13)
;    r1 = key handler address (0 to just return valid flags)
;
; On exit:
;    r0 = Mask of supported key handler flags
;         Or pointer to error block
;

130
        LDR     R0, =KeyHandler_Flag_Wide
        CMP     R1, #0
        ExitSWIHandler EQ
        Push    "R2"
        LDR     R2, [R1, #KeyHandler_KeyTranSize]
        TST     R2, #KeyHandler_HasFlags
        LDRNE   R2, [R1, #KeyHandler_Flags]
        BICNES  R2, R2, R0
        Pull    "R2"
        ExitSWIHandler EQ
        ADR     R0, ErrorBlock_BadKeyHandler
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      ]
        ORR     lr, lr, #V_bit
        ExitSWIHandler

        MakeErrorBlock BadKeyHandler

; OS_ReadSysInfo 14 - Return IIC bus count
;
; On entry:
;    r0 = 14 (reason code 14)
;
; On exit:
;    r0 = Number of IIC buses (as per HAL_IICBuses)
;

140
        Push    "r1-r3,sb,lr"
        AddressHAL
        CallHAL HAL_IICBuses
        Pull    "r1-r3,sb,lr"
        ExitSWIHandler

; OS_ReadSysInfo 15 - Enumerate extended ROM footer entries
;
; On entry:
;    r0 = 15 (reason code 15)
;    r1 = location to start (from previous call) or 0 to begin
;
; On exit:
;    r1 = data pointer, or 0 if end
;    r2 = entry ID (corrupt if r1 == 0)
;    r3 = entry length (corrupt if r1 == 0)

150
        Push    "lr"
        BL      ExtendedROMFooter_Find
        CMP     r0, #-1
        BEQ     %FT158
        MOV     lr, r0                  ; Footer end
        CMP     r1, #0
        LDREQ   r1, [lr]
        MOVEQ   r1, r1, LSL #16
        SUBEQ   r1, lr, r1, LSR #16     ; Footer start
        LDRNEB  r3, [r1, #-1]
        ADDNE   r1, r1, r3              ; If not starting enumeration, advance by length of previous entry
        CMP     r1, lr
        BEQ     %FT158
        LDRB    r2, [r1], #1
        LDRB    r3, [r1], #1
        B       %FT159
158
        MOV     r1, #0
159
        MOV     r0, #15
        Pull    "lr"
        ExitSWIHandler

;
; Extended ROM footer functions
;
; These operate on a new tag-based structure located at the end of the ROM
; image. Each entry consists of a one-byte ID, a one-byte length, and then N
; bytes of data. The length byte doesn't count the two initial header bytes.
;
; The end of the list is implicity terminated by a footer word; the footer word
; contains the length of the structure in the low two bytes (minus the length of
; the footer word), and a 16-bit CRC in the top two bytes (again, minus the
; footer word). The footer word will be word-aligned, but everything else is
; assumed to be byte aligned.
;
; Current tags:
;
; 0     ROM build date, stored as 5-byte time (length = 5)
; 1     Compressed ROM softload hint (length = 8). First word is negative
;       checksum of uncompressed image, second word is OS header offset.
; 2     Debug symbols offset (length = 4). Byte offset from the start of the ROM
;       to the debug symbols.
;

ExtendedROMFooter_Find  ROUT
        ; Find the header word for the extended ROM footer. Returns -1 if not found.
        Push    "r1-r4,lr"
        LDR     r4, =ZeroPage
        LDR     r0, [r4, #ExtendedROMFooter]
        CMP     r0, #0
        BNE     %FT10
        ; Examine the end of the ROM image
        ; Footer should be located just before the standard 20 byte footer
        LDR     r2, =ROM+OSROM_ImageSize*1024-24
        LDR     r1, [r2]
        CMP     r1, #-1
        MOVEQ   r0, r1
        BEQ     %FT09
        ; Check CRC
        MOV     r1, r1, LSL #16
        SUB     r1, r2, r1, LSR #16
        MOV     r3, #1
        SWI     XOS_CRC
        MOVVS   r0, #-1
        BVS     %FT09
        LDR     r1, [r2]
        CMP     r0, r1, LSR #16
        MOVNE   r0, #-1
        MOVEQ   r0, r2
09
        STR     r0, [r4, #ExtendedROMFooter]
10
        Pull    "r1-r4,pc"

ExtendedROMFooter_FindTag  ROUT
        ; Find the tag number given in R0.
        ; Returns data pointer in R0 & length in R1 on success.
        ; Returns 0 in R0 (and corrupt R1) for failure.
        Push    "r2-r3,lr"
        MOV     r2, r0
        BL      ExtendedROMFooter_Find
        CMP     r0, #-1
        BEQ     %FT09
        MOV     r3, r0
        LDR     r0, [r0]
        MOV     r0, r0, LSL #16
        SUB     r0, r3, r0, LSR #16
05
        CMP     r0, r3
        BEQ     %FT09
        LDRB    lr, [r0], #1
        LDRB    r1, [r0], #1
        CMP     lr, r2
        BEQ     %FT10
        ADD     r0, r0, r1
        B       %BT05
09
        MOV     r0, #0
10
        Pull    "r2-r3,pc"

RSI9_OSname    = "$SystemName $VString",0

        ALIGN
        LTORG

        END
