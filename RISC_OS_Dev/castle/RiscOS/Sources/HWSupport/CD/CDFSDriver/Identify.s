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
; -> Identify.s















;       This contains code for the CD_Identify SWI

















; by MEW of Eesox 28-Apr-93


;----------------------------------------------------------------------------------------------
cd_identify ROUT
;
; on entry:
;          r7 -> control block
;                control block + 0  = SCSI device id
;                control block + 4  = SCSI card number
;                control block + 8  = Logical unit number
;                control block + 12 = 0 - drive type not needed
; on exit:
;          if oVerflow clear:
;                r0 - r1 preserved
;                r2 = drive type given by CDFS driver, else -1 if type not recognised
;          if oVerflow set:
;                r0 -> error block, could be because no drivers loaded
;                r1 - r9 preserved
;
;----------------------------------------------------------------------------------------------

; the 'buffer' in workspace is to be used as follows:
; bytes 0  to  7 are to build the inquiry command up
; bytes 8  to 44 are for the returned inquiry data

 Debug "cd_identify",NL

;--------------------------------
; Are there any drivers loaded ?
;--------------------------------
 LDR       r14, number_of_drivers
 TEQ       r14, #0
 addr      r0, driver_not_present, EQ
 BEQ       error_handler_lookup  ; [ no - so error ]

;----------------------------------------------------------------
; Make up a new control block for the driver with its drive type
;----------------------------------------------------------------
 LDMIA     r7, { r8, r9, r10 }
 MOV       r14, #0
 ADR       r7, control_block
 STMIA     r7, { r8, r9, r10, r14 }

;--------------------------------
; SCSI Inquiry command
;--------------------------------
 BL       space_saver

 ORR       r0, r0, #escapepolloff + readdata   ; prevent 'escape key'

 ADR       r3, cdb_inquiry
 LDMIA     r3, { r4, r5 }
 ORR       r4, r4, r10, LSL #8+5
 STMIA     r2, { r4, r5 }

 ADR       r3, buffer + 8

 MOV       r4, #36

 MOV       r5, #0

 SWI       XSCSI_Op

;          r0  -> 36 byte SCSI inquiry data or 0
;          r1  -> if r0 =0 THEN this -> an error block ie/ the reason inquiry data failed
;          r7  -> control block, ignore the driver type, ie/ control block + 20
;          r11 =  reason code for CD_Identify
;          r12 -> their workspace
;          r13 -> full descending stack

 ADRVC     r0, buffer + 8
 MOVVS     r1, r0
 MOVVS     r0, #0

 ADR       r7, control_block

;--------------------------------
; Prepare for jump to hs
;--------------------------------
 ADR       r4, sld_list
 MOV       r3, #MAX_NUMBER_OF_DRIVERS

02
 LDR       r5, [ r4 ], #4
 SUBS      r3, r3, #1
 BEQ       not_recognised

 TEQ       r5, #0
 BEQ       %BT02

;--------------------------------
; Jump to each of the drivers
;--------------------------------
 RSB       r6, r3, #MAX_NUMBER_OF_DRIVERS - 1
 ADR       r2, wsp_list



 Push      "r0, r1, r3, r4, r6, r7, r12"
 LDR       r12, [ r2, r6, LSL #2 ]

;------------------------------------------
; Build a return address including PC flags (if in 26-bit mode)
; Actually doesn't matter if you preserve flags, since CMP will splat them all
;------------------------------------------
 MOV       r11, #30

 MOV       r14, pc
 ADD       pc, r5, #4

back_from_identify

; r2 = drive type or -1 if not recognised

 Pull      "r0, r1, r3, r4, r6, r7, r12"

 CMP       r2, #-1
 BEQ       %BT02

;--------------------------------
; Add my drive type and return
;--------------------------------
 ADD       r12, r2, r6, LSL #2

 STR       r12, [sp, #2*4]
 SWIExitVC

;----------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------
cdb_inquiry = &12, 0, 0, 0, 36, 0
 ALIGN

;----------------------------------------------------------------------------------------------
not_recognised
 MOV       r2, #-1
 STR       r2, [sp, #2*4]
 SWIExitVC

;----------------------------------------------------------------------------------------------

;----------------------------------------------------------------------------------------------

 END
