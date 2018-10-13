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

;ReadData
;r0=GPIO number
i2c_Read_Data
	Push	"r1-r6,lr"
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r6,pc",EQ			; restore registers and exit
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpgpioa			;
	BL	i2c_read			;
	Pull	"r1-r6,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	AND	r0,r0,r5			;mask pin
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r6,pc"			; restore registers and exit
;r0=value (0 or 1) -1 if not there
;---------------------------------------------
;WriteData
;r0=GPIO number
;r1=value
i2c_Write_Data
	Push	"r0-r8,lr"			;
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r0-r8,pc",EQ			; restore registers and exit
	MOV	r6,r0				;
	MOV	r7,r1				;
	BL	i2c_Read_Data			;
	Pull	"r1-r8,pc",VS			;restore registers and exit if error
	MOV	r0,r6				;
	ADD	r4,r12,#i2creturn		;
	LDRB	r6,[r4]				;
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpgpioa			;
	CMP	r7,#0				;
	BICEQ	r2,r6,r5			;
	ORRNE	r2,r6,r5			;
	BL	i2c_write			;
	Pull	"r0-r8,pc"			; restore registers and exit
;---------------------------------------------
;ReadOE
;r0=GPIO number
i2c_Read_OE
	Push	"r1-r6,lr"
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r6,pc",EQ			; restore registers and exit
	BL	i2c_get_things
	MOV	r2,#1				;
	ADD	r1,r4,#mcpiodira		;
	BL	i2c_read			;
	Pull	"r1-r6,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	AND	r0,r0,r5			;mask pin
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r6,pc"			; restore registers and exit
;r0=value (0 or 1) or -1 if not there
;---------------------------------------------
;WriteOE
;r0=GPIO number
;r1=value
i2c_Write_OE
	Push	"r1-r7,lr"			;
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r7,pc",EQ			; restore registers and exit
	MOV	r6,r0				;
	MOV	r7,r1				;
	BL	i2c_Read_OE			;
	MOV	r0,r6				;
	ADD	r4,r12,#i2creturn		;
	LDRB	r6,[r4]				;
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpiodira		;
	CMP	r7,#0				;
	BICEQ	r2,r6,r5			;
	ORRNE	r2,r6,r5			;
	BL	i2c_write			;
	Pull	"r1-r7,pc"			; restore registers and exit
;r0=old value or -1 if not there
;---------------------------------------------
;ReadMode
;WriteMode
;r0=GPIO number
;r1=value
i2c_Read_Mode
i2c_Write_Mode
	Push	"r1-r7,lr"			;
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r7,pc",EQ			; restore registers and exit
	MOV	r0,#4				; GPIO
	Pull	"r1-r7,pc"			; restore registers and exit
;r0=old value or -1 if not there
;---------------------------------------------
;r0=chip address (0-7)
i2c_ReadBlock
	Push	"r1-r9,lr"			;
	AND	r0,r0,#&7			;
	MOV	r0,r0,LSL #4			;point to first gpio of chip
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r9,pc",EQ			; restore registers and exit
	ADD	r9,r0,#8			;point to eighth gpio of chip
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpgpioa			;
	BL	i2c_read			;
	Pull	"r1-r9,pc",VS			;restore registers and exit if error
	LDRB	r8,[r1]				;
	MOV	r0,r9				;get second port readings
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpgpioa			;
	BL	i2c_read			;
	Pull	"r1-r9,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	MOV	r0,r0,LSL#8			;move up
	ORR	r0,r0,r8			;add in 0-7 bits
	Pull	"r1-r9,pc"			; restore registers and exit
;r0=16 bits from chip or -1 if not there
;---------------------------------------------
;r0=chip address (0-7)
;r1=lower 16 bits of gpio i/o
i2c_WriteBlock
	Push	"r0-r8,lr"			;
	AND	r0,r0,#&7			;
	MOV	r0,r0,LSL #4			;point to first gpio of chip
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r0-r8,pc",EQ			; restore registers and exit
	ADD	r8,r0,#8			;point to eighth gpio of chip
	MOV	r7,r1				;save for later
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpgpioa			;
	AND	r2,r7,#&FF			;just bottom 8
	BL	i2c_write			;
	Pull	"r0-r8,pc",VS			;restore registers and exit if error
	MOV	r0,r8				;do next 8
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpgpioa			;
	MOV	r7,r7,LSR #8			;move down
	AND	r2,r7,#&FF			;just bottom 8
	BL	i2c_write			;
	Pull	"r0-r8,pc"			; restore registers and exit
;---------------------------------------------
;r0=chip address (0-7)
i2c_ReadBlockOE
	Push	"r1-r9,lr"			;
	AND	r0,r0,#&7			;
	MOV	r0,r0,LSL #4			;point to first gpio of chip
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r9,pc",EQ			; restore registers and exit
	ADD	r9,r0,#8			;point to eighth gpio of chip
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpiodira		;
	BL	i2c_read			;
	Pull	"r1-r9,pc",VS			;restore registers and exit if error
	LDRB	r8,[r1]				;
	MOV	r0,r9				;get second port readings
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpiodira		;
	BL	i2c_read			;
	Pull	"r1-r9,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	MOV	r0,r0,LSL#8			;move up
	ORR	r0,r0,r8			;add in 0-7 bits
	Pull	"r1-r9,pc"			; restore registers and exit
;r0=16 bits from chip
;---------------------------------------------
;r0=chip address (0-7)
;r1=lower 16 bits of gpio oe
i2c_WriteBlockOE
	Push	"r0-r8,lr"			;
	AND	r0,r0,#&7			;
	MOV	r0,r0,LSL #4			;point to first gpio of chip
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r0-r8,pc",EQ			; restore registers and exit
	ADD	r8,r0,#8			;point to eighth gpio of chip
	MOV	r7,r1				;save for later
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpiodira		;
	AND	r2,r7,#&FF			;just bottom 8
	BL	i2c_write			;
	Pull	"r0-r8,pc",VS			;restore registers and exit if error
	MOV	r0,r8				;do next 8
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpiodira		;
	MOV	r7,r7,LSR #8			;move down
	AND	r2,r7,#&FF			;just bottom 8
	BL	i2c_write			;
	Pull	"r0-r8,pc"			; restore registers and exit
;---------------------------------------------
;r0=port address (0-15)
i2c_ReadByte
	Push	"r1-r9,lr"			;
	AND	r0,r0,#&15			;
	MOV	r0,r0,LSL #3			;point to first gpio of port
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r9,pc",EQ			; restore registers and exit
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpgpioa			;
	BL	i2c_read			;
	Pull	"r1-r9,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	Pull	"r1-r9,pc"			; restore registers and exit
;r0=8 bits from chip or -1 if not there
;---------------------------------------------
;r0=port address (0-15)
;r1=lower 8 bits of gpio i/o
i2c_WriteByte
	Push	"r0-r8,lr"			;
	AND	r0,r0,#&15			;
	MOV	r0,r0,LSL #3			;point to first gpio of port
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r0-r8,pc",EQ			; restore registers and exit
	MOV	r7,r1				;save for later
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpgpioa			;
	AND	r2,r7,#&FF			;just bottom 8
	BL	i2c_write			;
	Pull	"r0-r8,pc"			; restore registers and exit
;---------------------------------------------
;r0=port address (0-15)
i2c_ReadByteOE
	Push	"r1-r9,lr"			;
	AND	r0,r0,#&15			;
	MOV	r0,r0,LSL #3			;point to first gpio of port
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r9,pc",EQ			; restore registers and exit
	BL	i2c_get_things			;
	MOV	r2,#1				;
	ADD	r1,r4,#mcpiodira		;
	BL	i2c_read			;
	Pull	"r1-r9,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	Pull	"r1-r9,pc"			; restore registers and exit
;r0=8 bits from chip
;---------------------------------------------
;r0=port address (0-15)
;r1=lower 16 bits of gpio oe
i2c_WriteByteOE
	Push	"r0-r8,lr"			;
	AND	r0,r0,#&15			;
	MOV	r0,r0,LSL #3			;point to first gpio of port
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r0-r8,pc",EQ			; restore registers and exit
	MOV	r7,r1				;save for later
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpipola			;
	AND	r2,r7,#&FF			;just bottom 8
	BL	i2c_write			;
	Pull	"r0-r8,pc"			; restore registers and exit
;---------------------------------------------
i2c_Read_Polarity
	Push	"r1-r6,lr"
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r6,pc",EQ			; restore registers and exit
	BL	i2c_get_things
	MOV	r2,#1				;
	ADD	r1,r4,#mcpipola			;
	BL	i2c_read			;
	Pull	"r1-r6,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	AND	r0,r0,r5			;mask pin
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r6,pc"			; restore registers and exit
;r0=value (0 or 1) or -1 if not there
;---------------------------------------------
i2c_Write_Polarity
	Push	"r1-r7,lr"			;
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r7,pc",EQ			; restore registers and exit
	MOV	r6,r0				;
	MOV	r7,r1				;
	BL	i2c_Read_Polarity		;
	MOV	r0,r6				;
	ADD	r4,r12,#i2creturn		;
	LDRB	r6,[r4]				;
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpipola			;
	CMP	r7,#0				;
	BICEQ	r2,r6,r5			;
	ORRNE	r2,r6,r5			;
	BL	i2c_write			;
	Pull	"r1-r7,pc"			; restore registers and exit
;r0=old value or -1 if not there
;---------------------------------------------
i2c_Read_Pull
	Push	"r1-r6,lr"
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r6,pc",EQ			; restore registers and exit
	BL	i2c_get_things
	MOV	r2,#1				;
	ADD	r1,r4,#mcpgppua			;
	BL	i2c_read			;
	Pull	"r1-r6,pc",VS			;restore registers and exit if error
	LDRB	r0,[r1]				;
	AND	r0,r0,r5			;mask pin
	CMP	r0,#0				;
	MOVNE	r0,#1				;
	Pull	"r1-r6,pc"			; restore registers and exit
;r0=value (0 or 1) or -1 if not there
;---------------------------------------------
i2c_Write_Pull
	Push	"r1-r7,lr"			;
	BL	i2c_checkifinrange		;
	CMP	r0,#-1				;
	Pull	"r1-r7,pc",EQ			; restore registers and exit
	MOV	r6,r0				;
	MOV	r7,r1				;
	BL	i2c_Read_Pull			;
	MOV	r0,r6				;
	ADD	r4,r12,#i2creturn		;
	LDRB	r6,[r4]				;
	BL	i2c_get_things			;
	ADD	r1,r4,#mcpgppua			;
	CMP	r7,#0				;
	BICEQ	r2,r6,r5			;
	ORRNE	r2,r6,r5			;
	BL	i2c_write			;
	Pull	"r1-r7,pc"			; restore registers and exit
;r0=old value or -1 if not there
;---------------------------------------------
i2c_GPIO_Info
	Push	"r3-r8,lr"			;
	LDR	r2,[r12,#i2cprotect]		;
	CMP	r2,#0				;i2c protected ?
	MOVEQ	r0,#-1				;
	MOVEQ	r1,#-1				;return error code
	Pull	"r3-r8,pc",EQ			;
	LDR	r0,[r12,#i2clowgpio]		;
	LDR	r1,[r12,#i2chighgpio]		;
	LDR	r2,[r12,#machine]		;get machine type
	ADRL	r8,i2c_bus_nos			;get i2c bus used
	LDRB	r2,[r10,r2]			;
	Pull	"r3-r8,pc"			; restore registers and exit
;r0=lowest i2c gpio available
;r1=highest gpio available
;r2=bus number used on machine
;OR r0+r1=-1 i2c not protected
;OR r0=-1 and r1=0 no i2c gpio chips fitted
;---------------------------------------------
;r0 pointer to list
i2c_ReadConfig
	Push	"r1-r10,lr"			;
	MOV	r4,r0
	LDR	r0,[r12,#i2clowgpio]		;lowest i2c gpio
	LDR	r1,[r12,#i2chighgpio]		;highest
	CMP	r0,#-1				;non fitted/last
	MOVEQ	r0,r4
	Pull	"r1-r10,pc",EQ			;
	ORR	r0,r0,#i2c_flag			;
	ORR	r1,r1,#i2c_flag			;
10	MOV	r5,r0				;save gpio
	BL	i2c_Read_OE			;
	CMP	r0,#1				;
	MOVEQ	r0,#conf_io			;
	ORR	r6,r5,r0			;
	MOV	r0,#0				;not extended
	ORR	r6,r6,r0,LSR #8			;
	ORR	r6,r6,#i2c_flag			;
	STR	r6,[r4],#4			;
	ADD	r0,r5,#1			;
	CMP	r0,r1				;
	BLE	%BT10				;
	MOV	r0,r4				;pass pointer back
	Pull	"r1-r10,pc"			;
;r0 pointer to list
;---------------------------------------------
;r0=gpio number
i2c_checkifinrange
	Push	"r1-r4,lr"
	MOV	r4,r0				;save for later
	BL	i2c_GPIO_Info			;r0=lowest,r1=highest,r2+r3=corrupt
	CMP	r0,#-1				;
	Pull	"r1-r4,pc",EQ			;get out with error
	AND	r3,r4,#&FF			;just gpio number
	CMP	r3,r0				;check against lowest
	MOVLT	r0,#-1				;
	Pull	"r1-r4,pc",LT			;get out with error
	CMP	r3,r1				;check against highest
	MOVGT	r0,#-1				;
	Pull	"r1-r4,pc",GT			;get out with error
	MOV	r0,r4				;
	Pull	"r1-r4,pc"			;
;r0=-1 if error or preserved if ok
;---------------------------------------------
	END

