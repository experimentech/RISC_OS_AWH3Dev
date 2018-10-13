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
; > Sources.Macros

;-----------------------------------------------------------------------------
; TestMinusOne $reg
;
;       Checks if a register holds the value -1, without corrupting V bit.
;       On exit, Z set if register held -1.
;
        MACRO
$label  TestMinusOne $reg
$label  TEQ     $reg, $reg, ASR #31
        TEQCC   pc, #0
        MEND

;-----------------------------------------------------------------------------
; adrdeb $reg, $addr, $cc
;
;       When debugging is enabled we sometimes need an ADRL instead of an ADR.
;
        MACRO
$label  adrdeb  $reg, $addr, $cc
 [ debug
$label  ADR$cc.L $reg, $addr
 |
$label  ADR$cc   $reg, $addr
 ]
        MEND

;-----------------------------------------------------------------------------
; IRQOff  $tmp, $reg
;
;       Turn IRQs off and save the current PSR in $reg.
;       $reg is optional.
;
        MACRO
$label  IRQOff  $tmp, $reg

        LCLS    oldpsr
        [ "$reg" = ""
oldpsr  SETS    "$tmp"
        |
oldpsr  SETS    "$reg"
        ]
$label  MRS     $oldpsr, CPSR
        ORR     $tmp, $oldpsr, #I32_bit
        MSR     CPSR_c, $tmp
        MEND

;-----------------------------------------------------------------------------
; SwpPSR $reg, $psr, $tmp
;
;       Save 32-bit CPSR in $reg and set CPSR c bits from 26-bit style $psr.
;
        MACRO
$label  SwpPSR $reg, $psr, $tmp

$label  WritePSRc $psr, $tmp,, $reg
        MEND

;-----------------------------------------------------------------------------
; SetPSR  $reg, $cond, $fields
;
;       Set the PSR from bits in $reg (normally saved by IRQOff or FIQOff).
;
        MACRO
$label  SetPSR  $reg, $cond, $fields

      [ "$fields" = ""
        MSR$cond CPSR_cf, $reg
      |
        MSR$cond CPSR_$fields , $reg
      ]
        MEND

;-----------------------------------------------------------------------------
; LCBlock $lcb, $hand
;
;       Point $lcb to logical channel block for $hand.
;
        MACRO
$label  LCBlock $lcb, $hand
      [ HAL
        MOV     $lcb, $hand
      |
        ASSERT  LCBSize=20
$label  ADR     $lcb, ChannelBlock
        ADD     $lcb, $lcb, $hand, LSL #4
        ADD     $lcb, $lcb, $hand, LSL #2
      ]
        MEND

;-----------------------------------------------------------------------------
; PhysToDMAQ    $que, $phs
;
;       Point $que to the DMA queue for physical channel $phs.
;
        MACRO
$label  PhysToDMAQ      $que, $phs
      [ HAL
        ! 1, "Don't use PhysToDMAQ in HAL version!"
      |
        ASSERT  DMAQSize=16
$label  ADR     $que, DMAQueues
        ADD     $que, $que, $phs, LSL #4        ; DMAQueue + phys * 16
      ]
        MEND

;-----------------------------------------------------------------------------
; IOMDBase      $reg, $cc
;
;       Sets $reg to point to IOMD base address.
;
        MACRO
$label  IOMDBase $reg, $cc
      [ HAL
        ! 1, "Don't use IOMDBase in HAL version!"
      |
$label  MOV$cc  $reg, #IOMD_Base
      ]
        MEND

;-----------------------------------------------------------------------------
; DMARegBlk     $blk, $phs
;
;       Point $blk to the IOMD DMA register block for physical channel $phs.
;       It is assumed that r11->IOMD base address.
;
        MACRO
$label  DMARegBlk       $blk, $phs
      [ HAL
        ! 1, "Don't use DMARegBlk in HAL version!"
      |
$label  ADD     $blk, r11, #IOMD_IO0CURA        ; Base of DMA register blocks.
        ADD     $blk, $blk, $phs, LSL #5        ; Base + phys * 32
      ]
        MEND

;-----------------------------------------------------------------------------
        MACRO
$label  DebugTabInit    $nil,$wk1,$wk2
$label
 [ debugtab
        ADR     $wk1, DebugTable
        STR     $wk1, DebugTableCur
        ADR     $wk2, DebugTableEnd
$label.clr
        CMP     $wk1, $wk2
        STRCC   $nil, [$wk2, #-4]!
        BCC     $label.clr
 ]
        MEND

        MACRO
$label  DebugTab        $wk1,$wk2,$v1,$v2,$v3
$label
 [ debugtab
        LDR     $wk1, DebugTableCur
        ADR     $wk2, DebugTableEnd
 [ "$v1" <> ""
        TEQ     $wk1, $wk2
        ADREQ   $wk1, DebugTable
        MOV     $wk2, $v1
        STR     $wk2, [$wk1], #4
 ]
 [ "$v2" <> ""
        TEQ     $wk1, $wk2
        ADREQ   $wk1, DebugTable
        MOV     $wk2, $v2
        STR     $wk2, [$wk1], #4
 ]
 [ "$v3" <> ""
        TEQ     $wk1, $wk2
        ADREQ   $wk1, DebugTable
        MOV     $wk2, $v3
        STR     $wk2, [$wk1], #4
 ]
        STR     $wk1, DebugTableCur
 ]
        MEND

        END
