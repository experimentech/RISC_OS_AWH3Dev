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
;* Lastedit: 08 Mar 90 12:05:26 by Harry Meekings *
; OS interface for Clibrary / shared kernel
; Copyright (C) Acorn Computers Ltd., 1988

; The version number below bears no resemblance to any release version
; numbers.  It must be incremented by one each time a non-downwards compatible
; version of the library is produced (ie one where the new stubs will not
; function correctly with an older library).
LibraryVersionNumber            *       6

        GET     Hdr:ListOpts
        GET     Hdr:Machine.<Machine>
        GET     Hdr:APCS.<APCS>
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:FPEmulator

        GBLL    StrongARM
        GBLL    SASTMhatbroken
; This switch should be read as the "maybe split caches, don't do dynamic
; code" switch *only*, other StrongARM things like storing PC+8/PC+12
; differences must be deduced at run time. In 'kernel.s.swiv' this results
; in use of OS_CallASWI so as a result the CallASWI module must be loaded
; for pre RISC OS 3.70 use, and there are a few XOS_SynchroniseCodeAreas too.
StrongARM       SETL {TRUE}
SASTMhatbroken  SETL {TRUE} :LAND: StrongARM

X               EQU     1:SHL:17

; SWIs common to Brazil and Arthur
WriteC          EQU     X+0
WriteS          EQU     X+1
Write0          EQU     X+2
NewLine         EQU     X+3
ReadC           EQU     X+4
CLI             EQU     X+5
Byte            EQU     X+6
Word            EQU     X+7
File            EQU     X+8
Args            EQU     X+9
BGet            EQU     X+&a
BPut            EQU     X+&b
Multiple        EQU     X+&c
Open            EQU     X+&d
ReadLine        EQU     X+&e
Control         EQU     X+&f
GetEnv          EQU     X+&10
Exit            EQU     X+&11
SetEnv          EQU     X+&12
IntOn           EQU     X+&13
IntOff          EQU     X+&14
CallBack        EQU     X+&15
EnterSVC        EQU     X+&16
BreakPt         EQU     X+&17
BreakCtrl       EQU     X+&18
UnusedSWI       EQU     X+&19
KUpdateMEMC     EQU     X+&1A
SetCallBack     EQU     X+&1B
Mouse           EQU     X+&1C

WriteI          EQU     X+&100

; Arthur only SWIs
Module          EQU     X+&1E
ChangeEnv       EQU     X+&40
GenerateError   EQU     &2B               ; X form not sensible
ReadVarVal      EQU     X+&23
SetVarVal       EQU     X+&24
ExitAndDie      EQU     X+&4D

Lib_Init        EQU     &80680            ; shared library initialise

FPE_Version     EQU     X+&40480

Module_Claim    EQU     6                 ; Module reason codes
Module_Free     EQU     7
Module_Extend   EQU     13

; r0 values for swi ChangeEnv
Env_MemoryLimit         EQU     0
Env_UIHandler           EQU     1
Env_PAHandler           EQU     2
Env_DAHandler           EQU     3
Env_AEHandler           EQU     4
Env_ErrorHandler        EQU     6
Env_CallBackHandler     EQU     7
Env_EscapeHandler       EQU     9
Env_EventHandler        EQU     10
Env_ExitHandler         EQU     11
Env_ApplicationSpace    EQU     14
Env_UpCallHandler       EQU     16

Application_Base EQU    &8000

 [ ModeMayBeNonUser
        MACRO
        EnterLeafProcContainingSWI
        FunctionEntry
        MEND

        MACRO
        ExitLeafProcContainingSWI $cond
        Return
        MEND

  |

        MACRO
        EnterLeafProcContainingSWI
        MEND

        MACRO
        ExitLeafProcContainingSWI $cond
        Return "", LinkNotStacked
        MEND
 ]

 [ :DEF:DEFAULT_TEXT
        MACRO
        ErrorBlock $name, $string, $tag, $withdefault
E_$name
        &       Error_$name
        =       "$string", 0
        ALIGN
        ASSERT  "$tag" <> ""
        &       Error_$name
        =       "$tag", 0
        ALIGN
        MEND
 |
        MACRO
        ErrorBlock $name, $string, $tag, $withdefault
E_$name
        ASSERT  "$tag" <> ""
        &       Error_$name
  [ "$withdefault" <> ""
        =       "$tag:$string", 0
  |
        =       "$tag", 0
  ]
        ALIGN
        MEND
 ]

; Arthur error numbers
Error_NameNotFound              *       &124
Error_ValueTooLong              *       &125

Error_IllegalInstruction        *       &80000000
Error_PrefetchAbort             *       &80000001
Error_DataAbort                 *       &80000002
Error_AddressException          *       &80000003
Error_UnknownIRQ                *       &80000004
Error_BranchThroughZero         *       &80000005

Error_FPBase                    *       &80000200
Error_FPLimit                   *       &80000300

; Arthur errors generated by the library
CLib_Error_Base                 *       &800e80
CLib_Error_Range                *       &80

Error_BadMemory                 *       &800e80
Error_UnknownLib                *       &800e81
Error_StubCorrupt               *       &800e82
Error_StaticSizeWrong           *       &800e83
Error_StaticOffsetInconsistent  *       &800e84
Error_UnknownSWI                *       &800e85
Error_OldAPCS_A                 *       &800e86 ; } error number shared
Error_OldAPCS_R                 *       &800e86 ; }

Error_SharedLibraryNeeded       *       &800e90
Error_OldSharedLibrary          *       &800e91
Error_NoVeneer                  *     &80800e92
 [ :DEF:NEW_SWIS
Error_UnknownFn                 *       &800e93
 ]

Error_ReadFail                  *     &80800ea0
Error_WriteFail                 *     &80800ea1

Error_RecursiveTrap             *       &800e00
Error_UncaughtTrap              *       &800e01
Error_NoMainProgram             *       &800e02
Error_NotAvailable              *       &800e03
Error_NoEnvFile                 *       &800e04
Error_NoRoomForEnv              *       &800e05
Error_BadReturnCode             *       &800e06
Error_NoStackForTrapHandler     *       &800e07
Error_Exit                      *       &800e08   ; in non-user mode
Error_NoWorkSpace               *       &800e09

Error_ReservedForOverlayManager1 *      &800efe
Error_ReservedForOverlayManager2 *      &800eff

Error_DivideByZero              *     &80000020
Error_StackOverflow             *     &80000021

        END
