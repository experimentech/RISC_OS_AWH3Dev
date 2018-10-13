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

;s.BeagleSWIs


;***************** S W I 's ***********
;ReadData
;r0=GPIO number
Read_Data
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_Data			;
	Push	"r1-r10,lr"			;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r6,[r2,#proc_oe]		;
	LDRH	r5,[r2,#proc_datain]		;
	LDRH	r4,[r2,#proc_dataout]		;
	LDR	r2,[r0,r6]			;get oe register value
	AND	r2,r2,r1			;
	CMP	r2,#0				;is it output ?
	LDREQ	r0,[r0,r4]			;read data copy
	LDRNE	r0,[r0,r5]			;read data input
	AND	r0,r0,r1			;mask just ours
	CMP	r0,#0				;
	MOVNE	r0,#1				;
10
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=value (0 or 1) -1 if not GPIO

;---------------------------------------------

;WriteData
;r0=GPIO number
;r1=value
Write_Data
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_Data			;
	Push	"r2-r10,lr"			;
	MOV	r7,r1				;save value
	BL	check_protect_i2c		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r6,[r2,#proc_oe]		;
	LDRH	r5,[r2,#proc_cleardataout]	;
	LDRH	r4,[r2,#proc_setdataout]	;
	LDR	r2,[r0,r6]			;get oe register value
	TST	r2,r1				;is pin output
	MOVNE	r0,#-1				;its an input
	BNE	%FT10				;
	CMP	r7,#0				;check flag
	STRNE	r1,[r0,r4]			;set data bit
	STREQ	r1,[r0,r5]			;unset data bit
10
	Pull	"r2-r10,pc"			; restore registers and exit
;r0= -1 if input , protected or not GPIO
;or
;r0=logical address
;r1=pin

;---------------------------------------------
;ReadOE
;r0=GPIO number
Read_OE
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_OE			;
	Push	"r1-r10,lr"			;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r6,[r2,#proc_oe]		;
	LDR	r0,[r0,r6]			;get oe register value
	AND	r0,r0,r1			;
	CMP	r0,#0				;is it output ?
	MOVNE	r0,#1				;opposite logic to match Pi
10
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=value (0=output,1=input)

;---------------------------------------------
;WriteOE
;r0=GPIO number
;r1=value 0 or 1
Write_OE
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_OE			;
	Push	"r1-r10,lr"			;
	SWI	XOS_IntOff
	MOV	r7,r1				;save value
	BL	check_protect_i2c		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	Push	"r0"				;
	BL	get_table			;
	BL	find_register			;
	TST	r0,#input_only			;
	MOVNE	r7,#1				;
	Pull	"r0"				;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r6,[r2,#proc_oe]		;
	LDR	r3,[r0,r6]			;get oe register value
	CMP	r7,#0				;set as output or input
	BICEQ	r3,r3,r1			;set pin as output if not already
	ORRNE	r3,r3,r1			;set pin as input if not already
	STR	r3,[r0,r6]			;save back
	MOV	r0,#0				;
10	SWI	XOS_IntOn
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0 if ok -1 if protected

;----------------------------------------------
; MapAuxIn
;r0=mode
Aux_As_GPIO
	Push	"r0-r10,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#aux_pins]		;get list of pins
common	CMP	r6,#-1				;
	BEQ	%FT20
	TST	r0,#2				;check if in/out
	MOVEQ	r7,#1				;set OE
	MOVNE	r7,#0				;set OE
	TST	r0,#1				;check if up/down
	MOVEQ	r3,#mygpiomode1			;mode for pins
	MOVNE	r3,#mygpiomode2			;mode for pins
common1
10	LDRB	r0,[r6],#1			;get pin number
	CMP	r0,#&FF				;last one ?
	BEQ	%FT20				;
	MOV	r1,r3				;keep mode type
	MOV	r4,r0				;keep gpio number
	BL	Write_Mode			;
	CMP	r0,#-1				;
	BEQ	%BT10				;
	CMP	r7,#&FF				;skip OE
	BEQ	%BT10				;
	MOV	r1,r7				;get in/out mode
	MOV	r0,r4				;get gpio number
	BL	Write_OE			;write OE
	CMP	r7,#0				;set outputs ?
	BNE	%BT10				;
	MOV	r0,r4				;get gpio number
	MOV	r1,#0				;set output to off
	BL	Write_Data			;write data
	B	%BT10				;next
20
	Pull	"r0-r10,pc"			; restore registers and exit
;---------------------------------------------
; MapExpIn
;r0=mode
Exp_As_GPIO
	Push	"r0-r10,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#exp_pins]		;get list of pins
	B	common				;

;---------------------------------------------
; MapCameraIn
;r0=mode
Camera_As_GPIO
	Push	"r0-r10,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#camera_pins]		;get list of pins
	B	common				;
;---------------------------------------------
; SafeAuxIn
Aux_As_Safe
	Push	"r0-r10,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#aux_pins]		;get list of pins
safe	CMP	r6,#-1				;
	BEQ	%FT20
	MOV	r3,#safemode			;safe mode
	MOV	r7,#&FF				;skip OE write
	B	common1				;
20
	Pull	"r0-r10,pc"			; restore registers and exit
;---------------------------------------------
; SafeExpIn
Exp_As_Safe
	Push	"r0-r10,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#exp_pins]		;get list of pins
	B	safe				;
;---------------------------------------------
; SafecameraIn
Camera_As_Safe
	Push	"r0-r10,lr"			;
	BL	get_table			;
	LDR	r6,[r1,#camera_pins]		;get list of pins
	B	safe				;
;---------------------------------------------
;
Aux_As_USB
	Push	"r0-r10,lr"			;
	MOV	r7,#usb_pins			;
set_pins
	BL	get_table			;
	LDR	r6,[r1,r7]			;get list of pins + mode
	CMP	r6,#-1				;
	BEQ	%FT20
10	LDRH	r1,[r6],#2			;get pin and mode
	CMP	r1,#&FF				;last ?
	BEQ	%FT20				;
	AND	r0,r1,#&FF			;just gpio
	MOV	r1,r1,LSR #8			;just mode
	BL	Write_Mode
	B	%BT10
20
	Pull	"r0-r10,pc"			; restore registers and exit
;---------------------------------------------
;
Exp_As_UART
	Push	"r0-r10,lr"			;
	MOV	r7,#uart_pins			;
	B	set_pins			;
;---------------------------------------------
;
Aux_As_MMC
	Push	"r0-r10,lr"			;
	MOV	r7,#mmc_aux_pins		;
	B	set_pins			;
;---------------------------------------------
; mode2AuxIn
Exp_As_MMC
	Push	"r0-r10,lr"			;
	MOV	r7,#mmc_exp_pins		;
	B	set_pins			;
;---------------------------------------------
; mode3AuxIn
Aux_As_MM
	Push	"r0-r10,lr"			;
	MOV	r7,#mm_pins			;
	B	set_pins			;
;---------------------------------------------
;ReadMode
;r0=GPIO number
Read_Mode
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_Mode
	Push	"r1-r10,lr"			;
	MOV	r5,#1				; read/write flag
;r5=read or write (1/0)
;r6=mode to write
modecommon
	BL	get_table			;
	BL	find_register			;
	CMP	r0,#-1				;error ?
	BEQ	%FT10				;
	BIC	r0,r0,#input_only		; preserve r0
	MOV	r4,r0
	LDR	r1,[r12,#logicalstore1]		;get logical address
	CMP	r5,#0				; check read/write flag
	STREQH	r6,[r1,r4]			; write half word
	LDRNEH	r0,[r1,r4]			; read half word
	MOVEQ	r0,r6
10
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=mode (-1=not ours)
;---------------------------------------------
;WriteMode
;r0=GPIO number
;r1=mode
Write_Mode
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_Mode
	Push	"r1-r10,lr"			;
	MOV	r6,r1				; preserve data
	BL	check_protect_i2c		;
	MOV	r5,#0				; read/write flag
	CMP	r0,#-1				;
	BNE	modecommon			;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=mode (-1=not ours)
;---------------------------------------------
;ReadLevel0
;r0=GPIO number
Read_Level0
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_Polarity
	Push	"r1-r10,lr"			;
	MOV	r7,#1				; read/write flag
	MOV	r8,#proc_leveldetect0		;register
;r5=read or write (1,0)
;r6=mode to write
;r9=register to check
levelcommon
	BL	get_logical_and_pin		;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r8,[r2,r8]			;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	LDR	r3,[r0,r8]			;get register value
	MOV	r4,r3				;keep setting
	CMP	r6,#0				;set/unset
	BICEQ	r3,r3,r1			;dont care if reading
	ORRNE	r3,r3,r1			;
	CMP	r7,#0				;
	STREQ	r3,[r0,r8]			;save back
	AND	r0,r4,r1			;
	CMP	r0,#0				;
	MOVNE	r0,#1				;
10
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=mode
;---------------------------------------------
;WriteLevel0
;r0=GPIO number
;r1=0/1
Write_Level0
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_Polarity
	Push	"r1-r10,lr"			;
	MOV	r8,#proc_leveldetect0		;register
write_register
	MOV	r7,#0				; read/write flag
	CMP	r1,#0				; preserve data
	MOVEQ	r6,#0				;
	MOVNE	r6,#1				;
	BL	check_protect_i2c		;
	CMP	r0,#-1				;
	BNE	levelcommon			;
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=mode or -1 if protected
;preserves all others
;---------------------------------------------
;ReadLevel1
;r0=GPIO number
Read_Level1
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Read_Pull
	Push	"r1-r10,lr"			;
	MOV	r7,#1				; read/write flag
	MOV	r8,#proc_leveldetect1		;register
	B	levelcommon			;
;---------------------------------------------
;WriteLevel1
;r0=GPIO number
;r1=0/1
Write_Level1
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_Write_Pull
	Push	"r1-r10,lr"			;
	MOV	r8,#proc_leveldetect1		;register
	B	write_register			;
;---------------------------------------------
;ReadRising
;r0=GPIO number
Read_Rising
	Push	"r1-r10,lr"			;
	MOV	r7,#1				; read/write flag
	MOV	r8,#proc_risingdetect		;register
	B	levelcommon			;
;---------------------------------------------
;WriteRising
;r0=GPIO number
;r1=0/1
Write_Rising
	Push	"r1-r10,lr"			;
	MOV	r8,#proc_risingdetect		;register
	B	write_register			;
;---------------------------------------------
;ReadFallin
;r0=GPIO number
Read_Falling
	Push	"r1-r10,lr"			;
	MOV	r7,#1				; read/write flag
	MOV	r8,#proc_fallingdetect		;register
	B	levelcommon			;
;---------------------------------------------
;WriteFalling
;r0=GPIO number
;r1=0/1
Write_Falling
	Push	"r1-r10,lr"			;
	MOV	r8,#proc_fallingdetect		;register
	B	write_register			;
;---------------------------------------------
;ReadDebounceEnable
;r0=GPIO number
Read_DebounceEnable
	Push	"r1-r10,lr"			;
	MOV	r7,#1				; read/write flag
	MOV	r8,#proc_debounceenable		;register
	B	levelcommon			;
;---------------------------------------------
;WriteDebounceEnable
;r0=GPIO number
;r1=0/1
Write_DebounceEnable
	Push	"r1-r10,lr"			;
	MOV	r8,#proc_debounceenable		;register
	B	write_register			;
;---------------------------------------------
;ReadIRQ1
;r0=GPIO number
Read_IRQ1
	Push	"r1-r10,lr"			;
	MOV	r7,#1				; read/write flag
	MOV	r8,#proc_irqstatus1		;
	B	levelcommon			;
;---------------------------------------------
;WriteIRQ1
;r0=GPIO number
;r1=0/1
Write_IRQ1
	Push	"r1-r10,lr"			;
	MOV	r7,r1				;
	BL	check_protect_i2c		;
	CMP	r0,#-1				;
	BEQ	%FT10
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r6,[r2,#proc_irqstatus1]	;
	LDRH	r5,[r2,#proc_setirqenable1]	;
	LDRH	r4,[r2,#proc_clearirqenable1]	;
irqcommon
	LDR	r3,[r0,r6]			;get register value
	AND	r1,r3,r1			;
	CMP	r7,#0				;check flag
	STRNE	r1,[r0,r5]			;set irq bit
	STREQ	r1,[r0,r4]			;unset irq bit
	MOV	r0,#0				;
10
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0 if ok -1 if protected
;preserves all others
;---------------------------------------------
;ReadIRQ2
;r0=GPIO number
Read_IRQ2
	Push	"r1-r10,lr"			;
	MOV	r7,#1				; read/write flag
	MOV	r8,#proc_irqstatus2		;
	B	levelcommon			;
;---------------------------------------------
;WriteIRQ2
;r0=GPIO number
;r1=0/1
Write_IRQ2
	Push	"r1-r10,lr"			;
	MOV	r7,r1				;
	BL	check_protect_i2c		;
	BEQ	%FT10				;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r6,[r2,#proc_irqstatus2]	;
	LDRH	r5,[r2,#proc_setirqenable2]	;
	LDRH	r4,[r2,#proc_clearirqenable2]	;
	B	irqcommon
10
	Pull	"r1-r10,pc"			; restore registers and exit
;r0=0 if ok -1 if protected
;preserves all others
;---------------------------------------------
;readexp32
Read_Exp_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadBlock			;
	Push	"r2-r10,lr"			;
	BL	get_table			;
	LDR	r0,[r1,#widebit_pins]		;get list of pins
	CMP	r0,#-1				;check if exists
	BEQ	%FT10				;
	LDR	r5,[r0,#wide_exp]		;get mask
	LDR	r0,[r0,#wide_exppin]		;first pin
commonread32
	CMP	r0,#-1				;check if exists
	BEQ	%FT10				;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r4,[r2,#proc_oe]		;
	LDR	r4,[r0,r4]			;get oe register value
	LDRH	r6,[r2,#proc_dataout]		;
	LDR	r3,[r0,r6]			;get register value
	LDRH	r6,[r2,#proc_datain]		;
	LDR	r0,[r0,r6]			;get register value
	AND	r0,r0,r4			;just inputs
	MVN	r4,r4				;
	AND	r0,r3,r4			;just our pins again
	AND	r0,r0,r5			;just our pins
	MOV	r1,r5				;give user the bitmask
10
	Pull	"r2-r10,pc"			; restore registers and exit
;r0=data state
;r1=bitmask
;preserves all others
;---------------------------------------------
;Readaux32
;r0=bits to set/unset
Read_Aux_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadByte			;
	Push	"r2-r10,lr"			;
	BL	get_table			;
	LDR	r0,[r1,#widebit_pins]		;get list of pins
	CMP	r0,#-1				;check if exists
	BEQ	%BT10				;
	LDR	r5,[r0,#wide_aux]		;get mask
	LDR	r0,[r0,#wide_auxpin]		;first pin
	B	commonread32
;r0=bitmask of data state
;r1=bitmask
;preserves all others
;---------------------------------------------
;Readcam32
Read_Cam_32
	Push	"r2-r10,lr"			;
	BL	get_table			;
	LDR	r0,[r1,#widebit_pins]		;get list of pins
	CMP	r0,#-1				;check if exists
	BEQ	%BT10				;
	LDR	r5,[r0,#wide_cam]		;get mask
	LDR	r0,[r0,#wide_campin]		;first pin
	B	commonread32
;r0=bitmask of data state
;r1=bitmask
;preserves all others
;---------------------------------------------
;writeexp32
;r0=bits to set/unset
Write_Exp_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteBlock			;
	Push	"r0-r10,lr"			;
	LDR	r7,exp_bitmap			;get mask
	MOV	r6,r0				;keep bitmap
	MOV	r0,#gpio_139			;check mapped in
common32
	BL	check_protect_i2c		;
	CMP	r0,#-1				;error
	BEQ	%FT10				;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r5,[r2,#proc_setdataout]	;
	LDRH	r4,[r2,#proc_cleardataout]	;
	MVN	r3,r6				;invert settings
	ANDS	r3,r3,r7			;just our pins
	STRNE	r3,[r0,r4]			;unset them
	ANDS	r4,r6,r7			;just our pins
	STRNE	r4,[r0,r5]			;set them
10
	Pull	"r0-r10,pc"			; restore registers and exit
;preserves all registers
exp_bitmap	DCD	expbitmap
;---------------------------------------------
;writeaux32
;r0=bits to set/unset
Write_Aux_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteByte			;
	Push	"r0-r10,lr"			;
	LDR	r7,aux_bitmap			;get mask
	MOV	r6,r0				;keep bitmap
	MOV	r0,#gpio_12			;check mapped in
	B	common32
;preserves all registers
aux_bitmap	DCD	auxbitmap
;---------------------------------------------
;writecam32
;r0=bits to set/unset
Write_Cam_32
	Push	"r0-r10,lr"			;
	LDR	r7,cam_bitmap			;get mask
	MOV	r6,r0				;keep bitmap
	MOV	r0,#gpio_96			;check mapped in
	B	common32
;preserves all registers
cam_bitmap	DCD	cambitmap
;---------------------------------------------
;readexpOE32
Read_Exp_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadBlockOE			;
	Push	"r2-r10,lr"			;
	LDR	r5,exp_bitmap			;get mask
	MOV	r0,#gpio_139			;check mapped in
commonoeread32
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r6,[r2,#proc_oe]		;
	LDR	r0,[r0,r6]			;get register value
	AND	r0,r0,r5			;just our pins
	MOV	r1,r5				;give user bitmask
10
	Pull	"r2-r10,pc"			; restore registers and exit
;r0=bitmask of OE register
;r1=bitmask
;preserves all others

;---------------------------------------------
;readauxoe32
Read_Aux_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_ReadByteOE			;
	Push	"r2-r10,lr"			;
	LDR	r5,aux_bitmap			;get mask
	MOV	r0,#gpio_12			;check maped in
	B	commonoeread32
;r0=bitmask of OE register
;r1=bitmask
;preserves all others
;---------------------------------------------
;readcamoe32
;r0=bits to set/unset
Read_Cam_OE_32
	Push	"r2-r10,lr"			;
	LDR	r5,cam_bitmap			;get mask
	MOV	r0,#gpio_96			;check maped in
	B	commonoeread32
;r0=bitmask of OE register
;r1=bitmask
;preserves all others
;---------------------------------------------
;writeexpOE32
;r0=bits to set/unset
Write_Exp_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteBlockOE		;
	Push	"r0-r10,lr"			;
	LDR	r7,exp_bitmap			;get mask
	MOV	r6,r0				;keep bitmap
	MOV	r0,#gpio_139			;check maped in
commonoe32
	BL	check_protect_i2c		;
	CMP	r0,#-1				;error
	BEQ	%FT10				;
	BL	get_logical_and_pin		;
	CMP	r0,#-1				;
	BEQ	%FT10				;
	ADRL	r4,proc_reg_list		;
	ADD	r2,r2,r4			;
	LDRH	r5,[r2,#proc_oe]		;
	LDR	r2,[r0,r5]			;get register value
	MVN	r3,r7				;opposit mask
	AND	r4,r6,r7			;just our pins
	AND	r2,r2,r3			;clears all our outputs
	ORR	r1,r2,r4			;set/unset our pins
	STR	r1,[r0,r5]			;
10
	Pull	"r0-r10,pc"			; restore registers and exit
;preserves all registers
;---------------------------------------------
;writeauxoe32
;r0=bits to set/unset
Write_Aux_OE_32
	CMP	r0,#i2c_flag-1			;check if i2c gpio
	BCS	i2c_WriteByteOE			;
	Push	"r0-r10,lr"			;
	LDR	r7,aux_bitmap			;get mask
	MOV	r6,r0				;keep bitmap
	MOV	r0,#gpio_12			;check maped in
	B	commonoe32
;preserves all registers
;---------------------------------------------
;writecamoe32
;r0=bits to set/unset
Write_Cam_OE_32
	Push	"r0-r10,lr"			;
	LDR	r7,cam_bitmap			;get mask
	MOV	r6,r0				;keep bitmap
	MOV	r0,#gpio_96			;check maped in
	B	commonoe32
;preserves all registers
;---------------------------------------------
;r0=GPIO
Address
	Push	"r2-r10,lr"			;
	BL	get_logical_and_pin		;
	Pull	"r2-r10,pc"			;
;r0=Logical
;r1=Mask
;---------------------------------------------
;sramread
;r0=pointer to sram to get
;r1=pointer to buffer
;r2=size
sramread
	Push	"r0-r10,lr"			;
	ADD	r3,r0,r2			;check address
	CMP	r3,#sramsize			;
	BGE	%FT10				;bad address
	LDR	r3,[r12,#logicalsram]		;sram logical
	CMP	r3, #-1				;
	BEQ	%FT10				;bad address
	MOV	r5,r2				;
	ADD	r2,r2,r0			;add pointer
20	LDRB	r4,[r3,r2]			;get word
	STRB	r4,[r1,r5]			;save it
	SUB	r2,r2,#1			;dec pointer
	SUB	r5,r5,#1			;dec pointer
	CMP	r2,r0				;last byte ?
	BGE	%BT20				;
10
	Pull	"r0-r10,pc"			;
;---------------------------------------------
;sramwrite
;r0=pointer to sram to write
;r1=pointer to buffer
;r2=size
sramwrite
	Push	"r0-r10,lr"			;
	ADD	r3,r0,r2			;check address
	CMP	r3,#sramsize			;
	BGE	%FT10				;bad address
	LDR	r3,[r12,#logicalsram]		;sram logical
	CMP	r3, #-1				;
	BEQ	%FT10				;bad address
	MOV	r5,r2				;
	ADD	r2,r2,r0			;add pointer
20	LDRB	r4,[r1,r5]			;get word
	STRB	r4,[r3,r2]			;save it
	SUB	r2,r2,#1			;dec pointer
	SUB	r5,r5,#1			;dec pointer
	CMP	r2,r0				;last byte ?
	BGE	%BT20				;
10
	Pull	"r0-r10,pc"			;
;---------------------------------------------

;loadconfig
;r0 pointer to list
Load_Config
	Push	"r0-r10,lr"			;
	MOV	r4,r0
10	LDR	r0,[r4],#4			;get first word
	CMP	r0,#-1				;last ?
	BEQ	%FT20
	AND	r3,r0,#&0001F000		;get flags
	AND	r1,r0,#&00000700		;get pin mode
	MOV	r1,r1,LSR #8			;mode to bottom
	TST	r3,#conf_updown			;test updown bit
	ADDNE	r1,r1,#pullenable+pullup	;
	ADDEQ	r1,r1,#pullenable+pulldown	;
	TST	r3,#conf_inenable		;test input enable bit
	ADDEQ	r1,r1,#inputenable		;
	ADDNE	r1,r1,#inputdisable		;
	TST	r0,#i2c_flag			;i2c ?
	AND	r0,r0,#&FF			;just GPIO number
	ADDNE	r0,r0,#i2c_flag			;add flag if needed
	MOV	r5,r0				;keep GPIO
	BL	Write_Mode			;set it
	TST	r3,#conf_io			;test IO bit
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_OE			;
	TST	r3,#conf_extended		;test extended bit
	BEQ	%BT10				;get next if not
	TST	r3,#conf_lv0			;
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_Level0			;
	TST	r3,#conf_lv1			;
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_Level1			;
	TST	r3,#conf_rising			;
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_Rising			;
	TST	r3,#conf_falling		;
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_Falling			;
	TST	r3,#conf_debounce		;
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_DebounceEnable		;
	TST	r3,#conf_irq1			;
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_IRQ1			;
	TST	r3,#conf_irq2			;
	MOVNE	r1,#1				;set flag
	MOVEQ	r1,#0				;
	MOV	r0,r5				;gpio number
	BL	Write_IRQ2			;
	B	%BT10				;
20
	Pull	"r0-r10,pc"			;
;preserves all registers
;---------------------------------------------
;readconfig
;r0 pointer for list or -1 for my space
;r1 extended or normal flag
Read_Config
	Push	"r2-r10,lr"			;
	CMP	r0,#-1				;my space or yours
	ADDEQ	r0,r12,#configdata		;point to my RMA store
	MOV	r7,r0				;save it for later
	MOV	r3,r1				;keep flag
	BL	get_table			;pointer to list of tables
	LDR	r2,[r1,#aux_pins]		;get list of registers
	CMP	r2,#-1				;check if exists
	BLNE	dotableread			;
	LDR	r2,[r1,#exp_pins]		;get list of registers
	CMP	r2,#-1				;check if exists
	BLNE	dotableread			;
	LDR	r2,[r1,#camera_pins]		;get list of registers
	CMP	r2,#-1				;check if exists
	BLNE	dotableread			;
	LDR	r2,[r1,#user_pins]		;get list of registers
	CMP	r2,#-1				;check if exists
	BLNE	dotableread			;
	BL	i2c_ReadConfig			;do i2c read
	MOV	r4,#-1				;
	STR	r4,[r0]				;end of list
	MOV	r1,r0				;pass pointer to terminator back to user
	MOV	r0,r7				;let user know location
	Pull	"r2-r10,pc"			;
;r0 pointer to list -1 terminated
;r1 pointer to terminator


dotableread
	Push	"r1-r10,lr"			;
	MOV	r4,r0				;
10	LDRB	r0,[r2],#1			;get pin
	CMP	r0,#&FF				;last
	BEQ	%FT20				;do exp port now
	MOV	r5,r0				;save it
	STR	r0,[r4],#1			;start list
	BL	Read_Mode			;get pin mode
	AND	r6,r0,#7			;just mode
	TST	r0,#pullup			;
	MOVNE	r1,#conf_updown			;
	MOVEQ	r1,#0				;
	TST	r0,#pullenable			;
	ADDEQ	r1,r1,#conf_inenable		;
	ADDNE	r1,r1,#0			;
	ORR	r6,r6,r1,LSR #8			;set flags
	MOV	r0,r5				;
	BL	Read_OE				;get the IO mode
	CMP	r0,#1				;test result
	MOVEQ	r0,#conf_io			;
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
	BL	Read_Level0			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_lv0			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Read_Level1			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_lv1			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Read_Rising			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_rising			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Read_Falling			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_falling		;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Read_DebounceEnable		;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_debounce		;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Read_IRQ1			;
	CMP	r0,#1				;test result
	MOVNE	r0,#conf_irq1			;
	ORR	r6,r6,r0,LSR #16		;add flag
	MOV	r0,r5				;
	BL	Read_IRQ2			;
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
Enable_I2C
	Push	"r0-r10,lr"			;
	CMP	r0,#0				;
	BEQ	%FT10				;
	MOV	r3,r0				;keep r0
	BL	get_table			;
	LDR	r4,[r1,#i2c_pins]		;get list of registers
	CMP	r4,#-1				;no table
	MOVEQ	r0,#0				;so not protected
	BEQ	%FT10
30	LDRB	r0,[r4]				;
	CMP	r0,#&FF				;
	BEQ	%FT20
	BL	Read_Mode			;get old setting
	BIC	r0,r0,#7			;clear mode
	ORR	r1,r0,#mode0			;set to mode 0
	LDRB	r0,[r4],#1			;writeback pointer
	BL	Write_Mode			;
	B	%BT30
20	MOV	r0,r3				;get r0
10	STR	r0,[r12,#i2cprotect]		;set flag
	Pull	"r0-r10,pc"			;
;preserves all registers
;---------------------------------------------
GPIO_Info
	Push	"r3-r10,lr"			;
;copy table 2,3,4,5 to RMA
	BL	copy_tables_to_rma
	MOV	r0,#0				;lowest GPIO number
	MOV	r1,#top_gpio			;Highest GPIO number
	Pull	"r3-r10,pc"			;
;r0=lowest gpio
;r1=higest gpio
;r2=pointer to tables of useable pins
;preserves other registers;---------------------------------------------


	END
