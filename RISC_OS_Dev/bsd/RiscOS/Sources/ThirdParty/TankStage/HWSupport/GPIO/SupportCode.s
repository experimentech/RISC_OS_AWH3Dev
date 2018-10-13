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

; s.SupportCode

;---------------------------------------------

Get_Board
	Push	"r2-r10,lr"
	LDR	r0,[r12,#machine]		;get board type
	ADRL	r3,dummy_table			;tables start
	ADD	r3,r3,r0,LSL #tablesize		;point to board table
	LDR	r2,[r3,#boardnamestring]	;get this name pointer
	ADD	r1,r12,#machinename		;
	MOV	r4,#0				;index
100	LDRB	r3,[r2,r4]			;get byte
	STRB	r3,[r1,r4]			;move it
	CMP	r3,#13				;terminator ?
	BEQ	%FT20				;
	ADD	r4,r4,#1			;
	CMP	r4,#32				;too big
	BEQ	%FT20				;
	B	%BT100				;
20	MOV	r3,#0				;
	STRB	r3,[r1,r4]			;
	ADRL	r3,convert_internal_to_external	;
	LDRB	r0,[r3,r0]			;convert to external
	Pull	"r2-r10,pc"			;
;r0 is board type
;r1 points to board name 0 terminated
;preserves all others
;---------------------------------------------
;r0=GPIO number
;r1=table pointer
find_register
	Push	"r1-r4,lr"		;
	CMP	r0,#top_gpio		;check GPIO number
	MOVGE	r0,#-1			;
	BGE	%FT10			;
	LDR	r4,[r1,#control_reg]	;
	CMP	r4,#-1			;
	BEQ	%FT20			;
	MOV	r3,r0,LSL#1		;make it a pointer
	LDRH	r0,[r4,r3]		;get register
	CMP	r0,#0			;protected ?
20	MOVEQ	r0,#-1			;
10
	Pull	"r1-r4,pc"		;
;r0=physical address or -1
;preserves all others
;-----------------------------------------------------------------------------
;r0=GPIO number
get_logical_and_pin
	ADD	r3,r12,#logicalstore	;logical table
	AND	r1,r0,#2_11100000	;just block
	MOV	r1,r1,LSR #3		;make pointer
	AND	r2,r0,#31		;just pin number
	LDR	r0,[r3,r1]		;get logical address.
	MOV	r3,#1			;create mask from pin number
	MOV	r1,r3,LSL r2		;r1 = bit mask
	LDR	r2,[r12,#halproc]	;r2 = processor type
	MOV	r2,r2,LSL #proc_tableshift
	MOV	pc,lr
;r0=logical address or -1 if not GPIO
;r1=bit mask
;r2=processor table offset
;r3 corrupt
;-----------------------------------------------------------------------------
get_table
	LDR	r2,[r12,#machine]		;get machine type
	ADRL	r1,dummy_table			;tables start
	ADD	r1,r1,r2, LSL #tablesize	;offset
	LDR	r2,[r12,#halproc]		;get processor type
	MOV	pc,lr				;
;r1=pointer to board table
;r2=processor type
;-----------------------------------------------------------------------------
check_protect_i2c
	LDR	r1,[r12,#i2cprotect]		;get flag
	CMP	r1,#0				;
	BEQ	%FT10				;
	LDR	r2,[r12,#machine]		;get machine type
	ADRL	r1,dummy_table			;tables start
	ADD	r1,r1,r2, LSL #tablesize	;offset
	LDR	r2,[r1,#i2c_pins]		;get list of registers
	CMP	r2,#-1				;
	BEQ	%FT10
	LDR	r4,[r2]				;
	AND	r1,r4,#&FF			;mask bottom
	MOV	r2,r4,LSR #8			;move to lower
	AND	r2,r2,#&FF			;mask it
	MOV	r3,r4,LSR #16			;move to lower
	AND	r3,r3,#&FF			;mask it
	MOV	r4,r4,LSR #24			;move to lower
	CMP	r0,r1				;check against gpio's
	CMPNE	r0,r2				;
	CMPNE	r0,r3				;
	CMPNE	r0,r4				;
20	MOVEQ	r0,#-1				;error if it is one
10	MOV	pc,lr
;r0=gpio in or -1 if protected
;r1,r2,r3,r4 corrupt
;-----------------------------------------------------------------------------
copy_tables_to_rma
	Push	"lr"
	BL	get_table			;
	ADD	r4,r12,#gpiotablecopy		;
	LDR	r6,[r1,#exp_pins]		;get list of pins
	CMP	r6,#-1				;
	BLNE	moveit
	LDR	r6,[r1,#aux_pins]		;get list of pins
	CMP	r6,#-1				;
	BLNE	moveit
	LDR	r6,[r1,#camera_pins]		;get list of pins
	CMP	r6,#-1				;
	BLNE	moveit
	LDR	r6,[r1,#user_pins]		;get list of pins
	CMP	r6,#-1				;
	BLNE	moveit
	MOV	r0,#&FF
	STRB	r0,[r4],#1			;
	STRB	r0,[r4],#1			;
	STRB	r0,[r4],#1			;
	STRB	r0,[r4],#1			;
	ADD	r2,r12,#gpiotablecopy		;
	Pull	"pc"
;tables 2,3,4,5 copied to RMA
moveit
	LDRB	r0,[r6],#1			;get pin number
	STRB	r0,[r4],#1			;
	CMP	r0,#&FF				;last one ?
	BNE	moveit				;
	MOV	pc,lr
;-----------------------------------------------------------------------------
pi_setup
	Push	"r9,lr"
	BL	get_table			;
	LDR	r1,[r1,#control_reg]		;
	CMP	r1,#-1				;
	MOVEQ	r0,r1				;error in r0
	Pull	"r9,lr",EQ			;
	MOV	r9,r0,LSL #1
	LDRH	r1,[r1,r9]			;get sel register and lsl
	MOV	r9,r1,LSR #6			;sel register
	AND	r5,r1,#&FF			;lsl value
	CMP	r0,#31				;
	MOVGT	r4,#4				;
	MOVLE	r4,#0				;
	AND	r2,r0,#31			;
	ADD	r3,r12,#logicalstore		;logical table
	LDR	r0,[r3]				;r0 = logical address
	MOV	r3,#1				;create mask from pin number
	MOV	r1,r3,LSL r2			;r1 = bit mask
	ADD	r3,r0,#pi_GPSEL0		;
	ADD	r3,r3,r9			;r3 = select register
	LDR	r2,[r3]				;
	MOV	r6,#7				;
	MOV	r6,r6,LSL r5			;
	AND	r2,r2,r6			;
	MOV	r2,r2,LSR r5			;r2 = function
	Pull	"r9,pc"
;r0 = logical base or -1 if bad
;r1 = bit mask or -1 if bad
;r2 = function
;r3 = select register logical
;r4 = register 0 (0) or 1 (4)
;r5 = shift amount
;r6 = mask for select register
;-----------------------------------------------------------------------------
get_i2c_info
	Push	"r0-r8,lr"			;
	MOV	r8,#-1				;default to no chips
	STR	r8,[r12,#i2clowgpio]		;
	MOV	r8,#0				;
	STR	r8,[r12,#i2chighgpio]		;
10	CMP	r8,#16*8			;max chips
	MOVGT	r8,#-1				;
	STRGT	r8,[r12,#i2clowgpio]		;
	Pull	"r0-r8,pc",GT			;
	MOV	r0,r8				;gpio number
	MOV	r7,r8				;
	ADD	r8,r8,#16			;next chip
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpiodira		;
	MOV	r4,#1				;ignore swi error
	BL	i2c_read			;
	BVC	%FT19				;no error chip found
	LDR	r0,[r0]				;check which error
	LDR	r1,noack			;
	CMP	r0,r1				;no ack error number
;	Pull	"r0-r8,pc",NE			;another problem restore registers and exit
	B	%BT10				;no ack, try next chip
19	STR	r7,[r12,#i2clowgpio]		;
20	MOV	r0,r8				;gpio number
	SUB	r7,r8,#1			;
	ADD	r8,r8,#16			;next chip
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpiodira		;
	MOV	r4,#1				;ignore swi error
	BL	i2c_read			;
	BVC	%BT20				;no error try next chip
	LDR	r0,[r0]				;check which error
	LDR	r1,noack			;
	CMP	r0,r1				;
;	Pull	"r0-r8,pc",NE			;another problem restore registers and exit
	STR	r7,[r12,#i2chighgpio]		;
	Pull	"r0-r8,pc"			; restore registers and exit

noack	DCD	&20300
;---------------------------------------------
i2c_get_things
	Push	"r1,lr"			;stack return
	LDR	r1,[r12,#machine]	;get machine type
	ADRL	r10,i2c_bus_nos		;get i2c bus used
	LDRB	r2,[r10,r1]		;
	MOV	r3,r2,LSL #24		;
	AND	r0,r0,#2_11111111	;just bits
	AND	r1,r0,#2_11110000	;just "chip"
	MOV	r1,r1,LSR #3		;make pointer to chip * 2
	ADD	r1,r1,#mcpbase		;chip no + base of "chip" 0
	AND	r0,r0,#2_1111		;just pin number
	AND	r4,r0,#2_1000		;just >7
	MOV	r4,r4,LSR #3		;make pointer to register
	AND	r0,r0,#2_111		;just pin number
	MOV	r2,#1			;
	MOV	r5,r2,LSL r0		;bit mask
	MOV	r0,r1			;
	Pull	"r1,pc"			;pull return
;r0=address of chip
;r1=preserved
;r2=corrupt
;r3=bus no <<24
;r4=register offset
;r5=pin (mask)
;---------------------------------------------
;r0=address of chip
;r1=register to read
;r2=width of data to read
;r3=i2c bus number << 24
;r4=xswi flag
i2c_read
	Push	"r2-r5,lr"
	ADD	r5,r12,#i2csend		;iic send block pointer
	STR	r0,[r5]			;address of chip
	ADD	r0,r0,#1		;
	STR	r0,[r5,#12]		;address of chip + 1
	ADD	r0,r12,#i2cdata		;iic data block pointer
	STR	r0,[r5,#4]		;
	STR	r1,[r0]			;reg
	MOV	r0,#1			;
	STR	r0,[r5,#8]		;transfers
	ADD	r0,r12,#i2creturn	;iic return block pointer
	STR	r0,[r5,#16]		;
	STR	r2,[r5,#20]		;width of data returned
	MOV	r0,r5			;
	ADD	r1,r3,#2		;
	SWI	XOS_IICOp		;
	ADD	r1,r12,#i2creturn	;iic return block pointer
	Pull	"r2-r5,pc"
;r1=pointer to data (if no error)
;---------------------------------------------
;r0=address of chip
;r1=register to read
;r2=data
;r3=i2c bus number
;r4=xswi flag
i2c_write
	Push	"r0-r5,lr"
	ADD	r5,r12,#i2csend		;iic send block pointer
	STR	r0,[r5]			;address of chip
	ADD	r0,r12,#i2cdata		;iic data block pointer
	STR	r0,[r5,#4]		;
	STRB	r1,[r0]			;reg
	STRB	r2,[r0,#1]		;data
	MOV	r0,#2			;
	STR	r0,[r5,#8]		;transfers
	MOV	r0,r5			;
	ADD	r1,r3,#1		;
	SWI	XOS_IICOp		;
	Pull	"r0-r5,pc"
;---------------------------------------------
;r0=GPIO
;r1=On time
;r2=Off time
FlashOn
	CMP	r0,#i2c_flag-1		;check if i2c gpio
	MOVCS	pc,lr			;
	Push	"r1-r8,lr"		;
	MOV	r3,r1  			;save
	MOV	r6,r0			;
	MOV	r1,#1			;set output on
	CMP	r10,#HALDeviceID_GPIO_BCM2835
	BLEQ	Pi_Write_Data		;
	CMP	r0,#-1	 		;
	Pull	"r1-r8,pc",EQ
	CMP	r10,#HALDeviceID_GPIO_OMAP3
	BLEQ	Write_Data		;
	CMP	r0,#-1	 		;
	Pull	"r1-r8,pc",EQ
	CMP	r10,#HALDeviceID_GPIO_OMAP4
	BLEQ	Write_Data		;
	CMP	r0,#-1	 		;
	Pull	"r1-r8,pc",EQ
	AND	r4,r6,#2_11100000	;just block
	MOV	r4,r4,LSR #3		;make pointer
	ADD	r4,r4,r12		;
	AND	r6,r6,#31		;just pin number
	ADD	r7,r12,r6,LSL #2	;
	MOV	r5,#1			;
	MOV	r5,r5,LSL r6		;set flag
	LDR	r0,[r4,#flashflags]	;
	ORR	r0,r0,r5		;
	STR	r0,[r4,#flashflags]	;
	STR	r3,[r7,#flashmark]	;save mark count
	STR	r3,[r7,#flashstate]	;set state
	STR	r2,[r7,#flashspace]	;save space count
	MOV	r0,#0			;
	Pull	"r1-r8,pc"		;
;r0= -1 if input , protected or not GPIO
;or
;r0=0
;---------------------------------------------
;r0=GPIO
FlashOff
	CMP	r0,#i2c_flag-1		;check if i2c gpio
	MOVCS	pc,lr			;
	Push	"r0-r5,lr"
	AND	r4,r0,#2_11100000	;just block
	MOV	r4,r4,LSR #3		;make pointer
	ADD	r4,r4,r12		;
	AND	r0,r0,#31		;just pin number
	MOV	r5,#1			;
	MOV	r5,r5,LSL r0		;set flag
	LDR	r2,[r4,#flashflags]	;
	BIC	r2,r2,r5		;
	STR	r2,[r4,#flashflags]	;
	Pull	"r0-r5,pc"
;---------------------------------------------
FlashVector
	Push	"r0-r9,lr"		;
	LDR	r9,[r12,#halproc]	;
	ADD	r2,r12,#flashflags	;
	ADD	r3,r12,#flashmark		;
	MOV	r6,#0			;counter
10	LDR	r4,[r2],#4		;get flags
	CMP	r4,#0			;any set
	BNE	%FT20			;yes
	ADD	r6,r6,#1		;inc counter
	CMP	r2,r3			;last flags
	BLE	%BT10			;
	Pull	"r0-r9,pc"		;
20	MOV	r1,#0  			;counter
30	MOVS	r4,r4,ROR #1		;
	BLCS	dec	   		;this one ?
	ADD	r1,r1,#1		;
	CMP	r1,#32 			;last
	BLO	%BT30			;
	B	%BT10			;next flags

dec	Push	"r1,lr"
	ADD	r7,r12,r1,LSL #2	;point to state of this GPIO
	ADD	r7,r7,r6,LSL #5		;
	LDR	r5,[r7,#flashstate]	;
	SUB	r5,r5,#1		;decriment it
	STR	r5,[r7,#flashstate]	;
	CMP	r5,#0  			;change state ?
	Pull	"r1,pc",NE		;
	ADD	r0,r1,r6,LSL #5		;make into GPIO number
	Push	"r0"			;
	CMP	r9,#HALDeviceID_GPIO_BCM2835
	BLGE	Pi_Read_Data  		;read state
	CMP	r9,#HALDeviceID_GPIO_OMAP3	;
	BLEQ	Read_Data  		;read state
	CMP	r9,#HALDeviceID_GPIO_OMAP4	;
	BLEQ	Read_Data  		;read state
	CMP	r0,#0			;swop state
	MOVEQ	r1,#1			;
	LDREQ	r8,[r7,#flashmark]	;
	MOVNE	r1,#0			;
	LDRNE	r8,[r7,#flashspace]	;
	STR	r8,[r7,#flashstate]	;
	Pull	"r0"			;
	CMP	r9,#HALDeviceID_GPIO_BCM2835
	BLEQ	Pi_Write_Data		;
	CMP	r9,#HALDeviceID_GPIO_OMAP3
	BLEQ	Write_Data		;
	CMP	r9,#HALDeviceID_GPIO_OMAP4	;
	BLEQ	Write_Data  		;read state
	Pull	"r1,pc"			;

;---------------------------------------------

	END
