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

; s.ModHead

	AREA	|!Module|, CODE, READONLY


;******************************************************************************

;
;   Module code starts here
;

	ENTRY

Module_BaseAddr
	DCD	0
	DCD	RM_Init		-Module_BaseAddr
	DCD	RM_Die		-Module_BaseAddr
	DCD	0
	DCD	RM_Title	-Module_BaseAddr
	DCD	RM_HelpStr	-Module_BaseAddr
	DCD	RM_HC_Table	-Module_BaseAddr
	DCD	SWI_base				;SWI chunk number
	DCD	RM_SWIentry	-Module_BaseAddr
	DCD	RM_SWInames	-Module_BaseAddr
	DCD	0
	DCD	0					; Messages filename
	DCD	RM_Flags	-Module_BaseAddr	; Flags

RM_Title
	=	"$Module_ComponentName", 0

RM_HelpStr
	=	"$Module_ComponentName", 9, 9
	=	"$Module_HelpVersion", 13
	=	"SWI's to interact with the GPIO pins", 13
	=	0

	ALIGN

RM_Flags
	DCD	ModuleFlag_32bit			; 32-bit compatible

;******************************************************************************
;
;       RM_HC_Table - Help and command keyword table
;

RM_HC_Table
         =  "GPIOMap",0
         ALIGN
         DCD   Map_Code       -Module_BaseAddr
         DCD   0
         DCD   Map_Syntax     -Module_BaseAddr
         DCD   Map_Help       -Module_BaseAddr
         =  "GPIOMachine",0
         ALIGN
         DCD   Mach_Code       -Module_BaseAddr
         DCD   0
         DCD   Mach_Syntax     -Module_BaseAddr
         DCD   Mach_Help       -Module_BaseAddr

         DCD   0




;--------- C O M M A N D : REGISTER ---------------
Map_Help
	=	"Use 'GPIOMap' to display memory that has been mapped in ",0
	ALIGN
Map_Syntax
	=	"Syntax: *GPIOMap",0
	ALIGN
Map_Code
	Push	"r0-r12,lr"
	LDR	r12,[r12]
	SWI	XOS_WriteS
	=	"-------------------------------------------",0
	ALIGN
	SWI	XOS_NewLine
	SWI	XOS_WriteS
	=	"Physical  Logical   Size      Use",0
	ALIGN
 	SWI	XOS_NewLine
	SWI	XOS_WriteS
	=	"-------------------------------------------",0
	ALIGN
	SWI	XOS_NewLine
	ADD	r6,r12,#logicalstore
	BL	get_table
	LDR	r7,[r1,#physical_table]
	CMP	r7,#-1
	BEQ	%FT20
10	LDR	r0,[r7],#4
	CMP	r0,#-1
	BEQ	%FT20
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	LDR	r0,[r6],#4
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	MOV	r0,#mapsize
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	SWI	XOS_WriteS
	=	"GPIO",0
	ALIGN
	SWI	XOS_NewLine
	B	%BT10
20	BL	get_table
	LDR	r7,[r1,#map]
	CMP	r7,#-1
	BEQ	%FT30
	LDR	r0,[r7]
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	ADD	r6,r12,#logicalstore1
  	LDR	r0,[r6]
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	MOV	r0,#padsize
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	SWI	XOS_WriteS
	=	"Control Regs",0
	ALIGN
	SWI	XOS_NewLine
30	BL	get_table
	LDR	r7,[r1,#srambase]
	CMP	r7,#-1
	BEQ	%FT40
	LDR	r0,[r7]
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	ADD	r6,r12,#logicalsram
  	LDR	r0,[r6]
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	MOV	r0,#sramsize
	ADD     r1,r12,#MainTemp
        MOV     r2,#10
        SWI     XOS_ConvertHex8
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
        MOV     r0,#32
        SWI     XOS_WriteC
        SWI     XOS_WriteC
	SWI	XOS_WriteS
	=	"SRAM",0
	ALIGN
	SWI	XOS_NewLine

40	SWI	XOS_WriteS
	=	"-------------------------------------------",0
	ALIGN
	SWI	XOS_NewLine
	Pull	"r0-r12,pc"   ; restore registers and exit

Mach_Help
	=	"Use 'GPIOMachine' to display details of the machine we are running on ",0
	ALIGN
Mach_Syntax
	=	"Syntax: *GPIOMachine",0
	ALIGN
Mach_Code
	Push	"r0-r12,lr"
	LDR	r12,[r12]
	SWI	XOS_NewLine
	SWI	XOS_WriteS
	=	"We are running on ",0
	ALIGN
	ADD	r7,r12,#machinename
10	LDRB	r0,[r7],#1
	CMP	r0,#0
        SWINE	XOS_WriteC
	BNE	%BT10
	LDR	r0,[r12,#machine]
	CMP	r0,#hal_rev_dummy
	SWIEQ	XOS_NewLine
	BEQ	%FT20
	SWI	XOS_WriteS
	=	" hardware",0
	ALIGN
	SWI	XOS_NewLine
	SWI	XOS_WriteS
	=	"   Which is a GPIO machine type of &",0
	ALIGN
	LDR	r0,[r12,#machine]
	ADRL	r2,convert_internal_to_external	;
	LDRB	r0,[r2,r0]			;convert to external
        ADD     r1,r12,#MainTemp
        MOV     r2,#8
        SWI     XOS_ConvertHex2
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
	SWI	XOS_WriteS
	=	", Processor type of &",0
	ALIGN
	LDR	r0,[r12,#halboard]
        ADD     r1,r12,#MainTemp
        MOV     r2,#8
        SWI     XOS_ConvertHex2
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
	SWI	XOS_WriteS
	=	" and Board revision of &",0
	ALIGN
	LDR	r0,[r12,#halrevision]
        ADD     r1,r12,#MainTemp
        MOV     r2,#8
        SWI     XOS_ConvertHex2
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
	SWI	XOS_NewLine
	LDR	r0,[r12,#i2clowgpio]
	CMP	r0,#-1
	BEQ	%FT30
	SWI	XOS_WriteS
	=	"There are I2C GPIO expanders attached",0
	ALIGN
	SWI	XOS_NewLine
	SWI	XOS_WriteS
	=	"Lowest available is &",0
	ALIGN
        ADD     r1,r12,#MainTemp
        MOV     r2,#8
        SWI     XOS_ConvertHex2
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
	SWI	XOS_WriteS
	=	" and the higest available is &",0
	ALIGN
	LDR	r0,[r12,#i2chighgpio]
        ADD     r1,r12,#MainTemp
        MOV     r2,#8
        SWI     XOS_ConvertHex2
        ADD     r0,r12,#MainTemp
        SWI     XOS_Write0
20	SWI	XOS_NewLine
	Pull	"r0-r12,pc"   ; restore registers and exit

30	SWI	XOS_WriteS
	=	"There are no I2C GPIO expanders",0
	ALIGN
	B	%BT20

;****************************************** SWI ENTRY *******

RM_SWIentry
	LDR	r12,[r12]			;load private word = address of workspace
	LDR	r10,[r12,#halproc]		;get CPU type
	CMP	r10,#HALDeviceID_GPIO_OMAP3	;is not omap 3
	CMPNE	r10,#HALDeviceID_GPIO_OMAP4	;is not omap 4
	BNE	Pi_SWIentry			;
	CMP	r11, #(%FT10-%FT00):SHR:2	;dynamic jump
	ADDLT	pc,pc,r11,LSL #2		;
	B	RM_UnknownSWIerror
00
	B	Read_Data
	B	Write_Data
	B	Read_OE
	B	Write_OE
	B	Aux_As_GPIO
	B	Exp_As_GPIO
	B	Camera_As_GPIO
	B	Aux_As_Safe
	B	Exp_As_Safe
	B	Camera_As_Safe
	B	Aux_As_USB
	B	Exp_As_UART
	B	Aux_As_MMC
	B	Exp_As_MMC
	B	Aux_As_MM
	B	Read_Mode
	B	Write_Mode
	B	Read_Level0
	B	Write_Level0
	B	Read_Level1
	B	Write_Level1
	B	Read_Rising
	B	Write_Rising
	B	Read_Falling
	B	Write_Falling
	B	Read_DebounceEnable
	B	Write_DebounceEnable
	B	Read_IRQ1
	B	Write_IRQ1
	B	Read_IRQ2
	B	Write_IRQ2
	B	Read_Exp_32
	B	Read_Aux_32
	B	Read_Cam_32
	B	Write_Exp_32
	B	Write_Aux_32
	B	Write_Cam_32
	B	Read_Exp_OE_32
	B	Read_Aux_OE_32
	B	Read_Cam_OE_32
	B	Write_Exp_OE_32
	B	Write_Aux_OE_32
	B	Write_Cam_OE_32
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	FlashOn
	B	FlashOff
	B	GPIO_Info
	B	i2c_GPIO_Info
	B	sramread
	B	sramwrite
	B	Address
	B	Load_Config
	B	Read_Config
	B	Enable_I2C
	B	Get_Board
	B	get_i2c_info
10


Pi_SWIentry
	CMP	r10,#HALDeviceID_GPIO_BCM2835	;is not pi
	BNE	nomachinesupport		;
	CMP	r11, #(%FT30-%FT20):SHR:2	;dynamic jump
	ADDLT	pc,pc,r11,LSL #2		;
	B	RM_UnknownSWIerror
20
	B	Pi_Read_Data
	B	Pi_Write_Data
	B	Pi_Read_OE
	B	Pi_Write_OE
	B	Reserved
	B	Pi_Exp_As_GPIO
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Pi_Exp_As_UART
	B	Reserved
	B	Pi_Exp_As_MMC
	B	Reserved
	B	Pi_Read_Mode
	B	Pi_Write_Mode
	B	Pi_Read_Level0
	B	Pi_Write_Level0
	B	Pi_Read_Level1
	B	Pi_Write_Level1
	B	Pi_Read_Rising
	B	Pi_Write_Rising
	B	Pi_Read_Falling
	B	Pi_Write_Falling
	B	Reserved	;Pi_Read_DebounceEnable
	B	Reserved	;Pi_Write_DebounceEnable
	B	Reserved	;Pi_Read_IRQ1
	B	Reserved	;Pi_Write_IRQ1
	B	Reserved	;Pi_Read_IRQ2
	B	Reserved	;Pi_Write_IRQ2
	B	Pi_Read_Exp_32
	B	Pi_Read_Aux_32
	B	Reserved
	B	Pi_Write_Exp_32
	B	Pi_Write_Aux_32
	B	Reserved
	B	Pi_Read_Exp_OE_32
	B	Pi_Read_Aux_OE_32
	B	Reserved
	B	Pi_Write_Exp_OE_32
	B	Pi_Write_Aux_OE_32
	B	Reserved
	B	Pi_Read_Event
	B	Pi_Write_Event
	B	Pi_Read_Async
	B	Pi_Write_Async
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	Reserved
	B	FlashOn
	B	FlashOff
	B	Pi_GPIO_Info
	B	i2c_GPIO_Info
	B	Reserved	;sramread
	B	Reserved	;sramwrite
	B	Pi_Address
	B	Pi_Load_Config
	B	Pi_Read_Config
	B	Pi_Enable_I2C
	B	Get_Board
	B	get_i2c_info
30

RM_UnknownSWIerror
	ADRL	r0,RM_errMesg
	SETV
	MOV	pc,lr

;---------------------------------------------
;Reserved
Reserved
	MOV	pc,lr				;just get out
;---------------------------------------------
RM_SWInames
        =       "GPIO",0                        ;
        =       "ReadData",0                    ; swi1
        =       "WriteData",0                   ; swi2
	=	"ReadOE",0			; swi3
	=	"WriteOE",0			; swi4
	=	"AuxAsGPIO",0			; swi5
	=	"ExpAsGPIO",0			; swi6
	=	"CameraAsGPIO",0		; swi7
	=	"AuxAsSafe",0			; swi8
	=	"ExpAsSafe",0			; swi9
	=	"CameraAsSafe",0		; swi10
	=	"AuxAsUSB",0			; swi11
	=	"ExpAsUART",0			; swi12
	=	"AuxAsMMC",0			; swi13
	=	"ExpAsMMC",0			; swi14
	=	"AuxAsMM",0			; swi15
	=	"ReadMode",0			; swi16
	=	"WriteMode",0			; swi17
	=	"ReadLevel0",0			; swi18
	=	"WriteLevel0",0			; swi19
	=	"ReadLevel1",0			; swi20
	=	"WriteLevel1",0			; swi21
	=	"ReadRising",0			; swi22
	=	"WriteRising",0			; swi23
	=	"ReadFalling",0			; swi24
	=	"WriteFalling",0		; swi25
	=	"ReadDebounceEnable",0		; swi26
	=	"WriteDebounceEnable",0		; swi27
	=	"ReadIRQ1",0			; swi28
	=	"WriteIRQ1",0			; swi29
	=	"ReadIRQ2",0			; swi30
	=	"WriteIRQ2",0			; swi31
	=	"ReadExp32",0			; swi32
	=	"ReadAux32",0			; swi33
	=	"ReadCam32",0			; swi34
	=	"WriteExp32",0			; swi35
	=	"WriteAux32",0			; swi36
	=	"WriteCam32",0			; swi37
	=	"ReadExpOE32",0			; swi38
	=	"ReadAuxOE32",0			; swi39
	=	"ReadCamOE32",0			; swi40
	=	"WriteExpOE32",0		; swi41
	=	"WriteAuxOE32",0		; swi42
	=	"WriteCamOE32",0		; swi43
	=	"ReadEvent",0			; swi44
	=	"WriteEvent",0			; swi45
	=	"ReadAsync",0			; swi46
	=	"WriteAsync",0			; swi47
	=	"Reserved1",0			; swi48
	=	"Reserved2",0			; swi49
	=	"Reserved3",0			; swi50
	=	"Reserved4",0			; swi51
	=	"Reserved5",0			; swi52
	=	"FlashOn",0			; swi53
	=	"FlashOff",0			; swi54
	=	"Info",0			; swi55
	=	"I2CInfo",0			; swi56
	=	"SRAMRead",0			; swi57
	=	"SRAMWrite",0			; swi58
	=	"Address",0			; swi59
	=	"LoadConfig",0			; swi60
	=	"ReadConfig",0			; swi61
	=	"EnableI2C",0			; swi62
	=	"GetBoard",0			; swi63
	=	"RescanI2C",0			; swi64


        =       0
        ALIGN
;-----------------------------------------------------------------------------
	END
