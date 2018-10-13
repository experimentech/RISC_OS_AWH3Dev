;
; Copyright (c) 2011, Tank Stage Lighting
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;     * Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;     * Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;     * Neither the name of the copyright holder nor the names of their
;       contributors may be used to endorse or promote products derived from
;       this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;

;s.errors
;---------------------------------------------
initerror
	ADR	r0,initerrorrma
	B	errorcommon
initerror1
	ADR	r0,initerrorhardware
	B	errorcommon
initerror2
	ADR	r0,initerrormap1
	B	errorcommon
initerror3
	ADR	r0,initerrormap2
	B	errorcommon
initerror4
	ADR	r0,initerrormap3
	B	errorcommon
nomachinesupport
	ADR	r0,nomachineerror
	B	errorcommon
dieerror
	ADR	r0,dieerrorrma
	B	errorcommon
;---------------------------------------------
errorcommon
	STR	r0,[r13,#0]				;change r0 on stack
	SETV
	Pull	"r0-r11,pc"
;---------------------------------------------
RM_errMesg
	DCD	Error_block
	DCB	"Unkown GPIO SWI operation",0
	ALIGN
initerrorrma
	DCD	Error_block+1
	DCB	"The GPIO module could not claim RMA",0
	ALIGN
initerrorhardware
	DCD	Error_block+2
	DCB	"The GPIO module had a problem with the hardware",0
	ALIGN
initerrormap1
	DCD	Error_block+3
	DCB	"The GPIO module could not map in logical memory for the GPIO registers",0
	ALIGN
initerrormap2
	DCD	Error_block+4
	DCB	"The GPIO module could not map in logical memory for the control registers",0
	ALIGN
initerrormap3
	DCD	Error_block+5
	DCB	"The GPIO module could not map in logical memory for the SRAM",0
	ALIGN
dieerrorrma
	DCD	Error_block+6
	DCB	"The GPIO module could not clear RMA",0
	ALIGN
nomachineerror
	DCD	Error_block+7
	DCB	"The GPIO module does not support this SOC",0
	ALIGN
initerrortick
	DCD	Error_block+8
	DCB	"The GPIO module could not claim TickerV",0
	ALIGN
;---------------------------------------------

	END

