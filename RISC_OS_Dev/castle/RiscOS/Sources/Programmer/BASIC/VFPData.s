;ObjAsm header file created by VFPLib - (C)2011 TBA Software
;
;This file contains data-tables used within s.VFP in the BASIC source
;
;Generated automatically by VFPLib at Fri,28 Sep 2018.12:09:59
;
  [ :DEF: BuildingVFPData
	INCLUDE  hdr/VFPMacros
	AREA	|VFPLibObjHdr$Code|, CODE, READONLY, PIC
	ENTRY
  ]
;Param Op Number Definitions
VFP_OpCount	EQU 41
VFP_Op_a	EQU 0
VFP_Op_align	EQU 1
VFP_Op_cc	EQU 2
VFP_Op_cond	EQU 3
VFP_Op_E	EQU 4
VFP_Op_esize	EQU 5
VFP_Op_F	EQU 6
VFP_Op_ia	EQU 7
VFP_Op_imm	EQU 8
VFP_Op_imm3	EQU 9
VFP_Op_imm4	EQU 10
VFP_Op_imm6l	EQU 11
VFP_Op_imm6r	EQU 12
VFP_Op_imn	EQU 13
VFP_Op_L	EQU 14
VFP_Op_len	EQU 15
VFP_Op_op	EQU 16
VFP_Op_opc	EQU 17
VFP_Op_opc2	EQU 18
VFP_Op_opcmode	EQU 19
VFP_Op_P	EQU 20
VFP_Op_Q	EQU 21
VFP_Op_regcount	EQU 22
VFP_Op_rm	EQU 23
VFP_Op_Rt	EQU 24
VFP_Op_Ru	EQU 25
VFP_Op_sf	EQU 26
VFP_Op_size	EQU 27
VFP_Op_size1	EQU 28
VFP_Op_spec	EQU 29
VFP_Op_sx	EQU 30
VFP_Op_sz	EQU 31
VFP_Op_T	EQU 32
VFP_Op_type	EQU 33
VFP_Op_U	EQU 34
VFP_Op_Vd	EQU 35
VFP_Op_Vm	EQU 36
VFP_Op_Vmx	EQU 37
VFP_Op_Vn	EQU 38
VFP_Op_W	EQU 39
VFP_Op_x	EQU 40

  [ :DEF: BuildingVFPData
; start of VFP tables
VFPtables       DCB "VFPTABLE"
	DCD VFPOpTable-VFPtables
;
;List of Unique Datatype Combinations
VFPdt_00	VFP_DataTypeListEntry "F","32",32
		DCD 0
VFPdt_01	VFP_DataTypeListEntry "F","64",64
		DCD 0
VFPdt_02	VFP_DataTypeListEntry "I","8 ",8
		VFP_DataTypeListEntry "I","16",16
		VFP_DataTypeListEntry "I","32",32
		VFP_DataTypeListEntry "I","64",64
		VFP_DataTypeListEntry "F","32",32
		DCD 0
VFPdt_03	VFP_DataTypeListEntry " ","8 ",8
		VFP_DataTypeListEntry "I","8 ",8
		VFP_DataTypeListEntry "S","8 ",8
		VFP_DataTypeListEntry "U","8 ",8
		VFP_DataTypeListEntry "P","8 ",8
		VFP_DataTypeListEntry " ","16",16
		VFP_DataTypeListEntry "I","16",16
		VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "U","16",16
		VFP_DataTypeListEntry "P","16",16
		VFP_DataTypeListEntry "F","16",16
		VFP_DataTypeListEntry " ","32",32
		VFP_DataTypeListEntry "I","32",32
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "U","32",32
		VFP_DataTypeListEntry "F","32",32
		VFP_DataTypeListEntry " ","64",64
		VFP_DataTypeListEntry "I","64",64
		VFP_DataTypeListEntry "S","64",64
		VFP_DataTypeListEntry "U","64",64
		VFP_DataTypeListEntry "F","64",64
		DCD 0
VFPdt_04	VFP_DataTypeListEntry "I","16",16
		VFP_DataTypeListEntry "I","32",32
		DCD 0
VFPdt_05	VFP_DataTypeListEntry " ","8 ",8
		VFP_DataTypeListEntry " ","16",16
		VFP_DataTypeListEntry " ","32",32
		DCD 0
VFPdt_06	VFP_DataTypeListEntry "I","8 ",8
		VFP_DataTypeListEntry "I","16",16
		VFP_DataTypeListEntry "I","32",32
		DCD 0
VFPdt_07	VFP_DataTypeListEntry "S","8 ",8
		VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "U","8 ",8
		VFP_DataTypeListEntry "U","16",16
		VFP_DataTypeListEntry "U","32",32
		DCD 0
VFPdt_08	VFP_DataTypeListEntry "I","16",16
		DCD 0
VFPdt_09	VFP_DataTypeListEntry "I","32",32
		VFP_DataTypeListEntry "F","32",32
		DCD 0
VFPdt_0A	VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "U","16",16
		DCD 0
VFPdt_0B	VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "U","32",32
		DCD 0
VFPdt_0C	VFP_DataTypeListEntry "P","8 ",8
		DCD 0
VFPdt_0D	VFP_DataTypeListEntry "I","8 ",8
		VFP_DataTypeListEntry "I","16",16
		VFP_DataTypeListEntry "I","32",32
		VFP_DataTypeListEntry "I","64",64
		DCD 0
VFPdt_0E	VFP_DataTypeListEntry "I","16",16
		VFP_DataTypeListEntry "I","32",32
		VFP_DataTypeListEntry "I","64",64
		DCD 0
VFPdt_0F	VFP_DataTypeListEntry "S","8 ",8
		VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "F","32",32
		DCD 0
VFPdt_10	VFP_DataTypeListEntry "S","8 ",8
		DCD 0
VFPdt_11	VFP_DataTypeListEntry "S","16",16
		DCD 0
VFPdt_12	VFP_DataTypeListEntry "U","8 ",8
		DCD 0
VFPdt_13	VFP_DataTypeListEntry "U","16",16
		DCD 0
VFPdt_14	VFP_DataTypeListEntry " ","32",32
		DCD 0
VFPdt_15	VFP_DataTypeListEntry "I","8 ",8
		VFP_DataTypeListEntry "I","16",16
		VFP_DataTypeListEntry "I","32",32
		VFP_DataTypeListEntry "F","32",32
		DCD 0
VFPdt_16	VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "U","16",16
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "U","32",32
		DCD 0
VFPdt_17	VFP_DataTypeListEntry " ","8 ",8
		VFP_DataTypeListEntry " ","16",16
		VFP_DataTypeListEntry " ","32",32
		VFP_DataTypeListEntry " ","64",64
		DCD 0
VFPdt_18	VFP_DataTypeListEntry " ","16",16
		VFP_DataTypeListEntry " ","32",32
		DCD 0
VFPdt_19	VFP_DataTypeListEntry " ","16",16
		DCD 0
VFPdt_1A	VFP_DataTypeListEntry "S","8 ",8
		VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		DCD 0
VFPdt_1B	VFP_DataTypeListEntry " ","8 ",8
		DCD 0
VFPdt_1C	VFP_DataTypeListEntry " ","64",64
		DCD 0
VFPdt_1D	VFP_DataTypeListEntry "S","8 ",8
		VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "S","64",64
		VFP_DataTypeListEntry "U","8 ",8
		VFP_DataTypeListEntry "U","16",16
		VFP_DataTypeListEntry "U","32",32
		VFP_DataTypeListEntry "U","64",64
		DCD 0
VFPdt_1E	VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		DCD 0
VFPdt_1F	VFP_DataTypeListEntry "S","32",32
		DCD 0
VFPdt_20	VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "S","64",64
		DCD 0
VFPdt_21	VFP_DataTypeListEntry "U","16",16
		VFP_DataTypeListEntry "U","32",32
		VFP_DataTypeListEntry "U","64",64
		DCD 0
VFPdt_22	VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "S","64",64
		VFP_DataTypeListEntry "U","16",16
		VFP_DataTypeListEntry "U","32",32
		VFP_DataTypeListEntry "U","64",64
		DCD 0
VFPdt_23	VFP_DataTypeListEntry "S","8 ",8
		VFP_DataTypeListEntry "S","16",16
		VFP_DataTypeListEntry "S","32",32
		VFP_DataTypeListEntry "S","64",64
		DCD 0
VFPdt_24	VFP_DataTypeListEntry "U","32",32
		VFP_DataTypeListEntry "F","32",32
		DCD 0
VFPdt_25	VFP_DataTypeListEntry " ","8 ",8
		VFP_DataTypeListEntry " ","16",16
		DCD 0
VFPdt_26	VFP_DataTypeListEntry " ","16",16
		VFP_DataTypeListEntry " ","32",32
		VFP_DataTypeListEntry " ","64",64
		DCD 0
VFPdt_27	VFP_DataTypeListEntry "I","8 ",8
		DCD 0
VFPdt_28	VFP_DataTypeListEntry "I","32",32
		DCD 0

;Bit Field Args Lists
VFPbfa_00	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_01	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_02	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_E, &1, 7
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_03	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_E, &1, 7
		DCD 0
VFPbfa_04	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_opc2, &7, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_op, &1, 7
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_05	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_op, &1, 18
		VFP_BitFieldArgs VFP_Op_U, &1, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sf, &1, 8
		VFP_BitFieldArgs VFP_Op_sx, &1, 7
		VFP_BitFieldArgs VFP_Op_imm4, &1, 5
		VFP_BitFieldArgs VFP_Op_imm4, &1E, -1
		DCD 0
VFPbfa_06	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_op, &1, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_T, &1, 7
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_07	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_P, &1, 24
		VFP_BitFieldArgs VFP_Op_U, &1, 23
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_W, &1, 21
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 8
		VFP_BitFieldArgs VFP_Op_regcount, &FF, 0
		DCD 0
VFPbfa_08	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_U, &1, 23
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 8
		VFP_BitFieldArgs VFP_Op_imm, &FF, 0
		DCD 0
VFPbfa_09	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_op, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_0A	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_op, &1, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Rt, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		DCD 0
VFPbfa_0B	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_op, &1, 20
		VFP_BitFieldArgs VFP_Op_Ru, &F, 16
		VFP_BitFieldArgs VFP_Op_Rt, &F, 12
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_0C	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_opc, &C, 19
		VFP_BitFieldArgs VFP_Op_Vd, &F, 16
		VFP_BitFieldArgs VFP_Op_Rt, &F, 12
		VFP_BitFieldArgs VFP_Op_Vd, &10, 3
		VFP_BitFieldArgs VFP_Op_opc, &3, 5
		DCD 0
VFPbfa_0D	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_U, &1, 23
		VFP_BitFieldArgs VFP_Op_opc, &C, 19
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Rt, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_opc, &3, 5
		DCD 0
VFPbfa_0E	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm, &F0, 12
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_imm, &F, 0
		DCD 0
VFPbfa_0F	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_spec, &F, 16
		VFP_BitFieldArgs VFP_Op_Rt, &F, 12
		DCD 0
VFPbfa_10	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_regcount, &FF, 0
		DCD 0
VFPbfa_11	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_cc, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_12	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_op, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_13	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_rm, &3, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_op, &1, 7
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_14	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_rm, &3, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_15	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_sz, &1, 8
		VFP_BitFieldArgs VFP_Op_op, &1, 7
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_16	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_17	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_18	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_sz, &1, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_19	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_F, &1, 10
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_1A	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_1B	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size1, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_1C	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_1D	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_op, &1, 21
		VFP_BitFieldArgs VFP_Op_sz, &1, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_1E	VFP_BitFieldArgs VFP_Op_imm, &80, 17
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm, &70, 12
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_opcmode, &F, 8
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_imm, &F, 0
		DCD 0
VFPbfa_1F	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_op, &1, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_20	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_op, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_21	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_22	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imn, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 8
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_23	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &3, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_24	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm4, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_25	VFP_BitFieldArgs VFP_Op_cond, &F, 28
		VFP_BitFieldArgs VFP_Op_esize, &2, 21
		VFP_BitFieldArgs VFP_Op_Q, &1, 21
		VFP_BitFieldArgs VFP_Op_Vd, &F, 16
		VFP_BitFieldArgs VFP_Op_Rt, &F, 12
		VFP_BitFieldArgs VFP_Op_Vd, &10, 3
		VFP_BitFieldArgs VFP_Op_esize, &1, 5
		DCD 0
VFPbfa_26	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_27	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_imm, &F, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_28	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 9
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_29	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_type, &F, 8
		VFP_BitFieldArgs VFP_Op_size, &3, 6
		VFP_BitFieldArgs VFP_Op_align, &3, 4
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_2A	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_size, &3, 10
		VFP_BitFieldArgs VFP_Op_op, &3, 8
		VFP_BitFieldArgs VFP_Op_ia, &F, 4
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_2B	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &3, 8
		VFP_BitFieldArgs VFP_Op_size, &3, 6
		VFP_BitFieldArgs VFP_Op_T, &1, 5
		VFP_BitFieldArgs VFP_Op_a, &1, 4
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_2C	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_op, &1, 4
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_2D	VFP_BitFieldArgs VFP_Op_op, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_2E	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 9
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_2F	VFP_BitFieldArgs VFP_Op_Q, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 10
		VFP_BitFieldArgs VFP_Op_F, &1, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vmx, &10, 1
		VFP_BitFieldArgs VFP_Op_Vmx, &F, 0
		DCD 0
VFPbfa_30	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 10
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vmx, &10, 1
		VFP_BitFieldArgs VFP_Op_Vmx, &F, 0
		DCD 0
VFPbfa_31	VFP_BitFieldArgs VFP_Op_imm, &80, 17
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm, &70, 12
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_opcmode, &F, 8
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_opcmode, &10, 1
		VFP_BitFieldArgs VFP_Op_imm, &F, 0
		DCD 0
VFPbfa_32	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vm, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vm, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_33	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm3, &7, 19
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_34	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size1, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_35	VFP_BitFieldArgs VFP_Op_Q, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_F, &1, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vmx, &10, 1
		VFP_BitFieldArgs VFP_Op_Vmx, &F, 0
		DCD 0
VFPbfa_36	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vmx, &10, 1
		VFP_BitFieldArgs VFP_Op_Vmx, &F, 0
		DCD 0
VFPbfa_37	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_U, &1, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_38	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 9
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_39	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 10
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vmx, &10, 1
		VFP_BitFieldArgs VFP_Op_Vmx, &F, 0
		DCD 0
VFPbfa_3A	VFP_BitFieldArgs VFP_Op_Q, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vmx, &10, 1
		VFP_BitFieldArgs VFP_Op_Vmx, &F, 0
		DCD 0
VFPbfa_3B	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_3C	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 20
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Vmx, &10, 1
		VFP_BitFieldArgs VFP_Op_Vmx, &F, 0
		DCD 0
VFPbfa_3D	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size1, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &3, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_3E	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm6r, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 8
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_3F	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm6l, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &1, 8
		VFP_BitFieldArgs VFP_Op_L, &1, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_40	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_F, &1, 8
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_41	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm6r, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_L, &1, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_42	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm6r, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_43	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm6l, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_L, &1, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_44	VFP_BitFieldArgs VFP_Op_U, &1, 24
		VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm6l, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_45	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_46	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_imm6r, &3F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_L, &1, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_47	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_len, &3, 8
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_op, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_48	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_op, &1, 21
		VFP_BitFieldArgs VFP_Op_Vn, &F, 16
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_Vn, &10, 3
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_49	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_rm, &3, 8
		VFP_BitFieldArgs VFP_Op_op, &1, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_4A	VFP_BitFieldArgs VFP_Op_Vd, &10, 18
		VFP_BitFieldArgs VFP_Op_size, &3, 18
		VFP_BitFieldArgs VFP_Op_Vd, &F, 12
		VFP_BitFieldArgs VFP_Op_op, &7, 7
		VFP_BitFieldArgs VFP_Op_Q, &1, 6
		VFP_BitFieldArgs VFP_Op_Vm, &10, 1
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_4B	VFP_BitFieldArgs VFP_Op_x, &3, 3
		VFP_BitFieldArgs VFP_Op_Vm, &7, 0
		DCD 0
VFPbfa_4C	VFP_BitFieldArgs VFP_Op_x, &1, 4
		VFP_BitFieldArgs VFP_Op_Vm, &F, 0
		DCD 0
VFPbfa_4D	VFP_BitFieldArgs VFP_Op_x, &7, 0
		DCD 0
VFPbfa_4E	VFP_BitFieldArgs VFP_Op_x, &3, 0
		DCD 0
VFPbfa_4F	VFP_BitFieldArgs VFP_Op_x, &1, 2
		DCD 0
VFPbfa_50	VFP_BitFieldArgs VFP_Op_x, &3, 1
		DCD 0
VFPbfa_51	VFP_BitFieldArgs VFP_Op_size, &2, -1
		DCD 0
VFPbfa_52	VFP_BitFieldArgs VFP_Op_x, &7, 1
		DCD 0
VFPbfa_53	VFP_BitFieldArgs VFP_Op_x, &3, 2
		VFP_BitFieldArgs VFP_Op_align, &3, 0
		DCD 0
VFPbfa_54	VFP_BitFieldArgs VFP_Op_x, &1, 3
		VFP_BitFieldArgs VFP_Op_align, &7, 0
		DCD 0
VFPbfa_55	VFP_BitFieldArgs VFP_Op_x, &7, 1
		VFP_BitFieldArgs VFP_Op_align, &1, 0
		DCD 0
VFPbfa_56	VFP_BitFieldArgs VFP_Op_x, &3, 2
		VFP_BitFieldArgs VFP_Op_align, &1, 0
		DCD 0
VFPbfa_57	VFP_BitFieldArgs VFP_Op_x, &1, 3
		VFP_BitFieldArgs VFP_Op_align, &3, 0
		DCD 0
VFPbfa_58	VFP_BitFieldArgs VFP_Op_x, &3, 2
		DCD 0
VFPbfa_59	VFP_BitFieldArgs VFP_Op_x, &1, 3
		DCD 0
VFPbfa_5A	VFP_BitFieldArgs VFP_Op_align, &1, 0
		DCD 0

;VABS A2
VFPenc_00	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB00AC0,(VFPbfa_00-VFPtables)

;VADD (floating-point) A2
VFPenc_01	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E300A00,(VFPbfa_01-VFPtables)

;VCMP,VCMPE A1
VFPenc_02	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB40A40,(VFPbfa_02-VFPtables)

;VCMP,VCMPE A2
VFPenc_03	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB50A40,(VFPbfa_03-VFPtables)

;VCVT,VCVTR (float and integer,VFP) A1
VFPenc_04	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB80A40,(VFPbfa_04-VFPtables)

;VCVT (double and single) A1
VFPenc_05	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB70AC0,(VFPbfa_00-VFPtables)

;VCVT (float and fixed,VFP) A1
VFPenc_06	VFP_Encoding (VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EBA0A40,(VFPbfa_05-VFPtables)

;VCVTB,VCVTT A1
VFPenc_07	VFP_Encoding (VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_ARMv8+VFP_Enc_Flag_VFPv3H),0
		VFP_BitFieldRecord &EB20A40,(VFPbfa_06-VFPtables)

;VLDM A1,A2
VFPenc_08	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &C100A00,(VFPbfa_07-VFPtables)

;VLDR A1,A2
VFPenc_09	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &D100A00,(VFPbfa_08-VFPtables)

;VMUL (floating-point) A2
VFPenc_0A	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E200A00,(VFPbfa_01-VFPtables)

;VMLA,VMLS (floating-point) A2
VFPenc_0B	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E000A00,(VFPbfa_09-VFPtables)

;VDIV A1
VFPenc_0C	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E800A00,(VFPbfa_01-VFPtables)

;VSQRT A1
VFPenc_0D	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB10AC0,(VFPbfa_00-VFPtables)

;VMOV (ARM core and single) A1
VFPenc_0E	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E000A10,(VFPbfa_0A-VFPtables)

;VMOV (two ARM core and two single) A1
VFPenc_0F	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &C400A10,(VFPbfa_0B-VFPtables)

;VMOV (two ARM core and doubleword) A1
VFPenc_10	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &C400B10,(VFPbfa_0B-VFPtables)

;VMOV (ARM core to scalar) A1
VFPenc_11	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &E000B10,(VFPbfa_0C-VFPtables)

;VMOV (scalar to ARM core) A1
VFPenc_12	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &E100B10,(VFPbfa_0D-VFPtables)

;VMOV (immediate) A2
VFPenc_13	VFP_Encoding (VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB00A00,(VFPbfa_0E-VFPtables)

;VMOV (register) A2
VFPenc_14	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB00A40,(VFPbfa_00-VFPtables)

;VMSR A1
VFPenc_15	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &EE00A10,(VFPbfa_0F-VFPtables)

;VMRS A1
VFPenc_16	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &EF00A10,(VFPbfa_0F-VFPtables)

;VNEG A2
VFPenc_17	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EB10A40,(VFPbfa_00-VFPtables)

;VNMLA,VNMLS,VNMUL A1
VFPenc_18	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E100A00,(VFPbfa_09-VFPtables)

;VNMLA,VNMLS,VNMUL A2
VFPenc_19	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E200A40,(VFPbfa_01-VFPtables)

;VPOP A1,A2
VFPenc_1A	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &CBD0A00,(VFPbfa_10-VFPtables)

;VPOP A1,A2
VFPenc_1B	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &CBD0A00,(VFPbfa_10-VFPtables)

;VPUSH A1,A2
VFPenc_1C	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &D2D0A00,(VFPbfa_10-VFPtables)

;VPUSH A1,A2
VFPenc_1D	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &D2D0A00,(VFPbfa_10-VFPtables)

;VSTM A1,A2
VFPenc_1E	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &C000A00,(VFPbfa_07-VFPtables)

;VSUB (floating-point) A2
VFPenc_1F	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E300A40,(VFPbfa_01-VFPtables)

;VSTR A1,A2
VFPenc_20	VFP_Encoding (VFP_Enc_Flag_VFPv2+VFP_Enc_Flag_VFPv3+VFP_Enc_Flag_VFPv4+VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &D000A00,(VFPbfa_08-VFPtables)

;VFMA,VFMS A2
VFPenc_21	VFP_Encoding (VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &EA00A00,(VFPbfa_09-VFPtables)

;VFNMA,VFNMS A1
VFPenc_22	VFP_Encoding (VFP_Enc_Flag_VFPv4),0
		VFP_BitFieldRecord &E900A00,(VFPbfa_09-VFPtables)

;VSELEQ/GE/GT/VS A1
VFPenc_23	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &FE000A00,(VFPbfa_11-VFPtables)

;VMAXNM,VMINNM A2
VFPenc_24	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &FE800A00,(VFPbfa_12-VFPtables)

;VCVTA/M/N/P (floating-point) A1
VFPenc_25	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &FEBC0A40,(VFPbfa_13-VFPtables)

;VRINTA/M/N/P (floating-point) A1
VFPenc_26	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &FEB80A40,(VFPbfa_14-VFPtables)

;VRINTR/Z (floating-point) A1
VFPenc_27	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &EB60A40,(VFPbfa_15-VFPtables)

;VRINTX (floating-point) A1
VFPenc_28	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &EB70A40,(VFPbfa_00-VFPtables)

;VABA,VABAL A1
VFPenc_29	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000710,(VFPbfa_16-VFPtables)

;VABA,VABAL A2
VFPenc_2A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800500,(VFPbfa_17-VFPtables)

;VABD,VABDL (integer) A1
VFPenc_2B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000700,(VFPbfa_16-VFPtables)

;VABD,VABDL (integer) A2
VFPenc_2C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800700,(VFPbfa_17-VFPtables)

;VABD,VABDL (floating-point) A1
VFPenc_2D	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3200D00,(VFPbfa_18-VFPtables)

;VABS A1
VFPenc_2E	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B10300,(VFPbfa_19-VFPtables)

;VADD (integer) A1
VFPenc_2F	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000800,(VFPbfa_1A-VFPtables)

;VADDHN A1
VFPenc_30	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800400,(VFPbfa_1B-VFPtables)

;VADDL,VADDW A1
VFPenc_31	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800000,(VFPbfa_1C-VFPtables)

;VADD (floating-point) A1
VFPenc_32	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000D00,(VFPbfa_18-VFPtables)

;VACGE,VACGT A1
VFPenc_33	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000E10,(VFPbfa_1D-VFPtables)

;VBIC (immediate) A1
VFPopc_34	VFP_OPCModeListEntry "10xx1"
		VFP_OPCModeListEntry "110x1"
		DCD 0
VFPenc_34	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),(VFPopc_34-VFPtables)
		VFP_BitFieldRecord &F2800030,(VFPbfa_1E-VFPtables)

;VBIC (register) A1
VFPenc_35	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000110,(VFPbfa_1F-VFPtables)

;VBIF,VBIT,VBSL A1
VFPenc_36	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000110,(VFPbfa_20-VFPtables)

;VCEQ (register) A1
VFPenc_37	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000810,(VFPbfa_1A-VFPtables)

;VCGE (register) A1
VFPenc_38	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000310,(VFPbfa_16-VFPtables)

;VCGT (register) A1
VFPenc_39	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000300,(VFPbfa_16-VFPtables)

;VCEQ (register) A2
VFPenc_3A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000E00,(VFPbfa_18-VFPtables)

;VCGE (register) A2
VFPenc_3B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000E00,(VFPbfa_18-VFPtables)

;VCGT (register) A2
VFPenc_3C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3200E00,(VFPbfa_18-VFPtables)

;VCEQ (immediate #0) A1
VFPenc_3D	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B10100,(VFPbfa_19-VFPtables)

;VCGE (immediate #0) A1
VFPenc_3E	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B10080,(VFPbfa_19-VFPtables)

;VCGT (immediate #0) A1
VFPenc_3F	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B10000,(VFPbfa_19-VFPtables)

;VCLE (immediate #0) A1
VFPenc_40	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B10180,(VFPbfa_19-VFPtables)

;VCLT (immediate #0) A1
VFPenc_41	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B10200,(VFPbfa_19-VFPtables)

;VCLS A1
VFPenc_42	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00400,(VFPbfa_21-VFPtables)

;VCLZ A1
VFPenc_43	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00480,(VFPbfa_21-VFPtables)

;VCNT A1
VFPenc_44	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00500,(VFPbfa_21-VFPtables)

;VCVT (float and fixed,SIMD) A1
VFPenc_45	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800E10,(VFPbfa_22-VFPtables)

;VCVT (float and integer,SIMD) A1
VFPenc_46	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B30600,(VFPbfa_23-VFPtables)

;VDUP (scalar) A1
VFPenc_47	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00C00,(VFPbfa_24-VFPtables)

;VDUP (ARM core) A1
VFPenc_48	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &E800B10,(VFPbfa_25-VFPtables)

;VEOR A1
VFPenc_49	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000110,(VFPbfa_26-VFPtables)

;VEXT A1
VFPenc_4A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2B00000,(VFPbfa_27-VFPtables)

;VHADD,VHSUB A1
VFPenc_4B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000000,(VFPbfa_28-VFPtables)

;VLD (multiple) A1
VFPenc_4C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F4200000,(VFPbfa_29-VFPtables)

;VLD (single one) A1
VFPenc_4D	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F4A00000,(VFPbfa_2A-VFPtables)

;VLD (single all) A1
VFPenc_4E	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F4A00C00,(VFPbfa_2B-VFPtables)

;VMAX,VMIN (integer) A1
VFPenc_4F	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000600,(VFPbfa_2C-VFPtables)

;VMAX,VMIN (floating-point) A1
VFPenc_50	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000F00,(VFPbfa_1D-VFPtables)

;VMLA,VMLS (floating-point) A1
VFPenc_51	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000D10,(VFPbfa_1D-VFPtables)

;VMLA,VMLAL,VMLS,VMLSL (integer) A1
VFPenc_52	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000900,(VFPbfa_2D-VFPtables)

;VMLA,VMLAL,VMLS,VMLSL (integer) A2
VFPenc_53	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800800,(VFPbfa_2E-VFPtables)

;VMLA,VMLAL,VMLS,VMLSL (by scalar) A1
VFPenc_54	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800040,(VFPbfa_2F-VFPtables)

;VMLA,VMLAL,VMLS,VMLSL (by scalar) A2
VFPenc_55	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800240,(VFPbfa_30-VFPtables)

;VMOV (immediate) A1
VFPopc_56	VFP_OPCModeListEntry "00xx0"
		VFP_OPCModeListEntry "010x0"
		VFP_OPCModeListEntry "011xx"
		VFP_OPCModeListEntry "11110"
		DCD 0
VFPenc_56	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),(VFPopc_56-VFPtables)
		VFP_BitFieldRecord &F2800010,(VFPbfa_31-VFPtables)

;VMOV (register) A1
VFPenc_57	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2200110,(VFPbfa_32-VFPtables)

;VMOVL A1
VFPenc_58	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800A10,(VFPbfa_33-VFPtables)

;VMOVN A1
VFPenc_59	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B20200,(VFPbfa_34-VFPtables)

;VMUL (floating-point) A1
VFPenc_5A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000D10,(VFPbfa_18-VFPtables)

;VMUL,VMULL (by integer and poly) A1
VFPenc_5B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000910,(VFPbfa_2D-VFPtables)

;VMUL,VMULL (by integer and poly) A2
VFPenc_5C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800C00,(VFPbfa_2E-VFPtables)

;VMUL,VMULL (by scalar) A1
VFPenc_5D	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800840,(VFPbfa_35-VFPtables)

;VMUL,VMULL (by scalar) A2
VFPenc_5E	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800A40,(VFPbfa_36-VFPtables)

;VMVN (immediate) A1
VFPopc_5F	VFP_OPCModeListEntry "10xx0"
		VFP_OPCModeListEntry "110x0"
		VFP_OPCModeListEntry "1110x"
		DCD 0
VFPenc_5F	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),(VFPopc_5F-VFPtables)
		VFP_BitFieldRecord &F2800010,(VFPbfa_31-VFPtables)

;VMVN (register) A1
VFPenc_60	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00580,(VFPbfa_21-VFPtables)

;VNEG A1
VFPenc_61	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B10380,(VFPbfa_19-VFPtables)

;VORR (immediate) A1
VFPopc_62	VFP_OPCModeListEntry "00xx1"
		VFP_OPCModeListEntry "010x1"
		DCD 0
VFPenc_62	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),(VFPopc_62-VFPtables)
		VFP_BitFieldRecord &F2800010,(VFPbfa_1E-VFPtables)

;VORR (register) A1
VFPenc_63	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2200110,(VFPbfa_1F-VFPtables)

;VPADAL A1
VFPenc_64	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00600,(VFPbfa_37-VFPtables)

;VPADD A1
VFPenc_65	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000B10,(VFPbfa_1A-VFPtables)

;VPADD A2
VFPenc_66	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000D00,(VFPbfa_18-VFPtables)

;VPADDL A1
VFPenc_67	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00200,(VFPbfa_37-VFPtables)

;VPMAX,VPMIN (integer) A1
VFPenc_68	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000A00,(VFPbfa_2C-VFPtables)

;VPMAX,VPMIN (floating-point) A1
VFPenc_69	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000F00,(VFPbfa_1D-VFPtables)

;VQABS A1
VFPenc_6A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00700,(VFPbfa_21-VFPtables)

;VQADD A1
VFPenc_6B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000010,(VFPbfa_16-VFPtables)

;VQDMLAL,VQDMLSL A1
VFPenc_6C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800900,(VFPbfa_38-VFPtables)

;VQDMLAL,VQDMLSL A2
VFPenc_6D	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800340,(VFPbfa_39-VFPtables)

;VQDMULH A1
VFPenc_6E	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000B00,(VFPbfa_1A-VFPtables)

;VQDMULH A2
VFPenc_6F	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800C40,(VFPbfa_3A-VFPtables)

;VQDMULL A1
VFPenc_70	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800D00,(VFPbfa_3B-VFPtables)

;VQDMULL A2
VFPenc_71	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800B40,(VFPbfa_3C-VFPtables)

;VQMOVN,VQMOVUN A1
VFPenc_72	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B20200,(VFPbfa_3D-VFPtables)

;VQNEG A1
VFPenc_73	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00780,(VFPbfa_21-VFPtables)

;VQRDMULH A1
VFPenc_74	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000B00,(VFPbfa_1A-VFPtables)

;VQRDMULH A2
VFPenc_75	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800D40,(VFPbfa_3A-VFPtables)

;VQRSHL A1
VFPenc_76	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000510,(VFPbfa_16-VFPtables)

;VQRSHRN,VQRSHRUN A1
VFPenc_77	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800850,(VFPbfa_3E-VFPtables)

;VQSHRN,VQSHRUN A1
VFPenc_78	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800810,(VFPbfa_3E-VFPtables)

;VQSHL (register) A1
VFPenc_79	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000410,(VFPbfa_16-VFPtables)

;VQSHL,VQSHLU (immediate) A1
VFPenc_7A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800610,(VFPbfa_3F-VFPtables)

;VQSUB A1
VFPenc_7B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000210,(VFPbfa_16-VFPtables)

;VRADDHN A1
VFPenc_7C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3800400,(VFPbfa_1B-VFPtables)

;VRSUBHN A1
VFPenc_7D	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3800600,(VFPbfa_1B-VFPtables)

;VSUBHN (integer) A1
VFPenc_7E	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800600,(VFPbfa_1B-VFPtables)

;VRECPE A1
VFPenc_7F	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B30400,(VFPbfa_40-VFPtables)

;VRECPS A1
VFPenc_80	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000F10,(VFPbfa_18-VFPtables)

;VREV A1
VFPenc_81	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00000,(VFPbfa_23-VFPtables)

;VRHADD A1
VFPenc_82	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000100,(VFPbfa_16-VFPtables)

;VRSHL A1
VFPenc_83	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000500,(VFPbfa_16-VFPtables)

;VRSHR A1
VFPenc_84	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800210,(VFPbfa_41-VFPtables)

;VRSHRN A1
VFPenc_85	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800850,(VFPbfa_42-VFPtables)

;VRSQRTE A1
VFPenc_86	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B30480,(VFPbfa_40-VFPtables)

;VRSQRTS A1
VFPenc_87	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2200F10,(VFPbfa_18-VFPtables)

;VRSRA A1
VFPenc_88	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800310,(VFPbfa_41-VFPtables)

;VSHL (immediate) A1
VFPenc_89	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800510,(VFPbfa_43-VFPtables)

;VSHL (register) A1
VFPenc_8A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000400,(VFPbfa_16-VFPtables)

;VSHLL A1
VFPenc_8B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800A10,(VFPbfa_44-VFPtables)

;VSHLL A2
VFPenc_8C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B20300,(VFPbfa_45-VFPtables)

;VSHR A1
VFPenc_8D	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800010,(VFPbfa_41-VFPtables)

;VSHRN A1
VFPenc_8E	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800810,(VFPbfa_42-VFPtables)

;VSLI A1
VFPenc_8F	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3800510,(VFPbfa_43-VFPtables)

;VSRA A1
VFPenc_90	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800110,(VFPbfa_41-VFPtables)

;VSRI A1
VFPenc_91	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3800410,(VFPbfa_46-VFPtables)

;VST (multiple) A1
VFPenc_92	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F4000000,(VFPbfa_29-VFPtables)

;VST (single one) A1
VFPenc_93	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F4800000,(VFPbfa_2A-VFPtables)

;VSUB (floating-point) A1
VFPenc_94	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2200D00,(VFPbfa_18-VFPtables)

;VSUB (integer) A1
VFPenc_95	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3000800,(VFPbfa_1A-VFPtables)

;VSUBL,VSUBW A1
VFPenc_96	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2800200,(VFPbfa_1C-VFPtables)

;VSWP A1
VFPenc_97	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B20000,(VFPbfa_21-VFPtables)

;VTBL,VTBX A1
VFPenc_98	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B00800,(VFPbfa_47-VFPtables)

;VTRN A1
VFPenc_99	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B20080,(VFPbfa_21-VFPtables)

;VTST A1
VFPenc_9A	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000810,(VFPbfa_1A-VFPtables)

;VUZP A1
VFPenc_9B	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B20100,(VFPbfa_21-VFPtables)

;VZIP A1
VFPenc_9C	VFP_Encoding (VFP_Enc_Flag_SIMDv1+VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F3B20180,(VFPbfa_21-VFPtables)

;VFMA,VFMS A1
VFPenc_9D	VFP_Encoding (VFP_Enc_Flag_SIMDv2),0
		VFP_BitFieldRecord &F2000C10,(VFPbfa_1D-VFPtables)

;VMAXNM,VMINNM A1
VFPenc_9E	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &F3000F10,(VFPbfa_48-VFPtables)

;VCVTA/M/N/P (SIMD) A1
VFPenc_9F	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &F3B30000,(VFPbfa_49-VFPtables)

;VRINTA/M/N/P/X/Z (SIMD) A1
VFPenc_A0	VFP_Encoding (VFP_Enc_Flag_ARMv8),0
		VFP_BitFieldRecord &F3B20400,(VFPbfa_4A-VFPtables)

;Pattern Definitions
VFPpat_00	VFP_Pattern "VDIV{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_01	VFP_Pattern "VDIV{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_02	VFP_Pattern "VSQRT{<c>}.<dt> <Dd>,<Dm>"
VFPpat_03	VFP_Pattern "VSQRT{<c>}.<dt> <Sd>,<Sm>"
VFPpat_04	VFP_Pattern "VAND.<dt> <Qd>,<#-32>"
VFPpat_05	VFP_Pattern "VAND.<dt> <Dd>,<#-32>"
VFPpat_06	VFP_Pattern "VBIC.<dt> <Qd>,<#32>"
VFPpat_07	VFP_Pattern "VBIC.<dt> <Dd>,<#32>"
VFPpat_08	VFP_Pattern "VAND{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_09	VFP_Pattern "VAND{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_0A	VFP_Pattern "VBIC{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_0B	VFP_Pattern "VBIC{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_0C	VFP_Pattern "VORR{.<dt>} <Qd>,<#32>"
VFPpat_0D	VFP_Pattern "VORR{.<dt>} <Dd>,<#32>"
VFPpat_0E	VFP_Pattern "VORN{.<dt>} <Qd>,<#-32>"
VFPpat_0F	VFP_Pattern "VORN{.<dt>} <Dd>,<#-32>"
VFPpat_10	VFP_Pattern "VORR{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_11	VFP_Pattern "VORR{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_12	VFP_Pattern "VORN{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_13	VFP_Pattern "VORN{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_14	VFP_Pattern "VTST.<size> <Qd>,<Qn>,<Qm>"
VFPpat_15	VFP_Pattern "VTST.<size> <Dd>,<Dn>,<Dm>"
VFPpat_16	VFP_Pattern "VMUL.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_17	VFP_Pattern "VMUL.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_18	VFP_Pattern "VMUL{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_19	VFP_Pattern "VMUL{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1A	VFP_Pattern "VMLA.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_1B	VFP_Pattern "VMLA.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1C	VFP_Pattern "VMLAL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_1D	VFP_Pattern "VMLS.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_1E	VFP_Pattern "VMLS.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1F	VFP_Pattern "VMLSL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_20	VFP_Pattern "VMUL.<dt> <Qd>,<Qn>,<Dm[x]7>"
VFPpat_21	VFP_Pattern "VMUL.<dt> <Qd>,<Qn>,<Dm[x]F>"
VFPpat_22	VFP_Pattern "VMUL.<dt> <Dd>,<Dn>,<Dm[x]7>"
VFPpat_23	VFP_Pattern "VMUL.<dt> <Dd>,<Dn>,<Dm[x]F>"
VFPpat_24	VFP_Pattern "VMULL.<dt> <Qd>,<Dn>,<Dm[x]7>"
VFPpat_25	VFP_Pattern "VMULL.<dt> <Qd>,<Dn>,<Dm[x]F>"
VFPpat_26	VFP_Pattern "VMUL.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_27	VFP_Pattern "VMUL.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_28	VFP_Pattern "VMUL.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_29	VFP_Pattern "VMUL.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_2A	VFP_Pattern "VMULL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_2B	VFP_Pattern "VMULL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_2C	VFP_Pattern "VADD.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_2D	VFP_Pattern "VADD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_2E	VFP_Pattern "VADDHN.<dt> <Dd>,<Qn>,<Qm>"
VFPpat_2F	VFP_Pattern "VADDL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_30	VFP_Pattern "VADDW.<dt> <Qd>,<Qn>,<Dm>"
VFPpat_31	VFP_Pattern "VADD.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_32	VFP_Pattern "VADD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_33	VFP_Pattern "VADD{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_34	VFP_Pattern "VADD{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_35	VFP_Pattern "VSUB.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_36	VFP_Pattern "VSUB.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_37	VFP_Pattern "VSUB{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_38	VFP_Pattern "VSUB{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_39	VFP_Pattern "VABS.<dt> <Qd>,<Qm>"
VFPpat_3A	VFP_Pattern "VABS.<dt> <Dd>,<Dm>"
VFPpat_3B	VFP_Pattern "VABS{<c>}.<dt> <Dd>,<Dm>"
VFPpat_3C	VFP_Pattern "VABS{<c>}.<dt> <Sd>,<Sm>"
VFPpat_3D	VFP_Pattern "VMOVL{<c>}.<dt> <Qd>,<Dm>"
VFPpat_3E	VFP_Pattern "VMOVN{<c>}.<dt> <Dd>,<Qm>"
VFPpat_3F	VFP_Pattern "VMOV{<c>}{.<dt>} <Qd>,<#32>"
VFPpat_40	VFP_Pattern "VMOV{<c>}{.<dt>} <Dd>,<#32>"
VFPpat_41	VFP_Pattern "VMOV{<c>}.<dt> <Dd>,<#32>"
VFPpat_42	VFP_Pattern "VMOV{<c>}.<dt> <Sd>,<#32>"
VFPpat_43	VFP_Pattern "VMOV{<c>}.<dt> <Dd>,<Dm>"
VFPpat_44	VFP_Pattern "VMOV{<c>}.<dt> <Sd>,<Sm>"
VFPpat_45	VFP_Pattern "VMOV{<c>}{.<size>} <Qd>,<Qm>"
VFPpat_46	VFP_Pattern "VMOV{<c>}{.<size>} <Dd>,<Dm>"
VFPpat_47	VFP_Pattern "VMOV{<c>}.<size> <Dd[x]>,<Rt>"
VFPpat_48	VFP_Pattern "VMOV{<c>} <Sm>,<Sn>,<Rt>,<Ru>"
VFPpat_49	VFP_Pattern "VMOV{<c>} <Sn>,<Rt>"
VFPpat_4A	VFP_Pattern "VMOV{<c>} <Dm>,<Rt>,<Ru>"
VFPpat_4B	VFP_Pattern "VMOV{<c>}.<dt> <Rt>,<Dn[x]>"
VFPpat_4C	VFP_Pattern "VMOV{<c>}.<dt> <Rt>,<Dn[x]>"
VFPpat_4D	VFP_Pattern "VMOV{<c>}.<dt> <Rt>,<Dn[x]>"
VFPpat_4E	VFP_Pattern "VMOV{<c>}.<dt> <Rt>,<Dn[x]>"
VFPpat_4F	VFP_Pattern "VMOV{<c>}.<size> <Rt>,<Dn[x]>"
VFPpat_50	VFP_Pattern "VMOV{<c>} <Rt>,<Sn>"
VFPpat_51	VFP_Pattern "VMOV{<c>} <Rt>,<Ru>,<Sm>,<Sn>"
VFPpat_52	VFP_Pattern "VMOV{<c>} <Rt>,<Ru>,<Dm>"
VFPpat_53	VFP_Pattern "VMVN{.<size>} <Qd>,<Qm>"
VFPpat_54	VFP_Pattern "VMVN{.<size>} <Dd>,<Dm>"
VFPpat_55	VFP_Pattern "VMVN{.<dt>} <Qd>,<#32>"
VFPpat_56	VFP_Pattern "VMVN{.<dt>} <Dd>,<#32>"
VFPpat_57	VFP_Pattern "VMSR{<c>} <spec>,APSR_nzcv"
VFPpat_58	VFP_Pattern "VMSR{<c>} <spec>,APSR_f"
VFPpat_59	VFP_Pattern "VMRS{<c>} APSR_nzcv,<spec>"
VFPpat_5A	VFP_Pattern "VMRS{<c>} APSR_f,<spec>"
VFPpat_5B	VFP_Pattern "VMSR{<c>} <spec>,<Rt>"
VFPpat_5C	VFP_Pattern "VMRS{<c>} <Rt>,<spec>"
VFPpat_5D	VFP_Pattern "VCMP{<c>}.<dt> <Dd>,<Dm>"
VFPpat_5E	VFP_Pattern "VCMPE{<c>}.<dt> <Dd>,<Dm>"
VFPpat_5F	VFP_Pattern "VCMP{<c>}.<dt> <Sd>,<Sm>"
VFPpat_60	VFP_Pattern "VCMPE{<c>}.<dt> <Sd>,<Sm>"
VFPpat_61	VFP_Pattern "VCMP{<c>}.<dt> <Dd>,#0{.0}"
VFPpat_62	VFP_Pattern "VCMPE{<c>}.<dt> <Dd>,#0{.0}"
VFPpat_63	VFP_Pattern "VCMP{<c>}.<dt> <Sd>,#0{.0}"
VFPpat_64	VFP_Pattern "VCMPE{<c>}.<dt> <Sd>,#0{.0}"
VFPpat_65	VFP_Pattern "VCEQ.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_66	VFP_Pattern "VCEQ.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_67	VFP_Pattern "VCEQ.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_68	VFP_Pattern "VCEQ.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_69	VFP_Pattern "VCGE.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_6A	VFP_Pattern "VCGE.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_6B	VFP_Pattern "VCGE.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_6C	VFP_Pattern "VCGE.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_6D	VFP_Pattern "VCGT.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_6E	VFP_Pattern "VCGT.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_6F	VFP_Pattern "VCGT.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_70	VFP_Pattern "VCGT.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_71	VFP_Pattern "VCLE.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_72	VFP_Pattern "VCLE.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_73	VFP_Pattern "VCLE.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_74	VFP_Pattern "VCLE.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_75	VFP_Pattern "VCLT.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_76	VFP_Pattern "VCLT.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_77	VFP_Pattern "VCLT.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_78	VFP_Pattern "VCLT.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_79	VFP_Pattern "VCEQ.<dt> <Qd>,<Qm>,#0"
VFPpat_7A	VFP_Pattern "VCEQ.<dt> <Dd>,<Dm>,#0"
VFPpat_7B	VFP_Pattern "VCGE.<dt> <Qd>,<Qm>,#0"
VFPpat_7C	VFP_Pattern "VCGE.<dt> <Dd>,<Dm>,#0"
VFPpat_7D	VFP_Pattern "VCGT.<dt> <Qd>,<Qm>,#0"
VFPpat_7E	VFP_Pattern "VCGT.<dt> <Dd>,<Dm>,#0"
VFPpat_7F	VFP_Pattern "VCLE.<dt> <Qd>,<Qm>,#0"
VFPpat_80	VFP_Pattern "VCLE.<dt> <Dd>,<Dm>,#0"
VFPpat_81	VFP_Pattern "VCLT.<dt> <Qd>,<Qm>,#0"
VFPpat_82	VFP_Pattern "VCLT.<dt> <Dd>,<Dm>,#0"
VFPpat_83	VFP_Pattern "VCVT{<c>}.S32.<dt> <Sd>,<Dm>"
VFPpat_84	VFP_Pattern "VCVT{<c>}.S32.<dt> <Sd>,<Sm>"
VFPpat_85	VFP_Pattern "VCVTR{<c>}.S32.<dt> <Sd>,<Dm>"
VFPpat_86	VFP_Pattern "VCVTR{<c>}.S32.<dt> <Sd>,<Sm>"
VFPpat_87	VFP_Pattern "VCVT{<c>}.U32.<dt> <Sd>,<Dm>"
VFPpat_88	VFP_Pattern "VCVT{<c>}.U32.<dt> <Sd>,<Sm>"
VFPpat_89	VFP_Pattern "VCVTR{<c>}.U32.<dt> <Sd>,<Dm>"
VFPpat_8A	VFP_Pattern "VCVTR{<c>}.U32.<dt> <Sd>,<Sm>"
VFPpat_8B	VFP_Pattern "VCVT{<c>}.<dt>.S32 <Dd>,<Sm>"
VFPpat_8C	VFP_Pattern "VCVT{<c>}.<dt>.U32 <Dd>,<Sm>"
VFPpat_8D	VFP_Pattern "VCVT{<c>}.<dt>.S32 <Sd>,<Sm>"
VFPpat_8E	VFP_Pattern "VCVT{<c>}.<dt>.U32 <Sd>,<Sm>"
VFPpat_8F	VFP_Pattern "VCVT{<c>}.F64.<dt> <Dd>,<Sm>"
VFPpat_90	VFP_Pattern "VCVT{<c>}.F32.<dt> <Sd>,<Dm>"
VFPpat_91	VFP_Pattern "VCVT.<dt>.F32 <Qd>,<Qm>,<#c>"
VFPpat_92	VFP_Pattern "VCVT.<dt>.F32 <Dd>,<Dm>,<#c>"
VFPpat_93	VFP_Pattern "VCVT.F32.<dt> <Qd>,<Qm>,<#c>"
VFPpat_94	VFP_Pattern "VCVT.F32.<dt> <Dd>,<Dm>,<#c>"
VFPpat_95	VFP_Pattern "VCVT{<c>}.F64.<dt> <Dd>,<#f>"
VFPpat_96	VFP_Pattern "VCVT{<c>}.F32.<dt> <Sd>,<#f>"
VFPpat_97	VFP_Pattern "VCVT{<c>}.<dt>.F64 <Dd>,<#f>"
VFPpat_98	VFP_Pattern "VCVT{<c>}.<dt>.F32 <Sd>,<#f>"
VFPpat_99	VFP_Pattern "VCVT.S32.<dt> <Qd>,<Qm>"
VFPpat_9A	VFP_Pattern "VCVT.S32.<dt> <Dd>,<Dm>"
VFPpat_9B	VFP_Pattern "VCVT.U32.<dt> <Qd>,<Qm>"
VFPpat_9C	VFP_Pattern "VCVT.U32.<dt> <Dd>,<Dm>"
VFPpat_9D	VFP_Pattern "VCVT.<dt>.S32 <Qd>,<Qm>"
VFPpat_9E	VFP_Pattern "VCVT.<dt>.S32 <Dd>,<Dm>"
VFPpat_9F	VFP_Pattern "VCVT.<dt>.U32 <Qd>,<Qm>"
VFPpat_A0	VFP_Pattern "VCVT.<dt>.U32 <Dd>,<Dm>"
VFPpat_A1	VFP_Pattern "VCVTB{<c>}.F16.F32 <Sd>,<Sm>"
VFPpat_A2	VFP_Pattern "VCVTB{<c>}.F32.F16 <Sd>,<Sm>"
VFPpat_A3	VFP_Pattern "VCVTT{<c>}.F16.F32 <Sd>,<Sm>"
VFPpat_A4	VFP_Pattern "VCVTT{<c>}.F32.F16 <Sd>,<Sm>"
VFPpat_A5	VFP_Pattern "VLD1.<size> (<Dd>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_A6	VFP_Pattern "VLD1.<size> (<Dd>{,|-}<Dd+1>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_A7	VFP_Pattern "VLD1.<size> (<Dd>{,<Dd+1>,|-}<Dd+2>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_A8	VFP_Pattern "VLD1.<size> (<Dd>{,<Dd+1>,<Dd+2>,|-}<Dd+3>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_A9	VFP_Pattern "VST1.<size> (<Dd>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_AA	VFP_Pattern "VST1.<size> (<Dd>{,|-}<Dd+1>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_AB	VFP_Pattern "VST1.<size> (<Dd>{,<Dd+1>,|-}<Dd+2>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_AC	VFP_Pattern "VST1.<size> (<Dd>{,<Dd+1>,<Dd+2>,|-}<Dd+3>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_AD	VFP_Pattern "VLD2.<size> (<Dd>{,|-}<Dd+1>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_AE	VFP_Pattern "VLD2.<size> (<Dd>,<Dd+2>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_AF	VFP_Pattern "VLD2.<size> (<Dd>{,<Dd+1>,<Dd+2>,|-}<Dd+3>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B0	VFP_Pattern "VST2.<size> (<Dd>{,|-}<Dd+1>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B1	VFP_Pattern "VST2.<size> (<Dd>,<Dd+2>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B2	VFP_Pattern "VST2.<size> (<Dd>{,<Dd+1>,<Dd+2>,|-}<Dd+3>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B3	VFP_Pattern "VLD3.<size> (<Dd>{,<Dd+1>,|-}<Dd+2>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B4	VFP_Pattern "VLD3.<size> (<Dd>,<Dd+2>,<Dd+4>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B5	VFP_Pattern "VST3.<size> (<Dd>{,<Dd+1>,|-}<Dd+2>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B6	VFP_Pattern "VST3.<size> (<Dd>,<Dd+2>,<Dd+4>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B7	VFP_Pattern "VLD4.<size> (<Dd>{,<Dd+1>,<Dd+2>,|-}<Dd+3>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B8	VFP_Pattern "VLD4.<size> (<Dd>,<Dd+2>,<Dd+4>,<Dd+6>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_B9	VFP_Pattern "VST4.<size> (<Dd>{,<Dd+1>,<Dd+2>,|-}<Dd+3>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_BA	VFP_Pattern "VST4.<size> (<Dd>,<Dd+2>,<Dd+4>,<Dd+6>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_BB	VFP_Pattern "VLD1.<size> (<Dd[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_BC	VFP_Pattern "VST1.<size> (<Dd[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_BD	VFP_Pattern "VLD2.<size> (<Dd[x]>{,|-}<Dd+1[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_BE	VFP_Pattern "VST2.<size> (<Dd[x]>{,|-}<Dd+1[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_BF	VFP_Pattern "VLD2.<size> (<Dd[x]>,<Dd+2[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_C0	VFP_Pattern "VST2.<size> (<Dd[x]>,<Dd+2[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_C1	VFP_Pattern "VLD3.<size> (<Dd[x]>{,<Dd+1[x]>,|-}<Dd+2[x]>),[<Rn>]<!>{,<Rm>}"
VFPpat_C2	VFP_Pattern "VST3.<size> (<Dd[x]>{,<Dd+1[x]>,|-}<Dd+2[x]>),[<Rn>]<!>{,<Rm>}"
VFPpat_C3	VFP_Pattern "VLD3.<size> (<Dd[x]>,<Dd+2[x]>,<Dd+4[x]>),[<Rn>]<!>{,<Rm>}"
VFPpat_C4	VFP_Pattern "VST3.<size> (<Dd[x]>,<Dd+2[x]>,<Dd+4[x]>),[<Rn>]<!>{,<Rm>}"
VFPpat_C5	VFP_Pattern "VLD4.<size> (<Dd[x]>{,<Dd+1[x]>,<Dd+2[x]>,|-}<Dd+3[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_C6	VFP_Pattern "VST4.<size> (<Dd[x]>{,<Dd+1[x]>,<Dd+2[x]>,|-}<Dd+3[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_C7	VFP_Pattern "VLD4.<size> (<Dd[x]>,<Dd+2[x]>,<Dd+4[x]>,<Dd+6[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_C8	VFP_Pattern "VST4.<size> (<Dd[x]>,<Dd+2[x]>,<Dd+4[x]>,<Dd+6[x]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_C9	VFP_Pattern "VLD1.<size> (<Dd[]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_CA	VFP_Pattern "VLD1.<size> (<Dd[]>{,|-}<Dd+1[]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_CB	VFP_Pattern "VLD2.<size> (<Dd[]>{,|-}<Dd+1[]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_CC	VFP_Pattern "VLD2.<size> (<Dd[]>,<Dd+2[]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_CD	VFP_Pattern "VLD3.<size> (<Dd[]>{,<Dd+1[]>,|-}<Dd+2[]>),[<Rn>]<!>{,<Rm>}"
VFPpat_CE	VFP_Pattern "VLD3.<size> (<Dd[]>,<Dd+2[]>,<Dd+4[]>),[<Rn>}]<!>{,<Rm>}"
VFPpat_CF	VFP_Pattern "VLD4.<size> (<Dd[]>{,<Dd+1[]>,<Dd+2[]>,|-}<Dd+3[]>),[<Rn>@128]<!>{,<Rm>}"
VFPpat_D0	VFP_Pattern "VLD4.<size> (<Dd[]>{,<Dd+1[]>,<Dd+2[]>,|-}<Dd+3[]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_D1	VFP_Pattern "VLD4.<size> (<Dd[]>,<Dd+2[]>,<Dd+4[]>,<Dd+6[]>),[<Rn>@128]<!>{,<Rm>}"
VFPpat_D2	VFP_Pattern "VLD4.<size> (<Dd[]>,<Dd+2[]>,<Dd+4[]>,<Dd+6[]>),[<Rn>{<@>}]<!>{,<Rm>}"
VFPpat_D3	VFP_Pattern "VLDMIA{<c>}{.64} <Rn><!>,(<Dd>{-<Dd->}{,<Dd+?>}~)"
VFPpat_D4	VFP_Pattern "VLDMDB{<c>}{.64} <Rn>!,(<Dd>{-<Dd->}{,<Dd+?>}~)"
VFPpat_D5	VFP_Pattern "VLDMIA{<c>}{.32} <Rn><!>,(<Sd>{-<Sd->}{,<Sd+?>}~)"
VFPpat_D6	VFP_Pattern "VLDMDB{<c>}{.32} <Rn>!,(<Sd>{-<Sd->}{,<Sd+?>}~)"
VFPpat_D7	VFP_Pattern "VSTMIA{<c>}{.64} <Rn><!>,(<Dd>{-<Dd->}{,<Dd+?>}~)"
VFPpat_D8	VFP_Pattern "VSTMDB{<c>}{.64} <Rn>!,(<Dd>{-<Dd->}{,<Dd+?>}~)"
VFPpat_D9	VFP_Pattern "VSTMIA{<c>}{.32} <Rn><!>,(<Sd>{-<Sd->}{,<Sd+?>}~)"
VFPpat_DA	VFP_Pattern "VSTMDB{<c>}{.32} <Rn>!,(<Sd>{-<Sd->}{,<Sd+?>}~)"
VFPpat_DB	VFP_Pattern "VPUSH{<c>} (<Dd>{-<Dd->}{,<Dd+?>}~)"
VFPpat_DC	VFP_Pattern "VPUSH{<c>} (<Sd>{-<Sd->}{,<Sd+?>}~)"
VFPpat_DD	VFP_Pattern "VPOP{<c>} (<Dd>{-<Dd->}{,<Dd+?>}~)"
VFPpat_DE	VFP_Pattern "VPOP{<c>} (<Sd>{-<Sd->}{,<Sd+?>}~)"
VFPpat_DF	VFP_Pattern "VLDR{<c>} <Dd>,[<Rn>{,<#+-10>}]"
VFPpat_E0	VFP_Pattern "VLDR{<c>} <Dd>,<lbl>"
VFPpat_E1	VFP_Pattern "VLDR{<c>} <Sd>,[<Rn>{,<#+-10>}]"
VFPpat_E2	VFP_Pattern "VLDR{<c>} <Sd>,<lbl>"
VFPpat_E3	VFP_Pattern "VSTR{<c>} <Dd>,[<Rn>{,<#+-10>}]"
VFPpat_E4	VFP_Pattern "VSTR{<c>} <Dd>,<lbl>"
VFPpat_E5	VFP_Pattern "VSTR{<c>} <Sd>,[<Rn>{,<#+-10>}]"
VFPpat_E6	VFP_Pattern "VSTR{<c>} <Sd>,<lbl>"
VFPpat_E7	VFP_Pattern "VABA.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_E8	VFP_Pattern "VABA.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_E9	VFP_Pattern "VABAL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_EA	VFP_Pattern "VABD.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_EB	VFP_Pattern "VABD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_EC	VFP_Pattern "VABDL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_ED	VFP_Pattern "VABD.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_EE	VFP_Pattern "VABD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_EF	VFP_Pattern "VACGE.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_F0	VFP_Pattern "VACGE.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_F1	VFP_Pattern "VACGT.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_F2	VFP_Pattern "VACGT.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_F3	VFP_Pattern "VACLE.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_F4	VFP_Pattern "VACLE.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_F5	VFP_Pattern "VACLT.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_F6	VFP_Pattern "VACLT.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_F7	VFP_Pattern "VBIF{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_F8	VFP_Pattern "VBIF{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_F9	VFP_Pattern "VBIT{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_FA	VFP_Pattern "VBIT{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_FB	VFP_Pattern "VBSL{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_FC	VFP_Pattern "VBSL{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_FD	VFP_Pattern "VCLS.<dt> <Qd>,<Qm>"
VFPpat_FE	VFP_Pattern "VCLS.<dt> <Dd>,<Dm>"
VFPpat_FF	VFP_Pattern "VCLZ.<dt> <Qd>,<Qm>"
VFPpat_100	VFP_Pattern "VCLZ.<dt> <Dd>,<Dm>"
VFPpat_101	VFP_Pattern "VCNT.<size> <Qd>,<Qm>"
VFPpat_102	VFP_Pattern "VCNT.<size> <Dd>,<Dm>"
VFPpat_103	VFP_Pattern "VDUP.<size> <Qd>,<Dm[x]>"
VFPpat_104	VFP_Pattern "VDUP.<size> <Dd>,<Dm[x]>"
VFPpat_105	VFP_Pattern "VDUP{<c>}.<size> <Qd>,<Rt>"
VFPpat_106	VFP_Pattern "VDUP{<c>}.<size> <Dd>,<Rt>"
VFPpat_107	VFP_Pattern "VDUP.<size> <Qd>,<Dm[x]>"
VFPpat_108	VFP_Pattern "VDUP.<size> <Dd>,<Dm[x]>"
VFPpat_109	VFP_Pattern "VDUP{<c>}.<size> <Qd>,<Rt>"
VFPpat_10A	VFP_Pattern "VDUP{<c>}.<size> <Dd>,<Rt>"
VFPpat_10B	VFP_Pattern "VEOR{.<size>} <Qd>,<Qn>,<Qm>"
VFPpat_10C	VFP_Pattern "VEOR{.<size>} <Dd>,<Dn>,<Dm>"
VFPpat_10D	VFP_Pattern "VEXT.<size> <Qd>,<Qn>,<Qm>,<#4>"
VFPpat_10E	VFP_Pattern "VEXT.<size> <Dd>,<Dn>,<Dm>,<#3>"
VFPpat_10F	VFP_Pattern "VEXT.<size> <Qd>,<Qn>,<Qm>,<#3s1>"
VFPpat_110	VFP_Pattern "VEXT.<size> <Dd>,<Dn>,<Dm>,<#2s1>"
VFPpat_111	VFP_Pattern "VEXT.<size> <Qd>,<Qn>,<Qm>,<#2s2>"
VFPpat_112	VFP_Pattern "VEXT.<size> <Dd>,<Dn>,<Dm>,<#1s2>"
VFPpat_113	VFP_Pattern "VEXT.<size> <Qd>,<Qn>,<Qm>,<#1s3>"
VFPpat_114	VFP_Pattern "VHADD.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_115	VFP_Pattern "VHADD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_116	VFP_Pattern "VHSUB.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_117	VFP_Pattern "VHSUB.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_118	VFP_Pattern "VMAX.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_119	VFP_Pattern "VMAX.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_11A	VFP_Pattern "VMIN.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_11B	VFP_Pattern "VMIN.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_11C	VFP_Pattern "VMAX.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_11D	VFP_Pattern "VMAX.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_11E	VFP_Pattern "VMIN.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_11F	VFP_Pattern "VMIN.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_120	VFP_Pattern "VMLA.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_121	VFP_Pattern "VMLA.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_122	VFP_Pattern "VMLA{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_123	VFP_Pattern "VMLA{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_124	VFP_Pattern "VMLS.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_125	VFP_Pattern "VMLS.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_126	VFP_Pattern "VMLS{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_127	VFP_Pattern "VMLS{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_128	VFP_Pattern "VMLA.<dt> <Qd>,<Qn>,<Dm[x]7>"
VFPpat_129	VFP_Pattern "VMLA.<dt> <Qd>,<Qn>,<Dm[x]F>"
VFPpat_12A	VFP_Pattern "VMLA.<dt> <Dd>,<Dn>,<Dm[x]7>"
VFPpat_12B	VFP_Pattern "VMLA.<dt> <Dd>,<Dn>,<Dm[x]F>"
VFPpat_12C	VFP_Pattern "VMLAL.<dt> <Qd>,<Dn>,<Dm[x]7>"
VFPpat_12D	VFP_Pattern "VMLAL.<dt> <Qd>,<Dn>,<Dm[x]F>"
VFPpat_12E	VFP_Pattern "VMLS.<dt> <Qd>,<Qn>,<Dm[x]7>"
VFPpat_12F	VFP_Pattern "VMLS.<dt> <Qd>,<Qn>,<Dm[x]F>"
VFPpat_130	VFP_Pattern "VMLS.<dt> <Dd>,<Dn>,<Dm[x]7>"
VFPpat_131	VFP_Pattern "VMLS.<dt> <Dd>,<Dn>,<Dm[x]F>"
VFPpat_132	VFP_Pattern "VMLSL.<dt> <Qd>,<Dn>,<Dm[x]7>"
VFPpat_133	VFP_Pattern "VMLSL.<dt> <Qd>,<Dn>,<Dm[x]F>"
VFPpat_134	VFP_Pattern "VNMLA{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_135	VFP_Pattern "VNMLA{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_136	VFP_Pattern "VNMLS{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_137	VFP_Pattern "VNMLS{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_138	VFP_Pattern "VNMUL{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_139	VFP_Pattern "VNMUL{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_13A	VFP_Pattern "VNEG.<dt> <Qd>,<Qm>"
VFPpat_13B	VFP_Pattern "VNEG.<dt> <Dd>,<Dm>"
VFPpat_13C	VFP_Pattern "VNEG{<c>}.<dt> <Dd>,<Dm>"
VFPpat_13D	VFP_Pattern "VNEG{<c>}.<dt> <Sd>,<Sm>"
VFPpat_13E	VFP_Pattern "VPADAL.<dt> <Qd>,<Qm>"
VFPpat_13F	VFP_Pattern "VPADAL.<dt> <Dd>,<Dm>"
VFPpat_140	VFP_Pattern "VPADD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_141	VFP_Pattern "VPADD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_142	VFP_Pattern "VPADDL.<dt> <Qd>,<Qm>"
VFPpat_143	VFP_Pattern "VPADDL.<dt> <Dd>,<Dm>"
VFPpat_144	VFP_Pattern "VPMAX.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_145	VFP_Pattern "VPMIN.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_146	VFP_Pattern "VPMAX.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_147	VFP_Pattern "VPMIN.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_148	VFP_Pattern "VQABS.<dt> <Qd>,<Qm>"
VFPpat_149	VFP_Pattern "VQABS.<dt> <Dd>,<Dm>"
VFPpat_14A	VFP_Pattern "VQADD.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_14B	VFP_Pattern "VQADD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_14C	VFP_Pattern "VQDMLAL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_14D	VFP_Pattern "VQDMLAL.<dt> <Qd>,<Dn>,<Dm[x]7>"
VFPpat_14E	VFP_Pattern "VQDMLAL.<dt> <Qd>,<Dn>,<Dm[x]F>"
VFPpat_14F	VFP_Pattern "VQDMLSL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_150	VFP_Pattern "VQDMLSL.<dt> <Qd>,<Dn>,<Dm[x]7>"
VFPpat_151	VFP_Pattern "VQDMLSL.<dt> <Qd>,<Dn>,<Dm[x]F>"
VFPpat_152	VFP_Pattern "VQDMULH.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_153	VFP_Pattern "VQDMULH.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_154	VFP_Pattern "VQDMULH.<dt> <Qd>,<Qn>,<Dm[x]>"
VFPpat_155	VFP_Pattern "VQDMULH.<dt> <Qd>,<Qn>,<Dm[x]>"
VFPpat_156	VFP_Pattern "VQDMULH.<dt> <Dd>,<Dn>,<Dm[x]>"
VFPpat_157	VFP_Pattern "VQDMULH.<dt> <Dd>,<Dn>,<Dm[x]>"
VFPpat_158	VFP_Pattern "VQDMULL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_159	VFP_Pattern "VQDMULL.<dt> <Qd>,<Dn>,<Dm[x]>"
VFPpat_15A	VFP_Pattern "VQDMULL.<dt> <Qd>,<Dn>,<Dm[x]>"
VFPpat_15B	VFP_Pattern "VQMOVN.<dt> <Dd>,<Qm>"
VFPpat_15C	VFP_Pattern "VQMOVN.<dt> <Dd>,<Qm>"
VFPpat_15D	VFP_Pattern "VQMOVUN.<dt> <Dd>,<Qm>"
VFPpat_15E	VFP_Pattern "VQNEG.<dt> <Qd>,<Qm>"
VFPpat_15F	VFP_Pattern "VQNEG.<dt> <Dd>,<Dm>"
VFPpat_160	VFP_Pattern "VQRDMULH.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_161	VFP_Pattern "VQRDMULH.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_162	VFP_Pattern "VQRDMULH.<dt> <Qd>,<Qn>,<Dm[x]>"
VFPpat_163	VFP_Pattern "VQRDMULH.<dt> <Qd>,<Qn>,<Dm[x]>"
VFPpat_164	VFP_Pattern "VQRDMULH.<dt> <Dd>,<Dn>,<Dm[x]>"
VFPpat_165	VFP_Pattern "VQRDMULH.<dt> <Dd>,<Dn>,<Dm[x]>"
VFPpat_166	VFP_Pattern "VQRSHL.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_167	VFP_Pattern "VQRSHL.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_168	VFP_Pattern "VQRSHRN.<dt> <Dd>,<Qm>,<#e>"
VFPpat_169	VFP_Pattern "VQRSHRUN.<dt> <Dd>,<Qm>,<#e>"
VFPpat_16A	VFP_Pattern "VQSHRN.<dt> <Dd>,<Qm>,<#e>"
VFPpat_16B	VFP_Pattern "VQSHRUN.<dt> <Dd>,<Qm>,<#e>"
VFPpat_16C	VFP_Pattern "VQSHL.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_16D	VFP_Pattern "VQSHL.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_16E	VFP_Pattern "VQSHL.<dt> <Qd>,<Qm>,<#g>"
VFPpat_16F	VFP_Pattern "VQSHL.<dt> <Dd>,<Dm>,<#g>"
VFPpat_170	VFP_Pattern "VQSHLU.<dt> <Qd>,<Qm>,<#g>"
VFPpat_171	VFP_Pattern "VQSHLU.<dt> <Dd>,<Dm>,<#g>"
VFPpat_172	VFP_Pattern "VQSUB.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_173	VFP_Pattern "VQSUB.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_174	VFP_Pattern "VRADDHN.<dt> <Dd>,<Qn>,<Qm>"
VFPpat_175	VFP_Pattern "VRSUBHN.<dt> <Dd>,<Qn>,<Qm>"
VFPpat_176	VFP_Pattern "VSUBHN.<dt> <Dd>,<Qn>,<Qm>"
VFPpat_177	VFP_Pattern "VRECPE.<dt> <Qd>,<Qm>"
VFPpat_178	VFP_Pattern "VRECPE.<dt> <Dd>,<Dm>"
VFPpat_179	VFP_Pattern "VRECPS.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_17A	VFP_Pattern "VRECPS.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_17B	VFP_Pattern "VREV16.<size> <Qd>,<Qm>"
VFPpat_17C	VFP_Pattern "VREV16.<size> <Dd>,<Dm>"
VFPpat_17D	VFP_Pattern "VREV32.<size> <Qd>,<Qm>"
VFPpat_17E	VFP_Pattern "VREV32.<size> <Dd>,<Dm>"
VFPpat_17F	VFP_Pattern "VREV64.<size> <Qd>,<Qm>"
VFPpat_180	VFP_Pattern "VREV64.<size> <Dd>,<Dm>"
VFPpat_181	VFP_Pattern "VRHADD.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_182	VFP_Pattern "VRHADD.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_183	VFP_Pattern "VRSHL.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_184	VFP_Pattern "VRSHL.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_185	VFP_Pattern "VRSHR.<dt> <Qd>,<Qm>,<#d>"
VFPpat_186	VFP_Pattern "VRSHR.<dt> <Dd>,<Dm>,<#d>"
VFPpat_187	VFP_Pattern "VRSHRN.<size> <Dd>,<Qm>,<#e>"
VFPpat_188	VFP_Pattern "VRSQRTE.<dt> <Qd>,<Qm>"
VFPpat_189	VFP_Pattern "VRSQRTE.<dt> <Dd>,<Dm>"
VFPpat_18A	VFP_Pattern "VRSQRTS.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_18B	VFP_Pattern "VRSQRTS.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_18C	VFP_Pattern "VRSRA.<dt> <Qd>,<Qm>,<#d>"
VFPpat_18D	VFP_Pattern "VRSRA.<dt> <Dd>,<Dm>,<#d>"
VFPpat_18E	VFP_Pattern "VSHL.<dt> <Qd>,<Qm>,<#g>"
VFPpat_18F	VFP_Pattern "VSHL.<dt> <Dd>,<Dm>,<#g>"
VFPpat_190	VFP_Pattern "VSHL.<dt> <Qd>,<Qm>,<Qn>"
VFPpat_191	VFP_Pattern "VSHL.<dt> <Dd>,<Dm>,<Dn>"
VFPpat_192	VFP_Pattern "VSHLL.<dt> <Qd>,<Dm>,#8"
VFPpat_193	VFP_Pattern "VSHLL.<dt> <Qd>,<Dm>,#16"
VFPpat_194	VFP_Pattern "VSHLL.<dt> <Qd>,<Dm>,#32"
VFPpat_195	VFP_Pattern "VSHLL.<dt> <Qd>,<Dm>,<#h>"
VFPpat_196	VFP_Pattern "VSHR.<dt> <Qd>,<Qm>,<#d>"
VFPpat_197	VFP_Pattern "VSHR.<dt> <Dd>,<Dm>,<#d>"
VFPpat_198	VFP_Pattern "VSHRN.<dt> <Dd>,<Qm>,<#e>"
VFPpat_199	VFP_Pattern "VSLI.<size> <Qd>,<Qm>,<#g>"
VFPpat_19A	VFP_Pattern "VSLI.<size> <Dd>,<Dm>,<#g>"
VFPpat_19B	VFP_Pattern "VSRA.<dt> <Qd>,<Qm>,<#d>"
VFPpat_19C	VFP_Pattern "VSRA.<dt> <Dd>,<Dm>,<#d>"
VFPpat_19D	VFP_Pattern "VSRI.<size> <Qd>,<Qm>,<#d>"
VFPpat_19E	VFP_Pattern "VSRI.<size> <Dd>,<Dm>,<#d>"
VFPpat_19F	VFP_Pattern "VSUB.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_1A0	VFP_Pattern "VSUB.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1A1	VFP_Pattern "VSUBL.<dt> <Qd>,<Dn>,<Dm>"
VFPpat_1A2	VFP_Pattern "VSUBW.<dt> <Qd>,<Qn>,<Dm>"
VFPpat_1A3	VFP_Pattern "VSWP{.<size>} <Qd>,<Qm>"
VFPpat_1A4	VFP_Pattern "VSWP{.<size>} <Dd>,<Dm>"
VFPpat_1A5	VFP_Pattern "VTBL.<size> <Dd>,(<Dn>),<Dm>"
VFPpat_1A6	VFP_Pattern "VTBL.<size> <Dd>,(<Dn>{,|-}<Dn+1>),<Dm>"
VFPpat_1A7	VFP_Pattern "VTBL.<size> <Dd>,(<Dn>{,<Dn+1>,|-}<Dn+2>),<Dm>"
VFPpat_1A8	VFP_Pattern "VTBL.<size> <Dd>,(<Dn>{,<Dn+1>,<Dn+2>,|-}<Dn+3>),<Dm>"
VFPpat_1A9	VFP_Pattern "VTBX.<size> <Dd>,(<Dn>),<Dm>"
VFPpat_1AA	VFP_Pattern "VTBX.<size> <Dd>,(<Dn>{,|-}<Dn+1>),<Dm>"
VFPpat_1AB	VFP_Pattern "VTBX.<size> <Dd>,(<Dn>{,<Dn+1>,|-}<Dn+2>),<Dm>"
VFPpat_1AC	VFP_Pattern "VTBX.<size> <Dd>,(<Dn>{,<Dn+1>,<Dn+2>,|-}<Dn+3>),<Dm>"
VFPpat_1AD	VFP_Pattern "VTRN.<size> <Qd>,<Qm>"
VFPpat_1AE	VFP_Pattern "VTRN.<size> <Dd>,<Dm>"
VFPpat_1AF	VFP_Pattern "VUZP.<size> <Qd>,<Qm>"
VFPpat_1B0	VFP_Pattern "VUZP.<size> <Dd>,<Dm>"
VFPpat_1B1	VFP_Pattern "VZIP.<size> <Qd>,<Qm>"
VFPpat_1B2	VFP_Pattern "VZIP.<size> <Dd>,<Dm>"
VFPpat_1B3	VFP_Pattern "VFMA.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_1B4	VFP_Pattern "VFMS.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_1B5	VFP_Pattern "VFMA.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1B6	VFP_Pattern "VFMS.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1B7	VFP_Pattern "VFMA{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1B8	VFP_Pattern "VFMS{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1B9	VFP_Pattern "VFMA{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1BA	VFP_Pattern "VFMS{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1BB	VFP_Pattern "VFNMA{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1BC	VFP_Pattern "VFNMS{<c>}.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1BD	VFP_Pattern "VFNMA{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1BE	VFP_Pattern "VFNMS{<c>}.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1BF	VFP_Pattern "VSELEQ.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1C0	VFP_Pattern "VSELEQ.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1C1	VFP_Pattern "VSELGE.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1C2	VFP_Pattern "VSELGE.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1C3	VFP_Pattern "VSELGT.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1C4	VFP_Pattern "VSELGT.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1C5	VFP_Pattern "VSELVS.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1C6	VFP_Pattern "VSELVS.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1C7	VFP_Pattern "VMAXNM.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1C8	VFP_Pattern "VMAXNM.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1C9	VFP_Pattern "VMINNM.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1CA	VFP_Pattern "VMINNM.<dt> <Sd>,<Sn>,<Sm>"
VFPpat_1CB	VFP_Pattern "VCVTA.S32.<dt> <Sd>,<Dm>"
VFPpat_1CC	VFP_Pattern "VCVTA.S32.<dt> <Sd>,<Sm>"
VFPpat_1CD	VFP_Pattern "VCVTA.U32.<dt> <Sd>,<Dm>"
VFPpat_1CE	VFP_Pattern "VCVTA.U32.<dt> <Sd>,<Sm>"
VFPpat_1CF	VFP_Pattern "VCVTN.S32.<dt> <Sd>,<Dm>"
VFPpat_1D0	VFP_Pattern "VCVTN.S32.<dt> <Sd>,<Sm>"
VFPpat_1D1	VFP_Pattern "VCVTN.U32.<dt> <Sd>,<Dm>"
VFPpat_1D2	VFP_Pattern "VCVTN.U32.<dt> <Sd>,<Sm>"
VFPpat_1D3	VFP_Pattern "VCVTP.S32.<dt> <Sd>,<Dm>"
VFPpat_1D4	VFP_Pattern "VCVTP.S32.<dt> <Sd>,<Sm>"
VFPpat_1D5	VFP_Pattern "VCVTP.U32.<dt> <Sd>,<Dm>"
VFPpat_1D6	VFP_Pattern "VCVTP.U32.<dt> <Sd>,<Sm>"
VFPpat_1D7	VFP_Pattern "VCVTM.S32.<dt> <Sd>,<Dm>"
VFPpat_1D8	VFP_Pattern "VCVTM.S32.<dt> <Sd>,<Sm>"
VFPpat_1D9	VFP_Pattern "VCVTM.U32.<dt> <Sd>,<Dm>"
VFPpat_1DA	VFP_Pattern "VCVTM.U32.<dt> <Sd>,<Sm>"
VFPpat_1DB	VFP_Pattern "VRINTA.F64.<dt> <Dd>,<Dm>"
VFPpat_1DC	VFP_Pattern "VRINTA.F32.<dt> <Sd>,<Sm>"
VFPpat_1DD	VFP_Pattern "VRINTN.F64.<dt> <Dd>,<Dm>"
VFPpat_1DE	VFP_Pattern "VRINTN.F32.<dt> <Sd>,<Sm>"
VFPpat_1DF	VFP_Pattern "VRINTP.F64.<dt> <Dd>,<Dm>"
VFPpat_1E0	VFP_Pattern "VRINTP.F32.<dt> <Sd>,<Sm>"
VFPpat_1E1	VFP_Pattern "VRINTM.F64.<dt> <Dd>,<Dm>"
VFPpat_1E2	VFP_Pattern "VRINTM.F32.<dt> <Sd>,<Sm>"
VFPpat_1E3	VFP_Pattern "VRINTR{<c>}.F64.<dt> <Dd>,<Dm>"
VFPpat_1E4	VFP_Pattern "VRINTR{<c>}.F32.<dt> <Sd>,<Sm>"
VFPpat_1E5	VFP_Pattern "VRINTZ{<c>}.F64.<dt> <Dd>,<Dm>"
VFPpat_1E6	VFP_Pattern "VRINTZ{<c>}.F32.<dt> <Sd>,<Sm>"
VFPpat_1E7	VFP_Pattern "VRINTX{<c>}.F64.<dt> <Dd>,<Dm>"
VFPpat_1E8	VFP_Pattern "VRINTX{<c>}.F32.<dt> <Sd>,<Sm>"
VFPpat_1E9	VFP_Pattern "VCVTB{<c>}.F16.F64 <Sd>,<Dm>"
VFPpat_1EA	VFP_Pattern "VCVTB{<c>}.F64.F16 <Dd>,<Sm>"
VFPpat_1EB	VFP_Pattern "VCVTT{<c>}.F16.F64 <Sd>,<Dm>"
VFPpat_1EC	VFP_Pattern "VCVTT{<c>}.F64.F16 <Dd>,<Sm>"
VFPpat_1ED	VFP_Pattern "VMAXNM.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_1EE	VFP_Pattern "VMAXNM.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1EF	VFP_Pattern "VMINNM.<dt> <Qd>,<Qn>,<Qm>"
VFPpat_1F0	VFP_Pattern "VMINNM.<dt> <Dd>,<Dn>,<Dm>"
VFPpat_1F1	VFP_Pattern "VCVTA.S32.<dt> <Qd>,<Qm>"
VFPpat_1F2	VFP_Pattern "VCVTA.S32.<dt> <Dd>,<Dm>"
VFPpat_1F3	VFP_Pattern "VCVTA.U32.<dt> <Qd>,<Qm>"
VFPpat_1F4	VFP_Pattern "VCVTA.U32.<dt> <Dd>,<Dm>"
VFPpat_1F5	VFP_Pattern "VCVTN.S32.<dt> <Qd>,<Qm>"
VFPpat_1F6	VFP_Pattern "VCVTN.S32.<dt> <Dd>,<Dm>"
VFPpat_1F7	VFP_Pattern "VCVTN.U32.<dt> <Qd>,<Qm>"
VFPpat_1F8	VFP_Pattern "VCVTN.U32.<dt> <Dd>,<Dm>"
VFPpat_1F9	VFP_Pattern "VCVTP.S32.<dt> <Qd>,<Qm>"
VFPpat_1FA	VFP_Pattern "VCVTP.S32.<dt> <Dd>,<Dm>"
VFPpat_1FB	VFP_Pattern "VCVTP.U32.<dt> <Qd>,<Qm>"
VFPpat_1FC	VFP_Pattern "VCVTP.U32.<dt> <Dd>,<Dm>"
VFPpat_1FD	VFP_Pattern "VCVTM.S32.<dt> <Qd>,<Qm>"
VFPpat_1FE	VFP_Pattern "VCVTM.S32.<dt> <Dd>,<Dm>"
VFPpat_1FF	VFP_Pattern "VCVTM.U32.<dt> <Qd>,<Qm>"
VFPpat_200	VFP_Pattern "VCVTM.U32.<dt> <Dd>,<Dm>"
VFPpat_201	VFP_Pattern "VRINTA.F32.<dt> <Qd>,<Qm>"
VFPpat_202	VFP_Pattern "VRINTA.F32.<dt> <Dd>,<Dm>"
VFPpat_203	VFP_Pattern "VRINTN.F32.<dt> <Qd>,<Qm>"
VFPpat_204	VFP_Pattern "VRINTN.F32.<dt> <Dd>,<Dm>"
VFPpat_205	VFP_Pattern "VRINTP.F32.<dt> <Qd>,<Qm>"
VFPpat_206	VFP_Pattern "VRINTP.F32.<dt> <Dd>,<Dm>"
VFPpat_207	VFP_Pattern "VRINTM.F32.<dt> <Qd>,<Qm>"
VFPpat_208	VFP_Pattern "VRINTM.F32.<dt> <Dd>,<Dm>"
VFPpat_209	VFP_Pattern "VRINTX.F32.<dt> <Qd>,<Qm>"
VFPpat_20A	VFP_Pattern "VRINTX.F32.<dt> <Dd>,<Dm>"
VFPpat_20B	VFP_Pattern "VRINTZ.F32.<dt> <Qd>,<Qm>"
VFPpat_20C	VFP_Pattern "VRINTZ.F32.<dt> <Dd>,<Dm>"
		ALIGN

;Align List
VFPali_00	VFP_AlignList 1
		VFP_AlignListEntry 64,1
		DCD 0
		DCD 0
VFPali_01	VFP_AlignList 1
		VFP_AlignListEntry 64,1
		DCD 0
		VFP_AlignList 1
		VFP_AlignListEntry 128,2
		DCD 0
		DCD 0
VFPali_02	VFP_AlignList 1
		VFP_AlignListEntry 64,1
		DCD 0
		VFP_AlignList 1
		VFP_AlignListEntry 128,2
		DCD 0
		VFP_AlignList 1
		VFP_AlignListEntry 256,3
		DCD 0
		DCD 0
VFPali_03	VFP_AlignList 3
		VFP_AlignListEntry 8,0
		VFP_AlignListEntry 16,1
		VFP_AlignListEntry 32,3
		DCD 0
		DCD 0
VFPali_04	VFP_AlignList 3
		VFP_AlignListEntry 16,1
		VFP_AlignListEntry 32,1
		VFP_AlignListEntry 64,1
		DCD 0
		DCD 0
VFPali_05	VFP_AlignList 2
		VFP_AlignListEntry 32,1
		VFP_AlignListEntry 64,1
		DCD 0
		DCD 0
VFPali_06	VFP_AlignList 3
		VFP_AlignListEntry 32,1
		VFP_AlignListEntry 64,1
		VFP_AlignListEntry 64,1
		DCD 0
		VFP_AlignList 1
		VFP_AlignListEntry 128,2
		DCD 0
		DCD 0
VFPali_07	VFP_AlignList 2
		VFP_AlignListEntry 64,1
		VFP_AlignListEntry 64,1
		DCD 0
		VFP_AlignList 1
		VFP_AlignListEntry 128,2
		DCD 0
		DCD 0
VFPali_08	VFP_AlignList 3
		VFP_AlignListEntry 0,0
		VFP_AlignListEntry 16,1
		VFP_AlignListEntry 32,1
		DCD 0
		DCD 0
VFPali_09	VFP_AlignList 3
		VFP_AlignListEntry 32,1
		VFP_AlignListEntry 64,1
		VFP_AlignListEntry 0,0
		DCD 0
		DCD 0

;Params List
VFPpar_00	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_01	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_02	VFP_ParamsList VFP_Op_Vmx,1
		VFP_BitFieldRecord &0,(VFPbfa_4B-VFPtables)
		DCD 0
VFPpar_03	VFP_ParamsList VFP_Op_Vmx,1
		VFP_BitFieldRecord &0,(VFPbfa_4C-VFPtables)
		DCD 0
VFPpar_04	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_05	VFP_ParamsList VFP_Op_opc,3
		VFP_BitFieldRecord &8,(VFPbfa_4D-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_4E-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_4F-VFPtables)
		DCD 0
VFPpar_06	VFP_ParamsList VFP_Op_opc,1
		VFP_BitFieldRecord &8,(VFPbfa_4D-VFPtables)
		DCD 0
VFPpar_07	VFP_ParamsList VFP_Op_opc,1
		VFP_BitFieldRecord &1,(VFPbfa_50-VFPtables)
		DCD 0
VFPpar_08	VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_opc,1
		VFP_BitFieldRecord &0,(VFPbfa_4F-VFPtables)
		DCD 0
VFPpar_09	VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_0A	VFP_ParamsList VFP_Op_Rt,1
		VFP_BitFieldRecord &F,0
		DCD 0
VFPpar_0B	VFP_ParamsList VFP_Op_E,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_0C	VFP_ParamsList VFP_Op_E,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_0D	VFP_ParamsList VFP_Op_opc2,1
		VFP_BitFieldRecord &5,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_0E	VFP_ParamsList VFP_Op_opc2,1
		VFP_BitFieldRecord &5,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_0F	VFP_ParamsList VFP_Op_opc2,1
		VFP_BitFieldRecord &4,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_10	VFP_ParamsList VFP_Op_opc2,1
		VFP_BitFieldRecord &4,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_11	VFP_ParamsList VFP_Op_opc2,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_12	VFP_ParamsList VFP_Op_opc2,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_13	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_14	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sf,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sx,1
		VFP_BitFieldRecord &0,(VFPbfa_51-VFPtables)
		DCD 0
VFPpar_15	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sf,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sx,1
		VFP_BitFieldRecord &0,(VFPbfa_51-VFPtables)
		DCD 0
VFPpar_16	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sf,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sx,1
		VFP_BitFieldRecord &0,(VFPbfa_51-VFPtables)
		DCD 0
VFPpar_17	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sf,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sx,1
		VFP_BitFieldRecord &0,(VFPbfa_51-VFPtables)
		DCD 0
VFPpar_18	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &2,0
		VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_19	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_1A	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_1B	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_1C	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_1D	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_1E	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_1F	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_20	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &7,0
		DCD 0
VFPpar_21	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &A,0
		DCD 0
VFPpar_22	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &6,0
		DCD 0
VFPpar_23	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_24	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &8,0
		DCD 0
VFPpar_25	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &9,0
		DCD 0
VFPpar_26	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &3,0
		DCD 0
VFPpar_27	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &4,0
		DCD 0
VFPpar_28	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &5,0
		DCD 0
VFPpar_29	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_2A	VFP_ParamsList VFP_Op_type,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_2B	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_ia,3
		VFP_BitFieldRecord &0,(VFPbfa_52-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_53-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_54-VFPtables)
		DCD 0
VFPpar_2C	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_ia,3
		VFP_BitFieldRecord &0,(VFPbfa_55-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_56-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_57-VFPtables)
		DCD 0
VFPpar_2D	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_ia,2
		VFP_BitFieldRecord &2,(VFPbfa_56-VFPtables)
		VFP_BitFieldRecord &4,(VFPbfa_57-VFPtables)
		DCD 0
VFPpar_2E	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &2,0
		VFP_ParamsList VFP_Op_ia,3
		VFP_BitFieldRecord &0,(VFPbfa_52-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_58-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_59-VFPtables)
		DCD 0
VFPpar_2F	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &2,0
		VFP_ParamsList VFP_Op_ia,2
		VFP_BitFieldRecord &2,(VFPbfa_58-VFPtables)
		VFP_BitFieldRecord &4,(VFPbfa_59-VFPtables)
		DCD 0
VFPpar_30	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_ia,3
		VFP_BitFieldRecord &0,(VFPbfa_55-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_56-VFPtables)
		VFP_BitFieldRecord &0,(VFPbfa_57-VFPtables)
		DCD 0
VFPpar_31	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_ia,2
		VFP_BitFieldRecord &2,(VFPbfa_56-VFPtables)
		VFP_BitFieldRecord &4,(VFPbfa_57-VFPtables)
		DCD 0
VFPpar_32	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,(VFPbfa_5A-VFPtables)
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_33	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,(VFPbfa_5A-VFPtables)
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_34	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,(VFPbfa_5A-VFPtables)
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_35	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,(VFPbfa_5A-VFPtables)
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_36	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &2,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_37	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &2,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_38	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_39	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,(VFPbfa_5A-VFPtables)
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_3A	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_size,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_3B	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_a,1
		VFP_BitFieldRecord &0,(VFPbfa_5A-VFPtables)
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_3C	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_P,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_3D	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_P,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_W,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_3E	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_P,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_3F	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_P,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_W,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_40	VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_41	VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_42	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		DCD 0
VFPpar_43	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_44	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_45	VFP_ParamsList VFP_Op_imm4,3
		VFP_BitFieldRecord &1,(VFPbfa_52-VFPtables)
		VFP_BitFieldRecord &2,(VFPbfa_58-VFPtables)
		VFP_BitFieldRecord &4,(VFPbfa_59-VFPtables)
		DCD 0
VFPpar_46	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_Vmx,1
		VFP_BitFieldRecord &0,(VFPbfa_4B-VFPtables)
		DCD 0
VFPpar_47	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_Vmx,1
		VFP_BitFieldRecord &0,(VFPbfa_4C-VFPtables)
		DCD 0
VFPpar_48	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_Vmx,1
		VFP_BitFieldRecord &0,(VFPbfa_4B-VFPtables)
		DCD 0
VFPpar_49	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_Vmx,1
		VFP_BitFieldRecord &0,(VFPbfa_4C-VFPtables)
		DCD 0
VFPpar_4A	VFP_ParamsList VFP_Op_U,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_4B	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_4C	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_4D	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_4E	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_4F	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &3,0
		DCD 0
VFPpar_50	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_51	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_52	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_53	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_len,1
		VFP_BitFieldRecord &3,0
		DCD 0
VFPpar_54	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_Q,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_55	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_Q,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_56	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_Q,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_57	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_Q,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_58	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_59	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_5A	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_5B	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_5C	VFP_ParamsList VFP_Op_cc,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_5D	VFP_ParamsList VFP_Op_cc,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_5E	VFP_ParamsList VFP_Op_cc,1
		VFP_BitFieldRecord &3,0
		DCD 0
VFPpar_5F	VFP_ParamsList VFP_Op_cc,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_60	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_61	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_62	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_63	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_64	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &2,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_65	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &2,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_66	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_67	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &3,0
		VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_68	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_69	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_6A	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_6B	VFP_ParamsList VFP_Op_rm,1
		VFP_BitFieldRecord &3,0
		DCD 0
VFPpar_6C	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_6D	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_6E	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_6F	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		VFP_ParamsList VFP_Op_T,1
		VFP_BitFieldRecord &1,0
		VFP_ParamsList VFP_Op_sz,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_70	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &2,0
		DCD 0
VFPpar_71	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &0,0
		DCD 0
VFPpar_72	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &7,0
		DCD 0
VFPpar_73	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &5,0
		DCD 0
VFPpar_74	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &1,0
		DCD 0
VFPpar_75	VFP_ParamsList VFP_Op_op,1
		VFP_BitFieldRecord &3,0
		DCD 0

;4 char code table
VFPOpTable	VFP_OpTableEntry "VABA",(VFPsyn_VABA-VFPtables)
		VFP_OpTableEntry "VABD",(VFPsyn_VABD-VFPtables)
		VFP_OpTableEntry "VABS",(VFPsyn_VABS-VFPtables)
		VFP_OpTableEntry "VACG",(VFPsyn_VACG-VFPtables)
		VFP_OpTableEntry "VACL",(VFPsyn_VACL-VFPtables)
		VFP_OpTableEntry "VADD",(VFPsyn_VADD-VFPtables)
		VFP_OpTableEntry "VAND",(VFPsyn_VAND-VFPtables)
		VFP_OpTableEntry "VBIC",(VFPsyn_VBIC-VFPtables)
		VFP_OpTableEntry "VBIF",(VFPsyn_VBIF-VFPtables)
		VFP_OpTableEntry "VBIT",(VFPsyn_VBIT-VFPtables)
		VFP_OpTableEntry "VBSL",(VFPsyn_VBSL-VFPtables)
		VFP_OpTableEntry "VCEQ",(VFPsyn_VCEQ-VFPtables)
		VFP_OpTableEntry "VCGE",(VFPsyn_VCGE-VFPtables)
		VFP_OpTableEntry "VCGT",(VFPsyn_VCGT-VFPtables)
		VFP_OpTableEntry "VCLE",(VFPsyn_VCLE-VFPtables)
		VFP_OpTableEntry "VCLS",(VFPsyn_VCLS-VFPtables)
		VFP_OpTableEntry "VCLT",(VFPsyn_VCLT-VFPtables)
		VFP_OpTableEntry "VCLZ",(VFPsyn_VCLZ-VFPtables)
		VFP_OpTableEntry "VCMP",(VFPsyn_VCMP-VFPtables)
		VFP_OpTableEntry "VCNT",(VFPsyn_VCNT-VFPtables)
		VFP_OpTableEntry "VCVT",(VFPsyn_VCVT-VFPtables)
		VFP_OpTableEntry "VDIV",(VFPsyn_VDIV-VFPtables)
		VFP_OpTableEntry "VDUP",(VFPsyn_VDUP-VFPtables)
		VFP_OpTableEntry "VEOR",(VFPsyn_VEOR-VFPtables)
		VFP_OpTableEntry "VEXT",(VFPsyn_VEXT-VFPtables)
		VFP_OpTableEntry "VFMA",(VFPsyn_VFMA-VFPtables)
		VFP_OpTableEntry "VFMS",(VFPsyn_VFMS-VFPtables)
		VFP_OpTableEntry "VFNM",(VFPsyn_VFNM-VFPtables)
		VFP_OpTableEntry "VHAD",(VFPsyn_VHAD-VFPtables)
		VFP_OpTableEntry "VHSU",(VFPsyn_VHSU-VFPtables)
		VFP_OpTableEntry "VLD1",(VFPsyn_VLD1-VFPtables)
		VFP_OpTableEntry "VLD2",(VFPsyn_VLD2-VFPtables)
		VFP_OpTableEntry "VLD3",(VFPsyn_VLD3-VFPtables)
		VFP_OpTableEntry "VLD4",(VFPsyn_VLD4-VFPtables)
		VFP_OpTableEntry "VLDM",(VFPsyn_VLDM-VFPtables)
		VFP_OpTableEntry "VLDR",(VFPsyn_VLDR-VFPtables)
		VFP_OpTableEntry "VMAX",(VFPsyn_VMAX-VFPtables)
		VFP_OpTableEntry "VMIN",(VFPsyn_VMIN-VFPtables)
		VFP_OpTableEntry "VMLA",(VFPsyn_VMLA-VFPtables)
		VFP_OpTableEntry "VMLS",(VFPsyn_VMLS-VFPtables)
		VFP_OpTableEntry "VMOV",(VFPsyn_VMOV-VFPtables)
		VFP_OpTableEntry "VMRS",(VFPsyn_VMRS-VFPtables)
		VFP_OpTableEntry "VMSR",(VFPsyn_VMSR-VFPtables)
		VFP_OpTableEntry "VMUL",(VFPsyn_VMUL-VFPtables)
		VFP_OpTableEntry "VMVN",(VFPsyn_VMVN-VFPtables)
		VFP_OpTableEntry "VNEG",(VFPsyn_VNEG-VFPtables)
		VFP_OpTableEntry "VNML",(VFPsyn_VNML-VFPtables)
		VFP_OpTableEntry "VNMU",(VFPsyn_VNMU-VFPtables)
		VFP_OpTableEntry "VORN",(VFPsyn_VORN-VFPtables)
		VFP_OpTableEntry "VORR",(VFPsyn_VORR-VFPtables)
		VFP_OpTableEntry "VPAD",(VFPsyn_VPAD-VFPtables)
		VFP_OpTableEntry "VPMA",(VFPsyn_VPMA-VFPtables)
		VFP_OpTableEntry "VPMI",(VFPsyn_VPMI-VFPtables)
		VFP_OpTableEntry "VPOP",(VFPsyn_VPOP-VFPtables)
		VFP_OpTableEntry "VPUS",(VFPsyn_VPUS-VFPtables)
		VFP_OpTableEntry "VQAB",(VFPsyn_VQAB-VFPtables)
		VFP_OpTableEntry "VQAD",(VFPsyn_VQAD-VFPtables)
		VFP_OpTableEntry "VQDM",(VFPsyn_VQDM-VFPtables)
		VFP_OpTableEntry "VQMO",(VFPsyn_VQMO-VFPtables)
		VFP_OpTableEntry "VQNE",(VFPsyn_VQNE-VFPtables)
		VFP_OpTableEntry "VQRD",(VFPsyn_VQRD-VFPtables)
		VFP_OpTableEntry "VQRS",(VFPsyn_VQRS-VFPtables)
		VFP_OpTableEntry "VQSH",(VFPsyn_VQSH-VFPtables)
		VFP_OpTableEntry "VQSU",(VFPsyn_VQSU-VFPtables)
		VFP_OpTableEntry "VRAD",(VFPsyn_VRAD-VFPtables)
		VFP_OpTableEntry "VREC",(VFPsyn_VREC-VFPtables)
		VFP_OpTableEntry "VREV",(VFPsyn_VREV-VFPtables)
		VFP_OpTableEntry "VRHA",(VFPsyn_VRHA-VFPtables)
		VFP_OpTableEntry "VRIN",(VFPsyn_VRIN-VFPtables)
		VFP_OpTableEntry "VRSH",(VFPsyn_VRSH-VFPtables)
		VFP_OpTableEntry "VRSQ",(VFPsyn_VRSQ-VFPtables)
		VFP_OpTableEntry "VRSR",(VFPsyn_VRSR-VFPtables)
		VFP_OpTableEntry "VRSU",(VFPsyn_VRSU-VFPtables)
		VFP_OpTableEntry "VSEL",(VFPsyn_VSEL-VFPtables)
		VFP_OpTableEntry "VSHL",(VFPsyn_VSHL-VFPtables)
		VFP_OpTableEntry "VSHR",(VFPsyn_VSHR-VFPtables)
		VFP_OpTableEntry "VSLI",(VFPsyn_VSLI-VFPtables)
		VFP_OpTableEntry "VSQR",(VFPsyn_VSQR-VFPtables)
		VFP_OpTableEntry "VSRA",(VFPsyn_VSRA-VFPtables)
		VFP_OpTableEntry "VSRI",(VFPsyn_VSRI-VFPtables)
		VFP_OpTableEntry "VST1",(VFPsyn_VST1-VFPtables)
		VFP_OpTableEntry "VST2",(VFPsyn_VST2-VFPtables)
		VFP_OpTableEntry "VST3",(VFPsyn_VST3-VFPtables)
		VFP_OpTableEntry "VST4",(VFPsyn_VST4-VFPtables)
		VFP_OpTableEntry "VSTM",(VFPsyn_VSTM-VFPtables)
		VFP_OpTableEntry "VSTR",(VFPsyn_VSTR-VFPtables)
		VFP_OpTableEntry "VSUB",(VFPsyn_VSUB-VFPtables)
		VFP_OpTableEntry "VSWP",(VFPsyn_VSWP-VFPtables)
		VFP_OpTableEntry "VTBL",(VFPsyn_VTBL-VFPtables)
		VFP_OpTableEntry "VTBX",(VFPsyn_VTBX-VFPtables)
		VFP_OpTableEntry "VTRN",(VFPsyn_VTRN-VFPtables)
		VFP_OpTableEntry "VTST",(VFPsyn_VTST-VFPtables)
		VFP_OpTableEntry "VUZP",(VFPsyn_VUZP-VFPtables)
		VFP_OpTableEntry "VZIP",(VFPsyn_VZIP-VFPtables)
		DCD 0

;Syntax Lookup table - grouped per 4 char code
VFPsyn_VABA	VFP_SyntaxLookup (VFPpat_E7-VFPtables),(VFPenc_29-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_E8-VFPtables),(VFPenc_29-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_E9-VFPtables),(VFPenc_2A-VFPtables),(VFPdt_07-VFPtables),0,0
		DCW 0
VFPsyn_VABD	VFP_SyntaxLookup (VFPpat_EA-VFPtables),(VFPenc_2B-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_EB-VFPtables),(VFPenc_2B-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_EC-VFPtables),(VFPenc_2C-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_ED-VFPtables),(VFPenc_2D-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_EE-VFPtables),(VFPenc_2D-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VABS	VFP_SyntaxLookup (VFPpat_39-VFPtables),(VFPenc_2E-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_3A-VFPtables),(VFPenc_2E-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_3B-VFPtables),(VFPenc_00-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_3C-VFPtables),(VFPenc_00-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VACG	VFP_SyntaxLookup (VFPpat_EF-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_F0-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_F1-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_F2-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VACL	VFP_SyntaxLookup (VFPpat_F3-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_F4-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_F5-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_F6-VFPtables),(VFPenc_33-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VADD	VFP_SyntaxLookup (VFPpat_2C-VFPtables),(VFPenc_2F-VFPtables),(VFPdt_0D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_2D-VFPtables),(VFPenc_2F-VFPtables),(VFPdt_0D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_2E-VFPtables),(VFPenc_30-VFPtables),(VFPdt_0E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_2F-VFPtables),(VFPenc_31-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_30-VFPtables),(VFPenc_31-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_31-VFPtables),(VFPenc_32-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_32-VFPtables),(VFPenc_32-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_33-VFPtables),(VFPenc_01-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_34-VFPtables),(VFPenc_01-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VAND	VFP_SyntaxLookup (VFPpat_04-VFPtables),(VFPenc_34-VFPtables),(VFPdt_02-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_05-VFPtables),(VFPenc_34-VFPtables),(VFPdt_02-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_08-VFPtables),(VFPenc_35-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_09-VFPtables),(VFPenc_35-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VBIC	VFP_SyntaxLookup (VFPpat_06-VFPtables),(VFPenc_34-VFPtables),(VFPdt_02-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_07-VFPtables),(VFPenc_34-VFPtables),(VFPdt_02-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_0A-VFPtables),(VFPenc_35-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_0B-VFPtables),(VFPenc_35-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VBIF	VFP_SyntaxLookup (VFPpat_F7-VFPtables),(VFPenc_36-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_42-VFPtables)
		VFP_SyntaxLookup (VFPpat_F8-VFPtables),(VFPenc_36-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_42-VFPtables)
		DCW 0
VFPsyn_VBIT	VFP_SyntaxLookup (VFPpat_F9-VFPtables),(VFPenc_36-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_43-VFPtables)
		VFP_SyntaxLookup (VFPpat_FA-VFPtables),(VFPenc_36-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_43-VFPtables)
		DCW 0
VFPsyn_VBSL	VFP_SyntaxLookup (VFPpat_FB-VFPtables),(VFPenc_36-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_44-VFPtables)
		VFP_SyntaxLookup (VFPpat_FC-VFPtables),(VFPenc_36-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_44-VFPtables)
		DCW 0
VFPsyn_VCEQ	VFP_SyntaxLookup (VFPpat_65-VFPtables),(VFPenc_37-VFPtables),(VFPdt_06-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_66-VFPtables),(VFPenc_37-VFPtables),(VFPdt_06-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_67-VFPtables),(VFPenc_3A-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_68-VFPtables),(VFPenc_3A-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_79-VFPtables),(VFPenc_3D-VFPtables),(VFPdt_15-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_7A-VFPtables),(VFPenc_3D-VFPtables),(VFPdt_15-VFPtables),0,0
		DCW 0
VFPsyn_VCGE	VFP_SyntaxLookup (VFPpat_69-VFPtables),(VFPenc_38-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_6A-VFPtables),(VFPenc_38-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_6B-VFPtables),(VFPenc_3B-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_6C-VFPtables),(VFPenc_3B-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_7B-VFPtables),(VFPenc_3E-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_7C-VFPtables),(VFPenc_3E-VFPtables),(VFPdt_0F-VFPtables),0,0
		DCW 0
VFPsyn_VCGT	VFP_SyntaxLookup (VFPpat_6D-VFPtables),(VFPenc_39-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_6E-VFPtables),(VFPenc_39-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_6F-VFPtables),(VFPenc_3C-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_70-VFPtables),(VFPenc_3C-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_7D-VFPtables),(VFPenc_3F-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_7E-VFPtables),(VFPenc_3F-VFPtables),(VFPdt_0F-VFPtables),0,0
		DCW 0
VFPsyn_VCLE	VFP_SyntaxLookup (VFPpat_71-VFPtables),(VFPenc_38-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_72-VFPtables),(VFPenc_38-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_73-VFPtables),(VFPenc_3B-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_74-VFPtables),(VFPenc_3B-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_7F-VFPtables),(VFPenc_40-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_80-VFPtables),(VFPenc_40-VFPtables),(VFPdt_0F-VFPtables),0,0
		DCW 0
VFPsyn_VCLS	VFP_SyntaxLookup (VFPpat_FD-VFPtables),(VFPenc_42-VFPtables),(VFPdt_1A-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_FE-VFPtables),(VFPenc_42-VFPtables),(VFPdt_1A-VFPtables),0,0
		DCW 0
VFPsyn_VCLT	VFP_SyntaxLookup (VFPpat_75-VFPtables),(VFPenc_39-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_76-VFPtables),(VFPenc_39-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_77-VFPtables),(VFPenc_3C-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_78-VFPtables),(VFPenc_3C-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_81-VFPtables),(VFPenc_41-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_82-VFPtables),(VFPenc_41-VFPtables),(VFPdt_0F-VFPtables),0,0
		DCW 0
VFPsyn_VCLZ	VFP_SyntaxLookup (VFPpat_FF-VFPtables),(VFPenc_43-VFPtables),(VFPdt_06-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_100-VFPtables),(VFPenc_43-VFPtables),(VFPdt_06-VFPtables),0,0
		DCW 0
VFPsyn_VCMP	VFP_SyntaxLookup (VFPpat_5D-VFPtables),(VFPenc_02-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_0B-VFPtables)
		VFP_SyntaxLookup (VFPpat_5E-VFPtables),(VFPenc_02-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_0C-VFPtables)
		VFP_SyntaxLookup (VFPpat_5F-VFPtables),(VFPenc_02-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_0B-VFPtables)
		VFP_SyntaxLookup (VFPpat_60-VFPtables),(VFPenc_02-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_0C-VFPtables)
		VFP_SyntaxLookup (VFPpat_61-VFPtables),(VFPenc_03-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_0B-VFPtables)
		VFP_SyntaxLookup (VFPpat_62-VFPtables),(VFPenc_03-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_0C-VFPtables)
		VFP_SyntaxLookup (VFPpat_63-VFPtables),(VFPenc_03-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_0B-VFPtables)
		VFP_SyntaxLookup (VFPpat_64-VFPtables),(VFPenc_03-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_0C-VFPtables)
		DCW 0
VFPsyn_VCNT	VFP_SyntaxLookup (VFPpat_101-VFPtables),(VFPenc_44-VFPtables),(VFPdt_1B-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_102-VFPtables),(VFPenc_44-VFPtables),(VFPdt_1B-VFPtables),0,0
		DCW 0
VFPsyn_VCVT	VFP_SyntaxLookup (VFPpat_83-VFPtables),(VFPenc_04-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_0D-VFPtables)
		VFP_SyntaxLookup (VFPpat_84-VFPtables),(VFPenc_04-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_0D-VFPtables)
		VFP_SyntaxLookup (VFPpat_85-VFPtables),(VFPenc_04-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_0E-VFPtables)
		VFP_SyntaxLookup (VFPpat_86-VFPtables),(VFPenc_04-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_0E-VFPtables)
		VFP_SyntaxLookup (VFPpat_87-VFPtables),(VFPenc_04-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_0F-VFPtables)
		VFP_SyntaxLookup (VFPpat_88-VFPtables),(VFPenc_04-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_0F-VFPtables)
		VFP_SyntaxLookup (VFPpat_89-VFPtables),(VFPenc_04-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_10-VFPtables)
		VFP_SyntaxLookup (VFPpat_8A-VFPtables),(VFPenc_04-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_10-VFPtables)
		VFP_SyntaxLookup (VFPpat_8B-VFPtables),(VFPenc_04-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_11-VFPtables)
		VFP_SyntaxLookup (VFPpat_8C-VFPtables),(VFPenc_04-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_12-VFPtables)
		VFP_SyntaxLookup (VFPpat_8D-VFPtables),(VFPenc_04-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_11-VFPtables)
		VFP_SyntaxLookup (VFPpat_8E-VFPtables),(VFPenc_04-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_12-VFPtables)
		VFP_SyntaxLookup (VFPpat_8F-VFPtables),(VFPenc_05-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_90-VFPtables),(VFPenc_05-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_91-VFPtables),(VFPenc_45-VFPtables),(VFPdt_0B-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_92-VFPtables),(VFPenc_45-VFPtables),(VFPdt_0B-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_93-VFPtables),(VFPenc_45-VFPtables),(VFPdt_0B-VFPtables),0,(VFPpar_13-VFPtables)
		VFP_SyntaxLookup (VFPpat_94-VFPtables),(VFPenc_45-VFPtables),(VFPdt_0B-VFPtables),0,(VFPpar_13-VFPtables)
		VFP_SyntaxLookup (VFPpat_95-VFPtables),(VFPenc_06-VFPtables),(VFPdt_16-VFPtables),0,(VFPpar_14-VFPtables)
		VFP_SyntaxLookup (VFPpat_96-VFPtables),(VFPenc_06-VFPtables),(VFPdt_16-VFPtables),0,(VFPpar_15-VFPtables)
		VFP_SyntaxLookup (VFPpat_97-VFPtables),(VFPenc_06-VFPtables),(VFPdt_16-VFPtables),0,(VFPpar_16-VFPtables)
		VFP_SyntaxLookup (VFPpat_98-VFPtables),(VFPenc_06-VFPtables),(VFPdt_16-VFPtables),0,(VFPpar_17-VFPtables)
		VFP_SyntaxLookup (VFPpat_99-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_18-VFPtables)
		VFP_SyntaxLookup (VFPpat_9A-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_18-VFPtables)
		VFP_SyntaxLookup (VFPpat_9B-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_19-VFPtables)
		VFP_SyntaxLookup (VFPpat_9C-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_19-VFPtables)
		VFP_SyntaxLookup (VFPpat_9D-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_1A-VFPtables)
		VFP_SyntaxLookup (VFPpat_9E-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_1A-VFPtables)
		VFP_SyntaxLookup (VFPpat_9F-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_1A-VFPtables)
		VFP_SyntaxLookup (VFPpat_A0-VFPtables),(VFPenc_46-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_1B-VFPtables)
		VFP_SyntaxLookup (VFPpat_A1-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_1C-VFPtables)
		VFP_SyntaxLookup (VFPpat_A2-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_1D-VFPtables)
		VFP_SyntaxLookup (VFPpat_A3-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_1E-VFPtables)
		VFP_SyntaxLookup (VFPpat_A4-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_1F-VFPtables)
		VFP_SyntaxLookup (VFPpat_1CB-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_60-VFPtables)
		VFP_SyntaxLookup (VFPpat_1CC-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_60-VFPtables)
		VFP_SyntaxLookup (VFPpat_1CD-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_61-VFPtables)
		VFP_SyntaxLookup (VFPpat_1CE-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_61-VFPtables)
		VFP_SyntaxLookup (VFPpat_1CF-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_62-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D0-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_62-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D1-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_63-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D2-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_63-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D3-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_64-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D4-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_64-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D5-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_65-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D6-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_65-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D7-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_66-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D8-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_66-VFPtables)
		VFP_SyntaxLookup (VFPpat_1D9-VFPtables),(VFPenc_25-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_67-VFPtables)
		VFP_SyntaxLookup (VFPpat_1DA-VFPtables),(VFPenc_25-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_67-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E9-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_6C-VFPtables)
		VFP_SyntaxLookup (VFPpat_1EA-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_6D-VFPtables)
		VFP_SyntaxLookup (VFPpat_1EB-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_6E-VFPtables)
		VFP_SyntaxLookup (VFPpat_1EC-VFPtables),(VFPenc_07-VFPtables),0,0,(VFPpar_6F-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F1-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_61-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F2-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_61-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F3-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_60-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F4-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_60-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F5-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_63-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F6-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_63-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F7-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_62-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F8-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_62-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F9-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_65-VFPtables)
		VFP_SyntaxLookup (VFPpat_1FA-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_65-VFPtables)
		VFP_SyntaxLookup (VFPpat_1FB-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_64-VFPtables)
		VFP_SyntaxLookup (VFPpat_1FC-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_64-VFPtables)
		VFP_SyntaxLookup (VFPpat_1FD-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_67-VFPtables)
		VFP_SyntaxLookup (VFPpat_1FE-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_67-VFPtables)
		VFP_SyntaxLookup (VFPpat_1FF-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_66-VFPtables)
		VFP_SyntaxLookup (VFPpat_200-VFPtables),(VFPenc_9F-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_66-VFPtables)
		DCW 0
VFPsyn_VDIV	VFP_SyntaxLookup (VFPpat_00-VFPtables),(VFPenc_0C-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_01-VFPtables),(VFPenc_0C-VFPtables),(VFPdt_01-VFPtables),0,0
		DCW 0
VFPsyn_VDUP	VFP_SyntaxLookup (VFPpat_103-VFPtables),(VFPenc_47-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_45-VFPtables)
		VFP_SyntaxLookup (VFPpat_104-VFPtables),(VFPenc_47-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_45-VFPtables)
		VFP_SyntaxLookup (VFPpat_105-VFPtables),(VFPenc_48-VFPtables),(VFPdt_05-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_106-VFPtables),(VFPenc_48-VFPtables),(VFPdt_05-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_107-VFPtables),(VFPenc_47-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_45-VFPtables)
		VFP_SyntaxLookup (VFPpat_108-VFPtables),(VFPenc_47-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_45-VFPtables)
		VFP_SyntaxLookup (VFPpat_109-VFPtables),(VFPenc_48-VFPtables),(VFPdt_05-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_10A-VFPtables),(VFPenc_48-VFPtables),(VFPdt_05-VFPtables),0,0
		DCW 0
VFPsyn_VEOR	VFP_SyntaxLookup (VFPpat_10B-VFPtables),(VFPenc_49-VFPtables),(VFPdt_03-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_10C-VFPtables),(VFPenc_49-VFPtables),(VFPdt_03-VFPtables),0,0
		DCW 0
VFPsyn_VEXT	VFP_SyntaxLookup (VFPpat_10D-VFPtables),(VFPenc_4A-VFPtables),(VFPdt_1B-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_10E-VFPtables),(VFPenc_4A-VFPtables),(VFPdt_1B-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_10F-VFPtables),(VFPenc_4A-VFPtables),(VFPdt_19-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_110-VFPtables),(VFPenc_4A-VFPtables),(VFPdt_19-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_111-VFPtables),(VFPenc_4A-VFPtables),(VFPdt_14-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_112-VFPtables),(VFPenc_4A-VFPtables),(VFPdt_14-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_113-VFPtables),(VFPenc_4A-VFPtables),(VFPdt_1C-VFPtables),0,0
		DCW 0
VFPsyn_VFMA	VFP_SyntaxLookup (VFPpat_1B3-VFPtables),(VFPenc_9D-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_54-VFPtables)
		VFP_SyntaxLookup (VFPpat_1B5-VFPtables),(VFPenc_9D-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_56-VFPtables)
		VFP_SyntaxLookup (VFPpat_1B7-VFPtables),(VFPenc_21-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_58-VFPtables)
		VFP_SyntaxLookup (VFPpat_1B9-VFPtables),(VFPenc_21-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5A-VFPtables)
		DCW 0
VFPsyn_VFMS	VFP_SyntaxLookup (VFPpat_1B4-VFPtables),(VFPenc_9D-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_55-VFPtables)
		VFP_SyntaxLookup (VFPpat_1B6-VFPtables),(VFPenc_9D-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_57-VFPtables)
		VFP_SyntaxLookup (VFPpat_1B8-VFPtables),(VFPenc_21-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_59-VFPtables)
		VFP_SyntaxLookup (VFPpat_1BA-VFPtables),(VFPenc_21-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5B-VFPtables)
		DCW 0
VFPsyn_VFNM	VFP_SyntaxLookup (VFPpat_1BB-VFPtables),(VFPenc_22-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_58-VFPtables)
		VFP_SyntaxLookup (VFPpat_1BC-VFPtables),(VFPenc_22-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_59-VFPtables)
		VFP_SyntaxLookup (VFPpat_1BD-VFPtables),(VFPenc_22-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5A-VFPtables)
		VFP_SyntaxLookup (VFPpat_1BE-VFPtables),(VFPenc_22-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5B-VFPtables)
		DCW 0
VFPsyn_VHAD	VFP_SyntaxLookup (VFPpat_114-VFPtables),(VFPenc_4B-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_115-VFPtables),(VFPenc_4B-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VHSU	VFP_SyntaxLookup (VFPpat_116-VFPtables),(VFPenc_4B-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_117-VFPtables),(VFPenc_4B-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VLD1	VFP_SyntaxLookup (VFPpat_A5-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_17-VFPtables),(VFPali_00-VFPtables),(VFPpar_20-VFPtables)
		VFP_SyntaxLookup (VFPpat_A6-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_17-VFPtables),(VFPali_01-VFPtables),(VFPpar_21-VFPtables)
		VFP_SyntaxLookup (VFPpat_A7-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_17-VFPtables),(VFPali_00-VFPtables),(VFPpar_22-VFPtables)
		VFP_SyntaxLookup (VFPpat_A8-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_17-VFPtables),(VFPali_02-VFPtables),(VFPpar_23-VFPtables)
		VFP_SyntaxLookup (VFPpat_BB-VFPtables),(VFPenc_4D-VFPtables),(VFPdt_05-VFPtables),(VFPali_03-VFPtables),(VFPpar_2B-VFPtables)
		VFP_SyntaxLookup (VFPpat_C9-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),(VFPali_08-VFPtables),(VFPpar_32-VFPtables)
		VFP_SyntaxLookup (VFPpat_CA-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),(VFPali_08-VFPtables),(VFPpar_33-VFPtables)
		DCW 0
VFPsyn_VLD2	VFP_SyntaxLookup (VFPpat_AD-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_05-VFPtables),(VFPali_01-VFPtables),(VFPpar_24-VFPtables)
		VFP_SyntaxLookup (VFPpat_AE-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_05-VFPtables),(VFPali_01-VFPtables),(VFPpar_25-VFPtables)
		VFP_SyntaxLookup (VFPpat_AF-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_05-VFPtables),(VFPali_02-VFPtables),(VFPpar_26-VFPtables)
		VFP_SyntaxLookup (VFPpat_BD-VFPtables),(VFPenc_4D-VFPtables),(VFPdt_05-VFPtables),(VFPali_04-VFPtables),(VFPpar_2C-VFPtables)
		VFP_SyntaxLookup (VFPpat_BF-VFPtables),(VFPenc_4D-VFPtables),(VFPdt_18-VFPtables),(VFPali_05-VFPtables),(VFPpar_2D-VFPtables)
		VFP_SyntaxLookup (VFPpat_CB-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),(VFPali_04-VFPtables),(VFPpar_34-VFPtables)
		VFP_SyntaxLookup (VFPpat_CC-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),(VFPali_04-VFPtables),(VFPpar_35-VFPtables)
		DCW 0
VFPsyn_VLD3	VFP_SyntaxLookup (VFPpat_B3-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_05-VFPtables),(VFPali_00-VFPtables),(VFPpar_27-VFPtables)
		VFP_SyntaxLookup (VFPpat_B4-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_05-VFPtables),(VFPali_00-VFPtables),(VFPpar_28-VFPtables)
		VFP_SyntaxLookup (VFPpat_C1-VFPtables),(VFPenc_4D-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_2E-VFPtables)
		VFP_SyntaxLookup (VFPpat_C3-VFPtables),(VFPenc_4D-VFPtables),(VFPdt_18-VFPtables),0,(VFPpar_2F-VFPtables)
		VFP_SyntaxLookup (VFPpat_CD-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_36-VFPtables)
		VFP_SyntaxLookup (VFPpat_CE-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_37-VFPtables)
		DCW 0
VFPsyn_VLD4	VFP_SyntaxLookup (VFPpat_B7-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_05-VFPtables),(VFPali_02-VFPtables),(VFPpar_29-VFPtables)
		VFP_SyntaxLookup (VFPpat_B8-VFPtables),(VFPenc_4C-VFPtables),(VFPdt_05-VFPtables),(VFPali_02-VFPtables),(VFPpar_2A-VFPtables)
		VFP_SyntaxLookup (VFPpat_C5-VFPtables),(VFPenc_4D-VFPtables),(VFPdt_05-VFPtables),(VFPali_06-VFPtables),(VFPpar_30-VFPtables)
		VFP_SyntaxLookup (VFPpat_C7-VFPtables),(VFPenc_4D-VFPtables),(VFPdt_18-VFPtables),(VFPali_07-VFPtables),(VFPpar_31-VFPtables)
		VFP_SyntaxLookup (VFPpat_CF-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_14-VFPtables),0,(VFPpar_38-VFPtables)
		VFP_SyntaxLookup (VFPpat_D0-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),(VFPali_09-VFPtables),(VFPpar_39-VFPtables)
		VFP_SyntaxLookup (VFPpat_D1-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_14-VFPtables),0,(VFPpar_3A-VFPtables)
		VFP_SyntaxLookup (VFPpat_D2-VFPtables),(VFPenc_4E-VFPtables),(VFPdt_05-VFPtables),(VFPali_09-VFPtables),(VFPpar_3B-VFPtables)
		DCW 0
VFPsyn_VLDM	VFP_SyntaxLookup (VFPpat_D3-VFPtables),(VFPenc_08-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_3C-VFPtables)
		VFP_SyntaxLookup (VFPpat_D4-VFPtables),(VFPenc_08-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_3D-VFPtables)
		VFP_SyntaxLookup (VFPpat_D5-VFPtables),(VFPenc_08-VFPtables),(VFPdt_14-VFPtables),0,(VFPpar_3E-VFPtables)
		VFP_SyntaxLookup (VFPpat_D6-VFPtables),(VFPenc_08-VFPtables),(VFPdt_14-VFPtables),0,(VFPpar_3F-VFPtables)
		DCW 0
VFPsyn_VLDR	VFP_SyntaxLookup (VFPpat_DF-VFPtables),(VFPenc_09-VFPtables),0,0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_E0-VFPtables),(VFPenc_09-VFPtables),0,0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_E1-VFPtables),(VFPenc_09-VFPtables),0,0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_E2-VFPtables),(VFPenc_09-VFPtables),0,0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VMAX	VFP_SyntaxLookup (VFPpat_118-VFPtables),(VFPenc_4F-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_119-VFPtables),(VFPenc_4F-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_11C-VFPtables),(VFPenc_50-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_11D-VFPtables),(VFPenc_50-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C7-VFPtables),(VFPenc_24-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C8-VFPtables),(VFPenc_24-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1ED-VFPtables),(VFPenc_9E-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1EE-VFPtables),(VFPenc_9E-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VMIN	VFP_SyntaxLookup (VFPpat_11A-VFPtables),(VFPenc_4F-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_11B-VFPtables),(VFPenc_4F-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_11E-VFPtables),(VFPenc_50-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_11F-VFPtables),(VFPenc_50-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C9-VFPtables),(VFPenc_24-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1CA-VFPtables),(VFPenc_24-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1EF-VFPtables),(VFPenc_9E-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F0-VFPtables),(VFPenc_9E-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VMLA	VFP_SyntaxLookup (VFPpat_1A-VFPtables),(VFPenc_52-VFPtables),(VFPdt_06-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1B-VFPtables),(VFPenc_52-VFPtables),(VFPdt_06-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C-VFPtables),(VFPenc_53-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_120-VFPtables),(VFPenc_51-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_121-VFPtables),(VFPenc_51-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_122-VFPtables),(VFPenc_0B-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_123-VFPtables),(VFPenc_0B-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_128-VFPtables),(VFPenc_54-VFPtables),(VFPdt_08-VFPtables),0,(VFPpar_46-VFPtables)
		VFP_SyntaxLookup (VFPpat_129-VFPtables),(VFPenc_54-VFPtables),(VFPdt_09-VFPtables),0,(VFPpar_47-VFPtables)
		VFP_SyntaxLookup (VFPpat_12A-VFPtables),(VFPenc_54-VFPtables),(VFPdt_08-VFPtables),0,(VFPpar_46-VFPtables)
		VFP_SyntaxLookup (VFPpat_12B-VFPtables),(VFPenc_54-VFPtables),(VFPdt_09-VFPtables),0,(VFPpar_47-VFPtables)
		VFP_SyntaxLookup (VFPpat_12C-VFPtables),(VFPenc_55-VFPtables),(VFPdt_0A-VFPtables),0,(VFPpar_46-VFPtables)
		VFP_SyntaxLookup (VFPpat_12D-VFPtables),(VFPenc_55-VFPtables),(VFPdt_0B-VFPtables),0,(VFPpar_47-VFPtables)
		DCW 0
VFPsyn_VMLS	VFP_SyntaxLookup (VFPpat_1D-VFPtables),(VFPenc_52-VFPtables),(VFPdt_06-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E-VFPtables),(VFPenc_52-VFPtables),(VFPdt_06-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1F-VFPtables),(VFPenc_53-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_124-VFPtables),(VFPenc_51-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_125-VFPtables),(VFPenc_51-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_126-VFPtables),(VFPenc_0B-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_127-VFPtables),(VFPenc_0B-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_12E-VFPtables),(VFPenc_54-VFPtables),(VFPdt_08-VFPtables),0,(VFPpar_48-VFPtables)
		VFP_SyntaxLookup (VFPpat_12F-VFPtables),(VFPenc_54-VFPtables),(VFPdt_09-VFPtables),0,(VFPpar_49-VFPtables)
		VFP_SyntaxLookup (VFPpat_130-VFPtables),(VFPenc_54-VFPtables),(VFPdt_08-VFPtables),0,(VFPpar_48-VFPtables)
		VFP_SyntaxLookup (VFPpat_131-VFPtables),(VFPenc_54-VFPtables),(VFPdt_09-VFPtables),0,(VFPpar_49-VFPtables)
		VFP_SyntaxLookup (VFPpat_132-VFPtables),(VFPenc_55-VFPtables),(VFPdt_0A-VFPtables),0,(VFPpar_48-VFPtables)
		VFP_SyntaxLookup (VFPpat_133-VFPtables),(VFPenc_55-VFPtables),(VFPdt_0B-VFPtables),0,(VFPpar_49-VFPtables)
		DCW 0
VFPsyn_VMOV	VFP_SyntaxLookup (VFPpat_3D-VFPtables),(VFPenc_58-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_3E-VFPtables),(VFPenc_59-VFPtables),(VFPdt_0E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_3F-VFPtables),(VFPenc_56-VFPtables),(VFPdt_02-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_40-VFPtables),(VFPenc_56-VFPtables),(VFPdt_02-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_41-VFPtables),(VFPenc_13-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_42-VFPtables),(VFPenc_13-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_43-VFPtables),(VFPenc_14-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_44-VFPtables),(VFPenc_14-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_45-VFPtables),(VFPenc_57-VFPtables),(VFPdt_03-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_46-VFPtables),(VFPenc_57-VFPtables),(VFPdt_03-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_47-VFPtables),(VFPenc_11-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_05-VFPtables)
		VFP_SyntaxLookup (VFPpat_48-VFPtables),(VFPenc_0F-VFPtables),0,0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_49-VFPtables),(VFPenc_0E-VFPtables),0,0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_4A-VFPtables),(VFPenc_10-VFPtables),0,0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_4B-VFPtables),(VFPenc_12-VFPtables),(VFPdt_10-VFPtables),0,(VFPpar_06-VFPtables)
		VFP_SyntaxLookup (VFPpat_4C-VFPtables),(VFPenc_12-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_07-VFPtables)
		VFP_SyntaxLookup (VFPpat_4D-VFPtables),(VFPenc_12-VFPtables),(VFPdt_12-VFPtables),0,(VFPpar_06-VFPtables)
		VFP_SyntaxLookup (VFPpat_4E-VFPtables),(VFPenc_12-VFPtables),(VFPdt_13-VFPtables),0,(VFPpar_07-VFPtables)
		VFP_SyntaxLookup (VFPpat_4F-VFPtables),(VFPenc_12-VFPtables),(VFPdt_14-VFPtables),0,(VFPpar_08-VFPtables)
		VFP_SyntaxLookup (VFPpat_50-VFPtables),(VFPenc_0E-VFPtables),0,0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_51-VFPtables),(VFPenc_0F-VFPtables),0,0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_52-VFPtables),(VFPenc_10-VFPtables),0,0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VMRS	VFP_SyntaxLookup (VFPpat_59-VFPtables),(VFPenc_16-VFPtables),0,0,(VFPpar_0A-VFPtables)
		VFP_SyntaxLookup (VFPpat_5A-VFPtables),(VFPenc_16-VFPtables),0,0,(VFPpar_0A-VFPtables)
		VFP_SyntaxLookup (VFPpat_5C-VFPtables),(VFPenc_16-VFPtables),0,0,0
		DCW 0
VFPsyn_VMSR	VFP_SyntaxLookup (VFPpat_57-VFPtables),(VFPenc_15-VFPtables),0,0,(VFPpar_0A-VFPtables)
		VFP_SyntaxLookup (VFPpat_58-VFPtables),(VFPenc_15-VFPtables),0,0,(VFPpar_0A-VFPtables)
		VFP_SyntaxLookup (VFPpat_5B-VFPtables),(VFPenc_15-VFPtables),0,0,0
		DCW 0
VFPsyn_VMUL	VFP_SyntaxLookup (VFPpat_16-VFPtables),(VFPenc_5A-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_17-VFPtables),(VFPenc_5A-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_18-VFPtables),(VFPenc_0A-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_19-VFPtables),(VFPenc_0A-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_20-VFPtables),(VFPenc_5D-VFPtables),(VFPdt_08-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_21-VFPtables),(VFPenc_5D-VFPtables),(VFPdt_09-VFPtables),0,(VFPpar_03-VFPtables)
		VFP_SyntaxLookup (VFPpat_22-VFPtables),(VFPenc_5D-VFPtables),(VFPdt_08-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_23-VFPtables),(VFPenc_5D-VFPtables),(VFPdt_09-VFPtables),0,(VFPpar_03-VFPtables)
		VFP_SyntaxLookup (VFPpat_24-VFPtables),(VFPenc_5E-VFPtables),(VFPdt_0A-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_25-VFPtables),(VFPenc_5E-VFPtables),(VFPdt_0B-VFPtables),0,(VFPpar_03-VFPtables)
		VFP_SyntaxLookup (VFPpat_26-VFPtables),(VFPenc_5B-VFPtables),(VFPdt_06-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_27-VFPtables),(VFPenc_5B-VFPtables),(VFPdt_0C-VFPtables),0,(VFPpar_04-VFPtables)
		VFP_SyntaxLookup (VFPpat_28-VFPtables),(VFPenc_5B-VFPtables),(VFPdt_06-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_29-VFPtables),(VFPenc_5B-VFPtables),(VFPdt_0C-VFPtables),0,(VFPpar_04-VFPtables)
		VFP_SyntaxLookup (VFPpat_2A-VFPtables),(VFPenc_5C-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_2B-VFPtables),(VFPenc_5C-VFPtables),(VFPdt_0C-VFPtables),0,(VFPpar_04-VFPtables)
		DCW 0
VFPsyn_VMVN	VFP_SyntaxLookup (VFPpat_53-VFPtables),(VFPenc_60-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_09-VFPtables)
		VFP_SyntaxLookup (VFPpat_54-VFPtables),(VFPenc_60-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_09-VFPtables)
		VFP_SyntaxLookup (VFPpat_55-VFPtables),(VFPenc_5F-VFPtables),(VFPdt_04-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_56-VFPtables),(VFPenc_5F-VFPtables),(VFPdt_04-VFPtables),0,0
		DCW 0
VFPsyn_VNEG	VFP_SyntaxLookup (VFPpat_13A-VFPtables),(VFPenc_61-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_13B-VFPtables),(VFPenc_61-VFPtables),(VFPdt_0F-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_13C-VFPtables),(VFPenc_17-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_13D-VFPtables),(VFPenc_17-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VNML	VFP_SyntaxLookup (VFPpat_134-VFPtables),(VFPenc_18-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_135-VFPtables),(VFPenc_18-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_136-VFPtables),(VFPenc_18-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_137-VFPtables),(VFPenc_18-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VNMU	VFP_SyntaxLookup (VFPpat_138-VFPtables),(VFPenc_19-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_139-VFPtables),(VFPenc_19-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VORN	VFP_SyntaxLookup (VFPpat_0E-VFPtables),(VFPenc_62-VFPtables),(VFPdt_04-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_0F-VFPtables),(VFPenc_62-VFPtables),(VFPdt_04-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_12-VFPtables),(VFPenc_63-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_13-VFPtables),(VFPenc_63-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VORR	VFP_SyntaxLookup (VFPpat_0C-VFPtables),(VFPenc_62-VFPtables),(VFPdt_04-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_0D-VFPtables),(VFPenc_62-VFPtables),(VFPdt_04-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_10-VFPtables),(VFPenc_63-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_11-VFPtables),(VFPenc_63-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VPAD	VFP_SyntaxLookup (VFPpat_13E-VFPtables),(VFPenc_64-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_13F-VFPtables),(VFPenc_64-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_140-VFPtables),(VFPenc_65-VFPtables),(VFPdt_06-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_141-VFPtables),(VFPenc_66-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_142-VFPtables),(VFPenc_67-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_143-VFPtables),(VFPenc_67-VFPtables),(VFPdt_07-VFPtables),0,0
		DCW 0
VFPsyn_VPMA	VFP_SyntaxLookup (VFPpat_144-VFPtables),(VFPenc_68-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_146-VFPtables),(VFPenc_69-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VPMI	VFP_SyntaxLookup (VFPpat_145-VFPtables),(VFPenc_68-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_147-VFPtables),(VFPenc_69-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VPOP	VFP_SyntaxLookup (VFPpat_DD-VFPtables),(VFPenc_1A-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_40-VFPtables)
		VFP_SyntaxLookup (VFPpat_DE-VFPtables),(VFPenc_1A-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_41-VFPtables)
		DCW 0
VFPsyn_VPUS	VFP_SyntaxLookup (VFPpat_DB-VFPtables),(VFPenc_1C-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_40-VFPtables)
		VFP_SyntaxLookup (VFPpat_DC-VFPtables),(VFPenc_1C-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_41-VFPtables)
		DCW 0
VFPsyn_VQAB	VFP_SyntaxLookup (VFPpat_148-VFPtables),(VFPenc_6A-VFPtables),(VFPdt_1A-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_149-VFPtables),(VFPenc_6A-VFPtables),(VFPdt_1A-VFPtables),0,0
		DCW 0
VFPsyn_VQAD	VFP_SyntaxLookup (VFPpat_14A-VFPtables),(VFPenc_6B-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_14B-VFPtables),(VFPenc_6B-VFPtables),(VFPdt_1D-VFPtables),0,0
		DCW 0
VFPsyn_VQDM	VFP_SyntaxLookup (VFPpat_14C-VFPtables),(VFPenc_6C-VFPtables),(VFPdt_1E-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_14D-VFPtables),(VFPenc_6D-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_46-VFPtables)
		VFP_SyntaxLookup (VFPpat_14E-VFPtables),(VFPenc_6D-VFPtables),(VFPdt_1F-VFPtables),0,(VFPpar_47-VFPtables)
		VFP_SyntaxLookup (VFPpat_14F-VFPtables),(VFPenc_6C-VFPtables),(VFPdt_1E-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_150-VFPtables),(VFPenc_6D-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_48-VFPtables)
		VFP_SyntaxLookup (VFPpat_151-VFPtables),(VFPenc_6D-VFPtables),(VFPdt_1F-VFPtables),0,(VFPpar_49-VFPtables)
		VFP_SyntaxLookup (VFPpat_152-VFPtables),(VFPenc_6E-VFPtables),(VFPdt_1E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_153-VFPtables),(VFPenc_6E-VFPtables),(VFPdt_1E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_154-VFPtables),(VFPenc_6F-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_155-VFPtables),(VFPenc_6F-VFPtables),(VFPdt_1F-VFPtables),0,(VFPpar_03-VFPtables)
		VFP_SyntaxLookup (VFPpat_156-VFPtables),(VFPenc_6F-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_157-VFPtables),(VFPenc_6F-VFPtables),(VFPdt_1F-VFPtables),0,(VFPpar_03-VFPtables)
		VFP_SyntaxLookup (VFPpat_158-VFPtables),(VFPenc_70-VFPtables),(VFPdt_1E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_159-VFPtables),(VFPenc_71-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_15A-VFPtables),(VFPenc_71-VFPtables),(VFPdt_1F-VFPtables),0,(VFPpar_03-VFPtables)
		DCW 0
VFPsyn_VQMO	VFP_SyntaxLookup (VFPpat_15B-VFPtables),(VFPenc_72-VFPtables),(VFPdt_20-VFPtables),0,(VFPpar_43-VFPtables)
		VFP_SyntaxLookup (VFPpat_15C-VFPtables),(VFPenc_72-VFPtables),(VFPdt_21-VFPtables),0,(VFPpar_42-VFPtables)
		VFP_SyntaxLookup (VFPpat_15D-VFPtables),(VFPenc_72-VFPtables),(VFPdt_20-VFPtables),0,(VFPpar_44-VFPtables)
		DCW 0
VFPsyn_VQNE	VFP_SyntaxLookup (VFPpat_15E-VFPtables),(VFPenc_73-VFPtables),(VFPdt_1A-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_15F-VFPtables),(VFPenc_73-VFPtables),(VFPdt_1A-VFPtables),0,0
		DCW 0
VFPsyn_VQRD	VFP_SyntaxLookup (VFPpat_160-VFPtables),(VFPenc_74-VFPtables),(VFPdt_1E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_161-VFPtables),(VFPenc_74-VFPtables),(VFPdt_1E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_162-VFPtables),(VFPenc_75-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_163-VFPtables),(VFPenc_75-VFPtables),(VFPdt_1F-VFPtables),0,(VFPpar_03-VFPtables)
		VFP_SyntaxLookup (VFPpat_164-VFPtables),(VFPenc_75-VFPtables),(VFPdt_11-VFPtables),0,(VFPpar_02-VFPtables)
		VFP_SyntaxLookup (VFPpat_165-VFPtables),(VFPenc_75-VFPtables),(VFPdt_1F-VFPtables),0,(VFPpar_03-VFPtables)
		DCW 0
VFPsyn_VQRS	VFP_SyntaxLookup (VFPpat_166-VFPtables),(VFPenc_76-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_167-VFPtables),(VFPenc_76-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_168-VFPtables),(VFPenc_77-VFPtables),(VFPdt_22-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_169-VFPtables),(VFPenc_77-VFPtables),(VFPdt_20-VFPtables),0,(VFPpar_4A-VFPtables)
		DCW 0
VFPsyn_VQSH	VFP_SyntaxLookup (VFPpat_16A-VFPtables),(VFPenc_78-VFPtables),(VFPdt_22-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_16B-VFPtables),(VFPenc_78-VFPtables),(VFPdt_20-VFPtables),0,(VFPpar_4A-VFPtables)
		VFP_SyntaxLookup (VFPpat_16C-VFPtables),(VFPenc_79-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_16D-VFPtables),(VFPenc_79-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_16E-VFPtables),(VFPenc_7A-VFPtables),(VFPdt_1D-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_16F-VFPtables),(VFPenc_7A-VFPtables),(VFPdt_1D-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_170-VFPtables),(VFPenc_7A-VFPtables),(VFPdt_23-VFPtables),0,(VFPpar_4A-VFPtables)
		VFP_SyntaxLookup (VFPpat_171-VFPtables),(VFPenc_7A-VFPtables),(VFPdt_23-VFPtables),0,(VFPpar_4A-VFPtables)
		DCW 0
VFPsyn_VQSU	VFP_SyntaxLookup (VFPpat_172-VFPtables),(VFPenc_7B-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_173-VFPtables),(VFPenc_7B-VFPtables),(VFPdt_1D-VFPtables),0,0
		DCW 0
VFPsyn_VRAD	VFP_SyntaxLookup (VFPpat_174-VFPtables),(VFPenc_7C-VFPtables),(VFPdt_0E-VFPtables),0,0
		DCW 0
VFPsyn_VREC	VFP_SyntaxLookup (VFPpat_177-VFPtables),(VFPenc_7F-VFPtables),(VFPdt_24-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_178-VFPtables),(VFPenc_7F-VFPtables),(VFPdt_24-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_179-VFPtables),(VFPenc_80-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_17A-VFPtables),(VFPenc_80-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VREV	VFP_SyntaxLookup (VFPpat_17B-VFPtables),(VFPenc_81-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_43-VFPtables)
		VFP_SyntaxLookup (VFPpat_17C-VFPtables),(VFPenc_81-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_43-VFPtables)
		VFP_SyntaxLookup (VFPpat_17D-VFPtables),(VFPenc_81-VFPtables),(VFPdt_25-VFPtables),0,(VFPpar_44-VFPtables)
		VFP_SyntaxLookup (VFPpat_17E-VFPtables),(VFPenc_81-VFPtables),(VFPdt_25-VFPtables),0,(VFPpar_44-VFPtables)
		VFP_SyntaxLookup (VFPpat_17F-VFPtables),(VFPenc_81-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_4B-VFPtables)
		VFP_SyntaxLookup (VFPpat_180-VFPtables),(VFPenc_81-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_4B-VFPtables)
		DCW 0
VFPsyn_VRHA	VFP_SyntaxLookup (VFPpat_181-VFPtables),(VFPenc_82-VFPtables),(VFPdt_07-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_182-VFPtables),(VFPenc_82-VFPtables),(VFPdt_07-VFPtables),0,0
		DCW 0
VFPsyn_VRIN	VFP_SyntaxLookup (VFPpat_1DB-VFPtables),(VFPenc_26-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_68-VFPtables)
		VFP_SyntaxLookup (VFPpat_1DC-VFPtables),(VFPenc_26-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_68-VFPtables)
		VFP_SyntaxLookup (VFPpat_1DD-VFPtables),(VFPenc_26-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_69-VFPtables)
		VFP_SyntaxLookup (VFPpat_1DE-VFPtables),(VFPenc_26-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_69-VFPtables)
		VFP_SyntaxLookup (VFPpat_1DF-VFPtables),(VFPenc_26-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_6A-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E0-VFPtables),(VFPenc_26-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_6A-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E1-VFPtables),(VFPenc_26-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_6B-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E2-VFPtables),(VFPenc_26-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_6B-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E3-VFPtables),(VFPenc_27-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E4-VFPtables),(VFPenc_27-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E5-VFPtables),(VFPenc_27-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E6-VFPtables),(VFPenc_27-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_1E7-VFPtables),(VFPenc_28-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_1E8-VFPtables),(VFPenc_28-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_201-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_70-VFPtables)
		VFP_SyntaxLookup (VFPpat_202-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_70-VFPtables)
		VFP_SyntaxLookup (VFPpat_203-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_71-VFPtables)
		VFP_SyntaxLookup (VFPpat_204-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_71-VFPtables)
		VFP_SyntaxLookup (VFPpat_205-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_72-VFPtables)
		VFP_SyntaxLookup (VFPpat_206-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_72-VFPtables)
		VFP_SyntaxLookup (VFPpat_207-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_73-VFPtables)
		VFP_SyntaxLookup (VFPpat_208-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_73-VFPtables)
		VFP_SyntaxLookup (VFPpat_209-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_74-VFPtables)
		VFP_SyntaxLookup (VFPpat_20A-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_74-VFPtables)
		VFP_SyntaxLookup (VFPpat_20B-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_75-VFPtables)
		VFP_SyntaxLookup (VFPpat_20C-VFPtables),(VFPenc_A0-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_75-VFPtables)
		DCW 0
VFPsyn_VRSH	VFP_SyntaxLookup (VFPpat_183-VFPtables),(VFPenc_83-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_184-VFPtables),(VFPenc_83-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_185-VFPtables),(VFPenc_84-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_186-VFPtables),(VFPenc_84-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_187-VFPtables),(VFPenc_85-VFPtables),(VFPdt_26-VFPtables),0,0
		DCW 0
VFPsyn_VRSQ	VFP_SyntaxLookup (VFPpat_188-VFPtables),(VFPenc_86-VFPtables),(VFPdt_24-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_189-VFPtables),(VFPenc_86-VFPtables),(VFPdt_24-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_18A-VFPtables),(VFPenc_87-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_18B-VFPtables),(VFPenc_87-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VRSR	VFP_SyntaxLookup (VFPpat_18C-VFPtables),(VFPenc_88-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_18D-VFPtables),(VFPenc_88-VFPtables),(VFPdt_1D-VFPtables),0,0
		DCW 0
VFPsyn_VRSU	VFP_SyntaxLookup (VFPpat_175-VFPtables),(VFPenc_7D-VFPtables),(VFPdt_0E-VFPtables),0,0
		DCW 0
VFPsyn_VSEL	VFP_SyntaxLookup (VFPpat_1BF-VFPtables),(VFPenc_23-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5C-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C0-VFPtables),(VFPenc_23-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_5C-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C1-VFPtables),(VFPenc_23-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5D-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C2-VFPtables),(VFPenc_23-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_5D-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C3-VFPtables),(VFPenc_23-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5E-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C4-VFPtables),(VFPenc_23-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_5E-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C5-VFPtables),(VFPenc_23-VFPtables),(VFPdt_01-VFPtables),0,(VFPpar_5F-VFPtables)
		VFP_SyntaxLookup (VFPpat_1C6-VFPtables),(VFPenc_23-VFPtables),(VFPdt_00-VFPtables),0,(VFPpar_5F-VFPtables)
		DCW 0
VFPsyn_VSHL	VFP_SyntaxLookup (VFPpat_18E-VFPtables),(VFPenc_89-VFPtables),(VFPdt_0D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_18F-VFPtables),(VFPenc_89-VFPtables),(VFPdt_0D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_190-VFPtables),(VFPenc_8A-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_191-VFPtables),(VFPenc_8A-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_192-VFPtables),(VFPenc_8C-VFPtables),(VFPdt_27-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_193-VFPtables),(VFPenc_8C-VFPtables),(VFPdt_08-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_194-VFPtables),(VFPenc_8C-VFPtables),(VFPdt_28-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_195-VFPtables),(VFPenc_8B-VFPtables),(VFPdt_07-VFPtables),0,0
		DCW 0
VFPsyn_VSHR	VFP_SyntaxLookup (VFPpat_196-VFPtables),(VFPenc_8D-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_197-VFPtables),(VFPenc_8D-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_198-VFPtables),(VFPenc_8E-VFPtables),(VFPdt_0E-VFPtables),0,0
		DCW 0
VFPsyn_VSLI	VFP_SyntaxLookup (VFPpat_199-VFPtables),(VFPenc_8F-VFPtables),(VFPdt_17-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_19A-VFPtables),(VFPenc_8F-VFPtables),(VFPdt_17-VFPtables),0,0
		DCW 0
VFPsyn_VSQR	VFP_SyntaxLookup (VFPpat_02-VFPtables),(VFPenc_0D-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_03-VFPtables),(VFPenc_0D-VFPtables),(VFPdt_00-VFPtables),0,0
		DCW 0
VFPsyn_VSRA	VFP_SyntaxLookup (VFPpat_19B-VFPtables),(VFPenc_90-VFPtables),(VFPdt_1D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_19C-VFPtables),(VFPenc_90-VFPtables),(VFPdt_1D-VFPtables),0,0
		DCW 0
VFPsyn_VSRI	VFP_SyntaxLookup (VFPpat_19D-VFPtables),(VFPenc_91-VFPtables),(VFPdt_17-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_19E-VFPtables),(VFPenc_91-VFPtables),(VFPdt_17-VFPtables),0,0
		DCW 0
VFPsyn_VST1	VFP_SyntaxLookup (VFPpat_A9-VFPtables),(VFPenc_92-VFPtables),(VFPdt_17-VFPtables),(VFPali_00-VFPtables),(VFPpar_20-VFPtables)
		VFP_SyntaxLookup (VFPpat_AA-VFPtables),(VFPenc_92-VFPtables),(VFPdt_17-VFPtables),(VFPali_01-VFPtables),(VFPpar_21-VFPtables)
		VFP_SyntaxLookup (VFPpat_AB-VFPtables),(VFPenc_92-VFPtables),(VFPdt_17-VFPtables),(VFPali_00-VFPtables),(VFPpar_22-VFPtables)
		VFP_SyntaxLookup (VFPpat_AC-VFPtables),(VFPenc_92-VFPtables),(VFPdt_17-VFPtables),(VFPali_02-VFPtables),(VFPpar_23-VFPtables)
		VFP_SyntaxLookup (VFPpat_BC-VFPtables),(VFPenc_93-VFPtables),(VFPdt_05-VFPtables),(VFPali_03-VFPtables),(VFPpar_2B-VFPtables)
		DCW 0
VFPsyn_VST2	VFP_SyntaxLookup (VFPpat_B0-VFPtables),(VFPenc_92-VFPtables),(VFPdt_05-VFPtables),(VFPali_01-VFPtables),(VFPpar_24-VFPtables)
		VFP_SyntaxLookup (VFPpat_B1-VFPtables),(VFPenc_92-VFPtables),(VFPdt_05-VFPtables),(VFPali_01-VFPtables),(VFPpar_25-VFPtables)
		VFP_SyntaxLookup (VFPpat_B2-VFPtables),(VFPenc_92-VFPtables),(VFPdt_05-VFPtables),(VFPali_02-VFPtables),(VFPpar_26-VFPtables)
		VFP_SyntaxLookup (VFPpat_BE-VFPtables),(VFPenc_93-VFPtables),(VFPdt_05-VFPtables),(VFPali_04-VFPtables),(VFPpar_2C-VFPtables)
		VFP_SyntaxLookup (VFPpat_C0-VFPtables),(VFPenc_93-VFPtables),(VFPdt_18-VFPtables),(VFPali_05-VFPtables),(VFPpar_2D-VFPtables)
		DCW 0
VFPsyn_VST3	VFP_SyntaxLookup (VFPpat_B5-VFPtables),(VFPenc_92-VFPtables),(VFPdt_05-VFPtables),(VFPali_00-VFPtables),(VFPpar_27-VFPtables)
		VFP_SyntaxLookup (VFPpat_B6-VFPtables),(VFPenc_92-VFPtables),(VFPdt_05-VFPtables),(VFPali_00-VFPtables),(VFPpar_28-VFPtables)
		VFP_SyntaxLookup (VFPpat_C2-VFPtables),(VFPenc_93-VFPtables),(VFPdt_05-VFPtables),0,(VFPpar_2E-VFPtables)
		VFP_SyntaxLookup (VFPpat_C4-VFPtables),(VFPenc_93-VFPtables),(VFPdt_18-VFPtables),0,(VFPpar_2F-VFPtables)
		DCW 0
VFPsyn_VST4	VFP_SyntaxLookup (VFPpat_B9-VFPtables),(VFPenc_92-VFPtables),(VFPdt_05-VFPtables),(VFPali_02-VFPtables),(VFPpar_29-VFPtables)
		VFP_SyntaxLookup (VFPpat_BA-VFPtables),(VFPenc_92-VFPtables),(VFPdt_05-VFPtables),(VFPali_02-VFPtables),(VFPpar_2A-VFPtables)
		VFP_SyntaxLookup (VFPpat_C6-VFPtables),(VFPenc_93-VFPtables),(VFPdt_05-VFPtables),(VFPali_06-VFPtables),(VFPpar_30-VFPtables)
		VFP_SyntaxLookup (VFPpat_C8-VFPtables),(VFPenc_93-VFPtables),(VFPdt_18-VFPtables),(VFPali_07-VFPtables),(VFPpar_31-VFPtables)
		DCW 0
VFPsyn_VSTM	VFP_SyntaxLookup (VFPpat_D7-VFPtables),(VFPenc_1E-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_3C-VFPtables)
		VFP_SyntaxLookup (VFPpat_D8-VFPtables),(VFPenc_1E-VFPtables),(VFPdt_19-VFPtables),0,(VFPpar_3D-VFPtables)
		VFP_SyntaxLookup (VFPpat_D9-VFPtables),(VFPenc_1E-VFPtables),(VFPdt_14-VFPtables),0,(VFPpar_3E-VFPtables)
		VFP_SyntaxLookup (VFPpat_DA-VFPtables),(VFPenc_1E-VFPtables),(VFPdt_14-VFPtables),0,(VFPpar_3F-VFPtables)
		DCW 0
VFPsyn_VSTR	VFP_SyntaxLookup (VFPpat_E3-VFPtables),(VFPenc_20-VFPtables),0,0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_E4-VFPtables),(VFPenc_20-VFPtables),0,0,(VFPpar_01-VFPtables)
		VFP_SyntaxLookup (VFPpat_E5-VFPtables),(VFPenc_20-VFPtables),0,0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_E6-VFPtables),(VFPenc_20-VFPtables),0,0,(VFPpar_00-VFPtables)
		DCW 0
VFPsyn_VSUB	VFP_SyntaxLookup (VFPpat_35-VFPtables),(VFPenc_94-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_36-VFPtables),(VFPenc_94-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_37-VFPtables),(VFPenc_1F-VFPtables),(VFPdt_01-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_38-VFPtables),(VFPenc_1F-VFPtables),(VFPdt_00-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_176-VFPtables),(VFPenc_7E-VFPtables),(VFPdt_0E-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_19F-VFPtables),(VFPenc_95-VFPtables),(VFPdt_0D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_1A0-VFPtables),(VFPenc_95-VFPtables),(VFPdt_0D-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_1A1-VFPtables),(VFPenc_96-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_00-VFPtables)
		VFP_SyntaxLookup (VFPpat_1A2-VFPtables),(VFPenc_96-VFPtables),(VFPdt_07-VFPtables),0,(VFPpar_01-VFPtables)
		DCW 0
VFPsyn_VSWP	VFP_SyntaxLookup (VFPpat_1A3-VFPtables),(VFPenc_97-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_09-VFPtables)
		VFP_SyntaxLookup (VFPpat_1A4-VFPtables),(VFPenc_97-VFPtables),(VFPdt_03-VFPtables),0,(VFPpar_09-VFPtables)
		DCW 0
VFPsyn_VTBL	VFP_SyntaxLookup (VFPpat_1A5-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_4C-VFPtables)
		VFP_SyntaxLookup (VFPpat_1A6-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_4D-VFPtables)
		VFP_SyntaxLookup (VFPpat_1A7-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_4E-VFPtables)
		VFP_SyntaxLookup (VFPpat_1A8-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_4F-VFPtables)
		DCW 0
VFPsyn_VTBX	VFP_SyntaxLookup (VFPpat_1A9-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_50-VFPtables)
		VFP_SyntaxLookup (VFPpat_1AA-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_51-VFPtables)
		VFP_SyntaxLookup (VFPpat_1AB-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_52-VFPtables)
		VFP_SyntaxLookup (VFPpat_1AC-VFPtables),(VFPenc_98-VFPtables),(VFPdt_1B-VFPtables),0,(VFPpar_53-VFPtables)
		DCW 0
VFPsyn_VTRN	VFP_SyntaxLookup (VFPpat_1AD-VFPtables),(VFPenc_99-VFPtables),(VFPdt_05-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_1AE-VFPtables),(VFPenc_99-VFPtables),(VFPdt_05-VFPtables),0,0
		DCW 0
VFPsyn_VTST	VFP_SyntaxLookup (VFPpat_14-VFPtables),(VFPenc_9A-VFPtables),(VFPdt_05-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_15-VFPtables),(VFPenc_9A-VFPtables),(VFPdt_05-VFPtables),0,0
		DCW 0
VFPsyn_VUZP	VFP_SyntaxLookup (VFPpat_1AF-VFPtables),(VFPenc_9B-VFPtables),(VFPdt_05-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_1B0-VFPtables),(VFPenc_9B-VFPtables),(VFPdt_05-VFPtables),0,0
		DCW 0
VFPsyn_VZIP	VFP_SyntaxLookup (VFPpat_1B1-VFPtables),(VFPenc_9C-VFPtables),(VFPdt_05-VFPtables),0,0
		VFP_SyntaxLookup (VFPpat_1B2-VFPtables),(VFPenc_9C-VFPtables),(VFPdt_05-VFPtables),0,0
		DCW 0
		ALIGN

  ]
		END
