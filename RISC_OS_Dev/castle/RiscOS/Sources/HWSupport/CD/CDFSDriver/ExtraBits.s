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
;----------------------------------------------------------------------------------------------
;                Convert addressing modes
;----------------------------------------------------------------------------------------------

; IF addressmode = LBAFormat THEN EXIT ( already done )

; IF addressmode = PBFormat THEN address = address - 2 seconds of data

; IF addressmode = MSFFormat THEN change address to minute,second,frame

;----------------------------------------------------------------------------------------------


;----------------------------------------------------------------------------------------------
ConvertToLBA ROUT
; on entry:
;          r0 = address mode
;          r1 = address
; on exit:
;          if oVerflow set then r0 -> error block
;          r1 = new address
;
; Errors can occur, eg/ invalid mode number
; When this is called, 'address' should contain the address on the disc
; in whatever format is being used.  'addressmode' should contain the number
; of the type of addressing being used.  Eg LBAFormat, MSFFormat, PBFormat
;
;----------------------------------------------------------------------------------------------

;--------------------------------------------------
; If already in LBA format then exit straight away
;--------------------------------------------------

 CMP       r0, #LBAFormat
 MOVEQ     pc, r14 ; V clear

 Push      "r0, r2 - r5, r14"

;--------------------------------------------------
; Check for allowable addressing mode
;--------------------------------------------------
 CMP       r0, #3
 addr      r0, InvalidFormat, CS
 BCS       Convert_Error

;--------------------------------------------------
; Branch to routines to convert from each mode to LBA
;--------------------------------------------------
; R0 = address mode
; R1 = address

 TEQ       r0, #1
 BEQ       ChangeFromMSFFormat

;--------------------------------------------------
;  Change from Physical Block TO Logical Block Address
;  Subtract 2 seconds worth of blocks to give LBA
;--------------------------------------------------

ChangeFromPBFormat

 SUBS      r1, r1, #( MaxNumberOfBlocks + 1 ) * 2

 addr      r0, PhysicalBlockError, LT
 BLT       Convert_Error

 VCLEAR
 Pull      "r0, r2 - r5, pc"


;----------------------------------------------------------------------------------------------
;    Change Minutes, Seconds, Frame TO LBA
ChangeFromMSFFormat    ; R1 = address, RETURNS R1 = address
;----------------------------------------------------------------------------------------------

; R1 = address

;-----------------------------------------
; R3 = frames
;-----------------------------------------
 MOV       r14, #255
 AND       r3, r1, r14

;-----------------------------------------
; R4 = seconds
;-----------------------------------------
 AND       r4, r14, r1, LSR #8

;-----------------------------------------
; R5 = minutes
;-----------------------------------------

 AND       r5, r14, r1, LSR #16

;-----------------------------------------
; Make sure that seconds are ( 0 - 59 )
;-----------------------------------------

 CMP       r4, #MaxNumberOfSeconds + 1
 addr      r0, BadSeconds, CS
 BCS       Convert_Error

;-----------------------------------------
; Make sure that frames are ( 0 - 74 )
;-----------------------------------------

 CMP       r3, #MaxNumberOfBlocks + 1
 addr      r0, BadBlocks, CS
 BCS       Convert_Error

;-----------------------------------------
; minutes = minutes * 60 + seconds
;-----------------------------------------

 MOV       r14, r5, LSL #6                     ; R14 = minutes * 64
 SUB       r5, r14, r5, LSL #2                 ; R5 = R14 - ( minutes * 4 )
 ADD       r5, r5, r4

;-----------------------------------------
; minutes = minutes * 75 + blocks
;-----------------------------------------
 MOV       r14, #MaxNumberOfBlocks + 1
 MLA       r5, r14, r5, r3

;-----------------------------------------
; minutes = minutes - 2 seconds
;-----------------------------------------
 SUB       r1, r5, #( MaxNumberOfBlocks + 1 ) * 2

;-----------------------------------------

 VCLEAR
 Pull       "r0, r2 - r5, pc"


;----------------------------------------------------------------------------------------------
ConvertToMSF ROUT
;                             Convert from LBA or PB to MSF format
; IF addressmode = MSFFormat THEN EXIT ( already done )
;
; IF addressmode = LBAFormat THEN ...
;
;
; on entry:
;          r0 = address mode
;          r1 = address
;
; on exit:
;          if oVerflow clear THEN r1 = new address ELSE r0->error block
;
; flags preserved
;----------------------------------------------------------------------------------------------

;-----------------------------------------
; If already in MSF format then exit straight away
;-----------------------------------------

 CMP        r0, #MSFFormat
 MOVEQ      pc, r14 ; V clear

 Push       "r0, r2 - r5, r14"


;-----------------------------------------
; Check for allowable addressing mode
;-----------------------------------------

 CMP        r0, #3
 addr       r0, InvalidFormat, CS
 BCS        Convert_Error

;-----------------------------------------
; Branch to routines to convert from each mode to MSF
;-----------------------------------------
; r0 = address mode
; r1 = address

 TEQ        r0, #0
 BEQ        ConvertLBAtoMSF

;-----------------------------------------
ConvertPBtoMSF
; R1 = address
;-----------------------------------------
; address = address - 150 ( error if < 0 )

 SUBS       r1, r1, #( MaxNumberOfBlocks + 1 ) * 2
 addr       r0, BadSeconds, LT
 BLT        Convert_Error

;-----------------------------------------
ConvertLBAtoMSF
; R1 = address
;-----------------------------------------
; R3 = Frames
; R4 = seconds
; R5 = minutes


;-----------------------------------------
; Frame = address MOD ( MaxNumberOfBlocks + 1 )
; R3 = R3 MOD ( MaxNumberOfBlocks + 1 )
;-----------------------------------------


;-----------------------------------------
; Seconds = ( address DIV 75 ) MOD 60
; R4
;-----------------------------------------

 MOV        r3, r1                                    ; r2 = address DIV 75
                                                      ;
 DivRem     r2, r3, #MaxNumberOfBlocks + 1, r14       ; r3 = address MOD 75

 DivRem     r4, r2, #MaxNumberOfSeconds + 1, r14      ; r4 = r2 DIV 60
                                                      ;
                                                      ; r2 = r2 MOD 60

; R4 = minutes
; R3 = frames
; R2 = seconds

;-----------------------------------------
; Push results together into one word
; Minutes << 16 + Seconds << 8 + Frames
;-----------------------------------------
 ORR        r3, r3, r2, LSL #8
 ORR        r1, r3, r4, LSL #16

 VCLEAR
 Pull       "r0, r2 - r5, pc"



Convert_Error
 VSET
 ADD     sp, sp, #4
 Pull    "r2 - r5, pc"


;----------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------

 END
