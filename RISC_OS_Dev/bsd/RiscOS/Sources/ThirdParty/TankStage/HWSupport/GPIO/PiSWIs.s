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

;s.PiSWIs

;***************** S W I 's ***********
;;ReadData
;r0=GPIO number
Pi_Read_Data
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_Data			;
	Push	"r1-r8,lr"
	BL	pi_setup
	CMP	r1,#-1				;
	BEQ	%FT10				;
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPLEV0]		;read value
	AND	r0,r2,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
10
	Pull	"r1-r8,pc"			; restore registers and exit
;r0=value (0 or 1) -1 if bad
;---------------------------------------------
;WriteData
;r0=GPIO number
;r1=value
Pi_Write_Data
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_Data			;
	Push	"r2-r9,lr"			;
	MOV	r9,r1				;save value
	BL	check_protect_i2c		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	BL	pi_setup
	CMP	r1,#-1				;
	BEQ	%FT10				;
	CMP	r2,#1				;output?
	MOVNE	r0,#-1
	BNE	%FT10
	ADD	r0,r0,r4			;
	CMP	r9,#0				;
	ADDEQ	r0,r0,#pi_GPCLR0		;
	ADDNE	r0,r0,#pi_GPSET0		;
	STR	r1,[r0]				;set register
10
	Pull	"r2-r9,pc"			; restore registers and exit
;r0= -1 if input , protected or not GPIO
;or
;r0=logical address of register used
;r1=pin mask
;---------------------------------------------
;ReadOE
;r0=GPIO number
Pi_Read_OE
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_OE			;
	Push	"r1-r8,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	MOV	r0,#-1				;
	CMP	r2,#0				;
	MOVEQ	r0,#1				;
	CMP	r2,#1				;
	MOVEQ	r0,#0				;
10
	Pull	"r1-r8,pc"			; restore registers and exit
;r0=value (0=output,1=input,-1 aux function)
;---------------------------------------------
;WriteOE
;r0=GPIO number
;r1=value 0 or 1
Pi_Write_OE
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_OE			;
	Push	"r1-r9,lr"			;
	MOV	r9,r0				;keep pin number
	BL	Pi_Read_Mode			;
	AND	r8,r0,#7			;just mode
	BIC	r0,r0,#7			;loose mode bits
	CMP	r8,#1				;not gpio
	MOVGT	r0,#-1				;
	BGT	%FT10				;
	CMP	r1,#0				;swap OE to match beagle
	MOVEQ	r1,#1				;
	MOVNE	r1,#0				;
	ORR	r1,r1,r0			;set mode bits
	MOV	r0,r9				;
	BL	Pi_Write_Mode			;
10
	Pull	"r1-r9,pc"			; restore registers and exit
;r0=0 if ok -1 if protected or not GPIO
;----------------------------------------------
; MapExpIn
;r0=mode
Pi_Exp_As_GPIO
	Push	"r0-r10,lr"			;
	BL	get_table			;
	LDR	r7,[r1,#exp_pins]		;get list of pins
	TST	r0,#2				;check if in/out
	MOVNE	r8,#Pi_GPIOOut			;
	MOVEQ	r8,#Pi_GPIOIn			;
	AND	r9,r0,#5			;
	TST	r9,#1				;up or down
	ORRNE	r8,r8,#8			;
	TST	r9,#4				;No pull up/down
	ORRNE	r8,r8,#4			;
10	LDRB	r0,[r7],#1			;get pin number
	CMP	r0,#&FF				;last one ?
	BEQ	%FT20				;
	BL	check_protect_i2c		;skip I2C ?
	CMP	r0,#-1				;
	BEQ	%BT10				;
	MOV	r1,r8				;keep mode type
	MOV	r10,r0				;keep gpio number
	BL	Pi_Write_Mode			;
	CMP	r0,#-1				;bad pin
	BEQ	%BT10				;
	CMP	r8,#Pi_GPIOOut			;set outputs ?
	BNE	%BT10				;
	MOV	r0,r10				;get gpio number
	MOV	r1,#0				;set output to off
	BL	Pi_Write_Data			;write data
	B	%BT10				;next
20
	Pull	"r0-r10,pc"			; restore registers and exit
;---------------------------------------------

Pi_Exp_As_UART
	Push	"r0-r7,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#uart_pins]		;get list of pins
expasin
10	LDRH	r0,[r6],#2			;get pin number
	CMP	r0,#&FF				;last one ?
	BEQ	%FT20				;
	MOV	r1,r0,LSR #8			;just mode
	AND	r0,r0,#&FF			;just gpio
	BL	Pi_Write_Mode			;
	B	%BT10				;
20
	Pull	"r0-r7,pc"			; restore registers and exit
;---------------------------------------------
;actually exp as SPIO
Pi_Exp_As_MMC
	Push	"r0-r7,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#mmc_exp_pins]		;get list of pins
	B	expasin
;---------------------------------------------
;ReadMode
;r0=GPIO number
Pi_Read_Mode
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_Mode
	Push	"r1-r8,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r8,pc",EQ			; restore registers and exit
	MOV	r0,r2				;
	ADD	r3,r12,#pipullen		;
	ADD	r3,r3,r4			; bank
	LDR	r2,[r3]				;
	ANDS	r2,r2,r1			;
	MOVEQ	r2,#pulldisable			;
	MOVNE	r2,#pullenable			;
	ORR	r0,r0,r2			; add enabled bit
	LDR	r2,[r3,#4]			;
	ANDS	r2,r2,r1			;
	MOVEQ	r2,#pulldown			;
	MOVNE	r2,#pullup			;
	ORR	r0,r0,r2			; add up/down bit
	Pull	"r1-r8,pc"			; restore registers and exit
;r0=mode (-1=not ours)
;---------------------------------------------
;WriteMode
;r0=GPIO number
;r1=mode
Pi_Write_Mode
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_Mode
	Push	"r1-r10,lr"			;
	AND	r9,r1,#7			;
	MOV	r8,r1				;keep setting
	BL	check_protect_i2c		;
	CMP	r0,#-1				;
;	BEQ	pwmout				;
	BEQ	%FT10				;
	SWI	XOS_IntOff
	BL	pi_setup			;
	ADD	r10,r12,#pipullen		;
	ADD	r10,r10,r4			; bank
	ADD	r2,r0,#pi_GPPUD			;control (no offset)
	ADD	r0,r0,r4			;
	ADD	r7,r0,#pi_GPPUDCLK0		;clock
	LDR	r0,[r10,#4]			;
	TST	r8,#pullup			;
	ORRNE	r0,r0,r1			;
	BICEQ	r0,r0,r1			;
	STR	r0,[r10,#4]			;
	MOVEQ	r4,#Pi_PUDEnDown		;
	MOVNE	r4,#Pi_PUDEnUp			;
	LDR	r0,[r10]			;
	TST	r8,#pullenable			;No pull up/down
	ORRNE	r0,r0,r1			;
	BICEQ	r0,r0,r1			;
	STR	r0,[r10]			;
	MOVEQ	r4,#Pi_PUDOff			;
	MOV	r9,r9, LSL r5			;
	LDR	r0,[r3]				;
	BIC	r0,r0,r6			;
	ORR	r0,r0,r9			;
	STR	r0,[r3]				;
	STR	r4,[r2]				;pull type
	BL	delay				;
	STR	r1,[r7]				;pin mask
	BL	delay				;
	MOV	r4,#0				;clear clock and control
	STR	r4,[r2]				;
	STR	r4,[r7]				;
	SWI	XOS_IntOn
	MOV	r0,#0				;
10
	Pull	"r1-r10,pc"			; restore registers and exit
;pwmout	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0 if OK -1 if protected

delay
	Push	"r0,lr"				;bodge delay
	MOV	r0,#&FF				;256 loop
30	SUB	r0,r0,#1			;
	CMP	r0,#0				;
	BNE	%BT30				;
	Pull	"r0,pc"				;restore registers and exit
;---------------------------------------------
;ReadLevel0
;r0=GPIO number
Pi_Read_Level0
	CMP	r0,#i2c_flag-1			; check if i2c gpio
	BCS	i2c_Read_Polarity
	Push	"r1-r10,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPLEN0]		; read value
	AND	r0,r2,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=mode
;---------------------------------------------
;WriteLevel0
;r0=GPIO number
;r1=0/1
Pi_Write_Level0
	CMP	r0,#i2c_flag-1			; check if i2c gpio
	BCS	i2c_Write_Polarity		;
	Push	"r1-r10,lr"			;
	MOV	r9,r1				; keep it
	BL	pi_setup			;
	CMP	r1,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPLEN0]		; read value
	CMP	r9,#0				;
	ORRNE	r2,r2,r1			;
	BICEQ	r2,r2,r1			;
	MOV	r0,r9				;
	STR	r2,[r3,#pi_GPLEN0]		; set register
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=r1 on entry or -1
;---------------------------------------------
;WriteLevel1
;r0=GPIO number
;r1=0/1
Pi_Read_Level1
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_Pull			;
	Push	"r1-r10,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPHEN0]		; read value
	AND	r0,r2,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0,1 or -1
;---------------------------------------------
;WriteLevel1
;r0=GPIO number
;r1=0/1
Pi_Write_Level1
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_Pull			;
	Push	"r1-r10,lr"			;
	MOV	r9,r1				; keep it
	BL	pi_setup			;
	CMP	r1,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPHEN0]		; read value
	CMP	r9,#0				;
	ORRNE	r2,r2,r1			;
	BICEQ	r2,r2,r1			;
	MOV	r0,r9				;
	STR	r2,[r3,#pi_GPHEN0]		; set register
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=r1 on entry or -1
;---------------------------------------------
;ReadRising
;r0=GPIO number
Pi_Read_Rising
	Push	"r1-r10,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPREN0]		; read value
	AND	r0,r2,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0,1 or -1
;---------------------------------------------
;WriteRising
;r0=GPIO number
;r1=0/1
Pi_Write_Rising
	Push	"r1-r10,lr"			;
	MOV	r9,r1				; keep it
	BL	pi_setup			;
	CMP	r1,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPREN0]		; read value
	CMP	r9,#0				;
	ORRNE	r2,r2,r1			;
	BICEQ	r2,r2,r1			;
	MOV	r0,r9				;
	STR	r2,[r3,#pi_GPREN0]		; set register
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=r1 on entry or -1
;---------------------------------------------
;ReadFallin
;r0=GPIO number
Pi_Read_Falling
	Push	"r1-r10,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPFEN0]		; read value
	AND	r0,r2,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0,1 or -1
;---------------------------------------------
;WriteFalling
;r0=GPIO number
;r1=0/1
Pi_Write_Falling
	Push	"r1-r10,lr"			;
	MOV	r9,r1				; keep it
	BL	pi_setup
	CMP	r1,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPFEN0]		; read value
	CMP	r9,#0				;
	ORRNE	r2,r2,r1			;
	BICEQ	r2,r2,r1			;
	MOV	r0,r9				;
	STR	r2,[r3,#pi_GPFEN0]		; set register
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=r1 on entry or -1
;---------------------------------------------
;ReadDebounceEnable
;r0=GPIO number
Pi_Read_DebounceEnable
	Push	"r1-r10,lr"			;
	Pull	"r1-r10,pc"			; restore registers and exit
;---------------------------------------------
;WriteDebounceEnable
;r0=GPIO number
;r1=0/1
Pi_Write_DebounceEnable
	Push	"r1-r10,lr"			;
	Pull	"r1-r10,pc"			; restore registers and exit
;---------------------------------------------
;ReadIRQ1
;r0=GPIO number
Pi_Read_IRQ1
	Push	"r1-r10,lr"			;
	Pull	"r1-r10,pc"			; restore registers and exit
;---------------------------------------------
;WriteIRQ1
;r0=GPIO number
;r1=0/1
Pi_Write_IRQ1
	Push	"r1-r10,lr"			;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0 if ok -1 if protected
;preserves all others
;---------------------------------------------
;ReadIRQ2
;r0=GPIO number
Pi_Read_IRQ2
	Push	"r1-r10,lr"			;
	Pull	"r1-r10,pc"			; restore registers and exit
;---------------------------------------------
;WriteIRQ2
;r0=GPIO number
;r1=0/1
Pi_Write_IRQ2
	Push	"r1-r10,lr"			;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0 if ok -1 if protected
;preserves all others
;---------------------------------------------
;readexp32
Pi_Read_Exp_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadBlock			;
	Push	"r1-r6,lr"			;
	MOV	r6,#0				;
	BL	Pi_GPIO_Info			;
	MOV	r5,#0				;counter
	MOV	r3,#0				;store
10	LDRB	r0,[r2,r5]			;get list of pins
	CMP	r0,#&FF				;last ?
	CMPEQ	r6,#0				;
	MOVEQ	r6,#1				;
	ADDEQ	r5,r5,#1			;
	BEQ	%BT10				;
	CMP	r0,#&FF				;last ?
	BEQ	%FT20				;
	BL	Pi_Read_Data			;
	CMP	r0,#-1				;
	MOVNE	r4,r0,LSL r5			;put data into word
	ORRNE	r3,r3,r4			;add to previous
	ADD	r5,r5,#1			;inc counter
	B	%BT10				;get next
20	MOV	r0,r3				;
	Pull	"r1-r6,pc"			; restore registers and exit
;r0=data state
;preserves all others
;---------------------------------------------
;writeexp32
;r0=bits to set/unset
;r1=bit mask
Pi_Write_Exp_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteBlock			;
	Push	"r0-r8,lr"			;
	MOV	r6,r1				;
	MOV	r7,r0				;
	MOV	r8,#0				;
	BL	Pi_GPIO_Info			;
	MOV	r5,#0				;counter
	MOV	r3,#0				;store
10	LDRB	r0,[r2,r5]			;get list of pins
	CMP	r0,#&FF				;last ?
	CMPEQ	r8,#0				;
	MOVEQ	r8,#1				;
	ADDEQ	r5,r5,#1			;
	BEQ	%BT10				;
	CMP	r0,#&FF				;last ?
	BEQ	%FT20				;
	MOVS	r7,r7,ROR #1			;
	MOVCC	r1,#0				;
	MOVCS	r1,#1				;
	MOVS	r6,r6,ROR #1			;
	BLCS	Pi_Write_Data			;
	ADD	r5,r5,#1			;
	B	%BT10				;
20
	Pull	"r0-r8,pc"			; restore registers and exit
;preserves all registers

;---------------------------------------------
;readexpOE32
Pi_Read_Exp_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadBlockOE			;
	Push	"r1-r7,lr"			;
	MOV	r6,#0				;
	BL	Pi_GPIO_Info			;
	MOV	r5,#0				;counter
	MOV	r3,#0				;store
10	LDRB	r0,[r2,r5]			;get list of pins
	CMP	r0,#&FF				;last ?
	CMPEQ	r6,#0				;
	MOVEQ	r6,#1				;
	ADDEQ	r5,r5,#1			;
	BEQ	%BT10				;
	CMP	r0,#&FF				;last ?
	BEQ	%FT20				;
	BL	Pi_Read_OE			;
	CMP	r0,#-1				;
	MOVNE	r4,r0,LSL r5			;put data into word
	ORRNE	r3,r3,r4			;add to previous
	ADD	r5,r5,#1			;inc counter
	B	%BT10				;get next
20	MOV	r0,r3				;
	Pull	"r1-r7,pc"			; restore registers and exit
;r0=bitmask of OE register
;preserves all others
;---------------------------------------------
;writeexpOE32
;r0=bits to set/unset
;r1=bit mask
Pi_Write_Exp_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteBlockOE		;
	Push	"r0-r8,lr"			;
	MOV	r6,r1				;
	MOV	r7,r0				;
	MOV	r8,#0				;
	BL	Pi_GPIO_Info			;
	MOV	r5,#0				;counter
	MOV	r3,#0				;store
10	LDRB	r0,[r2,r5]			;get list of pins
	CMP	r0,#&FF				;last ?
	CMPEQ	r8,#0				;
	MOVEQ	r8,#1				;
	ADDEQ	r5,r5,#1			;
	BEQ	%BT10				;
	CMP	r0,#&FF				;last ?
	BEQ	%FT20				;
	MOVS	r7,r7,ROR #1			;
	MOVCC	r1,#0				;
	MOVCS	r1,#1				;
	MOVS	r6,r6,ROR #1			;
	BLCS	Pi_Write_OE			;
	ADD	r5,r5,#1			;
	B	%BT10				;
20
	Pull	"r0-r8,pc"			; restore registers and exit
;preserves all registers
;---------------------------------------------
;readaux32
Pi_Read_Aux_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadByte			;
	Push	"r2-r5,lr"			;
	Pull	"r2-r5,pc"			; restore registers and exit
;r0=data state
;r1=bitmask
;preserves all others
;---------------------------------------------
;writeaux32
;r0=bits to set/unset
Pi_Write_Aux_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteByte			;
	Push	"r0-r7,lr"			;
	Pull	"r0-r7,pc"			; restore registers and exit
;preserves all registers

;---------------------------------------------
;readauxOE32
Pi_Read_Aux_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadByteOE			;
	Push	"r2-r7,lr"			;
	Pull	"r2-r7,pc"			; restore registers and exit
;r0=bitmask of OE register
;r1=bitmask
;preserves all others
;---------------------------------------------
;writeauxOE32
;r0=bits to set/unset
Pi_Write_Aux_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteByteOE			;
	Push	"r0-r7,lr"			;
	Pull	"r0-r7,pc"			; restore registers and exit
;preserves all registers
;---------------------------------------------
;readevent
;r0=gpio
Pi_Read_Event
	Push	"r1-r10,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPEDS0]		; read value
	AND	r0,r2,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0,1 or -1
;---------------------------------------------
;writeevent
;r0=gpio
Pi_Write_Event
	Push	"r1-r10,lr"			;
	MOV	r9,r1				; keep it
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPEDS0]		; read value
	CMP	r9,#0				;
	ORRNE	r2,r2,r1			;
	BICEQ	r2,r2,r1			;
	MOV	r0,r9				;
	STR	r2,[r3,#pi_GPEDS0]		; set register
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=r1 on entry or -1
;---------------------------------------------
;readevent
;r0=gpio
Pi_Read_Async
	Push	"r1-r10,lr"			;
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPAREN0]		; read value
	AND	r0,r2,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0,1 or -1
;---------------------------------------------
;writeevent
;r0=gpio
Pi_Write_Async
	Push	"r1-r10,lr"			;
	MOV	r9,r1				; keep it
	BL	pi_setup			;
	CMP	r0,#-1				;
	Pull	"r1-r10,pc",EQ			; restore registers and exit
	ADD	r3,r0,r4			;
	LDR	r2,[r3,#pi_GPAREN0]		; read value
	CMP	r9,#0				;
	ORRNE	r2,r2,r1			;
	BICEQ	r2,r2,r1			;
	MOV	r0,r9				;
	STR	r2,[r3,#pi_GPAREN0]		; set register
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=r1 on entry or -1
;---------------------------------------------
;r0=GPIO
Pi_Address
	Push	"r2-r10,lr"			;
	BL	pi_setup
	Pull	"r2-r10,pc"			;
;r0=Logical Base
;r1=Mask
;---------------------------------------------
;loadconfig
;r0 pointer to list
Pi_Load_Config
	Push	"r0-r10,lr"			;
	MOV	r4,r0
10	LDR	r0,[r4],#4			;get first word
	CMP	r0,#-1				;last ?
	BEQ	%FT20
	AND	r3,r0,#&0001F000		;get flags
	AND	r1,r0,#&00000700		;get pin mode
	MOV	r1,r1,LSR #8			;mode to bottom
	TST	r0,#i2c_flag			;i2c ?
	AND	r0,r0,#&FF			;just GPIO number and flag
	ADDNE	r0,r0,#i2c_flag			;add flag if needed
	MOV	r5,r0				;keep GPIO
	BL	Pi_Write_Mode			;set it
	TST	r0,#i2c_flag			;i2c ?
	BNE	%FT40				;do OE
	CMP	r1,#0				;
	CMPNE	r1,#1				;
	BNE	%FT30				;skip OE if not GPIO mode
40	TST	r3,#conf_io			;test IO bit
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Pi_Write_OE			;
30	TST	r3,#conf_extended		;test extended bit
	BEQ	%BT10				;get next if not
;extended bits


	B	%BT10				;get next
20
	Pull	"r0-r10,pc"			;
;---------------------------------------------
;readconfig
;r0 pointer for list or -1 for my space
;r1 extended or normal flag
Pi_Read_Config
	Push	"r2-r10,lr"			;
	CMP	r0,#-1				;my space or yours
	ADDEQ	r0,r12,#configdata		;point to my RMA store
	MOV	r7,r0				;save it for later
	MOV	r3,r1				;keep flag
	BL	get_table			;pointer to list of tables
	LDR	r2,[r1,#exp_pins]		;get list of registers
	CMP	r2,#-1				;
	BLNE	dopitableread			;
	LDR	r2,[r1,#aux_pins]		;get list of registers
	CMP	r2,#-1				;
	BLNE	dopitableread			;
	LDR	r2,[r1,#user_pins]		;get list of registers
	CMP	r2,#-1				;
	BLNE	dopitableread			;
	BL	i2c_ReadConfig			;
	MOV	r4,#-1				;
	STR	r4,[r0]				;end of list
	MOV	r1,r0				;pass pointer to terminator back to user
	MOV	r0,r7				;let user know location
	Pull	"r2-r10,pc"			;
;r0 pointer to list -1 terminated
;r1 pointer to terminator
dopitableread
	CMP	r2,#-1				;
	MOVEQ	pc,lr				;
	Push	"r1-r10,lr"			;
	MOV	r4,r0				;
10	LDRB	r0,[r2],#1			;get pin
	CMP	r0,#&FF				;last
	BEQ	%FT20				;do exp port now
	MOV	r5,r0				;save it
	STR	r0,[r4],#1			;start list
	BL	Pi_Read_Mode			;get pin mode
	AND	r6,r0,#7			;just mode
	MOV	r0,r5				;
	BL	Pi_Read_OE			;get the IO mode
	CMP	r0,#1				;test result
	MOVEQ	r0,#conf_io			;
	CMP	r0,#-1				;its not GPIO so default
	MOVEQ	r0,#0				;
	ORR	r6,r6,r0,LSR #8			;add flag
	CMP	r3,#1				;test extended request
	MOVEQ	r0,#conf_extended		;
	MOVNE	r0,#0				;
	ORR	r6,r6,r0,LSR #8			;
	STRB	r6,[r4],#1			;save flags
	ADDNE	r4,r4,#2			;point to next word
	BNE	%BT10				;
	MOV	r6,#0				;clear flag register
	MOV	r0,r5				;
	BL	Pi_Read_Level0			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_lv0			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Pi_Read_Level1			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_lv1			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Pi_Read_Rising			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_rising			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Pi_Read_Falling			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_falling		;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Pi_Read_DebounceEnable		;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_debounce		;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Pi_Read_IRQ1			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_irq1			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Pi_Read_IRQ2			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_irq2			;
	ORR	r6,r6,r0,LSR #16		;add flag
	STRB	r6,[r4],#1			;save flags
	ADD	r4,r4,#1			;point to next word
	B	%BT10				;get next
20
	MOV	r0,r4				;pass pointer back
	Pull	"r1-r10,pc"			;

;---------------------------------------------
;r0=0 or 1 1=enable
Pi_Enable_I2C
	Push	"r0-r10,lr"			;
	CMP	r0,#0				;
	BEQ	%FT10				;
	MOV	r3,r0				;keep r0
	BL	get_table			;
	LDR	r2,[r1,#i2c_pins]		;get list of registers
	CMP	r2,#-1				;no table
	MOVEQ	r0,#0				;so not protected
	BEQ	%FT10				;
30	LDRB	r0,[r2]				;
	CMP	r0,#&FF				;
	BEQ	%FT20
	MOV	r1,#Pi_Alt0			;
	LDRB	r0,[r2],#1			;writeback pointer
	BL	Pi_Write_Mode			;
	B	%BT30
20	MOV	r0,r3				;get r0
10	STR	r0,[r12,#i2cprotect]		;set flag
	Pull	"r0-r10,pc"			;
;---------------------------------------------
Pi_GPIO_Info
	Push	"r3-r10,lr"			;
;copy table 2,3,4,5 to RMA
	BL	copy_tables_to_rma
	MOV	r0,#0				;lowest GPIO number
	MOV	r1,#pi_top_gpio			;Highest GPIO number
	Pull	"r3-r10,pc"			;
;r0=lowest gpio
;r1=higest gpio
;r2 pointer to tables of useable pins
;preserves other registers
;---------------------------------------------

	END
