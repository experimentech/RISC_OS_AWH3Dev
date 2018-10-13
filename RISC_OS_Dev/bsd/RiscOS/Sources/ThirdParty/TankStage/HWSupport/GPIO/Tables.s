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

;s.Tables


;---------------------------------------------
dummy_table			;
	DCD	-1		;control reg
	DCD	-1		;exp pins
	DCD	-1		;aux pins
	DCD	-1		;camera pins
	DCD	-1		;user pins
	DCD	-1		;i2c
	DCD	-1		;widebit pins
	DCD	-1		;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	-1		;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	-1		;
	DCD	namedummy	;
beagle_table
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	XMtable7	;widebit pins
	DCD	XMtable8	;uart
	DCD	XMtable9	;usb
	DCD	XMtable10	;aux mmc
	DCD	XMtable11	;exp mmc
	DCD	XMtable12	;aux mm
	DCD	XMsrambase	;
	DCD	XMmap		;
	DCD	XMphysical_table;
	DCD	name1_0		;
beagle1_table
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	XMtable7	;widebit pins
	DCD	XMtable8	;uart
	DCD	XMtable9	;usb
	DCD	XMtable10	;aux mmc
	DCD	XMtable11	;exp mmc
	DCD	XMtable12	;aux mm
	DCD	XMsrambase	;
	DCD	XMmap		;
	DCD	XMphysical_table;
	DCD	name1_1		;
beagle2_table
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	XMtable7	;widebit pins
	DCD	XMtable8	;uart
	DCD	XMtable9	;usb
	DCD	XMtable10	;aux mmc
	DCD	XMtable11	;exp mmc
	DCD	XMtable12	;aux mm
	DCD	XMsrambase	;
	DCD	XMmap		;
	DCD	XMphysical_table;
	DCD	name1_2		;
beagle3_table
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	XMtable7	;widebit pins
	DCD	XMtable8	;uart
	DCD	XMtable9	;usb
	DCD	XMtable10	;aux mmc
	DCD	XMtable11	;exp mmc
	DCD	XMtable12	;aux mm
	DCD	XMsrambase	;
	DCD	XMmap		;
	DCD	XMphysical_table;
	DCD	name1_3		;
beagle4_table
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	XMtable7	;widebit pins
	DCD	XMtable8	;uart
	DCD	XMtable9	;usb
	DCD	XMtable10	;aux mmc
	DCD	XMtable11	;exp mmc
	DCD	XMtable12	;aux mm
	DCD	XMsrambase	;
	DCD	XMmap		;
	DCD	XMphysical_table;
	DCD	name1_4		;
beagle5_table
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	XMtable7	;widebit pins
	DCD	XMtable8	;uart
	DCD	XMtable9	;usb
	DCD	XMtable10	;aux mmc
	DCD	XMtable11	;exp mmc
	DCD	XMtable12	;aux mm
	DCD	XMsrambase	;
	DCD	XMmap		;
	DCD	XMphysical_table;
	DCD	name1_5		;
devkit_table
	DCD	XMtable1	;control reg
	DCD	DEVtable2	;exp pins
	DCD	-1		;no aux
	DCD	-1		;camera pins
	DCD	DEVtable5	;user pins
	DCD	DEVtable6	;i2c
	DCD	-1		;widebit pins
	DCD	DEVtable8	;uart
	DCD	-1		;usb
	DCD	DEVtable10	;mmc
	DCD	-1		;
	DCD	-1		;
	DCD	XMsrambase	;
	DCD	XMmap		;
	DCD	XMphysical_table;
	DCD	name2_0		;
igep_table			;copy of xm
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	-1		;widebit pins
	DCD	-1		;uart
	DCD	-1		;usb
	DCD	-1		;mmc
	DCD	-1		;
	DCD	-1		;
	DCD	-1		;sram base
	DCD	XMmap		;map
	DCD	XMphysical_table;
	DCD	name3_0		;
igep1_table			;copy of xm
	DCD	XMtable1	;control reg
	DCD	XMtable2	;exp pins
	DCD	XMtable3	;aux pins
	DCD	XMtable4	;camera pins
	DCD	XMtable5	;user pins
	DCD	XMtable6	;i2c
	DCD	-1		;widebit pins
	DCD	-1		;uart
	DCD	-1		;usb
	DCD	-1		;mmc
	DCD	-1		;
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	XMphysical_table;
	DCD	name3_1		;
pandora_table			;copy of xm
	DCD	XMtable1	;control reg
	DCD	Doratable2	;exp pins
	DCD	Doratable3	;aux pins
	DCD	-1		;camera pins
	DCD	-1		;user pins
	DCD	-1		;i2c
	DCD	-1		;widebit pins
	DCD	XMtable8	;uart
	DCD	-1		;usb
	DCD	-1		;mmc
	DCD	-1		;
	DCD	-1		;
	DCD	XMsrambase	;sram base
	DCD	XMmap		;map
	DCD	XMphysical_table;
	DCD	name4_0		;
panda_table			;copy of xm
	DCD	Pandatable1	;control reg
	DCD	PDtable2	;exp pins
	DCD	PDtable3	;aux pins
	DCD	PDtable4	;camera pins
	DCD	PDtable5	;user pins
	DCD	PDtable6	;i2c
	DCD	-1		;widebit pins
	DCD	PDtable8	;uart
	DCD	-1		;usb
	DCD	PDtable10	;mmc
	DCD	-1		;
	DCD	-1		;
	DCD	-1		;sram base
	DCD	PDMap		;map
	DCD	Pandaphysical_table;
	DCD	name5_0		;
pandaes_table			;copy of xm
	DCD	Pandatable1	;control reg
	DCD	PDtable2ES	;exp pins
	DCD	PDtable3	;aux pins
	DCD	PDtable4	;camera pins
	DCD	PDtable5ES	;user pins
	DCD	PDtable6	;i2c
	DCD	-1		;widebit pins
	DCD	PDtable8	;uart
	DCD	-1		;usb
	DCD	PDtable10	;mmc
	DCD	-1		;
	DCD	-1		;
	DCD	-1		;sram base
	DCD	PDMap		;map
	DCD	Pandaphysical_table;
	DCD	name5_1		;
rpi_table			;B rev 1
	DCD	RPItable1	;control reg
	DCD	RPItable2R1	;exp pins
	DCD	-1		;aux pins
	DCD	-1		;camera pins
	DCD	RPItable5	;user pins
	DCD	RPItable6R1	;i2c
	DCD	-1		;widebit pins
	DCD	RPItable8	;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	RPItable11	;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	RPIphysical_table;
	DCD	name6_0		;
rpi1_table			;B rev 2
	DCD	RPItable1	;control reg
	DCD	RPItable2R2	;exp pins
	DCD	RPItable3R2	;aux pins
	DCD	-1		;camera pins
	DCD	RPItable5	;user pins
	DCD	RPItable6R2	;i2c
	DCD	-1		;widebit pins
	DCD	RPItable8	;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	RPItable11	;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	RPIphysical_table;
	DCD	name6_1		;
rpi2_table			;A rev 2
	DCD	RPItable1	;control reg
	DCD	RPItable2R2	;exp pins
	DCD	RPItable3R2	;aux pins
	DCD	-1		;camera pins
	DCD	RPItable5	;user pins
	DCD	RPItable6R2	;i2c
	DCD	-1		;widebit pins
	DCD	RPItable8	;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	RPItable11	;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	RPIphysical_table;
	DCD	name6_2		;
rpi3_table			;B+
	DCD	RPItable1	;control reg
	DCD	RPItable2BP	;exp pins
	DCD	-1		;aux pins
	DCD	-1		;camera pins
	DCD	RPItable5Comp	;user pins
	DCD	RPItable6R2	;i2c
	DCD	-1		;widebit pins
	DCD	RPItable8	;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	RPItable11	;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	RPIphysical_table;
	DCD	name6_3		;
rpicompute_table		;Compute module
	DCD	RPItable1	;control reg
	DCD	RPItable2Comp	;exp pins
	DCD	-1		;aux pins
	DCD	-1		;camera pins
	DCD	RPItable5Comp	;user pins
	DCD	RPItable6Comp	;i2c
	DCD	-1		;widebit pins
	DCD	RPItable8	;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	RPItable11	;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	RPIphysical_table;
	DCD	name6_4		;
rpiAP_table			;Raspberry Pi A+
	DCD	RPItable1	;control reg
	DCD	RPItable2BP	;exp pins
	DCD	-1		;aux pins
	DCD	-1		;camera pins
	DCD	RPItable5Comp	;user pins
	DCD	RPItable6R2	;i2c
	DCD	-1		;widebit pins
	DCD	RPItable8	;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	RPItable11	;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	RPIphysical_table;
	DCD	name6_5		;
rpiMk2B_table			;Raspberry Pi Mk2 B rev 1
	DCD	RPItable1	;control reg
	DCD	RPItable2BP	;exp pins
	DCD	-1		;aux pins
	DCD	-1		;camera pins
	DCD	RPItable5Comp	;user pins
	DCD	RPItable6R2	;i2c
	DCD	-1		;widebit pins
	DCD	RPItable8	;uart
	DCD	-1		;usb
	DCD	-1		;
	DCD	RPItable11	;mmc/spio
	DCD	-1		;
	DCD	-1		;sram base
	DCD	-1		;map
	DCD	RPIMk2physical_table;
	DCD	name6_6		;
;add as needed

;position in this table is the same as the tables used for mapping machine specific.
convert_internal_to_external
	DCB	0		;none
	DCB	1		;Beagle a or b
	DCB	2		;Beagle c1,c2,c3
	DCB	3		;Beagle c4
	DCB	4		;beagle xm a
	DCB	5		;beagle xm b
	DCB	6		;beagle xm c
	DCB	7		;devkit
	DCB	8		;igep b/c
	DCB	9		;igep c
	DCB	10		;pandora
	DCB	14		;pandaboard
	DCB	15		;pandaboardes
	DCB	11		;B Pi rev1
	DCB	12		;B Pi rev2
	DCB	13		;A Pi rev2
	DCB	17		;B+ Pi
	DCB	18		;compute rev1
	DCB	16		;A+ Pi
	DCB	19		;Pi Mk2 B rev1
;add as needed
	ALIGN

namedummy =	"Machine not detected!",13
name1_0	=	"Beagleboard A or B",13
name1_1	=	"Beagleboard C1,C2 or C3",13
name1_2	=	"Beagleboard C4",13
name1_3	=	"Beagleboard-xM A",13
name1_4	=	"Beagleboard-xM B",13
name1_5	=	"Beagleboard-xM C",13
name2_0	=	"Devkit8000",13
name3_0	=	"IGEPv2 B/C",13
name3_1	=	"IGEPv2 C",13
name4_0 =	"Pandora",13
name5_0 =	"PandaBoard",13
name5_1 =	"PandaBoard ES",13
name6_0	=	"RaspberryPi B Rev1",13
name6_1	=	"RaspberryPi B Rev2",13
name6_2 =	"RaspberryPi A Rev2",13
name6_3 =	"RaspberryPi B Plus",13
name6_4 =	"Compute Module",13
name6_5 =	"RaspberryPi A Plus",13
name6_6 =	"RaspberryPi Mk2 B Rev1",13
;add as needed
        ALIGN

i2c_bus_nos
	DCB	&FF		;dummy
	DCB	i2cbus		;beagle a
	DCB	i2cbus		;beagle c
	DCB	i2cbus		;beagle c4
	DCB	i2cbus		;beagle xma
	DCB	i2cbus		;beagle xmb
	DCB	i2cbus		;beagle xmc
	DCB	dev_i2cbus	;devkit
	DCB	i2cbus		;igep b/c
	DCB	i2cbus		;igep c
	DCB	i2cbus		;pandora
	DCB	i2cbus		;panda
	DCB	i2cbus		;pandaes
	DCB	i2cbus		;pandaes
	DCB	pi_i2cbusr1	;pi b rev1
	DCB	pi_i2cbusr2	;pi b rev2
	DCB	pi_i2cbusr2	;pi a rev2
	DCB	pi_i2cbusr2	;pi b+
	DCB	pi_i2cbusr2	;pi compute
	DCB	pi_i2cbusr2	;pi a+
	DCB	pi_i2cbusr2	;pi Mk2 b rev1
;add as needed
	ALIGN

;*************************** Beagle Xm **************************************
;physical map table
XMphysical_table
	DCD	GPIO_1
	DCD	GPIO_2
	DCD	GPIO_3
	DCD	GPIO_4
	DCD	GPIO_5
	DCD	GPIO_6
	DCD	-1
XMmap	DCD	PADCONF_1
XMsrambase
	DCD	sramstart

;Control register table
XMtable1
	DCW	C_gpio_0
	DCW	C_gpio_1
	DCW	C_gpio_2
	DCW	C_gpio_3
	DCW	C_gpio_4
	DCW	C_gpio_5
	DCW	C_gpio_6
	DCW	C_gpio_7
	DCW	C_gpio_8
	DCW	C_gpio_9
	DCW	C_gpio_10
	DCW	C_gpio_11
	DCW	C_gpio_12
	DCW	C_gpio_13
	DCW	C_gpio_14
	DCW	C_gpio_15
	DCW	C_gpio_16
	DCW	C_gpio_17
	DCW	C_gpio_18
	DCW	C_gpio_19
	DCW	C_gpio_20
	DCW	C_gpio_21
	DCW	C_gpio_22
	DCW	C_gpio_23
	DCW	C_gpio_24
	DCW	C_gpio_25
	DCW	C_gpio_26
	DCW	C_gpio_27
	DCW	C_gpio_28
	DCW	C_gpio_29
	DCW	C_gpio_30
	DCW	C_gpio_31
	DCW	C_gpio_32
	DCW	C_gpio_33
	DCW	C_gpio_34
	DCW	C_gpio_35
	DCW	C_gpio_36
	DCW	C_gpio_37
	DCW	C_gpio_38
	DCW	C_gpio_39
	DCW	C_gpio_40
	DCW	C_gpio_41
	DCW	C_gpio_42
	DCW	C_gpio_43
	DCW	C_gpio_44
	DCW	C_gpio_45
	DCW	C_gpio_46
	DCW	C_gpio_47
	DCW	C_gpio_48
	DCW	C_gpio_49
	DCW	C_gpio_50
	DCW	C_gpio_51
	DCW	C_gpio_52
	DCW	C_gpio_53
	DCW	C_gpio_54
	DCW	C_gpio_55
	DCW	C_gpio_56
	DCW	C_gpio_57
	DCW	C_gpio_58
	DCW	C_gpio_59
	DCW	C_gpio_60
	DCW	C_gpio_61
	DCW	C_gpio_62
	DCW	C_gpio_63
	DCW	C_gpio_64
	DCW	C_gpio_65
	DCW	C_gpio_66
	DCW	C_gpio_67
	DCW	C_gpio_68
	DCW	C_gpio_69
	DCW	C_gpio_70
	DCW	C_gpio_71
	DCW	C_gpio_72
	DCW	C_gpio_73
	DCW	C_gpio_74
	DCW	C_gpio_75
	DCW	C_gpio_76
	DCW	C_gpio_77
	DCW	C_gpio_78
	DCW	C_gpio_79
	DCW	C_gpio_80
	DCW	C_gpio_81
	DCW	C_gpio_82
	DCW	C_gpio_83
	DCW	C_gpio_84
	DCW	C_gpio_85
	DCW	C_gpio_86
	DCW	C_gpio_87
	DCW	C_gpio_88
	DCW	C_gpio_89
	DCW	C_gpio_90
	DCW	C_gpio_91
	DCW	C_gpio_92
	DCW	C_gpio_93
	DCW	C_gpio_94
	DCW	C_gpio_95
	DCW	C_gpio_96
	DCW	C_gpio_97
	DCW	C_gpio_98
	DCW	C_gpio_99
	DCW	C_gpio_100
	DCW	C_gpio_101
	DCW	C_gpio_102
	DCW	C_gpio_103
	DCW	C_gpio_104
	DCW	C_gpio_105
	DCW	C_gpio_106
	DCW	C_gpio_107
	DCW	C_gpio_108
	DCW	C_gpio_109
	DCW	C_gpio_110
	DCW	C_gpio_111
	DCW	C_gpio_112
	DCW	C_gpio_113
	DCW	C_gpio_114
	DCW	C_gpio_115
	DCW	C_gpio_116
	DCW	C_gpio_117
	DCW	C_gpio_118
	DCW	C_gpio_119
	DCW	C_gpio_120
	DCW	C_gpio_121
	DCW	C_gpio_122
	DCW	C_gpio_123
	DCW	C_gpio_124
	DCW	C_gpio_125
	DCW	C_gpio_126
	DCW	C_gpio_127
	DCW	C_gpio_128
	DCW	C_gpio_129
	DCW	C_gpio_130
	DCW	C_gpio_131
	DCW	C_gpio_132
	DCW	C_gpio_133
	DCW	C_gpio_134
	DCW	C_gpio_135
	DCW	C_gpio_136
	DCW	C_gpio_137
	DCW	C_gpio_138
	DCW	C_gpio_139
	DCW	C_gpio_140
	DCW	C_gpio_141
	DCW	C_gpio_142
	DCW	C_gpio_143
	DCW	C_gpio_144
	DCW	C_gpio_145
	DCW	C_gpio_146
	DCW	C_gpio_147
	DCW	C_gpio_148
	DCW	C_gpio_149
	DCW	C_gpio_150
	DCW	C_gpio_151
	DCW	C_gpio_152
	DCW	C_gpio_153
	DCW	C_gpio_154
	DCW	C_gpio_155
	DCW	C_gpio_156
	DCW	C_gpio_157
	DCW	C_gpio_158
	DCW	C_gpio_159
	DCW	C_gpio_160
	DCW	C_gpio_161
	DCW	C_gpio_162
	DCW	C_gpio_163
	DCW	C_gpio_164
	DCW	C_gpio_165
	DCW	C_gpio_166
	DCW	C_gpio_167
	DCW	C_gpio_168
	DCW	C_gpio_169
	DCW	C_gpio_170
	DCW	C_gpio_171
	DCW	C_gpio_172
	DCW	C_gpio_173
	DCW	C_gpio_173
	DCW	C_gpio_175
	DCW	C_gpio_176
	DCW	C_gpio_177
	DCW	C_gpio_178
	DCW	C_gpio_179
	DCW	C_gpio_180
	DCW	C_gpio_181
	DCW	C_gpio_182
	DCW	C_gpio_183
	DCW	C_gpio_184
	DCW	C_gpio_185
	DCW	C_gpio_186
	DCW	C_gpio_187
	DCW	C_gpio_188
	DCW	C_gpio_189
	DCW	C_gpio_190
	DCW	C_gpio_191
tablex	DCW	&FFFF
	ALIGN
;Expansion GPIO's pin table
XMtable2
	DCB	gpio_139
	DCB	gpio_144
	DCB	gpio_138
	DCB	gpio_146
	DCB	gpio_137
	DCB	gpio_143
	DCB	gpio_136
	DCB	gpio_145
	DCB	gpio_135
	DCB	gpio_158
	DCB	gpio_134
	DCB	gpio_162
	DCB	gpio_133
	DCB	gpio_161
	DCB	gpio_132
	DCB	gpio_159
	DCB	gpio_131
	DCB	gpio_156
	DCB	gpio_130
	DCB	gpio_157
	DCB	gpio_183
	DCB	gpio_168
	DCB	&FF
	ALIGN
;Auxillary GPIO's pin table
XMtable3
	DCB	gpio_20
	DCB	gpio_21
	DCB	gpio_17
	DCB	gpio_16
	DCB	gpio_15
	DCB	gpio_19
	DCB	gpio_23
	DCB	gpio_14
	DCB	gpio_18
	DCB	gpio_13
	DCB	gpio_22
	DCB	gpio_12
	DCB	gpio_170
	DCB	gpio_57
	DCB	&FF
	ALIGN
;camera table
XMtable4
	DCB	gpio_110
	DCB	gpio_96
	DCB	gpio_109
	DCB	gpio_108	;INPUT ONLY
	DCB	gpio_183
	DCB	gpio_107	;INPUT ONLY
	DCB	gpio_168
	DCB	gpio_106	;INPUT ONLY
	DCB	gpio_105	;INPUT ONLY
	DCB	gpio_167
	DCB	gpio_104
	DCB	gpio_103
	DCB	gpio_102
	DCB	gpio_101
	DCB	gpio_100	;INPUT ONLY
	DCB	gpio_99		;INPUT ONLY
	DCB	gpio_97
	DCB	gpio_94
	DCB	gpio_95
	DCB	&FF
	ALIGN
;user table
XMtable5
	DCB	M_button
	DCB	M_led0
	DCB	M_led1
	DCB	&FF
	ALIGN
;i2c table
XMtable6
	DCB	i2c_1
	DCB	i2c_2
	DCB	i2c_3
	DCB	i2c_4
	DCB	&FF
	ALIGN
;32bit mask table
XMtable7
	DCD	expbitmap	;mask bit
	DCD	gpio_139	;first pin in mask
	DCD	auxbitmap	;mask bit
	DCD	gpio_12		;first pin in mask
	DCD	cambitmap	;mask bit
	DCD	gpio_96		;first pin in mask

;uart table
XMtable8
	DCW	uart_rx+uart_rx_mode
	DCW	uart_tx+uart_tx_mode
	DCW	uart_cts+uart_cts_mode
	DCW	uart_rts+uart_rts_mode
	DCW	&FF
	ALIGN

;usb table
XMtable9
	DCW	usb1_0+usb1_mode
	DCW	usb1_1+usb1_mode
	DCW	usb1_2+usb1_mode
	DCW	usb1_3+usb1_mode
	DCW	usb1_4+usb1_mode
	DCW	usb1_5+usb1_mode
	DCW	usb1_6+usb1_mode
	DCW	usb1_7+usb1_mode
	DCW	usb1_nxt+usb1_mode
	DCW	usb1_clk+usb1_mode
	DCW	usb1_dit+usb1_mode
	DCW	usb1_stp+usb1_mode
	DCW	&FF
	ALIGN
;aux mmc table
XMtable10
	DCW	mmc3_0+mmc3_mode
	DCW	mmc3_1+mmc3_mode
	DCW	mmc3_2+mmc3_mode
	DCW	mmc3_3+mmc3_mode
	DCW	mmc3_4+mmc3_mode
	DCW	mmc3_5+mmc3_mode
	DCW	mmc3_6+mmc3_mode
	DCW	mmc3_7+mmc3_mode
	DCW	mmc3_cmd+mmc3_mode
	DCW	mmc3_clk+mmc3_mode
	DCW	&FF
	ALIGN

;exp mmc table
XMtable11
	DCW	mmc2_0+mmc2_mode
	DCW	mmc2_1+mmc2_mode
	DCW	mmc2_2+mmc2_mode
	DCW	mmc2_3+mmc2_mode
	DCW	mmc2_4+mmc2_mode
	DCW	mmc2_5+mmc2_mode
	DCW	mmc2_6+mmc2_mode
	DCW	mmc2_7+mmc2_mode
	DCW	mmc2_cmd+mmc2_mode
	DCW	mmc2_clk+mmc2_mode
	DCW	&FF
	ALIGN

;aux mm table
XMtable12
	DCW	mm1_txen+mm1_mode
	DCW	mm1_txdat+mm1_mode
	DCW	mm1_txseo+mm1_mode
	DCW	mm1_rx+mm1_mode
	DCW	mm1_rxrcv+mm1_mode
	DCW	mm1_rxdp+mm1_mode
	DCW	&FF
	ALIGN

;************************* Beagle Xm End ************************************
;**************************** Devkit ****************************************
;expansion GPIO's pin table
DEVtable2
	DCB	gpio_158
	DCB	gpio_159
	DCB	gpio_156
	DCB	gpio_161
	DCB	gpio_162
	DCB	gpio_160
	DCB	gpio_157
	DCB	gpio_150
	DCB	gpio_149
	DCB	gpio_151
	DCB	gpio_148
	DCB	gpio_130
	DCB	gpio_131
	DCB	gpio_132
	DCB	gpio_133
	DCB	gpio_134
	DCB	gpio_135
	DCB	gpio_136
	DCB	gpio_137
	DCB	gpio_138
	DCB	gpio_139
	DCB	gpio_140
	DCB	gpio_141
	DCB	gpio_142
	DCB	gpio_143
	DCB	gpio_184
	DCB	gpio_185
	DCB	gpio_172
	DCB	gpio_173
	DCB	gpio_171
	DCB	gpio_174
	DCB	gpio_177
	DCB	gpio_170
	DCB	&FF
	ALIGN
;user bits table
DEVtable5
	DCB	dev_button
	DCB	dev_led1
	DCB	dev_led2
	DCB	dev_led3
	DCB	&FF
	ALIGN
;i2c table
DEVtable6
	DCB	dev_i2c_1
	DCB	dev_i2c_2
	DCB	&FF
	DCB	&FF
	DCB	&FF
	ALIGN
;uart table
DEVtable8
	DCW	dev_uart_rx+uart_rx_mode
	DCW	dev_uart_tx+uart_tx_mode
	DCW	dev_uart_cts+uart_cts_mode
	DCW	dev_uart_rts+uart_rts_mode
	DCW	&FF
	ALIGN
;aux mmc table
DEVtable10
	DCW	dev_mmc2_0+mmc2_mode
	DCW	dev_mmc2_1+mmc2_mode
	DCW	dev_mmc2_2+mmc2_mode
	DCW	dev_mmc2_3+mmc2_mode
	DCW	dev_mmc2_4+mmc2_mode
	DCW	dev_mmc2_5+mmc2_mode
	DCW	dev_mmc2_6+mmc2_mode
	DCW	dev_mmc2_7+mmc2_mode
	DCW	dev_mmc2_cmd+mmc2_mode
	DCW	dev_mmc2_clk+mmc2_mode
	DCW	&FF
	ALIGN

;**************************** Devkit End *************************************
;**************************** Pandora ****************************************
;Expansion GPIO's pin table
Doratable2
	DCB	gpio_145
	DCB	gpio_147
	DCB	gpio_144
	DCB	gpio_166
	DCB	gpio_146
	DCB	gpio_165
	DCB	&FF
	ALIGN
;Internal GPIO's pin table
Doratable3
	DCB	gpio_58
	DCB	gpio_64
	DCB	gpio_65
	DCB	gpio_95
	DCB	gpio_97
	DCB	gpio_107
	DCB	gpio_167
	DCB	gpio_170
	DCB	&FF
	ALIGN

;**************************** Pandora End****************************************
;**************************** Panda ****************************************
;physical map table
Pandaphysical_table
	DCD	PDGPIO_1
	DCD	PDGPIO_2
	DCD	PDGPIO_3
	DCD	PDGPIO_4
	DCD	PDGPIO_5
	DCD	PDGPIO_6
	DCD	-1
PDMap	DCD	PDPADCONF_1
;Control register table
Pandatable1
	DCW	C_PDgpio_0
	DCW	C_PDgpio_1
	DCW	C_PDgpio_2
	DCW	C_PDgpio_3
	DCW	C_PDgpio_4
	DCW	C_PDgpio_5
	DCW	C_PDgpio_6
	DCW	C_PDgpio_7
	DCW	C_PDgpio_8
	DCW	C_PDgpio_9
	DCW	C_PDgpio_10
	DCW	C_PDgpio_11
	DCW	C_PDgpio_12
	DCW	C_PDgpio_13
	DCW	C_PDgpio_14
	DCW	C_PDgpio_15
	DCW	C_PDgpio_16
	DCW	C_PDgpio_17
	DCW	C_PDgpio_18
	DCW	C_PDgpio_19
	DCW	C_PDgpio_20
	DCW	C_PDgpio_21
	DCW	C_PDgpio_22
	DCW	C_PDgpio_23
	DCW	C_PDgpio_24
	DCW	C_PDgpio_25
	DCW	C_PDgpio_26
	DCW	C_PDgpio_27
	DCW	C_PDgpio_28
	DCW	C_PDgpio_29
	DCW	C_PDgpio_30
	DCW	C_PDgpio_31
	DCW	C_PDgpio_32
	DCW	C_PDgpio_33
	DCW	C_PDgpio_34
	DCW	C_PDgpio_35
	DCW	C_PDgpio_36
	DCW	C_PDgpio_37
	DCW	C_PDgpio_38
	DCW	C_PDgpio_39
	DCW	C_PDgpio_40
	DCW	C_PDgpio_41
	DCW	C_PDgpio_42
	DCW	C_PDgpio_43
	DCW	C_PDgpio_44
	DCW	C_PDgpio_45
	DCW	C_PDgpio_46
	DCW	C_PDgpio_47
	DCW	C_PDgpio_48
	DCW	C_PDgpio_49
	DCW	C_PDgpio_50
	DCW	C_PDgpio_51
	DCW	C_PDgpio_52
	DCW	C_PDgpio_53
	DCW	C_PDgpio_54
	DCW	C_PDgpio_55
	DCW	C_PDgpio_56
	DCW	C_PDgpio_57
	DCW	C_PDgpio_58
	DCW	C_PDgpio_59
	DCW	C_PDgpio_60
	DCW	C_PDgpio_61
	DCW	C_PDgpio_62
	DCW	C_PDgpio_63
	DCW	C_PDgpio_64
	DCW	C_PDgpio_65
	DCW	C_PDgpio_66
	DCW	C_PDgpio_67
	DCW	C_PDgpio_68
	DCW	C_PDgpio_69
	DCW	C_PDgpio_70
	DCW	C_PDgpio_71
	DCW	C_PDgpio_72
	DCW	C_PDgpio_73
	DCW	C_PDgpio_74
	DCW	C_PDgpio_75
	DCW	C_PDgpio_76
	DCW	C_PDgpio_77
	DCW	C_PDgpio_78
	DCW	C_PDgpio_79
	DCW	C_PDgpio_80
	DCW	C_PDgpio_81
	DCW	C_PDgpio_82
	DCW	C_PDgpio_83
	DCW	C_PDgpio_84
	DCW	C_PDgpio_85
	DCW	C_PDgpio_86
	DCW	C_PDgpio_87
	DCW	C_PDgpio_88
	DCW	C_PDgpio_89
	DCW	C_PDgpio_90
	DCW	C_PDgpio_91
	DCW	C_PDgpio_92
	DCW	C_PDgpio_93
	DCW	C_PDgpio_94
	DCW	C_PDgpio_95
	DCW	C_PDgpio_96
	DCW	C_PDgpio_97
	DCW	C_PDgpio_98
	DCW	C_PDgpio_99
	DCW	C_PDgpio_100
	DCW	C_PDgpio_101
	DCW	C_PDgpio_102
	DCW	C_PDgpio_103
	DCW	C_PDgpio_104
	DCW	C_PDgpio_105
	DCW	C_PDgpio_106
	DCW	C_PDgpio_107
	DCW	C_PDgpio_108
	DCW	C_PDgpio_109
	DCW	C_PDgpio_110
	DCW	C_PDgpio_111
	DCW	C_PDgpio_112
	DCW	C_PDgpio_113
	DCW	C_PDgpio_114
	DCW	C_PDgpio_115
	DCW	C_PDgpio_116
	DCW	C_PDgpio_117
	DCW	C_PDgpio_118
	DCW	C_PDgpio_119
	DCW	C_PDgpio_120
	DCW	C_PDgpio_121
	DCW	C_PDgpio_122
	DCW	C_PDgpio_123
	DCW	C_PDgpio_124
	DCW	C_PDgpio_125
	DCW	C_PDgpio_126
	DCW	C_PDgpio_127
	DCW	C_PDgpio_128
	DCW	C_PDgpio_129
	DCW	C_PDgpio_130
	DCW	C_PDgpio_131
	DCW	C_PDgpio_132
	DCW	C_PDgpio_133
	DCW	C_PDgpio_134
	DCW	C_PDgpio_135
	DCW	C_PDgpio_136
	DCW	C_PDgpio_137
	DCW	C_PDgpio_138
	DCW	C_PDgpio_139
	DCW	C_PDgpio_140
	DCW	C_PDgpio_141
	DCW	C_PDgpio_142
	DCW	C_PDgpio_143
	DCW	C_PDgpio_144
	DCW	C_PDgpio_145
	DCW	C_PDgpio_146
	DCW	C_PDgpio_147
	DCW	C_PDgpio_148
	DCW	C_PDgpio_149
	DCW	C_PDgpio_150
	DCW	C_PDgpio_151
	DCW	C_PDgpio_152
	DCW	C_PDgpio_153
	DCW	C_PDgpio_154
	DCW	C_PDgpio_155
	DCW	C_PDgpio_156
	DCW	C_PDgpio_157
	DCW	C_PDgpio_158
	DCW	C_PDgpio_159
	DCW	C_PDgpio_160
	DCW	C_PDgpio_161
	DCW	C_PDgpio_162
	DCW	C_PDgpio_163
	DCW	C_PDgpio_164
	DCW	C_PDgpio_165
	DCW	C_PDgpio_166
	DCW	C_PDgpio_167
	DCW	C_PDgpio_168
	DCW	C_PDgpio_169
	DCW	C_PDgpio_170
	DCW	C_PDgpio_171
	DCW	C_PDgpio_172
	DCW	C_PDgpio_173
	DCW	C_PDgpio_174
	DCW	C_PDgpio_175
	DCW	C_PDgpio_176
	DCW	C_PDgpio_177
	DCW	C_PDgpio_178
	DCW	C_PDgpio_179
	DCW	C_PDgpio_180
	DCW	C_PDgpio_181
	DCW	C_PDgpio_182
	DCW	C_PDgpio_183
	DCW	C_PDgpio_184
	DCW	C_PDgpio_185
	DCW	C_PDgpio_186
	DCW	C_PDgpio_187
	DCW	C_PDgpio_188
	DCW	C_PDgpio_189
	DCW	C_PDgpio_190
	DCW	C_PDgpio_191
	DCW	&FFFF
	ALIGN
;Expansion GPIO's pin table
PDtable2
	DCB	gpio_38
	DCB	gpio_37
	DCB	gpio_36
	DCB	gpio_32
	DCB	gpio_61
	DCB	gpio_33
	DCB	gpio_54
	DCB	gpio_34
	DCB	gpio_55
	DCB	gpio_35
	DCB	gpio_50
	DCB	gpio_56
	DCB	gpio_51
	DCB	gpio_59
	DCB	&FF
	ALIGN
PDtable2ES
	DCB	gpio_38
	DCB	gpio_37
	DCB	gpio_121
	DCB	gpio_36
	DCB	gpio_32
	DCB	gpio_61
	DCB	gpio_33
	DCB	gpio_54
	DCB	gpio_34
	DCB	gpio_55
	DCB	gpio_35
	DCB	gpio_50
	DCB	gpio_56
	DCB	gpio_51
	DCB	gpio_59
	DCB	&FF
	ALIGN
;Auxillary GPIO's pin table
PDtable3
	DCB	gpio_140
	DCB	gpio_156
	DCB	gpio_155
	DCB	gpio_138
	DCB	gpio_136
	DCB	gpio_139
	DCB	gpio_137
	DCB	gpio_135
	DCB	gpio_134
	DCB	gpio_39
	DCB	gpio_133
	DCB	gpio_132
	DCB	&FF
	ALIGN
;camera table
PDtable4
	DCB	gpio_67
	DCB	gpio_73
	DCB	gpio_68
	DCB	gpio_74
	DCB	gpio_69
	DCB	gpio_75
	DCB	gpio_70
	DCB	gpio_76
	DCB	gpio_71
	DCB	gpio_40
	DCB	gpio_72
	DCB	gpio_45
	DCB	gpio_83
	DCB	gpio_130
	DCB	gpio_81
	DCB	gpio_131
	DCB	gpio_82
	DCB	gpio_47
	DCB	gpio_44
	DCB	gpio_181
	DCB	gpio_42
	DCB	&FF
	ALIGN
;user table
PDtable5
	DCB	PD_button
	DCB	PD_ledD1
	DCB	PD_ledD2
	DCB	&FF
	ALIGN
;user table
PDtable5ES
	DCB	PDES_button
	DCB	PDES_ledD1
	DCB	PDES_ledD2
	DCB	&FF
	ALIGN
;i2c
PDtable6
	DCB	PD_i2c_1
	DCB	PD_i2c_2
	DCB	PD_i2c_3
	DCB	PD_i2c_4
	DCB	&FF
	ALIGN
;uart table
PDtable8
	DCW	PD_uart4_rx+PD_uart4_mode
	DCW	PD_uart4_tx+PD_uart4_mode
	DCW	&FF
	ALIGN

;sdmmc1
PDtable10
	DCW	PD_mmc1_0+PD_mmc1_mode
	DCW	PD_mmc1_1+PD_mmc1_mode
	DCW	PD_mmc1_2+PD_mmc1_mode
	DCW	PD_mmc1_3+PD_mmc1_mode
	DCW	PD_mmc1_4+PD_mmc1_mode
	DCW	PD_mmc1_5+PD_mmc1_mode
	DCW	PD_mmc1_6+PD_mmc1_mode
	DCW	PD_mmc1_7+PD_mmc1_mode
	DCW	PD_mmc1_cmd+PD_mmc1_mode
	DCW	PD_mmc1_clk+PD_mmc1_mode
	DCW	&FF
	ALIGN


;**************************** Pandora End ************************************
;**************************** Raspberry ****************************************
;physical map table
RPIphysical_table
	DCD	pi_GPIO_Base
	DCD	-1
RPIMk2physical_table
	DCD	piMk2_GPIO_Base
	DCD	-1

;Function Select register table
RPItable1
	DCW	pi_FSEL0
	DCW	pi_FSEL1
	DCW	pi_FSEL2
	DCW	pi_FSEL3
	DCW	pi_FSEL4
	DCW	pi_FSEL5
	DCW	pi_FSEL6
	DCW	pi_FSEL7
	DCW	pi_FSEL8
	DCW	pi_FSEL9
	DCW	pi_FSEL10
	DCW	pi_FSEL11
	DCW	pi_FSEL12
	DCW	pi_FSEL13
	DCW	pi_FSEL14
	DCW	pi_FSEL15
	DCW	pi_FSEL16
	DCW	pi_FSEL17
	DCW	pi_FSEL18
	DCW	pi_FSEL19
	DCW	pi_FSEL20
	DCW	pi_FSEL21
	DCW	pi_FSEL22
	DCW	pi_FSEL23
	DCW	pi_FSEL24
	DCW	pi_FSEL25
	DCW	pi_FSEL26
	DCW	pi_FSEL27
	DCW	pi_FSEL28
	DCW	pi_FSEL29
	DCW	pi_FSEL30
	DCW	pi_FSEL31
	DCW	pi_FSEL32
	DCW	pi_FSEL33
	DCW	pi_FSEL34
	DCW	pi_FSEL35
	DCW	pi_FSEL36
	DCW	pi_FSEL37
	DCW	pi_FSEL38
	DCW	pi_FSEL39
	DCW	pi_FSEL40
	DCW	pi_FSEL41
	DCW	pi_FSEL42
	DCW	pi_FSEL43
	DCW	pi_FSEL44
	DCW	pi_FSEL45
	DCW	&FFFF
	ALIGN
;expansion GPIO's pin table
RPItable2R1
	DCB	gpio_0
	DCB	gpio_1
	DCB	gpio_4
	DCB	gpio_14
	DCB	gpio_15
	DCB	gpio_17
	DCB	gpio_18
	DCB	gpio_21
	DCB	gpio_22
	DCB	gpio_23
	DCB	gpio_24
	DCB	gpio_10
	DCB	gpio_9
	DCB	gpio_25
	DCB	gpio_11
	DCB	gpio_8
	DCB	gpio_7
	DCB	&FF
	ALIGN
RPItable2R2
	DCB	gpio_2
	DCB	gpio_3
	DCB	gpio_4
	DCB	gpio_14
	DCB	gpio_15
	DCB	gpio_17
	DCB	gpio_18
	DCB	gpio_27
	DCB	gpio_22
	DCB	gpio_23
	DCB	gpio_24
	DCB	gpio_10
	DCB	gpio_9
	DCB	gpio_25
	DCB	gpio_11
	DCB	gpio_8
	DCB	gpio_7
	DCB	&FF
	ALIGN
RPItable2BP
	DCB	gpio_2
	DCB	gpio_3
	DCB	gpio_4
	DCB	gpio_14
	DCB	gpio_15
	DCB	gpio_17
	DCB	gpio_18
	DCB	gpio_27
	DCB	gpio_22
	DCB	gpio_23
	DCB	gpio_24
	DCB	gpio_10
	DCB	gpio_9
	DCB	gpio_25
	DCB	gpio_11
	DCB	gpio_8
	DCB	gpio_7
	DCB	gpio_0
	DCB	gpio_1
	DCB	gpio_5
	DCB	gpio_6
	DCB	gpio_12
	DCB	gpio_13
	DCB	gpio_19
	DCB	gpio_16
	DCB	gpio_26
	DCB	gpio_20
	DCB	gpio_21
	DCB	&FF
	ALIGN
RPItable2Comp
	DCB	gpio_0
	DCB	gpio_1
	DCB	gpio_2
	DCB	gpio_3
	DCB	gpio_4
	DCB	gpio_5
	DCB	gpio_6
	DCB	gpio_7
	DCB	gpio_8
	DCB	gpio_9
	DCB	gpio_10
	DCB	gpio_11
	DCB	gpio_12
	DCB	gpio_13
	DCB	gpio_14
	DCB	gpio_15
	DCB	gpio_16
	DCB	gpio_17
	DCB	gpio_18
	DCB	gpio_19
	DCB	gpio_20
	DCB	gpio_21
	DCB	gpio_22
	DCB	gpio_23
	DCB	gpio_24
	DCB	gpio_25
	DCB	gpio_26
	DCB	gpio_27
	DCB	gpio_28
	DCB	gpio_29
	DCB	gpio_30
	DCB	gpio_31
	DCB	gpio_32
	DCB	gpio_33
	DCB	gpio_34
	DCB	gpio_35
	DCB	gpio_36
	DCB	gpio_37
	DCB	gpio_38
	DCB	gpio_39
	DCB	gpio_40
	DCB	gpio_41
	DCB	gpio_42
	DCB	gpio_43
	DCB	gpio_44
	DCB	gpio_45
	DCB	&FF
	ALIGN
;Auxillary GPIO's pin table
RPItable3R2
	DCB	gpio_28
	DCB	gpio_29
	DCB	gpio_30
	DCB	gpio_31
	DCB	&FF
	ALIGN
;user bits table
RPItable5
	DCB	Pi_LED
	DCB	&FF
	ALIGN
RPItable5Comp
	DCB	Com_LED
	DCB	&FF
	ALIGN
;i2c table
RPItable6R1
	DCB	rpi_i2c0_1
	DCB	rpi_i2c0_2
	DCB	&FF
	DCB	&FF
	DCB	&FF
	ALIGN
RPItable6R2
	DCB	rpi_i2c1_1
	DCB	rpi_i2c1_2
	DCB	&FF
	DCB	&FF
	DCB	&FF
	ALIGN
RPItable6Comp
	DCB	rpi_i2c0_1
	DCB	rpi_i2c0_2
	DCB	rpi_i2c1_1
	DCB	rpi_i2c1_2
	DCB	&FF
	ALIGN
;uart table
RPItable8
	DCW	rpi_uart0_rx+pi_uart0
	DCW	rpi_uart0_tx+pi_uart0
	DCW	&FF
	ALIGN

RPItable11
	DCW	rpi_spio0_ce1+pi_spio0
	DCW	rpi_spio0_ce0+pi_spio0
	DCW	rpi_spio0_miso+pi_spio0
	DCW	rpi_spio0_mosi+pi_spio0
	DCW	rpi_spio0_sclk+pi_spio0
	DCW	&FF
	ALIGN
;**************************** Raspberry End *************************************

;processor-register table
proc_reg_list					;omap3
	DCW	GPIO_SYSCONFIG
	DCW	GPIO_SYSTATUS
	DCW	GPIO_IRQSTATUS1
	DCW	GPIO_IRQENABLE1
	DCW	GPIO_WAKEUPENABLE
	DCW	GPIO_IRQSTATUS2
	DCW	GPIO_IRQENABLE2
	DCW	GPIO_CTRL
	DCW	GPIO_OE
	DCW	GPIO_DATAIN
	DCW	GPIO_DATAOUT
	DCW	GPIO_LEVELDETECT0
	DCW	GPIO_LEVELDETECT1
	DCW	GPIO_RISINGDETECT
	DCW	GPIO_FALLINGDETECT
	DCW	GPIO_DEBOUNCEENABLE
	DCW	GPIO_DEBOUNCETIME
	DCW	GPIO_CLEARIRQENABLE1
	DCW	GPIO_SETIRQENABLE1
	DCW	GPIO_CLEARIRQENABLE2
	DCW	GPIO_SETIRQENABLE2
	DCW	GPIO_CLEARWKUENA
	DCW	GPIO_SETWKUENA
	DCW	GPIO_CLEARDATAOUT
	DCW	GPIO_SETDATAOUT
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	ALIGN					;omap4
	DCW	omap4_GPIO_SYSCONFIG
	DCW	omap4_GPIO_SYSSTATUS
	DCW	omap4_GPIO_IRQSTATUS1
	DCW	omap4_GPIO_IRQENABLE1
	DCW	omap4_GPIO_WAKE_EN
	DCW	omap4_GPIO_IRQSTATUS2
	DCW	omap4_GPIO_IRQENABLE2
	DCW	omap4_GPIO_CTRL
	DCW	omap4_GPIO_OE
	DCW	omap4_GPIO_DATAIN
	DCW	omap4_GPIO_DATAOUT
	DCW	omap4_GPIO_LEVELDETECT0
	DCW	omap4_GPIO_LEVELDETECT1
	DCW	omap4_GPIO_RISINGDETECT
	DCW	omap4_GPIO_FALLINGDETECT
	DCW	omap4_GPIO_DEBOUNCE_EN
	DCW	omap4_GPIO_DEBOUNCE_VAL
	DCW	omap4_GPIO_CLEARIRQENABLE1
	DCW	omap4_GPIO_SETIRQENABLE1
	DCW	omap4_GPIO_CLEARIRQENABLE2
	DCW	omap4_GPIO_SETIRQENABLE2
	DCW	omap4_GPIO_CLEARWKUENA
	DCW	omap4_GPIO_SETWKUENA
	DCW	omap4_GPIO_CLEARDATAOUT
	DCW	omap4_GPIO_SETDATAOUT
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	DCW	0
	ALIGN


	END
