; 
; Copyright (c) 2006, James Peacock
; All rights reserved.
; 
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met: 
;     * Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;     * Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;     * Neither the name of RISC OS Open Ltd nor the names of its contributors
;       may be used to endorse or promote products derived from this software
;       without specific prior written permission.
; 
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
; 
;----------------------------------------------------------------------------

	GET	Hdr:ListOpts
	GET	Hdr:Macros
	GET	Hdr:System
        
;----------------------------------------------------------------------------

	AREA	|Asm$$Code|,CODE,PIC,READONLY
	EXPORT	asm_ticker_handler

;----------------------------------------------------------------------------
; asm_ticker_handler
;
; Requests a transient callback if there are any queued callbacks and there
; isn't a callback requested.
;
; Called in SVC mode with IRQs disabled.
;
; r12 => +0: Address of callback handler.
;        +4: Value to pass in R12 to callback handler.
;        +8: 0 if a callback is not required,
;            1 if one is required but not requested yet.
;	     2 if one is pending.
;
; See utils.c
;----------------------------------------------------------------------------

asm_ticker_handler
	Push	"r0-r2, lr"
	ldmia	r12,{r0-r2}
	teq	r2,#1
	bne	asm_ticker_handler_exit
	swi	XOS_AddCallBack
	movvc	r2,#2
	strvc	r2,[r12,#8]
asm_ticker_handler_exit
	Pull	"r0-r2,pc"

;----------------------------------------------------------------------------

	END
