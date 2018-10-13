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

;s.InitModule

 [ :LNOT::DEF: ROM
        GBLL    ROM
ROM     SETL    {FALSE}
 ]

 [ :LNOT: ROM
	IMPORT	|__RelocCode|		; Link symbol for relocation routine
 ]


;******************************************************************************
;
;       RM_Init - Initialisation entry point
;


RM_Init
        Push	"r0-r11,lr"
 [ :LNOT: ROM
        BL      |__RelocCode|		; initialise absolute code pointers
 ]
        MOV     r0,#ModHandReason_Claim	;
        LDR     r3,maxRMA		;
        SWI     XOS_Module		;
	BVS	initerror		;
        STR     r2,[r12]		; save RMA pointer
	MOV	r12,r2			;
	ADD	r0,r2,#MainTemp		; Clear only lower bits
        MOV     r1,#0			;
10					; clear memory
        STR	r1,[r2],#4		;
        CMP     r2,r0			;end ?
        BLT     %BT10
;get board type for maps
	MOV	r0,#HALDeviceType_Comms	;comms
	ADD	r0,r0,#HALDeviceComms_GPIO	;gpio
	MOV	r1,#0			;first call
	MOV	r8,#4			;OS_Hardware 4
	SWI	XOS_Hardware		;call it
	BVS	initerror1		;
	CMP	r1,#-1			;bad call ?
	MOVEQ	r1,#hal_dummy		;
	STREQ	r1,[r12,#halproc]	;
	MOVEQ	r1,#hal_dummy		;
	STREQ	r1,[r12,#halboard]	;
	MOVEQ	r1,#1			;
	STREQ	r1,[r12,#halrevision]	;
	MOVEQ	r0,#hal_rev_dummy	;board type default
	BEQ	%FT100			;
;check API matches our assumption
	LDR	r1,[r2,#HALDevice_Version]
	TEQ	r1,#0
	BNE	initerror1		;want API 0.00
;find real board type
	LDR	r1,[r2,#HALDevice_GPIORevision]
	STR	r1,[r12,#halrevision]	;
	LDR	r0,[r2,#HALDevice_GPIOType]
	STR	r0,[r12,#halboard]	;
	LDRH	r3,[r2,#HALDevice_ID]
	STR	r3,[r12,#halproc]	;
;omap3 section
	CMP	r3,#HALDeviceID_GPIO_OMAP3
	BNE	%FT400			;not omap3 try something else
	ADR	r2,omap3_gpio_tables	;pointer to board table
	CMP	r0,#GPIOType_OMAP3_BeagleBoard
	BNE	%FT20
	CMP	r1,#GPIORevision_BeagleBoard_xMC
	BLE	%FT99			;
20	CMP	r0,#GPIOType_OMAP3_DevKit8000
	BNE	%FT21
	CMP	r1,#GPIORevision_DevKit8000_Unknown
	BLE	%FT99			;
21	CMP	r0,#GPIOType_OMAP3_IGEPv2
	BNE	%FT22
	CMP	r1,#GPIORevision_IGEPv2_C
	BLE	%FT99			;
22	CMP	r0,#GPIOType_OMAP3_Pandora
	BNE	%FT23
	CMP	r1,#GPIORevision_Pandora_Unknown
	BLE	%FT99			;
23	ADR	r2,dummy_gpio_table	;pointer to board table
	MOV	r0,#hal_rev_dummy	;board type default if it falls through
	B	%FT100			;default if not any
;omap4 section
400
	CMP	r3,#HALDeviceID_GPIO_OMAP4
	BNE	%FT500			;not omap4 try something else
	ADR	r2,omap4_gpio_tables	;pointer to board table
	CMP	r0,#GPIOType_OMAP4_Panda
	BNE	%FT24
	CMP	r1,#GPIORevision_PandaES
	BLE	%FT99			;
24	ADR	r2,dummy_gpio_table	;pointer to board table
	MOV	r0,#hal_rev_dummy	;board type default if it falls through
	B	%FT100			;default if not any
;bcm section
500
	[ {FALSE}
	CMP	r3,#HALDeviceID_GPIO_BCM2835
	BNE	%FT600			;not pi try something else
	ADR	r2,bcm2835_gpio_tables	;pointer to board table
	CMP	r0,#GPIOType_BCM2835_RaspberryPi
	BNE	%FT28
	CMP	r1,#GPIORevision_RaspberryPi_Mk2_B_1
	BLE	%FT99			;
28	ADR	r2,dummy_gpio_table	;pointer to board table
	MOV	r0,#hal_rev_dummy	;board type default if it falls through
	B	%FT100			;default if not any
	]
;xxxx section
600
	ADR	r2,dummy_gpio_table	;pointer to board table
	MOV	r0,#hal_rev_dummy	;board type default if it falls through
	B	%FT100			;default if not any
;add more if needed
99	LDR	r0,[r2,r0, LSL #2]	;
	ADD	r0,r0,r1		;add revision to base
100	STR	r0,[r12,#machine]	;
	BL	Get_Board		;get name
;map in our memory
	MOV	r0,#-1			;setup logical store
	ADD	r5,r12,#logicalstore	;store for logical address
	ADD	r4,r12,#logicalstore1	;
101	STR	r0,[r5],#4		;
	CMP	r5,r4			;
	BLO	%BT101
	BL	get_table		;setup pointer
	LDR	r4,[r1,#physical_table]	;pointer to Physical memory
	CMP	r4,#-1			;no maps
	MOVEQ	r1,r4			;end table
	ADD	r5,r12,#logicalstore	;store for logical address
	BEQ	%FT30			;
20	MOV	r2,#mapsize		;size to map in
	MOV	r0,#13			;map in permanent
	LDR	r1,[r4],#4		;get first map
	CMP	r1,#-1			;last one ?
	BEQ	%FT30			;
	SWI	XOS_Memory		;
	BVS	initerror2		;
	STR	r3,[r5],#4		;store logical address
	B	%BT20			;next
30	STR	r1,[r5]			;store end flag
	BL	get_table		;setup pointer
	LDR	r4,[r1,#map]		;main control
	CMP	r4,#-1			;no map
	ADD	r5,r12,#logicalstore1	;store for logical address
	STREQ	r4,[r5]			;store logical address
	BEQ	%FT40			;
	MOV	r2,#padsize		;
	LDR	r1,[r4]			;
	SWINE	XOS_Memory		;
	BVS	initerror3		;
	STR	r3,[r5]			;store logical address
40	BL	get_table		;setup pointer
	LDR	r4,[r1,#srambase]	;map in sram
	CMP	r4,#-1			;no sram
	ADD	r5,r12,#logicalsram	;store for logical address
	STREQ	r4,[r5]			;store logical address
	BEQ	%FT50			;
	MOV	r2,#sramsize		;
	LDR	r1,[r4]			;
	SWI	XOS_Memory		;
	BVS	initerror4		;
	STR	r3,[r5]			;store logical address
50
	MOV	r0,#TickerV
	ADRL	r1,FlashVector		;
	MOV	r2,r12			;
	SWI	XOS_Claim		;
	BVS	initerrortick

	MOV	r0,#1			;protect i2c
	LDR	r10,[r12,#machine]	;get board type
	CMP	r10,#hal_rev_dummy	;is it unkown
	BEQ	%FT60
	[ {FALSE}
	CMP	r10,#hal_rev_pi		;is it a Pi
	BLGE	Pi_Enable_I2C		;
	BLLT	Enable_I2C		;
	BL	get_i2c_info		;get extender info
	]
60
	CLRV
	Pull	"r0-r11,pc"		;

maxRMA	DCD	RMAlimit
dummy_gpio_table
	DCD	hal_rev_dummy
omap3_gpio_tables
	DCD	hal_rev_beagle
	DCD	hal_rev_dev
	DCD	hal_rev_igep
	DCD	hal_rev_pandora
omap4_gpio_tables
	DCD	hal_rev_panda
	[ {FALSE}
bcm2835_gpio_tables
	DCD	hal_rev_pi
	]

;******************************************************************************
	END
