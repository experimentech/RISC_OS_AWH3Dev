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
        SUBT    Macros for Econet debugging

OldOpt  SETA    {OPT}
        OPT     OptNoList+OptNoP1List

; ***********************************
; ***    C h a n g e   L i s t    ***
; ***********************************
;
; Date       Name          Description
; ----       ----          -----------
; 01-Jul-93  BCockburn     Created from Hdr:EcoMacros
; 29-Mar-94  BCockburn     Moved all Econet specific macros in from Hdr:EcoMacros

ARM_config_cp	CP 15	; coprocessor number for configuration control
ARM_ID_reg	CN 0	; processor ID
ARM8A_cache_reg	CN 7	; cache operations, ARM 8 or StrongARM
C0		CN 0
C5		CN 5
C10		CN 10

        MACRO
$a      SetFIQ  $dest,$rega,$regb,$style,$init,$regc
        ; $dest is the label of the code to jump to
        ; $rega is the register to use for the pointer
        ; $regb is the register to use for the instruction
        ; $regc is an extra register required to preserve the mode during initialisation
        [       "$rega" = "" :LOR: "$regb" = "" :LOR: ("$init" = "Init" :LAND: "$regc" = "")
        !       1,"Syntax is: SetFIQ dest, rega, regb [, long [, init, regc]]"
        ]
        [       "$init" = "Init"
$a
        [ :LNOT: No32bitCode                            ; Cope with 32bit CPUs
        MRS     $regc, CPSR                             ; Switch to _32 mode with IRQs and FIQs off
        ORR     $regb, $regc, #I32_bit :OR: F32_bit     ; Has to be done in two stages because RISC OS
        MSR     CPSR_cxsf, $regb                        ; can't return to a 32bit mode and interrupts
        ORR     $regb, $regb, #2_10000                  ; can occur after the MSR but before the following
        MSR     CPSR_cxsf, $regb                        ; instruction.
        ]
        ADR     $rega, FIQVector
        LDR     $regb, =&E51FF004                       ; LDR pc, .+4 = LDR pc, [ pc, #-4 ]
        STR     $regb, [ $rega ], #4
        [ :LNOT: No32bitCode                            ; Cope with 32bit CPUs
        ; And switch back
        MSR     CPSR_cxsf, $regc
        ]
        [ StrongARM
        ; Local version of OS_SynchroniseCodeAreas, because it's far too much hassle
        ; calling a SWI in these circumstances
        MRC     ARM_config_cp, 0, $regc, ARM_ID_reg, C0, 0
        AND     $regc,$regc,#&F000
        TEQS    $regc,#&A000
        BNE     %FT01                                   ; not StrongARM
        ; We want to clean the (32-byte) data cache line containing
        ; the FIQVector word.
        ADR     $regc, FIQVector
        MCR     ARM_config_cp, 0, $regc, ARM8A_cache_reg, C10, 1  ; clean DC entry
        MCR     ARM_config_cp, 0, $regc, ARM8A_cache_reg, C10, 4  ; drain WB
        MCR     ARM_config_cp, 0, $regc, ARM8A_cache_reg, C5, 0   ; flush IC
        ; Normally 4 NOPs could be required to make sure the
        ; modified instruction wasn't in the pipeline. Fortunately
        ; we know that the FIQ vector can't be called within 3
        ; instructions of here (and if an FIQ were to go off, the
        ; pipeline would be flushed anyway).
1
        ]
        |
$a      ADR     $rega, FIQVector + 4
        ]
        [       "$style" = "Long"
        ADRL    $regb, $dest
        |
        ADR     $regb, $dest
        ]
        STR     $regb, [ $rega, #0 ]
        MEND

        MACRO
$a      SetJump $dest,$rega,$regb,$style
        ; $dest is the label of the code to jump to
        ; $rega is the register to use for the instruction
        ; $regb is the register to use for the pointer
        [       "$rega" = "" :LOR: "$regb" = ""
        !       1,"Syntax is: SetJump dest, temp, address [, long]"
        ]
        [       "$style" = "Long"
$a      ADRL    $rega, $dest
        |
$a      ADR     $rega, $dest
        ]
        ADR     $regb, NextJump
        STR     $rega, [ $regb, #0 ]
        MEND

        MACRO
$a      PutFIQ  $rega,$regb
        ; $rega is the register with the instruction in it
        ; $regb is the register to use for the pointer
        [       "$rega" = "" :LOR: "$regb" = ""
        !       1,"Syntax is: PutFIQ instruction, address"
        ]
$a      ADR     $rega, FIQVector + 4
        ADR     $regb, NextJump
        LDR     $regb, [ $regb, #0 ]
        STR     $regb, [ $rega, #0 ]
        MEND

        MACRO
$a      RTFIQ
$a      SUBS    pc, lr, #4
        MEND

        MACRO
$a      WaitForFIQ  $rega,$regb
        ; rega is the register to use for the instruction
        ; regb is the register to use for the pointer
        [       "$rega" = "" :LOR: "$regb" = ""
        !       1,"Syntax is: WaitForFIQ rega, regb"
        ]
$a      ADR     $rega, FIQVector + 4
        ADR     $regb, %FT10
        STR     $regb, [ $rega, #0 ]
        SUBS    pc, lr, #4
        ALIGN   $Alignment
10
        MEND

        MACRO
        MakeNetError    $cond
        [               Debug
        MOV$cond        r8, pc                          ; Goes into Offset_NetError
        ]
        B$cond          NetError
        MEND

        MACRO
        MakeNetError1   $cond
        [               Debug
        MOV$cond        r8, pc                          ; Goes into Offset_NetError
        ]
        B$cond          NetErrorWithSReg1
        MEND

        MACRO
        MakeNetError2   $cond
        [               Debug
        MOV$cond        r8, pc                          ; Goes into Offset_NetError
        ]
        B$cond          NetErrorWithSReg2
        MEND

        MACRO
        MakeReceptionError $cond
        [               Debug
        MOV$cond        r8, pc                          ; Goes into Offset_NetError
        ]
        B$cond          ReceptionError
        MEND

        MACRO
        MakeReceptionError2 $cond
        [               Debug
        MOV$cond        r8, pc                          ; Goes into Offset_NetError
        ]
        B$cond          ReceptionErrorWithSReg2
        MEND

        MACRO
        TurnAroundDelay $reg1,$reg2,$reg3,$delay
        MOV     r10, #IOC
        [               "$delay" = ""                   ; Default case is 40 microseconds
        MOV     $reg1, #80
        |                                               ; Delay value in microseconds
        MOV     $reg1, #(($delay)*2)
        ]
        STRB    $reg1, [ r10, #Timer0LR ]               ; Copies counter to output latch
        LDRB    $reg2, [ r10, #Timer0CL ]               ; Reg2 = low output latch
10                                                      ; loop waiting for 2MHz counter to change
        STRB    $reg1, [ r10, #Timer0LR ]               ; Copies counter to output latch
        LDRB    $reg3, [ r10, #Timer0CL ]               ; Reg3 = low output latch
        TEQS    $reg2, $reg3                            ; Has counter changed?
        BEQ     %BT10                                   ; Else wait for it to change
        ; counter has changed, decrement our count of ticks
        MOV     $reg2, $reg3                            ; Update copy of counter
        SUBS    $reg1, $reg1, #1                        ; Decrement ticks
        BNE     %BT10                                   ; Then continue if not done
; delay has expired
        LDR     r10, HardwareAddress
        MEND

        OPT OldOpt

        END
