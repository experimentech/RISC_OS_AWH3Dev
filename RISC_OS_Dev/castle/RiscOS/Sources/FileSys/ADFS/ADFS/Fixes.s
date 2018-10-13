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
;>Fixes   Modification history of ADFS since V 2.00 (04 Oct 1988)

        GBLA    max_fix
max_fix SETA    12

        MACRO
        applyfix $number,$state,$description
        GBLL    fix_$number
        [ Dev
fix_$number SETL $state
        |
         [ $number <= max_fix
fix_$number SETL {TRUE}
         |
fix_$number SETL {FALSE}
         ]
        ]
        [ fix_$number
        ! 0,"Apply fix $number $description"
        ]
        MEND


; VERSION 2.00


        applyfix 1,{TRUE},Fix Claim/Release Device Vector bug
;25-Oct-88      NReeves
;ADFS 2.00 (04 Oct 88) had a bug with hard disc podules in that it the bit it
;passed to Claim/Release Device Vector was bit 3 (which is HDC IRQ status)
;rather than bit 0 (which is HDC IRQ requesting). This meant that if the HDC
;was being used in a polled fashion with IRQs disabled and another podule
;interrupt happened the MOS interrupt dispatcher could find this bit set and
;call the uninitialised ADFS interrupt handler instead, usuall crashing the
;machine.


; VERSION 2.01
; the date was left at 04-Oct-88 since the change was done by patching the
; ROM

        applyfix 2,{TRUE},Reduce poll frequency on 'step to reset' drives
;29-Nov-89      RCManby
;Drives that require a step pulse to clear the disc changed reset line
;sound better if they are polled for disc insertion once per second, not ten
;times per second.
;This is a cosmetic change to keep the product managers happy.


; VERSION 2.02
; released dated 06-Dec-89

        applyfix 3,{TRUE},Fix address exceptions on format
;15-Jan-90      RCManby
;If user removes the disc, part way through formatting a track,
;he eventually gets an address exception.
;Fixed by adding track buffer size parameter to format op, to prevent
;reading past the end of the buffer.

        applyfix 4,{TRUE},Enable Escape during format
;16-Jan-90      RCManby
;Allow ESCape from *format


; VERSION 2.03
; released dated 26-Jan-90

        applyfix 5,{TRUE},Report errors from format correctly
;18-Jun-90      NRaine
;Only translate escape errors into the snazzy "Escape pressed during format ..."

; VERSION 2.04
; released dated 18-Jun-90

        applyfix 6,{TRUE},Fix background write sectors FIQ code
;04-Jul-90     TDobson
;Change background write sectors code to use what was the old write track
;FIQ code, not RManby's new stuff which assumes the End register is set up

; VERSION 2.05
; released dated 04-Jul-90

        applyfix 7,{TRUE},Fix 'sticky' bits in configured harddiscs
;25-Oct-90      TDobson
;Change code that reads the configured floppies/harddiscs (routine
;ReadNewCMOS0) to correctly mask out the top 2 bits of the CMOS location

        applyfix 8,{TRUE},Optimise BlockMove routine
;25-Oct-90      TDobson
;Optimise routine that copies a block of word-aligned data

; VERSION 2.06
; released dated 25-Oct-90

; Version 2.67
; release dated 28 Apr 92 for RISC OS 3.10

; ADFSUtils introduced for RISC OS 3.11

        applyfix 9,{TRUE},Background ops on 82C711 fixed
;19-Nov-92      JRoach
;Incorporate ADFSUtils fix. This closes IRQ window on background completion.
;Secondary problem of CDB reuse fixed by registration of dummy CDB.

        applyfix 10,{TRUE},Morley ST506 podule fix
;19-Nov-92      JRoach
;SenseController expected CommandAborted when aborting the command, but
;Morley card gives different response. This has been added.

        applyfix 11,{TRUE},82C711 index pulse timouts matched to drives' specs
;19-Nov-92      JRoach
;FlpMotorOnDelayIn and FlpEmptyTimer extended to bring into spec on the
;drives. Previous settings were 0.5 and 0.4 secs and resulted in excessive
;drive empty errors. New settings are 0.6 and 0.61 secs to give total time
;of 1.21 secs which is in spec for the drives.

        applyfix 12,{TRUE},Power save calls in Drive state machine
;08-Aug-94      RCManby
;The drive state machine was missing two FlpFDCcontrol calls (1 for power up,
;1 for power down), shown by use of ADFS with Stork Portable module. A4 portable
;doesn't actually do ANY floppy power saving, despite what the comments say
;in the A4 portable module sources!.

        END
