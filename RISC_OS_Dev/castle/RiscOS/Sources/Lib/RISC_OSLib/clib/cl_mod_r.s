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
;* Lastedit: 22 Feb 90 16:06:44 by Harry Meekings *
; driver code to call _main for NorCroft C system.
; Version to sit on top of shared library kernel
;
; Copyright (C) Acorn Computers Ltd., 1988.
;

        GBLL    Brazil_Compatible
        GBLS    Calling_Standard
        GBLL    ModeMayBeNonUser
        GBLL    SharedLibrary

Brazil_Compatible  SETL  {FALSE}
Calling_Standard   SETS  "APCS_U"
ModeMayBeNonUser   SETL  {TRUE}
SharedLibrary      SETL  {TRUE}

        GET     h_Regs.s
        GET     h_Brazil.s
        GET     h_modmacro.s

        Module CLib

        AREA    |C$$data|

StaticData
dataStart
        GET     clib.s.cl_data

        AREA    |Lib$$Init|, READONLY

        IMPORT  |CLib_data_end|
        &       2
        &       entriesStart
        &       entriesEnd
        &       dataStart
        &       |CLib_data_end|

        &       5
        &       entries2Start
        &       entries2End
        &       0
        &       0


        AREA    |RTSK$$Data|, READONLY
        IMPORT  |C$$code$$Base|
        IMPORT  |C$$code$$Limit|

        &       EndRTSK-.
        &       |C$$code$$Base|
        &       |C$$code$$Limit|
        &       CLanguageString
        &       0               ; No initialisation
        &       Finalise        ; finalisation
        &       TrapHandler
        &       UncaughtTrapHandler
        &       EventHandler
        &       UnhandledEventHandler
        ; Note: with the shared C library, the stub contains no finalisation
        ; but the library does.  (and the kernel does library as well as
        ; client finalisation).  It needs to be this way rather than the
        ; obvious stub containing finalisation because early versions of the
        ; C library had none.
EndRTSK

        AREA    |C$$code|, CODE, READONLY

entriesStart
        GET     clib.s.cl_entries
entriesEnd

entries2Start
        GET     clib.s.cl_entry2
entries2End

        EXPORT  |__main|
        ; The compiler produces references to this, so it must be defined,
        ; but it had better not be branched to.
|__main|
        DCI     &E7FFFFFF       ; In illegal instruction space
CLanguageString = "C",0
        ALIGN

        LNK     clib.s.cl_body
