/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
#include "dis2.h"

/* This file has the generated disassembler source appended to it */
typedef struct {
	uint8_t dis2_argf_0_4;
	uint8_t dis2_argf_0_4_5_1;
	uint8_t dis2_argf_0_8;
	uint8_t dis2_argf_10_1;
	uint8_t dis2_argf_10_2;
	uint8_t dis2_argf_12_4;
	uint8_t dis2_argf_12_4_22_1;
	uint8_t dis2_argf_16_1;
	uint8_t dis2_argf_16_2;
	uint8_t dis2_argf_16_3;
	uint8_t dis2_argf_16_4;
	uint8_t dis2_argf_16_4_0_4;
	uint8_t dis2_argf_16_4_7_1;
	uint8_t dis2_argf_16_6;
	uint8_t dis2_argf_18_1;
	uint8_t dis2_argf_18_2;
	uint8_t dis2_argf_19_3;
	uint8_t dis2_argf_20_1;
	uint8_t dis2_argf_20_2;
	uint8_t dis2_argf_21_1;
	uint8_t dis2_argf_21_2;
	uint8_t dis2_argf_22_1;
	uint8_t dis2_argf_22_1_12_4;
	uint8_t dis2_argf_23_1;
	uint8_t dis2_argf_24_1;
	uint8_t dis2_argf_24_1_16_3_0_4;
	uint8_t dis2_argf_28_4;
	uint8_t dis2_argf_4_1;
	uint8_t dis2_argf_4_2;
	uint8_t dis2_argf_4_4;
	uint8_t dis2_argf_5_1;
	uint8_t dis2_argf_5_1_0_4;
	uint8_t dis2_argf_5_2;
	uint8_t dis2_argf_6_1;
	uint8_t dis2_argf_6_2;
	uint8_t dis2_argf_7_1;
	uint8_t dis2_argf_7_1_16_4;
	uint8_t dis2_argf_7_2;
	uint8_t dis2_argf_7_3;
	uint8_t dis2_argf_8_1;
	uint8_t dis2_argf_8_1_24_1;
	uint8_t dis2_argf_8_2;
	uint8_t dis2_argf_8_4;
	uint8_t dis2_argf_9_1;
	uint32_t dis2_argn_100_0;
	uint32_t dis2_argn_2f_0;
	uint32_t dis2_argn_6f_0;
	uint32_t dis2_argn_a0_0;
	uint32_t dis2_argn_ef_0;
	uint32_t dis2_argn_f_0;
} dis2_argstruct;
static RETURNTYPE dis2_leaf_UNDEFINED_0x87078(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_UNDEFINED_0x87078(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)0000(op:4)(:12)1001(:4) {ne(cond,0xf)} {lor(eq(op,0x5),eq(op,0x7))} UNDEFINED
     (cond:4)1100010L(RdHi:4)(RdLo:4)0000(0000)(0)(acc:3) {ne(cond,0xf)} {L} MRA (as UNDEFINED)
     (cond:4)1100010L(RdHi:4)(RdLo:4)0000(0000)(0)(acc:3) {ne(cond,0xf)} {lnot(L)} MAR (as UNDEFINED)
     (cond:4)1110001011xy(Rs:4)0000(acc:3)1(Rm:4) {ne(cond,0xf)} MIAxy (as UNDEFINED)
     (cond:4)11100010(opcode_3:4)(Rs:4)0000(acc:3)1(Rm:4) {ne(cond,0xf)} {eq(opcode_3,0x8)} MIAPH (as UNDEFINED)
     (cond:4)11100010(opcode_3:4)(Rs:4)0000(acc:3)1(Rm:4) {ne(cond,0xf)} {eq(opcode_3,0x0)} MIA (as UNDEFINED)
     (cond:4)11100010(opcode_3:4)(Rs:4)0000(acc:3)1(Rm:4) {ne(cond,0xf)} {lnot(eq(opcode_3,0x0))} {lnot(eq(opcode_3,0x8))} {lnot(eq(opcode<19:18>,0x3))} UNPREDICTABLE_DSP (as UNDEFINED)
     (cond:4)11101(cd:2)1(e)(Fn:3)(Rd:4)0001(fgh:3)1(i)(Fm:3) {ne(cond,0xf)} {ne(Rd,0xf)} UNDEFINED
     (cond:4)11101111(0)(Fn:3)11110001(000)1(i)(Fm:3) {ne(cond,0xf)} CNFE (as UNDEFINED)
     (cond:4)11101101(0)(Fn:3)11110001(000)1(i)(Fm:3) {ne(cond,0xf)} CMFE (as UNDEFINED)
     (cond:4)11101011(0)(Fn:3)11110001(000)1(i)(Fm:3) {ne(cond,0xf)} CNF (as UNDEFINED)
     (cond:4)11101001(0)(Fn:3)11110001(000)1(i)(Fm:3) {ne(cond,0xf)} CMF (as UNDEFINED)
     (cond:4)11101(bc:2)0(0)(Fn:3)(Rd:4)0001(0)(00)1(i)(Fm:3) {ne(cond,0xf)} UNDEFINED
     (cond:4)1110011(LS)(0)(Fn:3)(Rd:4)0001(0)(00)1(i)(Fm:3) {ne(cond,0xf)} UNDEFINED
     (cond:4)11100101(0)(000)(Rd:4)0001(0)(00)1(0)(000) {ne(cond,0xf)} RFC (as UNDEFINED)
     (cond:4)11100100(0)(000)(Rd:4)0001(0)(00)1(0)(000) {ne(cond,0xf)} WFC (as UNDEFINED)
     (cond:4)11100011(0)(000)(Rd:4)0001(0)(00)1(0)(000) {ne(cond,0xf)} RFS (as UNDEFINED)
     (cond:4)11100010(0)(000)(Rd:4)0001(0)(00)1(0)(000) {ne(cond,0xf)} WFS (as UNDEFINED)
     (cond:4)11100001(0)(000)(Rd:4)0001(0)(gh:2)1(0)(Fm:3) {ne(cond,0xf)} FIX (as UNDEFINED)
     (cond:4)11100000(e)(Fn:3)(Rd:4)0001(f)(gh:2)1(0)(000) {ne(cond,0xf)} {e} {f} UNDEFINED
     (cond:4)11100000(e)(Fn:3)(Rd:4)0001(f)(gh:2)1(0)(000) {ne(cond,0xf)} {lnot(land(e,f))} FLT (as UNDEFINED)
     (cond:4)11101111(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} NRM (as UNDEFINED)
     (cond:4)11101110(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} URD (as UNDEFINED)
     (cond:4)11101101(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} ATN (as UNDEFINED)
     (cond:4)11101100(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} ACS (as UNDEFINED)
     (cond:4)11101011(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} ASN (as UNDEFINED)
     (cond:4)11101010(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} TAN (as UNDEFINED)
     (cond:4)11101001(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} COS (as UNDEFINED)
     (cond:4)11101000(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} SIN (as UNDEFINED)
     (cond:4)11100111(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} EXP (as UNDEFINED)
     (cond:4)11100110(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} LGN (as UNDEFINED)
     (cond:4)11100101(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} LOG (as UNDEFINED)
     (cond:4)11100100(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} SQT (as UNDEFINED)
     (cond:4)11100011(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} RND (as UNDEFINED)
     (cond:4)11100010(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} ABS (as UNDEFINED)
     (cond:4)11100001(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} MNF (as UNDEFINED)
     (cond:4)11100000(e)(000)1(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} MVF (as UNDEFINED)
     (cond:4)1110(abcd:4)(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} {gt(abcd,0xc)} UNDEFINED
     (cond:4)11101100(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} POL (as UNDEFINED)
     (cond:4)11101011(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} FRD (as UNDEFINED)
     (cond:4)11101010(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} FDV (as UNDEFINED)
     (cond:4)11101001(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} FML (as UNDEFINED)
     (cond:4)11101000(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} RMF (as UNDEFINED)
     (cond:4)11100111(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} RPW (as UNDEFINED)
     (cond:4)11100110(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} POW (as UNDEFINED)
     (cond:4)11100101(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} RDF (as UNDEFINED)
     (cond:4)11100100(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} DVF (as UNDEFINED)
     (cond:4)11100011(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} RSF (as UNDEFINED)
     (cond:4)11100010(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} SUF (as UNDEFINED)
     (cond:4)11100001(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} MUF (as UNDEFINED)
     (cond:4)11100000(e)(Fn:3)0(Fd:3)0001(f)(gh:2)0(i)(Fm:3) {ne(cond,0xf)} {lnot(land(e,f))} ADF (as UNDEFINED)
     (cond:4)1110(abcd:4)1(Fn:3)(j)(Fd:3)00011(gh:2)0(i)(Fm:3) {ne(cond,0xf)} UNDEFINED
     (cond:4)110P(UD)(N1)(Wb)(LS)(Rn:4)(N0)(Fd:3)0010(offset:8) {ne(cond,0xf)} {lnot(P)} {lnot(Wb)} UNDEFINED
     (cond:4)110P(UD)(N1)(Wb)(LS)(Rn:4)(N0)(Fd:3)0010(offset:8) {ne(cond,0xf)} {lor(P,Wb)} LFM_SFM (as UNDEFINED)
     (cond:4)110P(UD)(T1)(Wb)(LS)(Rn:4)(T0)(Fd:3)0001(offset:8) {ne(cond,0xf)} {lnot(P)} {lnot(Wb)} UNDEFINED
     (cond:4)110P(UD)(T1)(Wb)(LS)(Rn:4)(T0)(Fd:3)0001(offset:8) {ne(cond,0xf)} {lor(P,Wb)} LDF_STF (as UNDEFINED)
     (cond:4)00011111(Rn:4)(Rt:4)(11)111001(1111) {ne(cond,0xf)} LDREXH_A1 (as UNDEFINED)
     (cond:4)00011011(Rn:4)(Rt:4)(11)111001(1111) {ne(cond,0xf)} LDREXD_A1 (as UNDEFINED)
     (cond:4)00011101(Rn:4)(Rt:4)(11)111001(1111) {ne(cond,0xf)} LDREXB_A1 (as UNDEFINED)
     (cond:4)00011001(Rn:4)(Rt:4)(11)111001(1111) {ne(cond,0xf)} LDREX_A1 (as UNDEFINED)
     (cond:4)00011110(Rn:4)(Rd:4)(11)111001(Rt:4) {ne(cond,0xf)} STREXH_A1 (as UNDEFINED)
     (cond:4)00011010(Rn:4)(Rd:4)(11)111001(Rt:4) {ne(cond,0xf)} STREXD_A1 (as UNDEFINED)
     (cond:4)00011100(Rn:4)(Rd:4)(11)111001(Rt:4) {ne(cond,0xf)} STREXB_A1 (as UNDEFINED)
     (cond:4)00011000(Rn:4)(Rd:4)(11)111001(Rt:4) {ne(cond,0xf)} STREX_A1 (as UNDEFINED)
     (cond:4)0001(op:4)(:8)(11)(op1:2)1001(:4) {ne(cond,0xf)} {ge(op,0xc)} {eq(op1,0x1)} UNDEFINED
     (cond:4)0001(op:4)(:8)(11)(op1:2)1001(:4) {ne(cond,0xf)} {lor(eq(op,0xa),eq(op,0xb))} {lnot(band(op1,0x2))} UNDEFINED
     (cond:4)0001(op:4)(:8)(11)(op1:2)1001(:4) {ne(cond,0xf)} {lor(eq(op,0x8),eq(op,0x9))} {eq(op1,0x1)} UNDEFINED
     (cond:4)00010(sz:2)0(Rn:4)(Rd:4)(0)(0)C(0)0(op2:3)(Rm:4) {ne(cond,0xf)} {eq(op2,0x4)} CRC_A1 (as UNDEFINED)
     (cond:4)001100100000(11110000)00000101 {ne(cond,0xf)} SEVL_A1 (as UNDEFINED)
     (cond:4)00010(op:2)0(imm12:12)0(op2:3)(imm4:4) {ne(cond,0xf)} {eq(op2,0x7)} {lnot(op)} HLT_A1 (as UNDEFINED)
     (cond:4)00011110(Rn:4)(Rd:4)(11)101001(Rt:4) {ne(cond,0xf)} STLEXH_A1 (as UNDEFINED)
     (cond:4)00011100(Rn:4)(Rd:4)(11)101001(Rt:4) {ne(cond,0xf)} STLEXB_A1 (as UNDEFINED)
     (cond:4)00011010(Rn:4)(Rd:4)(11)101001(Rt:4) {ne(cond,0xf)} STLEXD_A1 (as UNDEFINED)
     (cond:4)00011000(Rn:4)(Rd:4)(11)101001(Rt:4) {ne(cond,0xf)} STLEX_A1 (as UNDEFINED)
     (cond:4)00011111(Rn:4)(Rt:4)(11)101001(1111) {ne(cond,0xf)} LDAEXH_A1 (as UNDEFINED)
     (cond:4)00011101(Rn:4)(Rt:4)(11)101001(1111) {ne(cond,0xf)} LDAEXB_A1 (as UNDEFINED)
     (cond:4)00011011(Rn:4)(Rt:4)(11)101001(1111) {ne(cond,0xf)} LDAEXD_A1 (as UNDEFINED)
     (cond:4)00011001(Rn:4)(Rt:4)(11)101001(1111) {ne(cond,0xf)} LDAEX_A1 (as UNDEFINED)
     (cond:4)00011(sz:2)0(Rn:4)(1111)(11)001001(Rt:4) {ne(cond,0xf)} {ne(sz,0x1)} STL_A1 (as UNDEFINED)
     (cond:4)00011(sz:2)1(Rn:4)(Rt:4)(11)001001(1111) {ne(cond,0xf)} {ne(sz,0x1)} LDA_A1 (as UNDEFINED)
     111100111D11(size:2)10(Vd:4)01011QM0(Vm:4) {lor(land(Q,lor(band(Vd,0x1),band(Vm,0x1))),ne(size,0x2))} UNDEFINED
     111100111D11(size:2)10(Vd:4)01001QM0(Vm:4) {lor(land(Q,lor(band(Vd,0x1),band(Vm,0x1))),ne(size,0x2))} UNDEFINED
     111100111D11(size:2)10(Vd:4)01(op:3)QM0(Vm:4) {Q} {lor(eq(op,0x4),eq(op,0x6))} UNDEFINED
     111100111D11(size:2)10(Vd:4)01(op:3)QM0(Vm:4) {lor(lnot(band(op,0x5)),eq(band(op,0x5),0x5))} {lor(land(Q,lor(band(Vd,0x1),band(Vm,0x1))),ne(size,0x2))} UNDEFINED
     111100111D11(size:2)11(Vd:4)00(RM:2)(op)QM0(Vm:4) {lor(ne(size,0x2),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100110D(op)(sz)(Vn:4)(Vd:4)1111NQM1(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),sz)} UNDEFINED
     111100111D11(size:2)10(Vd:4)00011QM0(Vm:4) {lor(lor(eq(size,0x3),land(lnot(Q),eq(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)10(Vd:4)00010QM0(Vm:4) {lor(lor(eq(size,0x3),land(lnot(Q),eq(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100100D(size:2)(Vn:4)(Vd:4)1000NQM1(Vm:4) {lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100111D11(size:2)10(Vd:4)00001QM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)10(Vd:4)00000QM0(Vm:4) {lor(size,band(Q,bor(Vd,Vm)))} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)001(op)N0M0(Vm:4) {ne(size,0x3)} {band(bor(Vd,band(op,Vn)),0x1)} UNDEFINED
     111100101D(size:2)(Vn:4)(Vd:4)0110N0M0(Vm:4) {ne(size,0x3)} {band(bor(Vn,Vm),0x1)} UNDEFINED
     111100100D1(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),sz)} UNDEFINED
     111100110D(size:2)(Vn:4)(Vd:4)1000NQM0(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     111101001D00(Rn:4)(Vd:4)(size:2)11(index_align:4)(Rm:4) {lor(eq(size,0x3),land(eq(size,0x2),eq(band(index_align,0x3),0x3)))} UNDEFINED
     111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lt(type,0x2)} {eq(size,0x3)} UNDEFINED
     111101001D00(Rn:4)(Vd:4)(size:2)10(index_align:4)(Rm:4) {lor(eq(size,0x3),lor(band(index_align,0x1),land(eq(size,0x2),band(index_align,0x3))))} UNDEFINED
     111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(band(type,0xe),0x4)} {lor(eq(size,0x3),band(align,0x2))} UNDEFINED
     111101001D00(Rn:4)(Vd:4)(size:2)01(index_align:4)(Rm:4) {lor(eq(size,0x3),land(eq(size,0x2),band(index_align,0x2)))} UNDEFINED
     111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lor(eq(band(type,0xe),0x8),eq(type,0x3))} {lor(eq(size,0x3),land(eq(band(type,0xe),0x8),eq(align,0x3)))} UNDEFINED
     111101001D00(Rn:4)(Vd:4)(size:2)00(index_align:4)(Rm:4) {lor(eq(size,0x3),lor(band(index_align,lsl(0x1,size)),land(eq(size,0x2),leor(band(index_align,0x1),band(index_align,0x2)))))} UNDEFINED
     111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lor(land(eq(band(type,0xe),0x6),band(align,0x2)),land(eq(type,0xa),eq(align,0x3)))} UNDEFINED
     111100111D(imm6:6)(Vd:4)0100LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {band(Q,bor(Vd,Vm))} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)0001LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {band(Q,bor(Vd,Vm))} UNDEFINED
     111100111D(imm6:6)(Vd:4)0101LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {band(Q,bor(Vd,Vm))} UNDEFINED
     111100101D(imm6:6)(Vd:4)100000M1(Vm:4) {gt(imm6,0x7)} {band(Vm,0x1)} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)0000LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {band(Q,bor(Vd,Vm))} UNDEFINED
     111100111D11(size:2)10(Vd:4)001100M0(Vm:4) {lor(eq(size,0x3),band(Vd,0x1))} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)101000M1(Vm:4) {gt(imm6,0x7)} {lnot(ispow2(imm6))} {band(Vd,0x1)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0100NQM0(Vm:4) {band(Q,bor(bor(Vd,Vm),Vn))} UNDEFINED
     111100101D(imm6:6)(Vd:4)0101LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {band(Q,bor(Vd,Vm))} UNDEFINED
     111100111D(size:2)(Vn:4)(Vd:4)0110N0M0(Vm:4) {ne(size,0x3)} {band(bor(Vn,Vm),0x1)} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)0011LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {band(Q,bor(Vd,Vm))} UNDEFINED
     111100100D1(sz)(Vn:4)(Vd:4)1111NQM1(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),sz)} UNDEFINED
     111100111D11(size:2)11(Vd:4)010F1QM0(Vm:4) {lor(band(Q,bor(Vd,Vm)),ne(size,0x2))} UNDEFINED
     111100101D(imm6:6)(Vd:4)100001M1(Vm:4) {gt(imm6,0x7)} {band(Vm,0x1)} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)0010LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {band(Q,bor(Vd,Vm))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0101NQM0(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0001NQM0(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3))} UNDEFINED
     111100111D11(size:2)00(Vd:4)000(op:2)QM0(Vm:4) {lor(ge(add(op,size),0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100100D0(sz)(Vn:4)(Vd:4)1111NQM1(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),sz)} UNDEFINED
     111100111D11(size:2)11(Vd:4)010F0QM0(Vm:4) {lor(band(Q,bor(Vd,Vm)),ne(size,0x2))} UNDEFINED
     111100111D(size:2)(Vn:4)(Vd:4)0100N0M0(Vm:4) {ne(size,0x3)} {band(bor(Vn,Vm),0x1)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0010NQM1(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)100(op)00M1(Vm:4) {gt(imm6,0x7)} {lor(U,op)} {band(Vm,0x1)} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)011(op)LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lor(lnot(lor(U,op)),band(Q,bor(Vd,Vm)))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0100NQM1(Vm:4) {band(Q,bor(bor(Vd,Vm),Vn))} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)100(op)01M1(Vm:4) {gt(imm6,0x7)} {lor(U,op)} {band(Vm,0x1)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0101NQM1(Vm:4) {band(Q,bor(bor(Vd,Vm),Vn))} UNDEFINED
     1111001Q1D(size:2)(Vn:4)(Vd:4)1101N1M0(Vm:4) {ne(size,0x3)} {lor(band(Q,bor(Vd,Vn)),lnot(size))} UNDEFINED
     111100110D(size:2)(Vn:4)(Vd:4)1011NQM0(Vm:4) {lor(lor(band(Q,bor(bor(Vd,Vn),Vm)),lnot(size)),eq(size,0x3))} UNDEFINED
     111100111D11(size:2)00(Vd:4)01111QM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)10(Vd:4)0010(op:2)M0(Vm:4) {op} {lor(eq(size,0x3),band(Vm,0x1))} UNDEFINED
     111100101D(size:2)(Vn:4)(Vd:4)1011N1M0(Vm:4) {ne(size,0x3)} {lor(lnot(size),band(Vd,0x1))} UNDEFINED
     111100101D(size:2)(Vn:4)(Vd:4)1101N0M0(Vm:4) {ne(size,0x3)} {lor(lnot(size),band(Vd,0x1))} UNDEFINED
     1111001Q1D(size:2)(Vn:4)(Vd:4)1100N1M0(Vm:4) {ne(size,0x3)} {lor(band(Q,bor(Vd,Vn)),lnot(size))} UNDEFINED
     111100100D(size:2)(Vn:4)(Vd:4)1011NQM0(Vm:4) {lor(lor(band(Q,bor(bor(Vd,Vn),Vm)),lnot(size)),eq(size,0x3))} UNDEFINED
     111100101D(size:2)(Vn:4)(Vd:4)0(op)11N1M0(Vm:4) {ne(size,0x3)} {lor(lnot(size),band(Vd,0x1))} UNDEFINED
     111100101D(size:2)(Vn:4)(Vd:4)10(op)1N0M0(Vm:4) {ne(size,0x3)} {lor(lnot(size),band(Vd,0x1))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0000NQM1(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     111100111D11(size:2)00(Vd:4)01110QM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100110D(op)(sz)(Vn:4)(Vd:4)1111NQM0(Vm:4) {lor(sz,Q)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)1010NQM(op)(Vm:4) {lor(eq(size,0x3),Q)} UNDEFINED
     111100111D11(size:2)00(Vd:4)0010(op)QM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100110D0(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lor(sz,Q)} UNDEFINED
     111100100D(size:2)(Vn:4)(Vd:4)1011NQM1(Vm:4) {lor(eq(size,0x3),Q)} UNDEFINED
     111100111D11(size:2)00(Vd:4)0110(op)QM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100100D10(Vn:4)(Vd:4)0001NQM1(Vm:4) {lor(ne(N,M),ne(Vn,Vm))} {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q01(imm4:4) {band(cmode,0x1)} {lt(cmode,0xc)} {band(Q,Vd)} UNDEFINED
     111100100D11(Vn:4)(Vd:4)0001NQM1(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     111100111D11(size:2)01(Vd:4)0F111QM0(Vm:4) {lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)00(Vd:4)01011QM0(Vm:4) {lor(size,band(Q,bor(Vd,Vm)))} UNDEFINED
     1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q11(imm4:4) {lnot(land(band(cmode,0x1),lt(cmode,0xc)))} {lt(cmode,0xe)} {band(Q,Vd)} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)1010N1M0(Vm:4) {ne(size,0x3)} {lor(lnot(size),band(Vd,0x1))} UNDEFINED
     1111001Q1D(size:2)(Vn:4)(Vd:4)100FN1M0(Vm:4) {ne(size,0x3)} {lor(lor(lnot(size),eq(F,size)),band(Q,bor(Vd,Vn)))} UNDEFINED
     111100110D0(sz)(Vn:4)(Vd:4)1101NQM1(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),sz)} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)11(op)0N0M0(Vm:4) {ne(size,0x3)} {lor(land(op,lor(U,size)),band(Vd,0x1))} UNDEFINED
     1111001(op)0D(size:2)(Vn:4)(Vd:4)1001NQM1(Vm:4) {lor(lor(eq(size,0x3),land(op,size)),band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100111D11(size:2)10(Vd:4)001000M0(Vm:4) {lor(eq(size,0x3),band(Vm,0x1))} UNDEFINED
     1111001U1D(imm3:3)000(Vd:4)101000M1(Vm:4) {eq(bitcount(imm3),0x1)} {band(Vd,0x1)} UNDEFINED
     111100100D10(Vm:4)(Vd:4)0001MQ(M2)1(Vm2:4) {eq(M,M2)} {eq(Vm,Vm2)} {band(Q,bor(Vd,Vm))} UNDEFINED
     1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q(op)1(imm4:4) {lnot(land(land(lnot(op),band(cmode,0x1)),ne(band(cmode,0xc),0xc)))} {lnot(land(op,ne(cmode,0xe)))} {band(Q,Vd)} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)0(op)10N1M0(Vm:4) {ne(size,0x3)} {lor(lnot(size),band(Vd,0x1))} UNDEFINED
     1111001Q1D(size:2)(Vn:4)(Vd:4)0(op)0FN1M0(Vm:4) {ne(size,0x3)} {lor(lor(lnot(size),land(F,eq(size,0x1))),band(Q,bor(Vd,Vn)))} UNDEFINED
     111100100D(op)(sz)(Vn:4)(Vd:4)1101NQM1(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),sz)} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)10(op)0N0M0(Vm:4) {ne(size,0x3)} {band(Vd,0x1)} UNDEFINED
     1111001(op)0D(size:2)(Vn:4)(Vd:4)1001NQM0(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3))} UNDEFINED
     111100100D(op)(sz)(Vn:4)(Vd:4)1111NQM0(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),sz)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0110NQM(op)(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3))} UNDEFINED
     111101001D10(Rn:4)(Vd:4)1111(size:2)Ta(Rm:4) {eq(size,0x3)} {lnot(a)} UNDEFINED
     111101001D10(Rn:4)(Vd:4)(size:2)11(index_align:4)(Rm:4) {eq(size,0x2)} {eq(band(index_align,0x3),0x3)} UNDEFINED
     111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lt(type,0x2)} {eq(size,0x3)} UNDEFINED
     111101001D10(Rn:4)(Vd:4)1110(size:2)Ta(Rm:4) {lor(eq(size,0x3),a)} UNDEFINED
     111101001D10(Rn:4)(Vd:4)(size:2)10(index_align:4)(Rm:4) {eq(size,0x2)} {band(index_align,0x3)} UNDEFINED
     111101001D10(Rn:4)(Vd:4)(size:2)10(index_align:4)(Rm:4) {lnot(band(size,0x2))} {band(index_align,0x1)} UNDEFINED
     111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(band(type,0xe),0x4)} {lor(eq(size,0x3),band(align,0x2))} UNDEFINED
     111101001D10(Rn:4)(Vd:4)1101(size:2)Ta(Rm:4) {eq(size,0x3)} UNDEFINED
     111101001D10(Rn:4)(Vd:4)(size:2)01(index_align:4)(Rm:4) {ne(size,0x3)} {eq(size,0x2)} {band(index_align,0x2)} UNDEFINED
     111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lor(eq(band(type,0xe),0x8),eq(type,0x3))} {lor(eq(size,0x3),land(eq(band(type,0xe),0x8),eq(align,0x3)))} UNDEFINED
     111101001D10(Rn:4)(Vd:4)1100(size:2)Ta(Rm:4) {lor(eq(size,0x3),land(lnot(size),a))} UNDEFINED
     111101001D10(Rn:4)(Vd:4)(size:2)00(index_align:4)(Rm:4) {eq(size,0x2)} {lor(band(index_align,0x4),band(beor(index_align,lsr(index_align,0x1)),0x1))} UNDEFINED
     111101001D10(Rn:4)(Vd:4)(size:2)00(index_align:4)(Rm:4) {eq(size,0x1)} {band(index_align,0x2)} UNDEFINED
     111101001D10(Rn:4)(Vd:4)(size:2)00(index_align:4)(Rm:4) {lnot(size)} {band(index_align,0x1)} UNDEFINED
     111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(type,0xa)} {eq(align,0x3)} UNDEFINED
     111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(band(type,0xe),0x6)} {band(align,0x2)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)00(op)0NQM0(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3))} UNDEFINED
     111100100D(op)(sz)(Vn:4)(Vd:4)1100NQM1(Vm:4) {sz} UNDEFINED
     111100101D11(Vn:4)(Vd:4)(imm4:4)NQM0(Vm:4) {lor(band(Q,bor(bor(Vd,Vn),Vm)),land(lnot(Q),band(imm4,0x8)))} UNDEFINED
     111100110D00(Vn:4)(Vd:4)0001NQM1(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     (cond:4)11101bQ0(Vd:4)(Rt:4)1011D0e1(0000) {ne(cond,0xf)} {lor(band(Q,Vd),band(b,e))} UNDEFINED_MCR_MCR2_A1 (as UNDEFINED)
     111100111D11(imm4:4)(Vd:4)11000QM0(Vm:4) {lor(lnot(band(imm4,0x7)),band(Q,Vd))} UNDEFINED
     111100111D11(size:2)10(Vd:4)011(op)00M0(Vm:4) {lor(lor(ne(size,0x1),band(op,Vd)),band(beor(op,0x1),Vm))} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)111(op)0QM1(Vm:4) {band(imm6,0x20)} {band(Q,bor(Vd,Vm))} UNDEFINED
     1111001U1D(imm6:6)(Vd:4)111(op)0QM1(Vm:4) {gt(beor(imm6,0x20),0x27)} UNDEFINED
     111100111D11(size:2)11(Vd:4)011(op:2)QM0(Vm:4) {lor(ne(size,0x2),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)00(Vd:4)01010QM0(Vm:4) {lor(size,band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)00(Vd:4)01001QM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)01(Vd:4)0F100QM0(Vm:4) {lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)00(Vd:4)01000QM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)01(Vd:4)0F011QM0(Vm:4) {lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100111D11(size:2)01(Vd:4)0F000QM0(Vm:4) {lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100110D1(sz)(Vn:4)(Vd:4)1110NQM0(Vm:4) {lor(sz,band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0011NQM0(Vm:4) {lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100111D11(size:2)01(Vd:4)0F001QM0(Vm:4) {lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100110D0(sz)(Vn:4)(Vd:4)1110NQM0(Vm:4) {lor(sz,band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0011NQM1(Vm:4) {lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100111D11(size:2)01(Vd:4)0F010QM0(Vm:4) {lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100100D0(sz)(Vn:4)(Vd:4)1110NQM0(Vm:4) {lor(sz,band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100110D(size:2)(Vn:4)(Vd:4)1000NQM1(Vm:4) {lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100110D(op:2)(Vn:4)(Vd:4)0001NQM1(Vm:4) {op} {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     111100100D01(Vn:4)(Vd:4)0001NQM1(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q11(imm4:4) {band(cmode,0x1)} {lt(cmode,0xc)} {band(Q,Vd)} UNDEFINED
     111100100D00(Vn:4)(Vd:4)0001NQM1(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)000(op)N0M0(Vm:4) {ne(size,0x3)} {band(bor(Vd,band(op,Vn)),0x1)} UNDEFINED
     111100101D(size:2)(Vn:4)(Vd:4)0100N0M0(Vm:4) {ne(size,0x3)} {band(bor(Vn,Vm),0x1)} UNDEFINED
     111100100D0(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lor(sz,band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100100D(size:2)(Vn:4)(Vd:4)1000NQM0(Vm:4) {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     111100110D(op)(sz)(Vn:4)(Vd:4)1110NQM1(Vm:4) {lor(sz,band(Q,bor(bor(Vd,Vn),Vm)))} UNDEFINED
     111100111D11(size:2)01(Vd:4)0F110QM0(Vm:4) {lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm)))} UNDEFINED
     111100110D1(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lnot(sz)} {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     111100110D1(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {sz} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)0111N0M0(Vm:4) {ne(size,0x3)} {band(Vd,0x1)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0111NQM0(Vm:4) {ne(size,0x3)} {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0111NQM0(Vm:4) {eq(size,0x3)} UNDEFINED
     1111001U1D(size:2)(Vn:4)(Vd:4)0101N0M0(Vm:4) {ne(size,0x3)} {band(Vd,0x1)} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0111NQM1(Vm:4) {ne(size,0x3)} {band(Q,bor(bor(Vd,Vn),Vm))} UNDEFINED
     1111001U0D(size:2)(Vn:4)(Vd:4)0111NQM1(Vm:4) {eq(size,0x3)} UNDEFINED
     11110100A(:1)L0(:8)(B:4)(:8) {lnot(A)} {ge(B,0xb)} UNDEFINED
     1111001a1(:1)000(bcd:3)(:4)(cmode:4)0(:1)(op)1(efgh:4) {op} {eq(cmode,0xf)} UNDEFINED
     111100111(:1)11(:2)(A:2)(:4)0(B:5)(:1)0(:4) {eq(A,0x2)} {eq(band(B,0x1e),0xe)} UNDEFINED
     111100111(:1)11(:2)(A:2)(:4)0(B:5)(:1)0(:4) {eq(A,0x2)} {eq(B,0xd)} UNDEFINED
     111100111(:1)11(:2)(A:2)(:4)0(B:5)(:1)0(:4) {eq(A,0x1)} {eq(band(B,0xe),0xa)} UNDEFINED
     111100111(:1)11(:2)(A:2)(:4)0(B:5)(:1)0(:4) {lnot(A)} {eq(band(B,0x1c),0xc)} UNDEFINED
     1111001U1(:1)(imm3:3)(:7)(A:4)LB(:1)1(:4) {lor(L,imm3)} {ge(A,0xb)} {le(A,0xd)} UNDEFINED
     1111001U1(:1)(imm3:3)(:7)(A:4)LB(:1)1(:4) {L} {ge(A,0xe)} UNDEFINED
     1111001U1(:1)(imm3:3)(:7)(A:4)LB(:1)1(:4) {L} {ge(A,0x8)} {le(A,0xa)} UNDEFINED
     1111001U1(:1)(imm3:3)(:7)(A:4)LB(:1)1(:4) {imm3} {eq(A,0xa)} {B} {lnot(L)} UNDEFINED
     1111001U1(:1)(imm3:3)(:7)(A:4)LB(:1)1(:4) {lor(L,imm3)} {lnot(U)} {eq(A,0x4)} UNDEFINED
     1111001U1(:1)(B:2)(:8)(A:4)(:1)1(:1)0(:4) {ne(B,0x3)} {ge(A,0xe)} UNDEFINED
     1111001U1(:1)(B:2)(:8)(A:4)(:1)1(:1)0(:4) {ne(B,0x3)} {U} {le(A,0xb)} {eq(band(A,0x3),0x3)} UNDEFINED
     1111001U1(:1)(B:2)(:8)(A:4)(:1)0(:1)0(:4) {ne(B,0x3)} {lnot(U)} {eq(A,0xf)} UNDEFINED
     1111001U1(:1)(B:2)(:8)(A:4)(:1)0(:1)0(:4) {ne(B,0x3)} {U} {eq(band(A,0x9),0x9)} UNDEFINED
     1111001U0(:1)(C:2)(:8)(A:4)(:3)(B)(:4) {eq(A,0xe)} {B} {lnot(U)} UNDEFINED
     1111001U0(:1)(C:2)(:8)(A:4)(:3)(B)(:4) {eq(A,0xe)} {lnot(B)} {lnot(U)} {ge(C,0x2)} UNDEFINED
     1111001U0(:1)(C:2)(:8)(A:4)(:3)(B)(:4) {eq(A,0xd)} {B} {U} {ge(C,0x2)} UNDEFINED
     1111001U0(:1)(C:2)(:8)(A:4)(:3)(B)(:4) {eq(A,0xc)} {lor(lnot(B),U)} UNDEFINED
     1111001U0(:1)(C:2)(:8)(A:4)(:3)(B)(:4) {eq(A,0xb)} {B} {U} UNDEFINED
     1111001U(A:5)(:7)(B:4)(C:4)(:4) {eq(band(A,0x16),0x16)} {lnot(band(C,0x1))} {U} {eq(B,0xc)} {band(C,0x8)} UNDEFINED
     1111001U(A:5)(:7)(B:4)(C:4)(:4) {eq(band(A,0x16),0x16)} {lnot(band(C,0x1))} {U} {gt(B,0xc)} UNDEFINED
     (cond:4)110PUDW0(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} {eq(P,U)} {W} UNDEFINED_STC_STC2_A1 (as UNDEFINED)
     (cond:4)110PUDW0(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} {eq(P,U)} {W} UNDEFINED_STC_STC2_A1 (as UNDEFINED)
     (cond:4)1110U(opc1:2)1(Vn:4)(Rt:4)1011N(opc2:2)1(0000) {ne(cond,0xf)} {lnot(band(opc1,0x2))} {lor(land(U,lnot(opc2)),eq(opc2,0x2))} UNDEFINED_MRC_MRC2_A1 (as UNDEFINED)
     (cond:4)11100(opc1:2)0(Vd:4)(Rt:4)1011D(opc2:2)1(0000) {ne(cond,0xf)} {lnot(band(opc1,0x2))} {eq(opc2,0x2)} UNDEFINED_MCR_MCR2_A1 (as UNDEFINED)
     (cond:4)110PUDW11111(Vd:4)1010(imm8:8) {ne(cond,0xf)} {eq(P,U)} {W} UNDEFINED_LDC_LDC2_lit_A1 (as UNDEFINED)
     (cond:4)110PUDW1(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} {eq(P,U)} {W} {ne(Rn,0xf)} UNDEFINED_LDC_LDC2_imm_A1 (as UNDEFINED)
     (cond:4)110PUDW11111(Vd:4)1011(imm8:8) {ne(cond,0xf)} {eq(P,U)} {W} UNDEFINED_LDC_LDC2_lit_A1 (as UNDEFINED)
     (cond:4)110PUDW1(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} {eq(P,U)} {W} {ne(Rn,0xf)} UNDEFINED_LDC_LDC2_imm_A1 (as UNDEFINED)
     (cond:4)11000101(:8)101C(op:4)(:4) {ne(cond,0xf)} {gt(op,0x3)} UNDEFINED_MRRC_MRRC2_A1 (as UNDEFINED)
     (cond:4)11000100(:8)101C(op:4)(:4) {ne(cond,0xf)} {gt(op,0x3)} UNDEFINED_MCRR_MCRR2_A1 (as UNDEFINED)
     (cond:4)11000101(:8)101C(op:4)(:4) {ne(cond,0xf)} {lnot(band(op,0xd))} UNDEFINED_MRRC_MRRC2_A1 (as UNDEFINED)
     (cond:4)11000100(:8)101C(op:4)(:4) {ne(cond,0xf)} {lnot(band(op,0xd))} UNDEFINED_MCRR_MCRR2_A1 (as UNDEFINED)
     (cond:4)1110(A:3)L(:8)101C(:1)(B:2)1(:4) {ne(cond,0xf)} {lnot(L)} {C} {band(A,0x4)} {band(B,0x2)} UNDEFINED_MCR_MCR2_A1 (as UNDEFINED)
     (cond:4)1110(A:3)L(:8)101C(:1)(B:2)1(:4) {ne(cond,0xf)} {L} {lnot(C)} {A} {ne(A,0x7)} UNDEFINED_MRC_MRC2_A1 (as UNDEFINED)
     (cond:4)1110(A:3)L(:8)101C(:1)(B:2)1(:4) {ne(cond,0xf)} {lnot(L)} {lnot(C)} {A} {ne(A,0x7)} UNDEFINED_MCR_MCR2_A1 (as UNDEFINED)
     (cond:4)110(opcode:5)(Rn:4)(:4)101(:9) {ne(cond,0xf)} {lt(opcode,0x2)} UNDEFINED
     (cond:4)1110(opc1:4)(opc2:4)(:4)101(:1)(opc3:2)(:1)0(opc4:4) {ne(cond,0xf)} {eq(band(opc1,0xb),0xb)} {band(opc3,0x1)} {eq(opc2,0x9)} UNDEFINED_CDP_CDP2_A1 (as UNDEFINED)
     (cond:4)1110(opc1:4)(opc2:4)(:4)101(:1)(opc3:2)(:1)0(opc4:4) {ne(cond,0xf)} {eq(band(opc1,0xb),0x8)} {band(opc3,0x1)} UNDEFINED_CDP_CDP2_A1 (as UNDEFINED)
     (cond:4)100PU1(0)0(Rn:4)(reglist:16) {ne(cond,0xf)} STM_user_A1 (as UNDEFINED)
     1111100PU1W0(110100000101000)(mode:5) SRS_A1 (as UNDEFINED)
     (cond:4)00010110(000000000000)0111(imm4:4) {ne(cond,0xf)} SMC_A1 (as UNDEFINED)
     1111100PU0W1(Rn:4)(0000101000000000) RFE_A1 (as UNDEFINED)
     (cond:4)00010R10(mask:4)(111100)0(0)0000(Rn:4) {ne(cond,0xf)} MSR_reg_A1 (as UNDEFINED)
     (cond:4)00110R10(mask:4)(1111)(imm12:12) {ne(cond,0xf)} {lor(mask,R)} MSR_imm_A1 (as UNDEFINED)
     (cond:4)00010R10(m1:4)(111100)1m0000(Rn:4) {ne(cond,0xf)} MSR_banked_A1 (as UNDEFINED)
     (cond:4)00010R00(1111)(Rd:4)(00)0(0)0000(0000) {ne(cond,0xf)} MRS_A1 (as UNDEFINED)
     (cond:4)00010R00(m1:4)(Rd:4)(00)1m0000(0000) {ne(cond,0xf)} MRS_banked_A1 (as UNDEFINED)
     (cond:4)100PU1(0)1(Rn:4)0(reglist:15) {ne(cond,0xf)} LDM_user_A1 (as UNDEFINED)
     (cond:4)100PU1W1(Rn:4)1(reglist:15) {ne(cond,0xf)} LDM_exception_A1 (as UNDEFINED)
     (cond:4)00010100(imm12:12)0111(imm4:4) {ne(cond,0xf)} HVC_A1 (as UNDEFINED)
     (cond:4)00010110(000000000000)0110(1110) {ne(cond,0xf)} ERET_A1 (as UNDEFINED)
     111100010000(imod:2)M0(0000000)AIF0(mode:5) CPS_A1 (as UNDEFINED)
     (cond:4)001100100000(11110000)00000001 {ne(cond,0xf)} YIELD_A1 (as UNDEFINED)
     (cond:4)001100100000(11110000)00000011 {ne(cond,0xf)} WFI_A1 (as UNDEFINED)
     (cond:4)001100100000(11110000)00000010 {ne(cond,0xf)} WFE_A1 (as UNDEFINED)
     (cond:4)011011111111(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} UXTH_A1 (as UNDEFINED)
     (cond:4)011011001111(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} UXTB16_A1 (as UNDEFINED)
     (cond:4)011011101111(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} UXTB_A1 (as UNDEFINED)
     (cond:4)01101111(Rn:4)(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} {ne(Rn,0xf)} UXTAH_A1 (as UNDEFINED)
     (cond:4)01101100(Rn:4)(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} {ne(Rn,0xf)} UXTAB16_A1 (as UNDEFINED)
     (cond:4)01101110(Rn:4)(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} {ne(Rn,0xf)} UXTAB_A1 (as UNDEFINED)
     (cond:4)01100101(Rn:4)(Rd:4)(1111)1111(Rm:4) {ne(cond,0xf)} USUB8_A1 (as UNDEFINED)
     (cond:4)01100101(Rn:4)(Rd:4)(1111)0111(Rm:4) {ne(cond,0xf)} USUB16_A1 (as UNDEFINED)
     (cond:4)01100101(Rn:4)(Rd:4)(1111)0101(Rm:4) {ne(cond,0xf)} USAX_A1 (as UNDEFINED)
     (cond:4)01101110(sat_imm:4)(Rd:4)(1111)0011(Rn:4) {ne(cond,0xf)} USAT16_A1 (as UNDEFINED)
     (cond:4)0110111(sat_imm:5)(Rd:4)(imm5:5)(sh)01(Rn:4) {ne(cond,0xf)} USAT_A1 (as UNDEFINED)
     (cond:4)01111000(Rd:4)(Ra:4)(Rm:4)0001(Rn:4) {ne(cond,0xf)} {ne(Ra,0xf)} USADA8_A1 (as UNDEFINED)
     (cond:4)01111000(Rd:4)1111(Rm:4)0001(Rn:4) {ne(cond,0xf)} USAD8_A1 (as UNDEFINED)
     (cond:4)01100110(Rn:4)(Rd:4)(1111)1111(Rm:4) {ne(cond,0xf)} UQSUB8_A1 (as UNDEFINED)
     (cond:4)01100110(Rn:4)(Rd:4)(1111)0111(Rm:4) {ne(cond,0xf)} UQSUB16_A1 (as UNDEFINED)
     (cond:4)01100110(Rn:4)(Rd:4)(1111)0101(Rm:4) {ne(cond,0xf)} UQSAX_A1 (as UNDEFINED)
     (cond:4)01100110(Rn:4)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} UQASX_A1 (as UNDEFINED)
     (cond:4)01100110(Rn:4)(Rd:4)(1111)1001(Rm:4) {ne(cond,0xf)} UQADD8_A1 (as UNDEFINED)
     (cond:4)01100110(Rn:4)(Rd:4)(1111)0001(Rm:4) {ne(cond,0xf)} UQADD16_A1 (as UNDEFINED)
     (cond:4)0000100S(RdHi:4)(RdLo:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} UMULL_A1 (as UNDEFINED)
     (cond:4)0000101S(RdHi:4)(RdLo:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} UMLAL_A1 (as UNDEFINED)
     (cond:4)00000100(RdHi:4)(RdLo:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} UMAAL_A1 (as UNDEFINED)
     (cond:4)01100111(Rn:4)(Rd:4)(1111)1111(Rm:4) {ne(cond,0xf)} UHSUB8_A1 (as UNDEFINED)
     (cond:4)01100111(Rn:4)(Rd:4)(1111)0111(Rm:4) {ne(cond,0xf)} UHSUB16_A1 (as UNDEFINED)
     (cond:4)01100111(Rn:4)(Rd:4)(1111)0101(Rm:4) {ne(cond,0xf)} UHSAX_A1 (as UNDEFINED)
     (cond:4)01100111(Rn:4)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} UHASX_A1 (as UNDEFINED)
     (cond:4)01100111(Rn:4)(Rd:4)(1111)1001(Rm:4) {ne(cond,0xf)} UHADD8_A1 (as UNDEFINED)
     (cond:4)01100111(Rn:4)(Rd:4)(1111)0001(Rm:4) {ne(cond,0xf)} UHADD16_A1 (as UNDEFINED)
     (cond:4)01110011(Rd:4)(1111)(Rm:4)0001(Rn:4) {ne(cond,0xf)} UDIV_A1 (as UNDEFINED)
     111001111111(imm12:12)1111(imm4:4) UDF_A1 (as UNDEFINED)
     (cond:4)0111111(widthm1:5)(Rd:4)(lsb:5)101(Rn:4) {ne(cond,0xf)} UBFX_A1 (as UNDEFINED)
     (cond:4)01100101(Rn:4)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} UASX_A1 (as UNDEFINED)
     (cond:4)01100101(Rn:4)(Rd:4)(1111)1001(Rm:4) {ne(cond,0xf)} UADD8_A1 (as UNDEFINED)
     (cond:4)01100101(Rn:4)(Rd:4)(1111)0001(Rm:4) {ne(cond,0xf)} UADD16_A1 (as UNDEFINED)
     (cond:4)00010001(Rn:4)(0000)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} TST_rsr_A1 (as UNDEFINED)
     (cond:4)00010001(Rn:4)(0000)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} TST_reg_A1 (as UNDEFINED)
     (cond:4)00110001(Rn:4)(0000)(imm12:12) {ne(cond,0xf)} TST_imm_A1 (as UNDEFINED)
     (cond:4)00010011(Rn:4)(0000)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} TEQ_rsr_A1 (as UNDEFINED)
     (cond:4)00010011(Rn:4)(0000)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} TEQ_reg_A1 (as UNDEFINED)
     (cond:4)00110011(Rn:4)(0000)(imm12:12) {ne(cond,0xf)} TEQ_imm_A1 (as UNDEFINED)
     (cond:4)011010111111(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} SXTH_A1 (as UNDEFINED)
     (cond:4)011010001111(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} SXTB16_A1 (as UNDEFINED)
     (cond:4)011010101111(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} SXTB_A1 (as UNDEFINED)
     (cond:4)01101011(Rn:4)(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} {ne(Rn,0xf)} SXTAH_A1 (as UNDEFINED)
     (cond:4)01101000(Rn:4)(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} {ne(Rn,0xf)} SXTAB16_A1 (as UNDEFINED)
     (cond:4)01101010(Rn:4)(Rd:4)(rotate:2)(00)0111(Rm:4) {ne(cond,0xf)} {ne(Rn,0xf)} SXTAB_A1 (as UNDEFINED)
     (cond:4)00010B00(Rn:4)(Rt:4)(0000)1001(Rt2:4) {ne(cond,0xf)} SWP_SWPB_A1 (as UNDEFINED)
     (cond:4)1111(imm24:24) {ne(cond,0xf)} SVC_A1 (as UNDEFINED)
     (cond:4)0000010S1101(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} SUB_sp_reg_A1 (as UNDEFINED)
     (cond:4)0010010S1101(Rd:4)(imm12:12) {ne(cond,0xf)} SUB_sp_imm_A1 (as UNDEFINED)
     (cond:4)0000010S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} SUB_rsr_A1 (as UNDEFINED)
     (cond:4)0000010S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} {ne(Rn,0xd)} SUB_reg_A1 (as UNDEFINED)
     (cond:4)0010010S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} {lor(ne(Rn,0xf),S)} {ne(Rn,0xd)} SUB_imm_A1 (as UNDEFINED)
     (cond:4)0110U010(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} STRT_A2 (as UNDEFINED)
     (cond:4)0100U010(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} STRT_A1 (as UNDEFINED)
     (cond:4)0000U010(Rn:4)(Rt:4)(0000)1011(Rm:4) {ne(cond,0xf)} STRHT_A2 (as UNDEFINED)
     (cond:4)0000U110(Rn:4)(Rt:4)(imm4H:4)1011(imm4L:4) {ne(cond,0xf)} STRHT_A1 (as UNDEFINED)
     (cond:4)000PU0W0(Rn:4)(Rt:4)(0000)1011(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} STRH_reg_A1 (as UNDEFINED)
     (cond:4)000PU1W0(Rn:4)(Rt:4)(imm4H:4)1011(imm4L:4) {ne(cond,0xf)} {lor(P,lnot(W))} STRH_imm_A1 (as UNDEFINED)
     (cond:4)000PU0W0(Rn:4)(Rt:4)(0000)1111(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} STRD_reg_A1 (as UNDEFINED)
     (cond:4)000PU1W0(Rn:4)(Rt:4)(imm4H:4)1111(imm4L:4) {ne(cond,0xf)} {lor(P,lnot(W))} STRD_imm_A1 (as UNDEFINED)
     (cond:4)0110U110(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} STRBT_A2 (as UNDEFINED)
     (cond:4)0100U110(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} STRBT_A1 (as UNDEFINED)
     (cond:4)011PU1W0(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} STRB_reg_A1 (as UNDEFINED)
     (cond:4)010PU1W0(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} {lor(P,lnot(W))} STRB_imm_A1 (as UNDEFINED)
     (cond:4)011PU0W0(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} STR_reg_A1 (as UNDEFINED)
     (cond:4)010PU0W0(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} {lor(P,lnot(W))} {lnot(land(land(land(eq(Rn,0xd),P),land(lnot(U),W)),eq(imm12,0x4)))} STR_imm_A1 (as UNDEFINED)
     (cond:4)100110W0(Rn:4)(reglist:16) {ne(cond,0xf)} STMIB_A1 (as UNDEFINED)
     (cond:4)100100W0(Rn:4)(reglist:16) {ne(cond,0xf)} {lor(lor(ne(W,0x1),ne(Rn,0xd)),lt(bitcount(reglist),0x2))} STMDB_A1 (as UNDEFINED)
     (cond:4)100000W0(Rn:4)(reglist:16) {ne(cond,0xf)} STMDA_A1 (as UNDEFINED)
     (cond:4)100010W0(Rn:4)(reglist:16) {ne(cond,0xf)} STMIA_A1 (as UNDEFINED)
     1111110PUDW0(Rn:4)(CRd:4)(coproc:4)(imm8:8) {lor(lor(P,U),W)} STC_STC2_A2 (as UNDEFINED)
     111111000000(Rn:4)(CRd:4)(coproc:4)(imm8:8) UNDEFINED
     (cond:4)110PUDW0(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} {ne(coproc,0x2)} STC_STC2_A1 (as UNDEFINED)
     (cond:4)11000000(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} {ne(coproc,0x2)} UNDEFINED
     (cond:4)01100001(Rn:4)(Rd:4)(1111)1111(Rm:4) {ne(cond,0xf)} SSUB8_A1 (as UNDEFINED)
     (cond:4)01100001(Rn:4)(Rd:4)(1111)0111(Rm:4) {ne(cond,0xf)} SSUB16_A1 (as UNDEFINED)
     (cond:4)01100001(Rn:4)(Rd:4)(1111)0101(Rm:4) {ne(cond,0xf)} SSAX_A1 (as UNDEFINED)
     (cond:4)01101010(sat_imm:4)(Rd:4)(1111)0011(Rn:4) {ne(cond,0xf)} SSAT16_A1 (as UNDEFINED)
     (cond:4)0110101(sat_imm:5)(Rd:4)(imm5:5)(sh)01(Rn:4) {ne(cond,0xf)} SSAT_A1 (as UNDEFINED)
     (cond:4)01110000(Rd:4)1111(Rm:4)01M1(Rn:4) {ne(cond,0xf)} SMUSD_A1 (as UNDEFINED)
     (cond:4)00010010(Rd:4)(0000)(Rm:4)1M10(Rn:4) {ne(cond,0xf)} SMULWx_A1 (as UNDEFINED)
     (cond:4)0000110S(RdHi:4)(RdLo:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} SMULL_A1 (as UNDEFINED)
     (cond:4)00010110(Rd:4)(0000)(Rm:4)1MN0(Rn:4) {ne(cond,0xf)} SMULxx_A1 (as UNDEFINED)
     (cond:4)01110000(Rd:4)1111(Rm:4)00M1(Rn:4) {ne(cond,0xf)} SMUAD_A1 (as UNDEFINED)
     (cond:4)01110101(Rd:4)1111(Rm:4)00R1(Rn:4) {ne(cond,0xf)} SMMUL_A1 (as UNDEFINED)
     (cond:4)01110101(Rd:4)(Ra:4)(Rm:4)11R1(Rn:4) {ne(cond,0xf)} SMMLS_A1 (as UNDEFINED)
     (cond:4)01110101(Rd:4)(Ra:4)(Rm:4)00R1(Rn:4) {ne(cond,0xf)} {ne(Ra,0xf)} SMMLA_A1 (as UNDEFINED)
     (cond:4)01110100(RdHi:4)(RdLo:4)(Rm:4)01M1(Rn:4) {ne(cond,0xf)} SMLSLD_A1 (as UNDEFINED)
     (cond:4)01110000(Rd:4)(Ra:4)(Rm:4)01M1(Rn:4) {ne(cond,0xf)} {ne(Ra,0xf)} SMLSD_A1 (as UNDEFINED)
     (cond:4)00010010(Rd:4)(Ra:4)(Rm:4)1M00(Rn:4) {ne(cond,0xf)} SMLAWx_A1 (as UNDEFINED)
     (cond:4)01110100(RdHi:4)(RdLo:4)(Rm:4)00M1(Rn:4) {ne(cond,0xf)} SMLALD_A1 (as UNDEFINED)
     (cond:4)00010100(RdHi:4)(RdLo:4)(Rm:4)1MN0(Rn:4) {ne(cond,0xf)} SMLALxx_A1 (as UNDEFINED)
     (cond:4)0000111S(RdHi:4)(RdLo:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} SMLAL_A1 (as UNDEFINED)
     (cond:4)01110000(Rd:4)(Ra:4)(Rm:4)00M1(Rn:4) {ne(cond,0xf)} {ne(Ra,0xf)} SMLAD_A1 (as UNDEFINED)
     (cond:4)00010000(Rd:4)(Ra:4)(Rm:4)1MN0(Rn:4) {ne(cond,0xf)} SMLAxx_A1 (as UNDEFINED)
     (cond:4)01100011(Rn:4)(Rd:4)(1111)1111(Rm:4) {ne(cond,0xf)} SHSUB8_A1 (as UNDEFINED)
     (cond:4)01100011(Rn:4)(Rd:4)(1111)0111(Rm:4) {ne(cond,0xf)} SHSUB16_A1 (as UNDEFINED)
     (cond:4)01100011(Rn:4)(Rd:4)(1111)0101(Rm:4) {ne(cond,0xf)} SHSAX_A1 (as UNDEFINED)
     (cond:4)01100011(Rn:4)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} SHASX_A1 (as UNDEFINED)
     (cond:4)01100011(Rn:4)(Rd:4)(1111)1001(Rm:4) {ne(cond,0xf)} SHADD8_A1 (as UNDEFINED)
     (cond:4)01100011(Rn:4)(Rd:4)(1111)0001(Rm:4) {ne(cond,0xf)} SHADD16_A1 (as UNDEFINED)
     (cond:4)001100100000(11110000)00000100 {ne(cond,0xf)} SEV_A1 (as UNDEFINED)
     111100010000(000)1(000000)E(0)0000(0000) SETEND_A1 (as UNDEFINED)
     (cond:4)01101000(Rn:4)(Rd:4)(1111)1011(Rm:4) {ne(cond,0xf)} SEL_A1 (as UNDEFINED)
     (cond:4)01110001(Rd:4)(1111)(Rm:4)0001(Rn:4) {ne(cond,0xf)} SDIV_A1 (as UNDEFINED)
     (cond:4)0111101(widthm1:5)(Rd:4)(lsb:5)101(Rn:4) {ne(cond,0xf)} SBFX_A1 (as UNDEFINED)
     (cond:4)0000110S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} SBC_rsr_A1 (as UNDEFINED)
     (cond:4)0000110S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} SBC_reg_A1 (as UNDEFINED)
     (cond:4)0010110S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} SBC_imm_A1 (as UNDEFINED)
     (cond:4)01100001(Rn:4)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} SASX_A1 (as UNDEFINED)
     (cond:4)01100001(Rn:4)(Rd:4)(1111)1001(Rm:4) {ne(cond,0xf)} SADD8_A1 (as UNDEFINED)
     (cond:4)01100001(Rn:4)(Rd:4)(1111)0001(Rm:4) {ne(cond,0xf)} SADD16_A1 (as UNDEFINED)
     (cond:4)0000111S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} RSC_rsr_A1 (as UNDEFINED)
     (cond:4)0000111S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} RSC_reg_A1 (as UNDEFINED)
     (cond:4)0010111S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} RSC_imm_A1 (as UNDEFINED)
     (cond:4)0000011S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} RSB_rsr_A1 (as UNDEFINED)
     (cond:4)0000011S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} RSB_reg_A1 (as UNDEFINED)
     (cond:4)0010011S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} RSB_imm_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)00000110(Rm:4) {ne(cond,0xf)} RRX_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(Rm:4)0111(Rn:4) {ne(cond,0xf)} ROR_reg_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(imm5:5)110(Rm:4) {ne(cond,0xf)} {imm5} ROR_imm_A1 (as UNDEFINED)
     (cond:4)01101111(1111)(Rd:4)(1111)1011(Rm:4) {ne(cond,0xf)} REVSH_A1 (as UNDEFINED)
     (cond:4)01101011(1111)(Rd:4)(1111)1011(Rm:4) {ne(cond,0xf)} REV16_A1 (as UNDEFINED)
     (cond:4)01101011(1111)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} REV_A1 (as UNDEFINED)
     (cond:4)01101111(1111)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} RBIT_A1 (as UNDEFINED)
     (cond:4)01100010(Rn:4)(Rd:4)(1111)1111(Rm:4) {ne(cond,0xf)} QSUB8_A1 (as UNDEFINED)
     (cond:4)01100010(Rn:4)(Rd:4)(1111)0111(Rm:4) {ne(cond,0xf)} QSUB16_A1 (as UNDEFINED)
     (cond:4)00010010(Rn:4)(Rd:4)(0000)0101(Rm:4) {ne(cond,0xf)} QSUB_A1 (as UNDEFINED)
     (cond:4)01100010(Rn:4)(Rd:4)(1111)0101(Rm:4) {ne(cond,0xf)} QSAX_A1 (as UNDEFINED)
     (cond:4)00010110(Rn:4)(Rd:4)(0000)0101(Rm:4) {ne(cond,0xf)} QDSUB_A1 (as UNDEFINED)
     (cond:4)00010100(Rn:4)(Rd:4)(0000)0101(Rm:4) {ne(cond,0xf)} QDADD_A1 (as UNDEFINED)
     (cond:4)01100010(Rn:4)(Rd:4)(1111)0011(Rm:4) {ne(cond,0xf)} QASX_A1 (as UNDEFINED)
     (cond:4)01100010(Rn:4)(Rd:4)(1111)1001(Rm:4) {ne(cond,0xf)} QADD8_A1 (as UNDEFINED)
     (cond:4)01100010(Rn:4)(Rd:4)(1111)0001(Rm:4) {ne(cond,0xf)} QADD16_A1 (as UNDEFINED)
     (cond:4)00010000(Rn:4)(Rd:4)(0000)0101(Rm:4) {ne(cond,0xf)} QADD_A1 (as UNDEFINED)
     (cond:4)010100101101(Rt:4)000000000100 {ne(cond,0xf)} PUSH_A2 (as UNDEFINED)
     (cond:4)100100101101(reglist:16) {ne(cond,0xf)} {ge(bitcount(reglist),0x2)} PUSH_A1 (as UNDEFINED)
     (cond:4)010010011101(Rt:4)000000000100 {ne(cond,0xf)} POP_A2 (as UNDEFINED)
     (cond:4)100010111101(reglist:16) {ne(cond,0xf)} {ge(bitcount(reglist),0x2)} POP_A1 (as UNDEFINED)
     11110110U101(Rn:4)(1111)(imm5:5)(type:2)0(Rm:4) PLI_reg_A1 (as UNDEFINED)
     11110100U101(Rn:4)(1111)(imm12:12) PLI_imm_lit_A1 (as UNDEFINED)
     11110111UR01(Rn:4)(1111)(imm5:5)(type:2)0(Rm:4) {lnot(R)} PLD_reg_A1b (as UNDEFINED)
     11110111UR01(Rn:4)(1111)(imm5:5)(type:2)0(Rm:4) {R} PLD_reg_A1a (as UNDEFINED)
     11110101U1011111(1111)(imm12:12) PLD_lit_A1 (as UNDEFINED)
     11110101UR01(Rn:4)(1111)(imm12:12) {ne(Rn,0xf)} {lnot(R)} PLD_imm_A1b (as UNDEFINED)
     11110101UR01(Rn:4)(1111)(imm12:12) {ne(Rn,0xf)} {R} PLD_imm_A1a (as UNDEFINED)
     (cond:4)01101000(Rn:4)(Rd:4)(imm5:5)(tb)01(Rm:4) {ne(cond,0xf)} PKH_A1 (as UNDEFINED)
     (cond:4)0001100S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} ORR_rsr_A1 (as UNDEFINED)
     (cond:4)0001100S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} ORR_reg_A1 (as UNDEFINED)
     (cond:4)0011100S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} ORR_imm_A1 (as UNDEFINED)
     (cond:4)001100100000(11110000)00000000 {ne(cond,0xf)} NOP_A1 (as UNDEFINED)
     (cond:4)0001111S(0000)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} MVN_rsr_A1 (as UNDEFINED)
     (cond:4)0001111S(0000)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} MVN_reg_A1 (as UNDEFINED)
     (cond:4)0011111S(0000)(Rd:4)(imm12:12) {ne(cond,0xf)} MVN_imm_A1 (as UNDEFINED)
     (cond:4)0000000S(Rd:4)(0000)(Rm:4)1001(Rn:4) {ne(cond,0xf)} MUL_A1 (as UNDEFINED)
     111111000101(Rt2:4)(Rt:4)(coproc:4)(opc1:4)(CRm:4) MRRC_MRRC2_A2 (as UNDEFINED)
     (cond:4)11000101(Rt2:4)(Rt:4)(coproc:4)(opc1:4)(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} {ne(coproc,0x2)} {lnot(land(opcode<20>,eq(coproc,0x0)))} MRRC_MRRC2_A1 (as UNDEFINED)
     11111110(opc1:3)1(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) MRC_MRC2_A2 (as UNDEFINED)
     (cond:4)1110(opc1:3)1(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} MRC_MRC2_A1 (as UNDEFINED)
     (cond:4)00110100(imm4:4)(Rd:4)(imm12:12) {ne(cond,0xf)} MOVT_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)00000000(Rm:4) {ne(cond,0xf)} MOV_reg_A1 (as UNDEFINED)
     (cond:4)00110000(imm4:4)(Rd:4)(imm12:12) {ne(cond,0xf)} MOV_imm_A2 (as UNDEFINED)
     (cond:4)0011101S(0000)(Rd:4)(imm12:12) {ne(cond,0xf)} MOV_imm_A1 (as UNDEFINED)
     (cond:4)00000110(Rd:4)(Ra:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} MLS_A1 (as UNDEFINED)
     (cond:4)0000001S(Rd:4)(Ra:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} MLA_A1 (as UNDEFINED)
     111111000100(Rt2:4)(Rt:4)(coproc:4)(opc1:4)(CRm:4) MCRR_MCRR2_A2 (as UNDEFINED)
     (cond:4)11000100(Rt2:4)(Rt:4)(coproc:4)(opc1:4)(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} {ne(coproc,0x2)} {lnot(land(lnot(opcode<20>),eq(coproc,0x0)))} MCRR_MCRR2_A1 (as UNDEFINED)
     11111110(opc1:3)0(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) MCR_MCR2_A2 (as UNDEFINED)
     (cond:4)1110(opc1:3)0(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} {lnot(land(eq(opc1,0x1),eq(coproc,0x0)))} MCR_MCR2_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(Rm:4)0011(Rn:4) {ne(cond,0xf)} LSR_reg_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(imm5:5)010(Rm:4) {ne(cond,0xf)} LSR_imm_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(Rm:4)0001(Rn:4) {ne(cond,0xf)} LSL_reg_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(imm5:5)000(Rm:4) {ne(cond,0xf)} {imm5} LSL_imm_A1 (as UNDEFINED)
     (cond:4)0110U011(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} LDRT_A2 (as UNDEFINED)
     (cond:4)0100U011(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} LDRT_A1 (as UNDEFINED)
     (cond:4)0000U011(Rn:4)(Rt:4)(0000)1111(Rm:4) {ne(cond,0xf)} LDRSHT_A2 (as UNDEFINED)
     (cond:4)0000U111(Rn:4)(Rt:4)(imm4H:4)1111(imm4L:4) {ne(cond,0xf)} LDRSHT_A1 (as UNDEFINED)
     (cond:4)000PU0W1(Rn:4)(Rt:4)(0000)1111(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} LDRSH_reg_A1 (as UNDEFINED)
     (cond:4)000(1)U1(0)11111(Rt:4)(imm4H:4)1111(imm4L:4) {ne(cond,0xf)} {lor(opcode<24>,lnot(opcode<21>))} LDRSH_lit_A1 (as UNDEFINED)
     (cond:4)000PU1W1(Rn:4)(Rt:4)(imm4H:4)1111(imm4L:4) {ne(cond,0xf)} {ne(Rn,0xf)} {lor(P,lnot(W))} LDRSH_imm_A1 (as UNDEFINED)
     (cond:4)0000U011(Rn:4)(Rt:4)(0000)1101(Rm:4) {ne(cond,0xf)} LDRSBT_A2 (as UNDEFINED)
     (cond:4)0000U111(Rn:4)(Rt:4)(imm4H:4)1101(imm4L:4) {ne(cond,0xf)} LDRSBT_A1 (as UNDEFINED)
     (cond:4)000PU0W1(Rn:4)(Rt:4)(0000)1101(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} LDRSB_reg_A1 (as UNDEFINED)
     (cond:4)000(1)U1(0)11111(Rt:4)(imm4H:4)1101(imm4L:4) {ne(cond,0xf)} {lor(opcode<24>,lnot(opcode<21>))} LDRSB_lit_A1 (as UNDEFINED)
     (cond:4)000PU1W1(Rn:4)(Rt:4)(imm4H:4)1101(imm4L:4) {ne(cond,0xf)} {ne(Rn,0xf)} {lor(P,lnot(W))} LDRSB_imm_A1 (as UNDEFINED)
     (cond:4)0000U011(Rn:4)(Rt:4)(0000)1011(Rm:4) {ne(cond,0xf)} LDRHT_A2 (as UNDEFINED)
     (cond:4)0000U111(Rn:4)(Rt:4)(imm4H:4)1011(imm4L:4) {ne(cond,0xf)} LDRHT_A1 (as UNDEFINED)
     (cond:4)000PU0W1(Rn:4)(Rt:4)(0000)1011(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} LDRH_reg_A1 (as UNDEFINED)
     (cond:4)000(1)U1(0)11111(Rt:4)(imm4H:4)1011(imm4L:4) {ne(cond,0xf)} {lor(opcode<24>,lnot(opcode<21>))} LDRH_lit_A1 (as UNDEFINED)
     (cond:4)000PU1W1(Rn:4)(Rt:4)(imm4H:4)1011(imm4L:4) {ne(cond,0xf)} {ne(Rn,0xf)} {lor(P,lnot(W))} LDRH_imm_A1 (as UNDEFINED)
     (cond:4)000PU0W0(Rn:4)(Rt:4)(0000)1101(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} LDRD_reg_A1 (as UNDEFINED)
     (cond:4)000(1)U1(0)01111(Rt:4)(imm4H:4)1101(imm4L:4) {ne(cond,0xf)} {lor(opcode<24>,lnot(opcode<21>))} LDRD_lit_A1 (as UNDEFINED)
     (cond:4)000PU1W0(Rn:4)(Rt:4)(imm4H:4)1101(imm4L:4) {ne(cond,0xf)} {ne(Rn,0xf)} {lor(P,lnot(W))} LDRD_imm_A1 (as UNDEFINED)
     (cond:4)0110U111(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} LDRBT_A2 (as UNDEFINED)
     (cond:4)0100U111(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} LDRBT_A1 (as UNDEFINED)
     (cond:4)011PU1W1(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} LDRB_reg_A1 (as UNDEFINED)
     (cond:4)010(1)U1(0)11111(Rt:4)(imm12:12) {ne(cond,0xf)} {lor(opcode<24>,lnot(opcode<21>))} LDRB_lit_A1 (as UNDEFINED)
     (cond:4)010PU1W1(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} {ne(Rn,0xf)} {lor(P,lnot(W))} LDRB_imm_A1 (as UNDEFINED)
     (cond:4)011PU0W1(Rn:4)(Rt:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} {lor(P,lnot(W))} LDR_reg_A1 (as UNDEFINED)
     (cond:4)010(1)U0(0)11111(Rt:4)(imm12:12) {ne(cond,0xf)} {lor(opcode<24>,lnot(opcode<21>))} LDR_lit_A1 (as UNDEFINED)
     (cond:4)010PU0W1(Rn:4)(Rt:4)(imm12:12) {ne(cond,0xf)} {ne(Rn,0xf)} {lor(P,lnot(W))} {lnot(land(land(land(eq(Rn,0xd),lnot(P)),land(U,lnot(W))),eq(imm12,0x4)))} LDR_imm_A1 (as UNDEFINED)
     (cond:4)100110W1(Rn:4)(reglist:16) {ne(cond,0xf)} LDMIB_A1 (as UNDEFINED)
     (cond:4)100100W1(Rn:4)(reglist:16) {ne(cond,0xf)} LDMDB_A1 (as UNDEFINED)
     (cond:4)100000W1(Rn:4)(reglist:16) {ne(cond,0xf)} LDMDA_A1 (as UNDEFINED)
     (cond:4)100010W1(Rn:4)(reglist:16) {ne(cond,0xf)} {lor(lor(ne(W,0x1),ne(Rn,0xd)),lt(bitcount(reglist),0x2))} LDMIA_A1 (as UNDEFINED)
     1111110PUDW11111(CRd:4)(coproc:4)(imm8:8) {lor(lor(P,U),W)} LDC_LDC2_lit_A2 (as UNDEFINED)
     1111110000011111(CRd:4)(coproc:4)(imm8:8) UNDEFINED
     (cond:4)110PUDW11111(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {lor(lor(P,U),W)} {ne(coproc,0x1)} {ne(coproc,0x2)} LDC_LDC2_lit_A1 (as UNDEFINED)
     (cond:4)110000011111(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} {ne(coproc,0x2)} UNDEFINED
     1111110PUDW1(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(Rn,0xf)} {lor(lor(P,U),W)} LDC_LDC2_imm_A2 (as UNDEFINED)
     111111000001(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(Rn,0xf)} UNDEFINED
     (cond:4)110PUDW1(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(Rn,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {lor(lor(P,U),W)} {ne(coproc,0x1)} {ne(coproc,0x2)} LDC_LDC2_imm_A1 (as UNDEFINED)
     (cond:4)11000001(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(Rn,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} {ne(coproc,0x2)} UNDEFINED
     111101010111(111111110000)0110(option:4) ISB_A1 (as UNDEFINED)
     (cond:4)0000001S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} EOR_rsr_A1 (as UNDEFINED)
     (cond:4)0000001S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} EOR_reg_A1 (as UNDEFINED)
     (cond:4)0010001S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} EOR_imm_A1 (as UNDEFINED)
     111101010111(111111110000)0100(option:4) DSB_A1 (as UNDEFINED)
     111101010111(111111110000)0101(option:4) DMB_A1 (as UNDEFINED)
     (cond:4)001100100000(11110000)1111(option:4) {ne(cond,0xf)} DBG_A1 (as UNDEFINED)
     (cond:4)00010101(Rn:4)(0000)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} CMP_rsr_A1 (as UNDEFINED)
     (cond:4)00010101(Rn:4)(0000)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} CMP_reg_A1 (as UNDEFINED)
     (cond:4)00110101(Rn:4)(0000)(imm12:12) {ne(cond,0xf)} CMP_imm_A1 (as UNDEFINED)
     (cond:4)00010111(Rn:4)(0000)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} CMN_rsr_A1 (as UNDEFINED)
     (cond:4)00010111(Rn:4)(0000)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} CMN_reg_A1 (as UNDEFINED)
     (cond:4)00110111(Rn:4)(0000)(imm12:12) {ne(cond,0xf)} CMN_imm_A1 (as UNDEFINED)
     (cond:4)00010110(1111)(Rd:4)(1111)0001(Rm:4) {ne(cond,0xf)} CLZ_A1 (as UNDEFINED)
     111101010111(111111110000)0001(1111) CLREX_A1 (as UNDEFINED)
     11111110(opc1:4)(CRn:4)(CRd:4)(coproc:4)(opc2:3)0(CRm:4) {lnot(land(land(eq(opcode<23>,0x1),eq(opcode<21:20>,0x0)),eq(opcode<11:9>,0x5)))} {lnot(land(land(land(eq(opcode<23>,0x1),eq(opcode<21:18>,0xf)),eq(opcode<11:9>,0x5)),eq(opcode<6>,0x1)))} {lnot(land(land(land(eq(opcode<23>,0x1),eq(opcode<21:18>,0xe)),eq(opcode<11:9>,0x5)),eq(opcode<7:6>,0x1)))} {lnot(land(land(eq(opcode<23>,0x0),eq(opcode<11:9>,0x5)),eq(opcode<6>,0x0)))} CDP_CDP2_A2 (as UNDEFINED)
     (cond:4)1110(opc1:4)(CRn:4)(CRd:4)(coproc:4)(opc2:3)0(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {ne(coproc,0x1)} CDP_CDP2_A1 (as UNDEFINED)
     (cond:4)00010010(111111111111)0010(Rm:4) {ne(cond,0xf)} BXJ_A1 (as UNDEFINED)
     (cond:4)00010010(111111111111)0001(Rm:4) {ne(cond,0xf)} BX_A1 (as UNDEFINED)
     (cond:4)00010010(111111111111)0011(Rm:4) {ne(cond,0xf)} BLX_reg_A1 (as UNDEFINED)
     1111101H(imm24:24) BL_BLX_imm_A2 (as UNDEFINED)
     (cond:4)1011(imm24:24) {ne(cond,0xf)} BL_BLX_imm_A1 (as UNDEFINED)
     (cond:4)00010010(imm12:12)0111(imm4:4) {ne(cond,0xf)} BKPT_A1 (as UNDEFINED)
     (cond:4)0001110S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} BIC_rsr_A1 (as UNDEFINED)
     (cond:4)0001110S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} BIC_reg_A1 (as UNDEFINED)
     (cond:4)0011110S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} BIC_imm_A1 (as UNDEFINED)
     (cond:4)0111110(msb:5)(Rd:4)(lsb:5)001(Rn:4) {ne(cond,0xf)} {ne(Rn,0xf)} BFI_A1 (as UNDEFINED)
     (cond:4)0111110(msb:5)(Rd:4)(lsb:5)0011111 {ne(cond,0xf)} BFC_A1 (as UNDEFINED)
     (cond:4)1010(imm24:24) {ne(cond,0xf)} B_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(Rm:4)0101(Rn:4) {ne(cond,0xf)} ASR_reg_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)(imm5:5)100(Rm:4) {ne(cond,0xf)} ASR_imm_A1 (as UNDEFINED)
     (cond:4)0000000S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} AND_rsr_A1 (as UNDEFINED)
     (cond:4)0000000S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} AND_reg_A1 (as UNDEFINED)
     (cond:4)0010000S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} AND_imm_A1 (as UNDEFINED)
     (cond:4)001001001111(Rd:4)(imm12:12) {ne(cond,0xf)} ADR_A2 (as UNDEFINED)
     (cond:4)001010001111(Rd:4)(imm12:12) {ne(cond,0xf)} ADR_A1 (as UNDEFINED)
     (cond:4)0000100S1101(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} ADD_sp_reg_A1 (as UNDEFINED)
     (cond:4)0010100S1101(Rd:4)(imm12:12) {ne(cond,0xf)} ADD_sp_imm_A1 (as UNDEFINED)
     (cond:4)0000100S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} ADD_rsr_A1 (as UNDEFINED)
     (cond:4)0000100S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} {ne(Rn,0xd)} ADD_reg_A1 (as UNDEFINED)
     (cond:4)0010100S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} {lor(ne(Rn,0xf),ne(S,0x0))} {ne(Rn,0xd)} ADD_imm_A1 (as UNDEFINED)
     (cond:4)0000101S(Rn:4)(Rd:4)(Rs:4)0(type:2)1(Rm:4) {ne(cond,0xf)} ADC_rsr_A1 (as UNDEFINED)
     (cond:4)0000101S(Rn:4)(Rd:4)(imm5:5)(type:2)0(Rm:4) {ne(cond,0xf)} ADC_reg_A1 (as UNDEFINED)
     (cond:4)0010101S(Rn:4)(Rd:4)(imm12:12) {ne(cond,0xf)} ADC_imm_A1 (as UNDEFINED)
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x61),0x61)} {band(op2,0x1)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x61),0x60)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {ge(band(op1,0x77),0x52)} {le(band(op1,0x77),0x56)} {lnot(band(op1,0x1))} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x50)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {gt(op1,0x10)} {lt(op1,0x20)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(op1,0x10)} {band(Rn,0x1)} {op2} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(op1,0x10)} {lnot(band(Rn,0x1))} {band(op2,0x2)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {lt(op1,0x10)} UNDEFINED
     1111(op1:8)(Rn:4)(:11)(op)(:4) {eq(band(op1,0xf0),0xf0)} UNDEFINED
     1111(op1:8)(Rn:4)(:11)(op)(:4) {eq(band(op1,0xe5),0x85)} UNDEFINED
     1111(op1:8)(Rn:4)(:11)(op)(:4) {eq(band(op1,0xe5),0x80)} UNDEFINED
     (cond:4)01110(op1:3)(:4)(A:4)(:4)(op2:3)1(:4) {ne(cond,0xf)} {eq(op1,0x5)} {band(op2,0x6)} {lt(op2,0x6)} UNDEFINED
     (cond:4)01110(op1:3)(:4)(A:4)(:4)(op2:3)1(:4) {ne(cond,0xf)} {band(op1,0x2)} {ne(op1,0x3)} UNDEFINED
     (cond:4)01110(op1:3)(:4)(A:4)(:4)(op2:3)1(:4) {ne(cond,0xf)} {eq(band(op1,0x5),0x1)} {op2} UNDEFINED
     (cond:4)01110(op1:3)(:4)(A:4)(:4)(op2:3)1(:4) {ne(cond,0xf)} {lnot(band(op1,0x3))} {band(op2,0x4)} UNDEFINED
     (cond:4)01101(op1:3)(A:4)(:8)(op2:3)1(:4) {ne(cond,0xf)} {eq(op1,0x4)} {ne(op2,0x3)} UNDEFINED
     (cond:4)01101(op1:3)(A:4)(:8)(op2:3)1(:4) {ne(cond,0xf)} {eq(band(op1,0x3),0x3)} {eq(op2,0x7)} UNDEFINED
     (cond:4)01101(op1:3)(A:4)(:8)(op2:3)1(:4) {ne(cond,0xf)} {eq(band(op1,0x3),0x2)} {eq(band(op2,0x5),0x5)} UNDEFINED
     (cond:4)01101(op1:3)(A:4)(:8)(op2:3)1(:4) {ne(cond,0xf)} {eq(band(op1,0x3),0x1)} UNDEFINED
     (cond:4)01101(op1:3)(A:4)(:8)(op2:3)1(:4) {ne(cond,0xf)} {lnot(op1)} {lor(eq(op2,0x1),eq(op2,0x7))} UNDEFINED
     (cond:4)011001(op1:2)(:12)(op2:3)1(:4) {ne(cond,0xf)} {op1} {lor(eq(op2,0x5),eq(op2,0x6))} UNDEFINED
     (cond:4)011001(op1:2)(:12)(op2:3)1(:4) {ne(cond,0xf)} {lnot(op1)} UNDEFINED
     (cond:4)011000(op1:2)(:12)(op2:3)1(:4) {ne(cond,0xf)} {op1} {lor(eq(op2,0x5),eq(op2,0x6))} UNDEFINED
     (cond:4)011000(op1:2)(:12)(op2:3)1(:4) {ne(cond,0xf)} {lnot(op1)} UNDEFINED
     (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {ne(cond,0xf)} {eq(op1,0x1f)} {ne(op2,0x7)} {ne(band(op2,0x3),0x2)} UNDEFINED
     (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {ne(cond,0xf)} {eq(op1,0x1e)} {ne(band(op2,0x3),0x2)} UNDEFINED
     (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {ne(cond,0xf)} {eq(band(op1,0x1e),0x1c)} {band(op2,0x3)} UNDEFINED
     (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {ne(cond,0xf)} {eq(band(op1,0x1e),0x1a)} {ne(band(op2,0x3),0x2)} UNDEFINED
     (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {ne(cond,0xf)} {eq(op1,0x19)} UNDEFINED
     (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {ne(cond,0xf)} {eq(op1,0x18)} {op2} UNDEFINED
     (cond:4)00010(op:2)0(op1:4)(:8)0(op2:3)(:4) {ne(cond,0xf)} {eq(op2,0x6)} {ne(op,0x3)} UNDEFINED
     (cond:4)00010(op:2)0(op1:4)(:8)0(op2:3)(:4) {ne(cond,0xf)} {eq(band(op2,0x6),0x2)} {ne(op,0x1)} UNDEFINED
     (cond:4)00010(op:2)0(op1:4)(:8)0(op2:3)(:4) {ne(cond,0xf)} {eq(op2,0x1)} {lnot(band(op,0x1))} UNDEFINED
     (cond:4)0001(op:4)(:12)1001(:4) {ne(cond,0xf)} {lt(op,0x8)} {band(op,0x3)} UNDEFINED
     (cond:4)0000(:2)1(op)(:4)(Rt:4)(:4)1(op2:2)1(:4) {ne(cond,0xf)} {band(op2,0x2)} {lnot(op)} {band(Rt,0x1)} UNDEFINED */
	const uint32_t nonstandard = 0; /* Prevent duplicate instances due to needless dependencies on 'nonstandard' */
	COMMON
	doundefined(PARAMS);
	return;
}
static RETURNTYPE dis2_leaf_UNPREDICTABLE_0x8c420(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_UNPREDICTABLE_0x8c420(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)0000(:2)1(op)(:4)(Rt:4)(:4)1(op2:2)1(:4) {ne(cond,0xf)} {band(op2,0x2)} {lnot(op)} {lnot(band(Rt,0x1))} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x63),0x63)} {lnot(band(op2,0x1))} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x63),0x43)} {ne(op1,0x57)} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(op1,0x57)} {ne(op2,0x1)} {lor(lt(op2,0x4),gt(op2,0x6))} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x51)} {eq(Rn,0xf)} UNPREDICTABLE */
	const uint32_t nonstandard = 0; /* Prevent duplicate instances due to needless dependencies on 'nonstandard' */
	COMMON
	if(params->opt->dci)
		sprintf(params->buf,"DCI\t%s%08X\t%s",HEX,OPCODE,MSG(MSG_UNPREDICTABLEINSTRUCTION));
	else
		sprintf(params->buf,"%s",MSG(MSG_UNPREDICTABLEINSTRUCTION));
	return;
}
static RETURNTYPE dis2_leaf_UNALLOCATED_HINT_0x9b160(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_UNALLOCATED_HINT_0x9b160(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)00110(op)10(op1:4)(:8)(op2:8) {ne(cond,0xf)} {lnot(op)} {lnot(op1)} {gt(op2,0x5)} {lt(op2,0xf0)} UNALLOCATED_HINT */
	const uint32_t nonstandard = 0; /* Prevent duplicate instances due to needless dependencies on 'nonstandard' */
	COMMON
	if(params->opt->dci)
		sprintf(params->buf,"DCI\t%s%08X\t%s",HEX,OPCODE,MSG(MSG_UNALLOCATEDHINT));
	else
		sprintf(params->buf,"%s",MSG(MSG_UNALLOCATEDHINT));
	return;
}
static RETURNTYPE dis2_leaf_VHADD_VHSUB_A1_0xf0ce8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VHADD_VHSUB_A1_0xf0ce8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)00(op)0NQM0(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3)))} VHADD_VHSUB_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t op = dis2_args->dis2_argf_9_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_N_M(JUSTPARAMS,(op?"VHSUB":"VHADD"),size,U,Q,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VRHADD_A1_0xf0d60(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x7f820(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_N_M(JUSTPARAMS,dis2_args_0,size,U,Q,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VRHADD_A1_0xf0d60(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0001NQM0(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3)))} VRHADD_A1 */
	dis2_optstrings_0x7f820(PARAMS PARAMSCOMMA dis2_args,"VRHADD");
	return;
}
static RETURNTYPE dis2_leaf_VQADD_A1_0xf1288(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQADD_A1_0xf1288(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0000NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VQADD_A1 */
	dis2_optstrings_0x7f820(PARAMS PARAMSCOMMA dis2_args,"VQADD");
	return;
}
static RETURNTYPE dis2_leaf_VBIC_reg_A1_0xf13f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1c5470(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_GEN_D_N_M(JUSTPARAMS,dis2_args_0,Q,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VBIC_reg_A1_0xf13f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D01(Vn:4)(Vd:4)0001NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VBIC_reg_A1 */
	dis2_optstrings_0x1c5470(PARAMS PARAMSCOMMA dis2_args,"VBIC");
	return;
}
static RETURNTYPE dis2_leaf_VBIF_VBIT_VBSL_A1_0xf1468(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VBIF_VBIT_VBSL_A1_0xf1468(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D(op:2)(Vn:4)(Vd:4)0001NQM1(Vm:4) {op} {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VBIF_VBIT_VBSL_A1 */
	const uint32_t op = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	static const char *ops[3] = {"VBSL","VBIT","VBIF"};
	ASIMD_GEN_D_N_M(JUSTPARAMS,ops[op-1],Q,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VAND_reg_A1_0xf1558(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VAND_reg_A1_0xf1558(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D00(Vn:4)(Vd:4)0001NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VAND_reg_A1 */
	dis2_optstrings_0x1c5470(PARAMS PARAMSCOMMA dis2_args,"VAND");
	return;
}
static RETURNTYPE dis2_leaf_VEOR_A1_0xf15d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VEOR_A1_0xf15d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D00(Vn:4)(Vd:4)0001NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VEOR_A1 */
	dis2_optstrings_0x1c5470(PARAMS PARAMSCOMMA dis2_args,"VEOR");
	return;
}
static RETURNTYPE dis2_leaf_VORR_reg_A1_0xf32a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VORR_reg_A1_0xf32a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D10(Vn:4)(Vd:4)0001NQM1(Vm:4) {lor(ne(N,M),ne(Vn,Vm))} {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VORR_reg_A1 */
	dis2_optstrings_0x1c5470(PARAMS PARAMSCOMMA dis2_args,"VORR");
	return;
}
static RETURNTYPE dis2_leaf_VMOV_reg_A1_0xf3320(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_reg_A1_0xf3320(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D10(Vm:4)(Vd:4)0001MQ(M2)1(Vm2:4) {eq(M,M2)} {eq(Vm,Vm2)} {lnot(band(Q,bor(Vd,Vm)))} VMOV_reg_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	sprintf(params->buf,(Q?"VMOV%s\tQ%d,Q%d":"VMOV%s\tD%d,D%d"),ASIMDCOND,D_Vd>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VORN_reg_A1_0xf3500(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VORN_reg_A1_0xf3500(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D11(Vn:4)(Vd:4)0001NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VORN_reg_A1 */
	dis2_optstrings_0x1c5470(PARAMS PARAMSCOMMA dis2_args,"VORN");
	return;
}
static RETURNTYPE dis2_leaf_VADDL_VADDW_A1_0xf7c48(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x112000(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t op = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_LW_D_N_M(JUSTPARAMS,(op?dis2_args_0:dis2_args_1),size,U,op,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VADDL_VADDW_A1_0xf7c48(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)000(op)N0M0(Vm:4) {ne(size,0x3)} {lnot(band(bor(Vd,band(op,Vn)),0x1))} VADDL_VADDW_A1 */
	dis2_optstrings_0x112000(PARAMS PARAMSCOMMA dis2_args,"VADDW","VADDL");
	return;
}
static RETURNTYPE dis2_leaf_VSHR_A1_0xf5918(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x127c60(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t L = dis2_args->dis2_argf_7_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize,amt;
	if(L)
	{
		esize = 3;
		amt = 64-imm6;
	}
	else if(imm6 & 0x20)
	{
		esize = 2;
		amt = 64-imm6;
	}
	else if(imm6 & 0x10)
	{
		esize = 1;
		amt = 32-imm6;
	}
	else
	{
		esize = 0;
		amt = 16-imm6;
	}
	ASIMD_D_M(JUSTPARAMS,dis2_args_0,esize,U,Q,D_Vd,M_Vm);
	scatf(params->buf,",#%d",amt);
	return;
}
RETURNTYPE dis2_leaf_VSHR_A1_0xf5918(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)0000LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(band(Q,bor(Vd,Vm)))} VSHR_A1 */
	dis2_optstrings_0x127c60(PARAMS PARAMSCOMMA dis2_args,"VSHR");
	return;
}
static RETURNTYPE dis2_leaf_VMOV_imm_A1_0xf83d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_imm_A1_0xf83d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q(op)1(imm4:4) {lnot(land(land(lnot(op),band(cmode,0x1)),ne(band(cmode,0xc),0xc)))} {lnot(land(op,ne(cmode,0xe)))} {lnot(band(Q,Vd))} VMOV_imm_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t i_imm3_imm4 = dis2_args->dis2_argf_24_1_16_3_0_4;
	const uint32_t op = dis2_args->dis2_argf_5_1;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t cmode = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_IMM(JUSTPARAMS,"VMOV",Q,D_Vd,op,cmode,i_imm3_imm4);
	return;
}
static RETURNTYPE dis2_leaf_VSRA_A1_0xf8210(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSRA_A1_0xf8210(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)0001LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(band(Q,bor(Vd,Vm)))} VSRA_A1 */
	dis2_optstrings_0x127c60(PARAMS PARAMSCOMMA dis2_args,"VSRA");
	return;
}
static RETURNTYPE dis2_leaf_VORR_imm_A1_0xf8288(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VORR_imm_A1_0xf8288(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q01(imm4:4) {band(cmode,0x1)} {lt(cmode,0xc)} {lnot(band(Q,Vd))} VORR_imm_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t i_imm3_imm4 = dis2_args->dis2_argf_24_1_16_3_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t cmode = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_IMM(JUSTPARAMS,"VORR",Q,D_Vd,0,cmode,i_imm3_imm4);
	return;
}
static RETURNTYPE dis2_leaf_VMVN_imm_A1_0xf5be8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x115d48(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t i_imm3_imm4 = dis2_args->dis2_argf_24_1_16_3_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t cmode = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_IMM(JUSTPARAMS,dis2_args_0,Q,D_Vd,1,cmode,i_imm3_imm4);
	return;
}
RETURNTYPE dis2_leaf_VMVN_imm_A1_0xf5be8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q11(imm4:4) {lnot(land(band(cmode,0x1),lt(cmode,0xc)))} {lt(cmode,0xe)} {lnot(band(Q,Vd))} VMVN_imm_A1 */
	dis2_optstrings_0x115d48(PARAMS PARAMSCOMMA dis2_args,"VMVN");
	return;
}
static RETURNTYPE dis2_leaf_VBIC_imm_A1_0xf95a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VBIC_imm_A1_0xf95a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001i1D000(imm3:3)(Vd:4)(cmode:4)0Q11(imm4:4) {band(cmode,0x1)} {lt(cmode,0xc)} {lnot(band(Q,Vd))} VBIC_imm_A1 */
	dis2_optstrings_0x115d48(PARAMS PARAMSCOMMA dis2_args,"VBIC");
	return;
}
static RETURNTYPE dis2_leaf_VMLxx_scalar_A1_0xfa478(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMLxx_scalar_A1_0xfa478(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001Q1D(size:2)(Vn:4)(Vd:4)0(op)0FN1M0(Vm:4) {ne(size,0x3)} {lnot(lor(lor(lnot(size),land(F,eq(size,0x1))),band(Q,bor(Vd,Vn))))} VMLxx_scalar_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t op = dis2_args->dis2_argf_10_1;
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t Q = dis2_args->dis2_argf_24_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t F = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	const char *mnemonic = (op?"VMLS":"VMLA");
	if(F)
	{
		ONLY1(ASIMDFP);
		ASIMD_F32_D_M(JUSTPARAMS,mnemonic,Q,D_Vd,N_Vn);
	}
	else
	{
		ONLY1(ASIMD);
		ASIMD_I_D_M(JUSTPARAMS,mnemonic,size,Q,D_Vd,N_Vn);
	}
	uint32_t index;
	if(size==1)
		index = (M<<1)|(Vm>>3);
	else
		index = M;
	scatf(params->buf,",D%d[%d]",Vm&~(size<<3),index);
	return;
}
static RETURNTYPE dis2_leaf_VEXT_A1_0xfcee8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VEXT_A1_0xfcee8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D11(Vn:4)(Vd:4)(imm4:4)NQM0(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),land(lnot(Q),band(imm4,0x8))))} VEXT_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t imm4 = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_GEN_D_N_M(JUSTPARAMS,"VEXT",Q,D_Vd,N_Vn,M_Vm);
	scatf(params->buf,",#%d",imm4);
	return;
}
static RETURNTYPE dis2_leaf_VREV16_VREV32_VREV64_A1_0xfcf60(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VREV16_VREV32_VREV64_A1_0xfcf60(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)000(op:2)QM0(Vm:4) {lnot(lor(ge(add(op,size),0x3),band(Q,bor(Vd,Vm))))} VREV16_VREV32_VREV64_A1 */
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t op = dis2_args->dis2_argf_7_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	const char *fmt = (Q?"VREV%d%s.%d\tQ%d,Q%d":"VREV%d%s.%d\tD%d,D%d");
	sprintf(params->buf,fmt,64>>op,ASIMDCOND,8<<size,D_Vd>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VCGT_imm_0_A1_0xfd420(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d50a0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t F = dis2_args->dis2_argf_10_1;
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	if(F)
	{
		ONLY1(ASIMDFP);
		ASIMD_F32_D_M(JUSTPARAMS,dis2_args_0,Q,D_Vd,M_Vm);
	}
	else
	{
		ONLY1(ASIMD);
		ASIMD_D_M(JUSTPARAMS,dis2_args_1,size,0,Q,D_Vd,M_Vm);
	}
	strcat(params->buf,", #0");
	return;
}
RETURNTYPE dis2_leaf_VCGT_imm_0_A1_0xfd420(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)01(Vd:4)0F000QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm))))} VCGT_imm_0_A1 */
	dis2_optstrings_0x1d50a0(PARAMS PARAMSCOMMA dis2_args,"VCGT","VCGT");
	return;
}
static RETURNTYPE dis2_leaf_VSWP_A1_0xfd8c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSWP_A1_0xfd8c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)00000QM0(Vm:4) {lnot(lor(size,band(Q,bor(Vd,Vm))))} VSWP_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	const char *fmt = (Q?"VSWP%s\tQ%d,Q%d":"VSWP%s\tD%d,D%d");
	sprintf(params->buf,fmt,ASIMDCOND,D_Vd>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VCVTx_ASIMD_A1_0xff060(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVTx_ASIMD_A1_0xff060(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)11(Vd:4)00(RM:2)(op)QM0(Vm:4) {lnot(lor(ne(size,0x2),band(Q,bor(Vd,Vm))))} VCVTx_ASIMD_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t op = dis2_args->dis2_argf_7_1;
	const uint32_t RM = dis2_args->dis2_argf_8_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	const char rms[4] = {'A','N','P','M'};
	sprintf(params->buf,(Q?"VCVT%c.%c32.F32\tQ%d,Q%d":"VCVT%c.%c32.F32\tD%d,D%d"),rms[RM],(op?'U':'S'),D_Vd>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VCGE_imm_0_A1_0x106b80(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCGE_imm_0_A1_0x106b80(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)01(Vd:4)0F001QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm))))} VCGE_imm_0_A1 */
	dis2_optstrings_0x1d50a0(PARAMS PARAMSCOMMA dis2_args,"VCGE","VCGE");
	return;
}
static RETURNTYPE dis2_leaf_VTRN_A1_0x1063f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x19b4b8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	const char *fmt = (Q?dis2_args_0:dis2_args_1);
	sprintf(params->buf,fmt,ASIMDCOND,8<<size,D_Vd>>Q,M_Vm>>Q);
	return;
}
RETURNTYPE dis2_leaf_VTRN_A1_0x1063f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)00001QM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(Vd,Vm))))} VTRN_A1 */
	dis2_optstrings_0x19b4b8(PARAMS PARAMSCOMMA dis2_args,"VTRN%s.%d\tQ%d,Q%d","VTRN%s.%d\tD%d,D%d");
	return;
}
static RETURNTYPE dis2_leaf_VCEQ_imm_0_A1_0x111900(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCEQ_imm_0_A1_0x111900(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)01(Vd:4)0F010QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm))))} VCEQ_imm_0_A1 */
	const uint32_t F = dis2_args->dis2_argf_10_1;
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	if(F)
	{
		ONLY1(ASIMDFP);
		ASIMD_F32_D_M(JUSTPARAMS,"VCEQ",Q,D_Vd,M_Vm);
	}
	else
	{
		ONLY1(ASIMD);
		ASIMD_I_D_M(JUSTPARAMS,"VCEQ",size,Q,D_Vd,M_Vm);
	}
	strcat(params->buf,", #0");
	return;
}
static RETURNTYPE dis2_leaf_VUZP_A1_0x10d928(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VUZP_A1_0x10d928(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)00010QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(lnot(Q),eq(size,0x2))),band(Q,bor(Vd,Vm))))} VUZP_A1 */
	dis2_optstrings_0x19b4b8(PARAMS PARAMSCOMMA dis2_args,"VUZP%s.%d\tQ%d,Q%d","VUZP%s.%d\tD%d,D%d");
	return;
}
static RETURNTYPE dis2_leaf_VCLE_imm_0_A1_0x10d738(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCLE_imm_0_A1_0x10d738(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)01(Vd:4)0F011QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm))))} VCLE_imm_0_A1 */
	dis2_optstrings_0x1d50a0(PARAMS PARAMSCOMMA dis2_args,"VCLE","VCLE");
	return;
}
static RETURNTYPE dis2_leaf_VZIP_A1_0x10dab8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VZIP_A1_0x10dab8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)00011QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(lnot(Q),eq(size,0x2))),band(Q,bor(Vd,Vm))))} VZIP_A1 */
	dis2_optstrings_0x19b4b8(PARAMS PARAMSCOMMA dis2_args,"VZIP%s.%d\tQ%d,Q%d","VZIP%s.%d\tD%d,D%d");
	return;
}
static RETURNTYPE dis2_leaf_VCGT_reg_A1_0x108550(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCGT_reg_A1_0x108550(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0011NQM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm))))} VCGT_reg_A1 */
	dis2_optstrings_0x7f820(PARAMS PARAMSCOMMA dis2_args,"VCGT");
	return;
}
static RETURNTYPE dis2_leaf_VQSUB_A1_0x123278(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQSUB_A1_0x123278(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0010NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VQSUB_A1 */
	dis2_optstrings_0x7f820(PARAMS PARAMSCOMMA dis2_args,"VQSUB");
	return;
}
static RETURNTYPE dis2_leaf_VCGE_reg_A1_0x12b0f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCGE_reg_A1_0x12b0f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0011NQM1(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm))))} VCGE_reg_A1 */
	dis2_optstrings_0x7f820(PARAMS PARAMSCOMMA dis2_args,"VCGE");
	return;
}
static RETURNTYPE dis2_leaf_VSUBL_VSUBW_A1_0x12e170(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSUBL_VSUBW_A1_0x12e170(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)001(op)N0M0(Vm:4) {ne(size,0x3)} {lnot(band(bor(Vd,band(op,Vn)),0x1))} VSUBL_VSUBW_A1 */
	dis2_optstrings_0x112000(PARAMS PARAMSCOMMA dis2_args,"VSUBW","VSUBL");
	return;
}
static RETURNTYPE dis2_leaf_VRSHR_A1_0x123080(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRSHR_A1_0x123080(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)0010LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(band(Q,bor(Vd,Vm)))} VRSHR_A1 */
	dis2_optstrings_0x127c60(PARAMS PARAMSCOMMA dis2_args,"VRSHR");
	return;
}
static RETURNTYPE dis2_leaf_VRSRA_A1_0x11d110(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRSRA_A1_0x11d110(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)0011LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(band(Q,bor(Vd,Vm)))} VRSRA_A1 */
	dis2_optstrings_0x127c60(PARAMS PARAMSCOMMA dis2_args,"VRSRA");
	return;
}
static RETURNTYPE dis2_leaf_VQDMLAL_VQDMLSL_A2_0xf5b60(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQDMLAL_VQDMLSL_A2_0xf5b60(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(size:2)(Vn:4)(Vd:4)0(op)11N1M0(Vm:4) {ne(size,0x3)} {lnot(lor(lnot(size),band(Vd,0x1)))} VQDMLAL_VQDMLSL_A2 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t op = dis2_args->dis2_argf_10_1;
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t index;
	if(size==1)
		index = (M<<1)|(Vm>>3);
	else
		index = M;
	ASIMD_QD_DN_DM(JUSTPARAMS,(op?"VQDMLSL":"VQDMLAL"),size,0,D_Vd,N_Vn,Vm&~(size<<3));
	scatf(params->buf,"[%d]",index);
	return;
}
static RETURNTYPE dis2_leaf_VMLxx_scalar_A2_0x11dd28(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMLxx_scalar_A2_0x11dd28(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)0(op)10N1M0(Vm:4) {ne(size,0x3)} {lnot(lor(lnot(size),band(Vd,0x1)))} VMLxx_scalar_A2 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t op = dis2_args->dis2_argf_10_1;
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	const char *mnemonic = (op?"VMLSL":"VMLAL");
	uint32_t index;
	if(size==1)
		index = (M<<1)|(Vm>>3);
	else
		index = M;
	ASIMD_QD_DN_DM(JUSTPARAMS,mnemonic,size,U,D_Vd,N_Vn,Vm&~(size<<3));
	scatf(params->buf,"[%d]",index);
	return;
}
static RETURNTYPE dis2_leaf_VPADDL_A1_0x12ffa0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d01f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t op = dis2_args->dis2_argf_7_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_M(JUSTPARAMS,dis2_args_0,size,op,Q,D_Vd,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VPADDL_A1_0x12ffa0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)0010(op)QM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(Vd,Vm))))} VPADDL_A1 */
	dis2_optstrings_0x1d01f0(PARAMS PARAMSCOMMA dis2_args,"VPADDL");
	return;
}
static RETURNTYPE dis2_leaf_VCLT_imm_0_A1_0x11ea68(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCLT_imm_0_A1_0x11ea68(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)01(Vd:4)0F100QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm))))} VCLT_imm_0_A1 */
	dis2_optstrings_0x1d50a0(PARAMS PARAMSCOMMA dis2_args,"VCLT","VCLT");
	return;
}
static RETURNTYPE dis2_leaf_VMOVN_A1_0x11f340(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOVN_A1_0x11f340(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)001000M0(Vm:4) {lnot(lor(eq(size,0x3),band(Vm,0x1)))} VMOVN_A1 */
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	sprintf(params->buf,"VMOVN%s.I%d\tD%d,Q%d",ASIMDCOND,16<<size,D_Vd,M_Vm>>1);
	return;
}
static RETURNTYPE dis2_leaf_VQMOVN_VQMOVUN_A1_0x126aa0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQMOVN_VQMOVUN_A1_0x126aa0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)0010(op:2)M0(Vm:4) {op} {lnot(lor(eq(size,0x3),band(Vm,0x1)))} VQMOVN_VQMOVUN_A1 */
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t op = dis2_args->dis2_argf_6_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	sprintf(params->buf,"VQMOV%sN%s.%c%d\tD%d,Q%d",(op==1?"U":""),ASIMDCOND,(op==3?'U':'S'),16<<size,D_Vd,M_Vm>>1);
	return;
}
static RETURNTYPE dis2_leaf_VABS_A1_0x11f4a0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1c0720(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t F = dis2_args->dis2_argf_10_1;
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	if(F)
	{
		ONLY1(ASIMDFP);
		ASIMD_F32_D_M(JUSTPARAMS,dis2_args_0,Q,D_Vd,M_Vm);
	}
	else
	{
		ONLY1(ASIMD);
		ASIMD_D_M(JUSTPARAMS,dis2_args_1,size,0,Q,D_Vd,M_Vm);
	}
	return;
}
RETURNTYPE dis2_leaf_VABS_A1_0x11f4a0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)01(Vd:4)0F110QM0(Vm:4) {ne(size,0x3)} {lnot(land(F,ne(size,0x2)))} {lnot(band(Q,bor(Vd,Vm)))} VABS_A1 */
	dis2_optstrings_0x1c0720(PARAMS PARAMSCOMMA dis2_args,"VABS","VABS");
	return;
}
static RETURNTYPE dis2_leaf_VSHLL_A2_0x1340b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSHLL_A2_0x1340b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)001100M0(Vm:4) {lnot(lor(eq(size,0x3),band(Vd,0x1)))} VSHLL_A2 */
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	sprintf(params->buf,"VSHLL%s.I%d\tQ%d,D%d,#%d",ASIMDCOND,8<<size,D_Vd>>1,M_Vm,8<<size);
	return;
}
static RETURNTYPE dis2_leaf_VNEG_A1_0x120a90(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VNEG_A1_0x120a90(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)01(Vd:4)0F111QM0(Vm:4) {lnot(lor(lor(eq(size,0x3),land(F,ne(size,0x2))),band(Q,bor(Vd,Vm))))} VNEG_A1 */
	dis2_optstrings_0x1c0720(PARAMS PARAMSCOMMA dis2_args,"VNEG","VNEG");
	return;
}
static RETURNTYPE dis2_leaf_VSHL_reg_A1_0x165e78(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x16d950(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_N_M(JUSTPARAMS,dis2_args_0,size,U,Q,D_Vd,M_Vm,N_Vn);
	return;
}
RETURNTYPE dis2_leaf_VSHL_reg_A1_0x165e78(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0100NQM0(Vm:4) {lnot(band(Q,bor(bor(Vd,Vm),Vn)))} VSHL_reg_A1 */
	dis2_optstrings_0x16d950(PARAMS PARAMSCOMMA dis2_args,"VSHL");
	return;
}
static RETURNTYPE dis2_leaf_VRSHL_A1_0x1635f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRSHL_A1_0x1635f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0101NQM0(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VRSHL_A1 */
	dis2_optstrings_0x16d950(PARAMS PARAMSCOMMA dis2_args,"VRSHL");
	return;
}
static RETURNTYPE dis2_leaf_VQSHL_reg_A1_0xf51c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQSHL_reg_A1_0xf51c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0100NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vm),Vn)))} VQSHL_reg_A1 */
	dis2_optstrings_0x16d950(PARAMS PARAMSCOMMA dis2_args,"VQSHL");
	return;
}
static RETURNTYPE dis2_leaf_VQRSHL_A1_0x130d10(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQRSHL_A1_0x130d10(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0101NQM1(Vm:4) {lnot(band(Q,bor(bor(Vd,Vm),Vn)))} VQRSHL_A1 */
	dis2_optstrings_0x16d950(PARAMS PARAMSCOMMA dis2_args,"VQRSHL");
	return;
}
static RETURNTYPE dis2_leaf_VADDHN_A1_0x11ca50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d3d20(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_I_DD_QN_QM(JUSTPARAMS,dis2_args_0,size+1,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VADDHN_A1_0x11ca50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(size:2)(Vn:4)(Vd:4)0100N0M0(Vm:4) {ne(size,0x3)} {lnot(band(bor(Vn,Vm),0x1))} VADDHN_A1 */
	dis2_optstrings_0x1d3d20(PARAMS PARAMSCOMMA dis2_args,"VADDHN");
	return;
}
static RETURNTYPE dis2_leaf_VABA_VABAL_A2_0x120928(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x149728(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_QD_DN_DM(JUSTPARAMS,dis2_args_0,size,U,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VABA_VABAL_A2_0x120928(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)0101N0M0(Vm:4) {ne(size,0x3)} {lnot(band(Vd,0x1))} VABA_VABAL_A2 */
	dis2_optstrings_0x149728(PARAMS PARAMSCOMMA dis2_args,"VABAL");
	return;
}
static RETURNTYPE dis2_leaf_VSHL_imm_A1_0x12d4e8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSHL_imm_A1_0x12d4e8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(imm6:6)(Vd:4)0101LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(band(Q,bor(Vd,Vm)))} VSHL_imm_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t L = dis2_args->dis2_argf_7_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize;
	if(L)
		esize = 3;
	else if(imm6 & 0x20)
		esize = 2;
	else if(imm6 & 0x10)
		esize = 1;
	else
		esize = 0;
	ASIMD_I_D_M(JUSTPARAMS,"VSHL",esize,Q,D_Vd,M_Vm);
	scatf(params->buf,",#%d",imm6&~(0xf8<<esize));
	return;
}
static RETURNTYPE dis2_leaf_VRADDHN_A1_0x12dfb0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRADDHN_A1_0x12dfb0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D(size:2)(Vn:4)(Vd:4)0100N0M0(Vm:4) {ne(size,0x3)} {lnot(band(bor(Vn,Vm),0x1))} VRADDHN_A1 */
	dis2_optstrings_0x1d3d20(PARAMS PARAMSCOMMA dis2_args,"VRADDHN");
	return;
}
static RETURNTYPE dis2_leaf_VSRI_A1_0x15db18(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSRI_A1_0x15db18(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D(imm6:6)(Vd:4)0100LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(band(Q,bor(Vd,Vm)))} VSRI_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t L = dis2_args->dis2_argf_7_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize,amt;
	if(L)
	{
		esize = 64;
		amt = 64-imm6;
	}
	else if(imm6 & 0x20)
	{
		esize = 32;
		amt = 64-imm6;
	}
	else if(imm6 & 0x10)
	{
		esize = 16;
		amt = 32-imm6;
	}
	else
	{
		esize = 8;
		amt = 16-imm6;
	}
	const char *fmt = (Q?"VSRI%s.%d\tQ%d,Q%d,#%d":"VSRI%s.%d\tD%d,D%d,#%d");
	sprintf(params->buf,fmt,ASIMDCOND,esize,D_Vd>>Q,M_Vm>>Q,amt);
	return;
}
static RETURNTYPE dis2_leaf_VSLI_A1_0x142d00(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSLI_A1_0x142d00(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D(imm6:6)(Vd:4)0101LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(band(Q,bor(Vd,Vm)))} VSLI_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t L = dis2_args->dis2_argf_7_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize;
	if(L)
		esize = 64;
	else if(imm6 & 0x20)
		esize = 32;
	else if(imm6 & 0x10)
		esize = 16;
	else
		esize = 8;
	const char *fmt = (Q?"VSLI%s.%d\tQ%d,Q%d,#%d":"VSLI%s.%d\tD%d,D%d,#%d");
	sprintf(params->buf,fmt,ASIMDCOND,esize,D_Vd>>Q,M_Vm>>Q,imm6&(esize-1));
	return;
}
static RETURNTYPE dis2_leaf_VCLS_A1_0x156668(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d4de0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_M(JUSTPARAMS,dis2_args_0,size,0,Q,D_Vd,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VCLS_A1_0x156668(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)01000QM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(Vd,Vm))))} VCLS_A1 */
	dis2_optstrings_0x1d4de0(PARAMS PARAMSCOMMA dis2_args,"VCLS");
	return;
}
static RETURNTYPE dis2_leaf_VCLZ_A1_0x156fe8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCLZ_A1_0x156fe8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)01001QM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(Vd,Vm))))} VCLZ_A1 */
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_I_D_M(JUSTPARAMS,"VCLZ",size,Q,D_Vd,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VCNT_A1_0x16a2e0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x16e4e0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	sprintf(params->buf,(Q?dis2_args_0:dis2_args_1),ASIMDCOND,D_Vd>>Q,M_Vm>>Q);
	return;
}
RETURNTYPE dis2_leaf_VCNT_A1_0x16a2e0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)01010QM0(Vm:4) {lnot(lor(size,band(Q,bor(Vd,Vm))))} VCNT_A1 */
	dis2_optstrings_0x16e4e0(PARAMS PARAMSCOMMA dis2_args,"VCNT%s.8\tQ%d,Q%d","VCNT%s.8\tD%d,D%d");
	return;
}
static RETURNTYPE dis2_leaf_VMVN_reg_A1_0x16b8b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMVN_reg_A1_0x16b8b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)01011QM0(Vm:4) {lnot(lor(size,band(Q,bor(Vd,Vm))))} VMVN_reg_A1 */
	dis2_optstrings_0x16e4e0(PARAMS PARAMSCOMMA dis2_args,"VMVN%s\tQ%d,Q%d","VMVN%s\tD%d,D%d");
	return;
}
static RETURNTYPE dis2_leaf_VRINTx_ASIMD_A1_0x16da40(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRINTx_ASIMD_A1_0x16da40(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)01(op:3)QM0(Vm:4) {lor(lnot(band(op,0x5)),eq(band(op,0x5),0x5))} {lnot(lor(land(Q,lor(band(Vd,0x1),band(Vm,0x1))),ne(size,0x2)))} VRINTx_ASIMD_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t op = dis2_args->dis2_argf_7_3;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	const char rms[4] = {'N','A','M','P'};
	sprintf(params->buf,(Q?"VRINT%c.F32.F32\tQ%d,Q%d":"VRINT%c.F32.F32\tD%d,D%d"),rms[op>>1],D_Vd>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VRINTX_ASIMD_A1_0x16e728(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1bfdb8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	sprintf(params->buf,(Q?dis2_args_0:dis2_args_1),D_Vd>>Q,M_Vm>>Q);
	return;
}
RETURNTYPE dis2_leaf_VRINTX_ASIMD_A1_0x16e728(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)01001QM0(Vm:4) {lnot(lor(land(Q,lor(band(Vd,0x1),band(Vm,0x1))),ne(size,0x2)))} VRINTX_ASIMD_A1 */
	dis2_optstrings_0x1bfdb8(PARAMS PARAMSCOMMA dis2_args,"VRINTX.F32.F32\tQ%d,Q%d","VRINTX.F32.F32\tD%d,D%d");
	return;
}
static RETURNTYPE dis2_leaf_VRINTZ_ASIMD_A1_0x1707f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRINTZ_ASIMD_A1_0x1707f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)01011QM0(Vm:4) {lnot(lor(land(Q,lor(band(Vd,0x1),band(Vm,0x1))),ne(size,0x2)))} VRINTZ_ASIMD_A1 */
	dis2_optstrings_0x1bfdb8(PARAMS PARAMSCOMMA dis2_args,"VRINTZ.F32.F32\tQ%d,Q%d","VRINTZ.F32.F32\tD%d,D%d");
	return;
}
static RETURNTYPE dis2_leaf_VRECPE_A1_0x16f4b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1bff28(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t size = dis2_args->dis2_argf_18_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t F = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	if(F)
	{
		ONLY1(ASIMDFP);
		ASIMD_F32_D_M(JUSTPARAMS,dis2_args_0,Q,D_Vd,M_Vm);
	}
	else
	{
		ONLY1(ASIMD);
		ASIMD_D_M(JUSTPARAMS,dis2_args_1,size,1,Q,D_Vd,M_Vm);
	}
	return;
}
RETURNTYPE dis2_leaf_VRECPE_A1_0x16f4b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)11(Vd:4)010F0QM0(Vm:4) {lnot(lor(band(Q,bor(Vd,Vm)),ne(size,0x2)))} VRECPE_A1 */
	dis2_optstrings_0x1bff28(PARAMS PARAMSCOMMA dis2_args,"VRECPE","VRECPE");
	return;
}
static RETURNTYPE dis2_leaf_VRSQRTE_A1_0x16f6f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRSQRTE_A1_0x16f6f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)11(Vd:4)010F1QM0(Vm:4) {lnot(lor(band(Q,bor(Vd,Vm)),ne(size,0x2)))} VRSQRTE_A1 */
	dis2_optstrings_0x1bff28(PARAMS PARAMSCOMMA dis2_args,"VRSQRTE","VRSQRTE");
	return;
}
static RETURNTYPE dis2_leaf_VMAX_VMIN_int_A1_0x14c820(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMAX_VMIN_int_A1_0x14c820(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0110NQM(op)(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3)))} VMAX_VMIN_int_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t op = dis2_args->dis2_argf_4_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_N_M(JUSTPARAMS,(op?"VMIN":"VMAX"),size,U,Q,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VABD_VABDL_A1_0x163a28(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VABD_VABDL_A1_0x163a28(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0111NQM0(Vm:4) {ne(size,0x3)} {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VABD_VABDL_A1 */
	dis2_optstrings_0x7f820(PARAMS PARAMSCOMMA dis2_args,"VABD");
	return;
}
static RETURNTYPE dis2_leaf_VABA_VABAL_A1_0x1509d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VABA_VABAL_A1_0x1509d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)0111NQM1(Vm:4) {ne(size,0x3)} {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VABA_VABAL_A1 */
	dis2_optstrings_0x7f820(PARAMS PARAMSCOMMA dis2_args,"VABA");
	return;
}
static RETURNTYPE dis2_leaf_VSUBHN_A1_0x14dc50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSUBHN_A1_0x14dc50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(size:2)(Vn:4)(Vd:4)0110N0M0(Vm:4) {ne(size,0x3)} {lnot(band(bor(Vn,Vm),0x1))} VSUBHN_A1 */
	dis2_optstrings_0x1d3d20(PARAMS PARAMSCOMMA dis2_args,"VSUBHN");
	return;
}
static RETURNTYPE dis2_leaf_VRSUBHN_A1_0x158ab8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRSUBHN_A1_0x158ab8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D(size:2)(Vn:4)(Vd:4)0110N0M0(Vm:4) {ne(size,0x3)} {lnot(band(bor(Vn,Vm),0x1))} VRSUBHN_A1 */
	dis2_optstrings_0x1d3d20(PARAMS PARAMSCOMMA dis2_args,"VRSUBHN");
	return;
}
static RETURNTYPE dis2_leaf_VABD_VABDL_A2_0x14e700(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VABD_VABDL_A2_0x14e700(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)0111N0M0(Vm:4) {ne(size,0x3)} {lnot(band(Vd,0x1))} VABD_VABDL_A2 */
	dis2_optstrings_0x149728(PARAMS PARAMSCOMMA dis2_args,"VABDL");
	return;
}
static RETURNTYPE dis2_leaf_VQSHL_VQSHLU_imm_A1_0x14f318(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQSHL_VQSHLU_imm_A1_0x14f318(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)011(op)LQM1(Vm:4) {lor(L,gt(imm6,0x7))} {lnot(lor(lnot(lor(U,op)),band(Q,bor(Vd,Vm))))} VQSHL_VQSHLU_imm_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t L = dis2_args->dis2_argf_7_1;
	const uint32_t op = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize;
	if(L)
		esize = 3;
	else if(imm6 & 0x20)
		esize = 2;
	else if(imm6 & 0x10)
		esize = 1;
	else
		esize = 0;
	ASIMD_D_M(JUSTPARAMS,((U&&!op)?"VQSHLU":"VQSHL"),esize,U&&op,Q,D_Vd,M_Vm);
	scatf(params->buf,",#%d",imm6&~(0xf8<<esize));
	return;
}
static RETURNTYPE dis2_leaf_VPADAL_A1_0x131120(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPADAL_A1_0x131120(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)0110(op)QM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(Vd,Vm))))} VPADAL_A1 */
	dis2_optstrings_0x1d01f0(PARAMS PARAMSCOMMA dis2_args,"VPADAL");
	return;
}
static RETURNTYPE dis2_leaf_VQABS_A1_0x17f510(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQABS_A1_0x17f510(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)01110QM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(Vd,Vm))))} VQABS_A1 */
	dis2_optstrings_0x1d4de0(PARAMS PARAMSCOMMA dis2_args,"VQABS");
	return;
}
static RETURNTYPE dis2_leaf_VQNEG_A1_0x178ac8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQNEG_A1_0x178ac8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)00(Vd:4)01111QM0(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(Vd,Vm))))} VQNEG_A1 */
	dis2_optstrings_0x1d4de0(PARAMS PARAMSCOMMA dis2_args,"VQNEG");
	return;
}
static RETURNTYPE dis2_leaf_VCVT_hp_sp_ASIMD_A1_0x1751e8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVT_hp_sp_ASIMD_A1_0x1751e8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)10(Vd:4)011(op)00M0(Vm:4) {lnot(lor(lor(ne(size,0x1),band(op,Vd)),band(beor(op,0x1),Vm)))} VCVT_hp_sp_ASIMD_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t op = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDHFP);
	const char *fmt = (op?"VCVT%s.F32.F16\tQ%d,D%d":"VCVT%s.F16.F32\tD%d,Q%d");
	sprintf(params->buf,fmt,ASIMDCOND,D_Vd>>op,M_Vm>>(1-op));
	return;
}
static RETURNTYPE dis2_leaf_VCVT_fp_int_ASIMD_A1_0x190168(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVT_fp_int_ASIMD_A1_0x190168(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(size:2)11(Vd:4)011(op:2)QM0(Vm:4) {lnot(lor(ne(size,0x2),band(Q,bor(Vd,Vm))))} VCVT_fp_int_ASIMD_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t op = dis2_args->dis2_argf_7_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDFP);
	static const char *dts[4] = {"F32.S32","F32.U32","S32.F32","U32.F32"};
	const char *fmt = (Q?"VCVT%s.%s\tQ%d,Q%d":"VCVT%s.%s\tD%d,D%d");
	sprintf(params->buf,fmt,ASIMDCOND,dts[op],D_Vd>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VADD_int_A1_0x159b78(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1cedc8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_I_D_N_M(JUSTPARAMS,dis2_args_0,size,Q,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VADD_int_A1_0x159b78(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D(size:2)(Vn:4)(Vd:4)1000NQM0(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VADD_int_A1 */
	dis2_optstrings_0x1cedc8(PARAMS PARAMSCOMMA dis2_args,"VADD");
	return;
}
static RETURNTYPE dis2_leaf_VMLxx_int_A1_0x1825d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMLxx_int_A1_0x1825d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001(op)0D(size:2)(Vn:4)(Vd:4)1001NQM0(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),eq(size,0x3)))} VMLxx_int_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t op = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_I_D_N_M(JUSTPARAMS,(op?"VMLS":"VMLA"),size,Q,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VTST_A1_0x14b540(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VTST_A1_0x14b540(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D(size:2)(Vn:4)(Vd:4)1000NQM1(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm))))} VTST_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	const char *fmt = (Q?"VTST%s.%d\tQ%d,Q%d,Q%d":"VTST%s.%d\tD%d,D%d,D%d");
	sprintf(params->buf,fmt,ASIMDCOND,8<<size,D_Vd>>Q,N_Vn>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VMUL_VMULL_int_poly_A1_0x18c328(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMUL_VMULL_int_poly_A1_0x18c328(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001(op)0D(size:2)(Vn:4)(Vd:4)1001NQM1(Vm:4) {lnot(lor(lor(eq(size,0x3),land(op,size)),band(Q,bor(bor(Vd,Vn),Vm))))} VMUL_VMULL_int_poly_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t op = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	const char *fmt = (Q?"VMUL%s.%c%d\tQ%d,Q%d,Q%d":"VMUL%s.%c%d\tD%d,D%d,D%d");
	sprintf(params->buf,fmt,ASIMDCOND,(op?'P':'I'),8<<size,D_Vd>>Q,N_Vn>>Q,M_Vm>>Q);
	return;
}
static RETURNTYPE dis2_leaf_VMLxx_int_A2_0xf3f30(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMLxx_int_A2_0xf3f30(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)10(op)0N0M0(Vm:4) {ne(size,0x3)} {lnot(band(Vd,0x1))} VMLxx_int_A2 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t op = dis2_args->dis2_argf_9_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_QD_DN_DM(JUSTPARAMS,(op?"VMLSL":"VMLAL"),size,U,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VQDMLAL_VQDMLSL_A1_0x158738(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQDMLAL_VQDMLSL_A1_0x158738(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(size:2)(Vn:4)(Vd:4)10(op)1N0M0(Vm:4) {ne(size,0x3)} {lnot(lor(lnot(size),band(Vd,0x1)))} VQDMLAL_VQDMLSL_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t op = dis2_args->dis2_argf_9_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_QD_DN_DM(JUSTPARAMS,(op?"VQDMLSL":"VQDMLAL"),size,0,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VSHRN_A1_0x17d310(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSHRN_A1_0x17d310(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(imm6:6)(Vd:4)100000M1(Vm:4) {gt(imm6,0x7)} {lnot(band(Vm,0x1))} VSHRN_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize;
	if(imm6 & 0x20)
		esize = 64;
	else if(imm6 & 0x10)
		esize = 32;
	else
		esize = 16;
	sprintf(params->buf,"VSHRN%s.I%d\tQ%d,D%d,#%d",ASIMDCOND,esize,D_Vd>>1,M_Vm,esize-imm6);
	return;
}
static RETURNTYPE dis2_leaf_VQSHRN_VQSHRUN_A1_0x1840d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d03d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t op = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize;
	if(imm6 & 0x20)
		esize = 64;
	else if(imm6 & 0x10)
		esize = 32;
	else
		esize = 16;
	sprintf(params->buf,dis2_args_0,((U&&!op)?"U":""),ASIMDCOND,((U&&op)?'U':'S'),esize,D_Vd,M_Vm>>1,esize-imm6);
	return;
}
RETURNTYPE dis2_leaf_VQSHRN_VQSHRUN_A1_0x1840d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)100(op)00M1(Vm:4) {gt(imm6,0x7)} {lor(U,op)} {lnot(band(Vm,0x1))} VQSHRN_VQSHRUN_A1 */
	dis2_optstrings_0x1d03d8(PARAMS PARAMSCOMMA dis2_args,"VQSHR%sN%s.%c%d\tD%d,Q%d,#%d");
	return;
}
static RETURNTYPE dis2_leaf_VMUL_VMULL_scalar_A1_0x180cf0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMUL_VMULL_scalar_A1_0x180cf0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001Q1D(size:2)(Vn:4)(Vd:4)100FN1M0(Vm:4) {ne(size,0x3)} {lnot(lor(lor(lnot(size),eq(F,size)),band(Q,bor(Vd,Vn))))} VMUL_VMULL_scalar_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t Q = dis2_args->dis2_argf_24_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t F = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	if(F)
	{
		ONLY1(ASIMDFP);
		ASIMD_F32_D_M(JUSTPARAMS,"VMUL",Q,D_Vd,N_Vn);
	}
	else
	{
		ONLY1(ASIMD);
		ASIMD_I_D_M(JUSTPARAMS,"VMUL",size,Q,D_Vd,N_Vn);
	}
	uint32_t index;
	if(size==1)
		index = (M<<1)|(Vm>>3);
	else
		index = M;
	scatf(params->buf,",D%d[%d]",Vm&~(size<<3),index);
	return;
}
static RETURNTYPE dis2_leaf_VRSHRN_A1_0x175ec8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRSHRN_A1_0x175ec8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(imm6:6)(Vd:4)100001M1(Vm:4) {gt(imm6,0x7)} {lnot(band(Vm,0x1))} VRSHRN_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize;
	if(imm6 & 0x20)
		esize = 64;
	else if(imm6 & 0x10)
		esize = 32;
	else
		esize = 16;
	sprintf(params->buf,"VRSHRN%s.I%d\tD%d,Q%d,#%d",ASIMDCOND,esize,D_Vd,M_Vm>>1,esize-imm6);
	return;
}
static RETURNTYPE dis2_leaf_VQRSHRN_VQRSHRUN_A1_0x19a5f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQRSHRN_VQRSHRUN_A1_0x19a5f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)100(op)01M1(Vm:4) {gt(imm6,0x7)} {lor(U,op)} {lnot(band(Vm,0x1))} VQRSHRN_VQRSHRUN_A1 */
	dis2_optstrings_0x1d03d8(PARAMS PARAMSCOMMA dis2_args,"VQRSHR%sN%s.%c%d\tD%d,Q%d,#%d");
	return;
}
static RETURNTYPE dis2_leaf_VSUB_int_A1_0x14d6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSUB_int_A1_0x14d6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D(size:2)(Vn:4)(Vd:4)1000NQM0(Vm:4) {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VSUB_int_A1 */
	dis2_optstrings_0x1cedc8(PARAMS PARAMSCOMMA dis2_args,"VSUB");
	return;
}
static RETURNTYPE dis2_leaf_VCEQ_reg_A1_0x17f2b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCEQ_reg_A1_0x17f2b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D(size:2)(Vn:4)(Vd:4)1000NQM1(Vm:4) {lnot(lor(eq(size,0x3),band(Q,bor(bor(Vd,Vn),Vm))))} VCEQ_reg_A1 */
	dis2_optstrings_0x1cedc8(PARAMS PARAMSCOMMA dis2_args,"VCEQ");
	return;
}
static RETURNTYPE dis2_leaf_VTBL_VTBX_A1_0x1a3708(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VTBL_VTBX_A1_0x1a3708(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(Vn:4)(Vd:4)10(len:2)N(op)M0(Vm:4) VTBL_VTBX_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t op = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t len = dis2_args->dis2_argf_8_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t dn = N_Vn;
	_UNPREDICTABLE(dn+len>=32);
	sprintf(params->buf,"VTB%c%s.8\tD%d,{D%d",(op?'X':'L'),ASIMDCOND,D_Vd,dn);
	uint32_t len2=len;
	while(len2--)
		scatf(params->buf,",D%d",++dn);
	scatf(params->buf,"},D%d",M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VPMAX_VPMIN_int_A1_0x1862c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPMAX_VPMIN_int_A1_0x1862c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U0D(size:2)(Vn:4)(Vd:4)1010NQM(op)(Vm:4) {lnot(lor(eq(size,0x3),Q))} VPMAX_VPMIN_int_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t op = dis2_args->dis2_argf_4_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_N_M(JUSTPARAMS,(op?"VPMIN":"VPMAX"),size,U,0,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VQDMULH_A1_0x1856e0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x115050(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_N_M(JUSTPARAMS,dis2_args_0,size,0,Q,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VQDMULH_A1_0x1856e0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D(size:2)(Vn:4)(Vd:4)1011NQM0(Vm:4) {lnot(lor(lor(band(Q,bor(bor(Vd,Vn),Vm)),lnot(size)),eq(size,0x3)))} VQDMULH_A1 */
	dis2_optstrings_0x115050(PARAMS PARAMSCOMMA dis2_args,"VQDMULH");
	return;
}
static RETURNTYPE dis2_leaf_VQRDMULH_A1_0x18f098(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQRDMULH_A1_0x18f098(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D(size:2)(Vn:4)(Vd:4)1011NQM0(Vm:4) {lnot(lor(lor(band(Q,bor(bor(Vd,Vn),Vm)),lnot(size)),eq(size,0x3)))} VQRDMULH_A1 */
	dis2_optstrings_0x115050(PARAMS PARAMSCOMMA dis2_args,"VQRDMULH");
	return;
}
static RETURNTYPE dis2_leaf_VPADD_int_A1_0x151010(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPADD_int_A1_0x151010(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D(size:2)(Vn:4)(Vd:4)1011NQM1(Vm:4) {lnot(lor(eq(size,0x3),Q))} VPADD_int_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_I_D_N_M(JUSTPARAMS,"VPADD",size,0,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VSHLL_A1_0x156218(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSHLL_A1_0x156218(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)101000M1(Vm:4) {gt(imm6,0x7)} {lnot(ispow2(imm6))} {lnot(band(Vd,0x1))} VSHLL_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize;
	if(imm6 & 0x20)
		esize = 32;
	else if(imm6 & 0x10)
		esize = 16;
	else
		esize = 8;
	sprintf(params->buf,"VSHLL%s.%c%d\tQ%d,D%d,#%d",ASIMDCOND,(U?'U':'S'),esize,D_Vd>>1,M_Vm,imm6&(esize-1));
	return;
}
static RETURNTYPE dis2_leaf_VMOVL_A1_0x15f498(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOVL_A1_0x15f498(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm3:3)000(Vd:4)101000M1(Vm:4) {eq(bitcount(imm3),0x1)} {lnot(band(Vd,0x1))} VMOVL_A1 */
	const uint32_t imm3 = dis2_args->dis2_argf_19_3;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	sprintf(params->buf,"VMOVL%s.%c%d\tQ%d,D%d",ASIMDCOND,(U?'U':'S'),8*imm3,D_Vd>>1,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VMUL_VMULL_scalar_A2_0x19a0b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMUL_VMULL_scalar_A2_0x19a0b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)1010N1M0(Vm:4) {ne(size,0x3)} {lnot(lor(lnot(size),band(Vd,0x1)))} VMUL_VMULL_scalar_A2 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t index;
	if(size==1)
		index = (M<<1)|(Vm>>3);
	else
		index = M;
	ASIMD_QD_DN_DM(JUSTPARAMS,"VMULL",size,U,D_Vd,N_Vn,Vm&~(size<<3));
	scatf(params->buf,"[%d]",index);
	return;
}
static RETURNTYPE dis2_leaf_VQDMULL_A2_0x196db0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQDMULL_A2_0x196db0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(size:2)(Vn:4)(Vd:4)1011N1M0(Vm:4) {ne(size,0x3)} {lnot(lor(lnot(size),band(Vd,0x1)))} VQDMULL_A2 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t index;
	if(size==1)
		index = (M<<1)|(Vm>>3);
	else
		index = M;
	ASIMD_QD_DN_DM(JUSTPARAMS,"VQDMULL",size,0,D_Vd,N_Vn,Vm&~(size<<3));
	scatf(params->buf,"[%d]",index);
	return;
}
static RETURNTYPE dis2_leaf_VFMA_VFMS_A1_0x18ecb8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VFMA_VFMS_A1_0x18ecb8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D(op)(sz)(Vn:4)(Vd:4)1100NQM1(Vm:4) {lnot(sz)} VFMA_VFMS_A1 */
	const uint32_t op = dis2_args->dis2_argf_21_1;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDv2FP);
	ASIMD_F32_D_N_M(JUSTPARAMS,(op?"VFMS":"VFMA"),Q,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VADD_fp_A1_0x18c908(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d9ef0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDFP);
	ASIMD_F32_D_N_M(JUSTPARAMS,dis2_args_0,Q,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VADD_fp_A1_0x18c908(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D0(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lnot(sz)} {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VADD_fp_A1 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VADD");
	return;
}
static RETURNTYPE dis2_leaf_VMLA_VMLS_fp_A1_0x194968(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d8e40(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t op = dis2_args->dis2_argf_21_1;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDFP);
	ASIMD_F32_D_N_M(JUSTPARAMS,(op?dis2_args_0:dis2_args_1),Q,D_Vd,N_Vn,M_Vm);
	return;
}
RETURNTYPE dis2_leaf_VMLA_VMLS_fp_A1_0x194968(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D(op)(sz)(Vn:4)(Vd:4)1101NQM1(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),sz))} VMLA_VMLS_fp_A1 */
	dis2_optstrings_0x1d8e40(PARAMS PARAMSCOMMA dis2_args,"VMLS","VMLA");
	return;
}
static RETURNTYPE dis2_leaf_VSUB_fp_A1_0x19f8b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSUB_fp_A1_0x19f8b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D1(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),sz))} VSUB_fp_A1 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VSUB");
	return;
}
static RETURNTYPE dis2_leaf_VMUL_VMULL_int_poly_A2_0x190f58(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMUL_VMULL_int_poly_A2_0x190f58(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(size:2)(Vn:4)(Vd:4)11(op)0N0M0(Vm:4) {ne(size,0x3)} {lnot(lor(land(op,lor(U,size)),band(Vd,0x1)))} VMUL_VMULL_int_poly_A2 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_24_1;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t op = dis2_args->dis2_argf_9_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	sprintf(params->buf,"VMULL%s.%c%d\tQ%d,D%d,D%d",ASIMDCOND,(op?'P':(U?'U':'S')),8<<size,D_Vd>>1,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VQDMULL_A1_0x1936e8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQDMULL_A1_0x1936e8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100101D(size:2)(Vn:4)(Vd:4)1101N0M0(Vm:4) {ne(size,0x3)} {lnot(lor(lnot(size),band(Vd,0x1)))} VQDMULL_A1 */
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_QD_DN_DM(JUSTPARAMS,"VQDMULL",size,0,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VQDMULH_A2_0x1a8830(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0xf0570(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_20_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t Q = dis2_args->dis2_argf_24_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	ASIMD_D_M(JUSTPARAMS,dis2_args_0,size,0,Q,D_Vd,N_Vn);
	uint32_t index;
	if(size==1)
		index = (M<<1)|(Vm>>3);
	else
		index = M;
	scatf(params->buf,",D%d[%d]",Vm&~(size<<3),index);
	return;
}
RETURNTYPE dis2_leaf_VQDMULH_A2_0x1a8830(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001Q1D(size:2)(Vn:4)(Vd:4)1100N1M0(Vm:4) {ne(size,0x3)} {lnot(lor(band(Q,bor(Vd,Vn)),lnot(size)))} VQDMULH_A2 */
	dis2_optstrings_0xf0570(PARAMS PARAMSCOMMA dis2_args,"VQDMULH");
	return;
}
static RETURNTYPE dis2_leaf_VQRDMULH_A2_0x1a88a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VQRDMULH_A2_0x1a88a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001Q1D(size:2)(Vn:4)(Vd:4)1101N1M0(Vm:4) {ne(size,0x3)} {lnot(lor(band(Q,bor(Vd,Vn)),lnot(size)))} VQRDMULH_A2 */
	dis2_optstrings_0xf0570(PARAMS PARAMSCOMMA dis2_args,"VQRDMULH");
	return;
}
static RETURNTYPE dis2_leaf_VPADD_fp_A1_0x1aa330(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPADD_fp_A1_0x1aa330(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D0(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lnot(lor(sz,Q))} VPADD_fp_A1 */
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDFP);
	ASIMD_F32_D_N_M(JUSTPARAMS,"VPADD",0,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VMUL_fp_A1_0x1abed8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMUL_fp_A1_0x1abed8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D0(sz)(Vn:4)(Vd:4)1101NQM1(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),sz))} VMUL_fp_A1 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VMUL");
	return;
}
static RETURNTYPE dis2_leaf_VABD_fp_A1_0x1ae0a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VABD_fp_A1_0x1ae0a8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D1(sz)(Vn:4)(Vd:4)1101NQM0(Vm:4) {lnot(sz)} {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VABD_fp_A1 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VABD");
	return;
}
static RETURNTYPE dis2_leaf_VDUP_scalar_A1_0x1aee70(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VDUP_scalar_A1_0x1aee70(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100111D11(imm4:4)(Vd:4)11000QM0(Vm:4) {band(imm4,0x7)} {lnot(band(Q,Vd))} VDUP_scalar_A1 */
	const uint32_t imm4 = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	uint32_t esize,index;
	if(imm4 & 1)
	{
		esize = 8;
		index = imm4>>1;
	}
	else if(imm4 & 2)
	{
		esize = 16;
		index = imm4>>2;
	}
	else
	{
		esize = 32;
		index = imm4>>3;
	}
	sprintf(params->buf,"VDUP%s.%d\t%c%d,D%d[%d]",ASIMDCOND,esize,(Q?'Q':'D'),D_Vd>>Q,M_Vm,index);
	return;
}
static RETURNTYPE dis2_leaf_VCEQ_reg_A2_0x19ac90(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCEQ_reg_A2_0x19ac90(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D0(sz)(Vn:4)(Vd:4)1110NQM0(Vm:4) {lnot(lor(sz,band(Q,bor(bor(Vd,Vn),Vm))))} VCEQ_reg_A2 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VCEQ");
	return;
}
static RETURNTYPE dis2_leaf_VMAX_VMIN_fp_A1_0x194898(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMAX_VMIN_fp_A1_0x194898(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D(op)(sz)(Vn:4)(Vd:4)1111NQM0(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),sz))} VMAX_VMIN_fp_A1 */
	dis2_optstrings_0x1d8e40(PARAMS PARAMSCOMMA dis2_args,"VMIN","VMAX");
	return;
}
static RETURNTYPE dis2_leaf_VRECPS_A1_0x195238(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRECPS_A1_0x195238(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D0(sz)(Vn:4)(Vd:4)1111NQM1(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),sz))} VRECPS_A1 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VRECPS");
	return;
}
static RETURNTYPE dis2_leaf_VRSQRTS_A1_0x1a0480(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRSQRTS_A1_0x1a0480(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100100D1(sz)(Vn:4)(Vd:4)1111NQM1(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),sz))} VRSQRTS_A1 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VRSQRTS");
	return;
}
static RETURNTYPE dis2_leaf_VCVT_fp_fx_ASIMD_A1_0x1b1fd8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVT_fp_fx_ASIMD_A1_0x1b1fd8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 1111001U1D(imm6:6)(Vd:4)111(op)0QM1(Vm:4) {band(imm6,0x20)} {lnot(band(Q,bor(Vd,Vm)))} VCVT_fp_fx_ASIMD_A1 */
	const uint32_t imm6 = dis2_args->dis2_argf_16_6;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t op_U = dis2_args->dis2_argf_8_1_24_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDFP);
	static const char *dts[4] = {"F32.S32","F32.U32","S32.F32","U32.F32"};
	const char *fmt = (Q?"VCVT%s.%s\tQ%d,Q%d,#%d":"VCVT%s.%s\tD%d,D%d,#%d");
	sprintf(params->buf,fmt,ASIMDCOND,dts[op_U],D_Vd>>Q,M_Vm>>Q,64-imm6);
	return;
}
static RETURNTYPE dis2_leaf_VCGE_reg_A2_0x1ba178(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCGE_reg_A2_0x1ba178(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D0(sz)(Vn:4)(Vd:4)1110NQM0(Vm:4) {lnot(lor(sz,band(Q,bor(bor(Vd,Vn),Vm))))} VCGE_reg_A2 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VCGE");
	return;
}
static RETURNTYPE dis2_leaf_VPMAX_VPMIN_fp_A1_0x1b74c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPMAX_VPMIN_fp_A1_0x1b74c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D(op)(sz)(Vn:4)(Vd:4)1111NQM0(Vm:4) {lnot(lor(sz,Q))} VPMAX_VPMIN_fp_A1 */
	const uint32_t op = dis2_args->dis2_argf_21_1;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMDFP);
	ASIMD_F32_D_N_M(JUSTPARAMS,(op?"VPMIN":"VPMAX"),0,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VACxx_A1_0x1bae90(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VACxx_A1_0x1bae90(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D(op)(sz)(Vn:4)(Vd:4)1110NQM1(Vm:4) {lnot(sz)} {lnot(band(Q,bor(bor(Vd,Vn),Vm)))} VACxx_A1 */
	dis2_optstrings_0x1d8e40(PARAMS PARAMSCOMMA dis2_args,"VACGT","VACGE");
	return;
}
static RETURNTYPE dis2_leaf_VMAXNM_VMINNM_A1_0x1baf08(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMAXNM_VMINNM_A1_0x1baf08(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D(op)(sz)(Vn:4)(Vd:4)1111NQM1(Vm:4) {lnot(lor(band(Q,bor(bor(Vd,Vn),Vm)),sz))} VMAXNM_VMINNM_A1 */
	const uint32_t op = dis2_args->dis2_argf_21_1;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t Q = dis2_args->dis2_argf_6_1;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	ASIMD_F32_D_N_M(JUSTPARAMS,(op?"VMINNM":"VMAXNM"),Q,D_Vd,N_Vn,M_Vm);
	return;
}
static RETURNTYPE dis2_leaf_VCGT_reg_A2_0x1b0f50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCGT_reg_A2_0x1b0f50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111100110D1(sz)(Vn:4)(Vd:4)1110NQM0(Vm:4) {lnot(lor(sz,band(Q,bor(bor(Vd,Vn),Vm))))} VCGT_reg_A2 */
	dis2_optstrings_0x1d9ef0(PARAMS PARAMSCOMMA dis2_args,"VCGT");
	return;
}
static RETURNTYPE dis2_leaf_VST4_mult_A1_0x1852a0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1dd0f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t align = dis2_args->dis2_argf_4_2;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t type = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,-1,4,type+1,Rn,(align?32<<align:0),Rm);
	return;
}
RETURNTYPE dis2_leaf_VST4_mult_A1_0x1852a0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lt(type,0x2)} {lnot(eq(size,0x3))} VST4_mult_A1 */
	dis2_optstrings_0x1dd0f0(PARAMS PARAMSCOMMA dis2_args,"VST4");
	return;
}
static RETURNTYPE dis2_leaf_VST1_mult_A1_0x1b50c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1de1e8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t align = dis2_args->dis2_argf_4_2;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t type = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	uint32_t count = 1;
	if(type==10)
		count = 2;
	else if(type==6)
		count = 3;
	else if(type==2)
		count = 4;
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,-1,count,1,Rn,(align?32<<align:0),Rm);
	return;
}
RETURNTYPE dis2_leaf_VST1_mult_A1_0x1b50c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lor(lor(eq(type,0x7),eq(type,0xa)),lor(eq(type,0x6),eq(type,0x2)))} {lnot(lor(land(eq(band(type,0xe),0x6),band(align,0x2)),land(eq(type,0xa),eq(align,0x3))))} VST1_mult_A1 */
	dis2_optstrings_0x1de1e8(PARAMS PARAMSCOMMA dis2_args,"VST1");
	return;
}
static RETURNTYPE dis2_leaf_VST2_mult_A1_0x1b85d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d98d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t align = dis2_args->dis2_argf_4_2;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t type = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	int count,stride;
	if(type==8)
	{
		count=2;
		stride=1;
	}
	else if(type==9)
	{
		count=2;
		stride=2;
	}
	else
	{
		/* type==3 */
		count=4;
		stride=1;
	}
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,-1,count,stride,Rn,(align?32<<align:0),Rm);
	return;
}
RETURNTYPE dis2_leaf_VST2_mult_A1_0x1b85d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lor(eq(band(type,0xe),0x8),eq(type,0x3))} {lnot(lor(eq(size,0x3),land(eq(band(type,0xe),0x8),eq(align,0x3))))} VST2_mult_A1 */
	dis2_optstrings_0x1d98d8(PARAMS PARAMSCOMMA dis2_args,"VST2");
	return;
}
static RETURNTYPE dis2_leaf_VST3_mult_A1_0x1bd4e0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1db9f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t align = dis2_args->dis2_argf_4_2;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t type = dis2_args->dis2_argf_8_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,-1,3,(type&1)+1,Rn,(align?64:0),Rm);
	return;
}
RETURNTYPE dis2_leaf_VST3_mult_A1_0x1bd4e0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D00(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(band(type,0xe),0x4)} {lnot(lor(eq(size,0x3),band(align,0x2)))} VST3_mult_A1 */
	dis2_optstrings_0x1db9f8(PARAMS PARAMSCOMMA dis2_args,"VST3");
	return;
}
static RETURNTYPE dis2_leaf_VST1_onelane_A1_0xf1b00(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1db200(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_10_2;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t index_align = dis2_args->dis2_argf_4_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,index_align>>(size+1),1,0,Rn,((index_align&size)?8<<size:0),Rm);
	return;
}
RETURNTYPE dis2_leaf_VST1_onelane_A1_0xf1b00(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D00(Rn:4)(Vd:4)(size:2)00(index_align:4)(Rm:4) {lnot(lor(eq(size,0x3),lor(band(index_align,lsl(0x1,size)),land(eq(size,0x2),leor(band(index_align,0x1),band(index_align,0x2))))))} VST1_onelane_A1 */
	dis2_optstrings_0x1db200(PARAMS PARAMSCOMMA dis2_args,"VST1");
	return;
}
static RETURNTYPE dis2_leaf_VST2_onelane_A1_0x127fa8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1db508(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_10_2;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t index_align = dis2_args->dis2_argf_4_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,index_align>>(size+1),2,((index_align&(size<<1))?1:0),Rn,((index_align&1)?16<<size:0),Rm);
	return;
}
RETURNTYPE dis2_leaf_VST2_onelane_A1_0x127fa8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D00(Rn:4)(Vd:4)(size:2)01(index_align:4)(Rm:4) {lnot(lor(eq(size,0x3),land(eq(size,0x2),band(index_align,0x2))))} VST2_onelane_A1 */
	dis2_optstrings_0x1db508(PARAMS PARAMSCOMMA dis2_args,"VST2");
	return;
}
static RETURNTYPE dis2_leaf_VST3_onelane_A1_0x133e40(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d96f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_10_2;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t index_align = dis2_args->dis2_argf_4_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,index_align>>(size+1),3,((index_align&(size<<1))?2:1),Rn,0,Rm);
	return;
}
RETURNTYPE dis2_leaf_VST3_onelane_A1_0x133e40(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D00(Rn:4)(Vd:4)(size:2)10(index_align:4)(Rm:4) {lnot(lor(eq(size,0x3),lor(band(index_align,0x1),land(eq(size,0x2),band(index_align,0x3)))))} VST3_onelane_A1 */
	dis2_optstrings_0x1d96f0(PARAMS PARAMSCOMMA dis2_args,"VST3");
	return;
}
static RETURNTYPE dis2_leaf_VST4_onelane_A1_0xf8ea8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d8df8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0)
{
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t size = dis2_args->dis2_argf_10_2;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t index_align = dis2_args->dis2_argf_4_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	uint32_t align;
	if(index_align & (1|size))
		align = (size==2?(32<<(index_align&3)):(32<<size));
	else
		align = 0;
	ASIMD_VLD_VST(JUSTPARAMS,dis2_args_0,size,D_Vd,index_align>>(size+1),4,((index_align&(size<<1))?2:1),Rn,align,Rm);
	return;
}
RETURNTYPE dis2_leaf_VST4_onelane_A1_0xf8ea8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D00(Rn:4)(Vd:4)(size:2)11(index_align:4)(Rm:4) {lnot(lor(eq(size,0x3),land(eq(size,0x2),eq(band(index_align,0x3),0x3))))} VST4_onelane_A1 */
	dis2_optstrings_0x1d8df8(PARAMS PARAMSCOMMA dis2_args,"VST4");
	return;
}
static RETURNTYPE dis2_leaf_UNALLOCATED_MEM_HINT_0x181528(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_UNALLOCATED_MEM_HINT_0x181528(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x41)} UNALLOCATED_MEM_HINT
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x61)} {lnot(band(op2,0x1))} UNALLOCATED_MEM_HINT */
	const uint32_t nonstandard = 0; /* Prevent duplicate instances due to needless dependencies on 'nonstandard' */
	COMMON
	if(params->opt->dci)
		sprintf(params->buf,"DCI\t%s%08X\t%s",HEX,OPCODE,MSG(MSG_UNALLOCATEDMEMHINT));
	else
		sprintf(params->buf,"%s",MSG(MSG_UNALLOCATEDMEMHINT));
	return;
}
static RETURNTYPE dis2_leaf_VLD2_mult_A1_0x1a47f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD2_mult_A1_0x1a47f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lor(eq(band(type,0xe),0x8),eq(type,0x3))} {lnot(lor(eq(size,0x3),land(eq(band(type,0xe),0x8),eq(align,0x3))))} VLD2_mult_A1 */
	dis2_optstrings_0x1d98d8(PARAMS PARAMSCOMMA dis2_args,"VLD2");
	return;
}
static RETURNTYPE dis2_leaf_VLD4_mult_A1_0x17c818(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD4_mult_A1_0x17c818(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {lt(type,0x2)} {lnot(eq(size,0x3))} VLD4_mult_A1 */
	dis2_optstrings_0x1dd0f0(PARAMS PARAMSCOMMA dis2_args,"VLD4");
	return;
}
static RETURNTYPE dis2_leaf_VLD1_mult_A1a_0x1a9c10(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD1_mult_A1a_0x1a9c10(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(band(type,0xe),0x6)} {lnot(band(align,0x2))} VLD1_mult_A1a
     111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(type,0x2)} VLD1_mult_A1c (as VLD1_mult_A1a)
     111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(type,0xa)} {lnot(eq(align,0x3))} VLD1_mult_A1b (as VLD1_mult_A1a) */
	dis2_optstrings_0x1de1e8(PARAMS PARAMSCOMMA dis2_args,"VLD1");
	return;
}
static RETURNTYPE dis2_leaf_VLD3_mult_A1_0x1b4850(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD3_mult_A1_0x1b4850(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101000D10(Rn:4)(Vd:4)(type:4)(size:2)(align:2)(Rm:4) {eq(band(type,0xe),0x4)} {lnot(lor(eq(size,0x3),band(align,0x2)))} VLD3_mult_A1 */
	dis2_optstrings_0x1db9f8(PARAMS PARAMSCOMMA dis2_args,"VLD3");
	return;
}
static RETURNTYPE dis2_leaf_VLD1_onelane_A1_0x150068(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD1_onelane_A1_0x150068(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)(size:2)00(index_align:4)(Rm:4) {ne(size,0x3)} {lnot(land(band(index_align,0x1),lnot(size)))} {lnot(land(band(index_align,0x2),eq(size,0x1)))} {lnot(land(lor(band(index_align,0x4),band(beor(index_align,lsr(index_align,0x1)),0x1)),eq(size,0x2)))} VLD1_onelane_A1 */
	dis2_optstrings_0x1db200(PARAMS PARAMSCOMMA dis2_args,"VLD1");
	return;
}
static RETURNTYPE dis2_leaf_VLD2_onelane_A1_0x197620(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD2_onelane_A1_0x197620(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)(size:2)01(index_align:4)(Rm:4) {ne(size,0x3)} {lnot(land(band(index_align,0x2),eq(size,0x2)))} VLD2_onelane_A1 */
	dis2_optstrings_0x1db508(PARAMS PARAMSCOMMA dis2_args,"VLD2");
	return;
}
static RETURNTYPE dis2_leaf_VLD3_onelane_A1_0x1b07f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD3_onelane_A1_0x1b07f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)(size:2)10(index_align:4)(Rm:4) {ne(size,0x3)} {lnot(land(band(index_align,0x1),lnot(band(size,0x2))))} {lnot(land(band(index_align,0x3),eq(size,0x2)))} VLD3_onelane_A1 */
	dis2_optstrings_0x1d96f0(PARAMS PARAMSCOMMA dis2_args,"VLD3");
	return;
}
static RETURNTYPE dis2_leaf_VLD4_onelane_A1_0x1b7180(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD4_onelane_A1_0x1b7180(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)(size:2)11(index_align:4)(Rm:4) {ne(size,0x3)} {lnot(land(eq(band(index_align,0x3),0x3),eq(size,0x2)))} VLD4_onelane_A1 */
	dis2_optstrings_0x1d8df8(PARAMS PARAMSCOMMA dis2_args,"VLD4");
	return;
}
static RETURNTYPE dis2_leaf_VLD1_alllanes_A1_0xf6ff8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD1_alllanes_A1_0xf6ff8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)1100(size:2)Ta(Rm:4) {lnot(lor(eq(size,0x3),land(lnot(size),a)))} VLD1_alllanes_A1 */
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t a = dis2_args->dis2_argf_4_1;
	const uint32_t T = dis2_args->dis2_argf_5_1;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,"VLD1",size,D_Vd,-2,T+1,1,Rn,(a?8<<size:0),Rm);
	return;
}
static RETURNTYPE dis2_leaf_VLD2_alllanes_A1_0x141280(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD2_alllanes_A1_0x141280(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)1101(size:2)Ta(Rm:4) {lnot(eq(size,0x3))} VLD2_alllanes_A1 */
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t a = dis2_args->dis2_argf_4_1;
	const uint32_t T = dis2_args->dis2_argf_5_1;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,"VLD2",size,D_Vd,-2,2,T+1,Rn,(a?16<<size:0),Rm);
	return;
}
static RETURNTYPE dis2_leaf_VLD3_alllanes_A1_0x16c358(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD3_alllanes_A1_0x16c358(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)1110(size:2)Ta(Rm:4) {lnot(lor(eq(size,0x3),a))} VLD3_alllanes_A1 */
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t T = dis2_args->dis2_argf_5_1;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	ASIMD_VLD_VST(JUSTPARAMS,"VLD3",size,D_Vd,-2,3,T+1,Rn,0,Rm);
	return;
}
static RETURNTYPE dis2_leaf_VLD4_alllanes_A1_0xd6ac0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLD4_alllanes_A1_0xd6ac0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111101001D10(Rn:4)(Vd:4)1111(size:2)Ta(Rm:4) {lnot(land(lnot(a),eq(size,0x3)))} VLD4_alllanes_A1 */
	const uint32_t Rm = dis2_args->dis2_argf_0_4;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t a = dis2_args->dis2_argf_4_1;
	const uint32_t T = dis2_args->dis2_argf_5_1;
	const uint32_t size = dis2_args->dis2_argf_6_2;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rn==15);
	static const uint8_t align[4] = {32,64,64,128};
	ASIMD_VLD_VST(JUSTPARAMS,"VLD4",(size&2?2:size),D_Vd,-2,4,T+1,Rn,(a?align[size]:0),Rm);
	return;
}
static RETURNTYPE dis2_leaf_PERMA_UNDEFINED_0x159780(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_PERMA_UNDEFINED_0x159780(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {lt(cond,0xe)} {eq(op1,0x1f)} {eq(op2,0x7)} PERMA_UNDEFINED */
	const uint32_t nonstandard = 0; /* Prevent duplicate instances due to needless dependencies on 'nonstandard' */
	COMMON
	if(params->opt->dci)
		sprintf(params->buf,"DCI\t%s%08X\t%s",HEX,OPCODE,MSG(MSG_PERMAUNDEFINED));
	else
		sprintf(params->buf,"%s",MSG(MSG_PERMAUNDEFINED));
	return;
}
static RETURNTYPE dis2_leaf_VMOV_2fp_A1_0x1bf0d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_2fp_A1_0x1bf0d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1100010(op)(Rt2:4)(Rt:4)101000M1(Vm:4) {ne(cond,0xf)} VMOV_2fp_A1 */
	const uint32_t Vm_M = dis2_args->dis2_argf_0_4_5_1;
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t Rt2 = dis2_args->dis2_argf_16_4;
	const uint32_t op = dis2_args->dis2_argf_20_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	_UNPREDICTABLE((Rt==15) || (Rt2==15) || (Vm_M==31));
	const char *cc = condition(JUSTPARAMS,cond);
	if(op)
	{
		_UNPREDICTABLE(Rt==Rt2);
		sprintf(params->buf,(params->opt->vfpual?"VMOV%s\t%s,%s,S%d,S%d":"FMRRS%s\t%s,%s,{S%d,S%d}"),cc,REG(Rt),REG(Rt2),Vm_M,Vm_M+1);
	}
	else
		sprintf(params->buf,(params->opt->vfpual?"VMOV%s\tS%d,S%d,%s,%s":"FMSRR%s\t{S%d,S%d},%s,%s"),cc,Vm_M,Vm_M+1,REG(Rt),REG(Rt2));
	return;
}
static RETURNTYPE dis2_leaf_VSTM_A2_0xd38c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1d9c90(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t Vd_D = dis2_args->dis2_argf_12_4_22_1;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t W = dis2_args->dis2_argf_21_1;
	const uint32_t U = dis2_args->dis2_argf_23_1;
	const uint32_t P = dis2_args->dis2_argf_24_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	uint32_t regs = imm8;
	_UNPREDICTABLE((Rn==15) && W);
	_UNPREDICTABLE(!regs || ((Vd_D+regs) > 32));
	sprintf(params->buf,(params->opt->vfpual?dis2_args_0:dis2_args_1),ldmmode(P,U),condition(JUSTPARAMS,cond),REG(Rn),(W?"!":""));
	if(regs > 1)
		scatf(params->buf,"S%d%cS%d}",Vd_D,(regs>2?'-':','),Vd_D+regs-1);
	else
		scatf(params->buf,"S%d}",Vd_D);
	return;
}
RETURNTYPE dis2_leaf_VSTM_A2_0xd38c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)110PUDW0(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(P,lnot(U)),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(W,eq(P,U)))} VSTM_A2 */
	dis2_optstrings_0x1d9c90(PARAMS PARAMSCOMMA dis2_args,"VSTM%s%s\t%s%s,{","FSTM%sS%s\t%s%s,{");
	return;
}
static RETURNTYPE dis2_leaf_VSTR_A2_0x1080d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSTR_A2_0x1080d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1101UD00(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} VSTR_A2 */
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t Vd_D = dis2_args->dis2_argf_12_4_22_1;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t U = dis2_args->dis2_argf_23_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	sprintf(params->buf,(params->opt->vfpual?"VSTR%s\tS%d,[%s,#%s%d]":"FSTS%s\tS%d,[%s,#%s%d]"),condition(JUSTPARAMS,cond),Vd_D,REG(Rn),(U?"":"-"),imm8<<2);
	return;
}
static RETURNTYPE dis2_leaf_VLDM_A2_0x190810(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLDM_A2_0x190810(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)110PUDW1(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(lnot(P),U),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(land(ne(Rn,0xf),W),eq(P,U)))} {lnot(land(land(W,eq(P,U)),eq(Rn,0xf)))} VLDM_A2 */
	dis2_optstrings_0x1d9c90(PARAMS PARAMSCOMMA dis2_args,"VLDM%s%s\t%s%s,{","FLDM%sS%s\t%s%s,{");
	return;
}
static RETURNTYPE dis2_leaf_VLDR_A2_0x1be190(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLDR_A2_0x1be190(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1101UD01(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} VLDR_A2 */
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t Vd_D = dis2_args->dis2_argf_12_4_22_1;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t U = dis2_args->dis2_argf_23_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	sprintf(params->buf,(params->opt->vfpual?"VLDR%s\tS%d,":"FLDS%s\tS%d,"),condition(JUSTPARAMS,cond),Vd_D);
	if(Rn==15)
	{
		doldrstrlit(JUSTPARAMS,U,0,imm8<<2,true);
	}
	else
	{
		scatf(params->buf,"[%s,#%s%d]",REG(Rn),(U?"":"-"),imm8<<2);
	}
	return;
}
static RETURNTYPE dis2_leaf_VPUSH_A2_0x8ebc8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1da638(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t Vd_D = dis2_args->dis2_argf_12_4_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	uint32_t regs = imm8;
	_UNPREDICTABLE(!regs || ((Vd_D+regs) > 32));
	sprintf(params->buf,(params->opt->vfpual?dis2_args_0:dis2_args_1),condition(JUSTPARAMS,cond),REG(13));
	if(regs > 1)
		scatf(params->buf,"S%d%cS%d}",Vd_D,(regs>2?'-':','),Vd_D+regs-1);
	else
		scatf(params->buf,"S%d}",Vd_D);
	return;
}
RETURNTYPE dis2_leaf_VPUSH_A2_0x8ebc8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11010D101101(Vd:4)1010(imm8:8) {ne(cond,0xf)} VPUSH_A2 */
	dis2_optstrings_0x1da638(PARAMS PARAMSCOMMA dis2_args,"VPUSH%s\t{","FSTMDBS%s\t%s!,{");
	return;
}
static RETURNTYPE dis2_leaf_VPOP_A2_0x8f0d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPOP_A2_0x8f0d8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11001D111101(Vd:4)1010(imm8:8) {ne(cond,0xf)} VPOP_A2 */
	dis2_optstrings_0x1da638(PARAMS PARAMSCOMMA dis2_args,"VPOP%s\t{","FLDMIAS%s\t%s!,{");
	return;
}
static RETURNTYPE dis2_leaf_VMOV_dbl_A1_0x1bfbd8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_dbl_A1_0x1bfbd8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1100010(op)(Rt2:4)(Rt:4)101100M1(Vm:4) {ne(cond,0xf)} VMOV_dbl_A1 */
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t Rt2 = dis2_args->dis2_argf_16_4;
	const uint32_t op = dis2_args->dis2_argf_20_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M_Vm = dis2_args->dis2_argf_5_1_0_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	_UNPREDICTABLE((Rt==15) || (Rt2==15));
	const char *cc = condition(JUSTPARAMS,cond);
	if(op)
	{
		_UNPREDICTABLE(Rt==Rt2);
		sprintf(params->buf,(params->opt->vfpual?"VMOV%s\t%s,%s,D%d":"FMRRD%s\t%s,%s,D%d"),cc,REG(Rt),REG(Rt2),M_Vm);
	}
	else
		sprintf(params->buf,(params->opt->vfpual?"VMOV%s\tD%d,%s,%s":"FMDRR%s\tD%d,%s,%s"),cc,M_Vm,REG(Rt),REG(Rt2));
	return;
}
static RETURNTYPE dis2_leaf_VSTM_A1_0x153b38(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1db688(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1,const char *dis2_args_2)
{
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t W = dis2_args->dis2_argf_21_1;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_23_1;
	const uint32_t P = dis2_args->dis2_argf_24_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	uint32_t regs = imm8>>1;
	_UNPREDICTABLE((Rn==15) && W);
	_UNPREDICTABLE(!regs || (regs > 16) || ((D_Vd+regs) > 32));
	const char *fmt;
	if(imm8 & 1)
	{
		_UNPREDICTABLE(D_Vd+regs > 16);
		fmt = dis2_args_0;
	}
	else if(params->opt->vfpual)
		fmt = dis2_args_1;
	else
		fmt = dis2_args_2;
	sprintf(params->buf,fmt,ldmmode(P,U),condition(JUSTPARAMS,cond),REG(Rn),(W?"!":""));
	if(regs > 1)
		scatf(params->buf,"D%d%cD%d}",D_Vd,(regs>2?'-':','),D_Vd+regs-1);
	else
		scatf(params->buf,"D%d}",D_Vd);
	return;
}
RETURNTYPE dis2_leaf_VSTM_A1_0x153b38(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)110PUDW0(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(P,lnot(U)),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(W,eq(P,U)))} VSTM_A1 */
	dis2_optstrings_0x1db688(PARAMS PARAMSCOMMA dis2_args,"FSTM%sX%s\t%s%s,{","VSTM%s%s\t%s%s,{","FSTM%sD%s\t%s%s,{");
	return;
}
static RETURNTYPE dis2_leaf_VSTR_A1_0x18b6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSTR_A1_0x18b6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1101UD00(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} VSTR_A1 */
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_23_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	sprintf(params->buf,(params->opt->vfpual?"VSTR%s\tD%d,[%s,#%s%d]":"FSTD%s\tD%d,[%s,#%s%d]"),condition(JUSTPARAMS,cond),D_Vd,REG(Rn),(U?"":"-"),imm8<<2);
	return;
}
static RETURNTYPE dis2_leaf_VLDM_A1_0xeb968(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLDM_A1_0xeb968(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)110PUDW1(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(lnot(P),U),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(land(ne(Rn,0xf),W),eq(P,U)))} {lnot(land(land(W,eq(P,U)),eq(Rn,0xf)))} VLDM_A1 */
	dis2_optstrings_0x1db688(PARAMS PARAMSCOMMA dis2_args,"FLDM%sX%s\t%s%s,{","VLDM%s%s\t%s%s,{","FLDM%sD%s\t%s%s,{");
	return;
}
static RETURNTYPE dis2_leaf_VLDR_A1_0xeba98(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VLDR_A1_0xeba98(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1101UD01(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} VLDR_A1 */
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t Rn = dis2_args->dis2_argf_16_4;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t U = dis2_args->dis2_argf_23_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	sprintf(params->buf,(params->opt->vfpual?"VLDR%s\tD%d,":"FLDD%s\tD%d,"),condition(JUSTPARAMS,cond),D_Vd);
	if(Rn==15)
	{
		doldrstrlit(JUSTPARAMS,U,0,imm8<<2,true);
	}
	else
	{
		scatf(params->buf,"[%s,#%s%d]",REG(Rn),(U?"":"-"),imm8<<2);
	}
	return;
}
static RETURNTYPE dis2_leaf_VPUSH_A1_0x1c1ca0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPUSH_A1_0x1c1ca0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11010D101101(Vd:4)1011(imm8:8) {ne(cond,0xf)} VPUSH_A1 */
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	uint32_t regs = imm8>>1;
	_UNPREDICTABLE(!regs || (regs > 16) || ((D_Vd+regs) > 32));
	const char *fmt;
	if(imm8 & 1)
	{
		_UNPREDICTABLE(D_Vd+regs > 16);
		fmt = "FSTMDBX%s\t%s!,{";
	}
	if(params->opt->vfpual)
		fmt = "VPUSH%s\t{";
	else
		fmt = "FSTMDBD%s\t%s!,{";
	sprintf(params->buf,fmt,condition(JUSTPARAMS,cond),REG(13));
	if(regs > 1)
		scatf(params->buf,"D%d%cD%d}",D_Vd,(regs>2?'-':','),D_Vd+regs-1);
	else
		scatf(params->buf,"D%d}",D_Vd);
	return;
}
static RETURNTYPE dis2_leaf_VPOP_A1_0x1c2b58(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VPOP_A1_0x1c2b58(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11001D111101(Vd:4)1011(imm8:8) {ne(cond,0xf)} VPOP_A1 */
	const uint32_t imm8 = dis2_args->dis2_argf_0_8;
	const uint32_t D_Vd = dis2_args->dis2_argf_22_1_12_4;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	uint32_t regs = imm8>>1;
	_UNPREDICTABLE(!regs || (regs > 16) || ((D_Vd+regs) > 32));
	const char *fmt;
	if(imm8 & 1)
	{
		_UNPREDICTABLE(D_Vd+regs > 16);
		fmt = "FLDMIAX%s\t%s!,{";
	}
	else if(params->opt->vfpual)
		fmt = "VPOP%s\t{";
	else
		fmt = "FLDMIAD%s\t%s!,{";
		sprintf(params->buf,fmt,condition(JUSTPARAMS,cond),REG(13));
	if(regs > 1)
		scatf(params->buf,"D%d%cD%d}",D_Vd,(regs>2?'-':','),D_Vd+regs-1);
	else
		scatf(params->buf,"D%d}",D_Vd);
	return;
}
static RETURNTYPE dis2_leaf_VMLA_VMLS_fp_A2_0x9b440(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1dc840(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1,const char *dis2_args_2,const char *dis2_args_3)
{
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t Vn = dis2_args->dis2_argf_16_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t op = dis2_args->dis2_argf_6_1;
	const uint32_t N = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	VFP_CC_VD_VN_VM(JUSTPARAMS,(op?dis2_args_0:dis2_args_1),(op?dis2_args_2:dis2_args_3),cond,sz,Vd,D,Vn,N,Vm,M);
	return;
}
RETURNTYPE dis2_leaf_VMLA_VMLS_fp_A2_0x9b440(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11100D00(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VMLA_VMLS_fp_A2 */
	dis2_optstrings_0x1dc840(PARAMS PARAMSCOMMA dis2_args,"VMLS","VMLA","FNMAC","FMAC");
	return;
}
static RETURNTYPE dis2_leaf_VNMLA_VNMLS_VNMUL_A1_0x1a2270(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VNMLA_VNMLS_VNMUL_A1_0x1a2270(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11100D01(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VNMLA_VNMLS_VNMUL_A1 */
	dis2_optstrings_0x1dc840(PARAMS PARAMSCOMMA dis2_args,"VNMLA","VNMLS","FNMSC","FMSC");
	return;
}
static RETURNTYPE dis2_leaf_VMUL_fp_A2_0x87120(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1dcb68(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t Vn = dis2_args->dis2_argf_16_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	VFP_CC_VD_VN_VM(JUSTPARAMS,dis2_args_0,dis2_args_1,cond,sz,Vd,D,Vn,N,Vm,M);
	return;
}
RETURNTYPE dis2_leaf_VMUL_fp_A2_0x87120(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11100D10(Vn:4)(Vd:4)101(sz)N0M0(Vm:4) {ne(cond,0xf)} VMUL_fp_A2 */
	dis2_optstrings_0x1dcb68(PARAMS PARAMSCOMMA dis2_args,"VMUL","FMUL");
	return;
}
static RETURNTYPE dis2_leaf_VADD_fp_A2_0xb6ee0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VADD_fp_A2_0xb6ee0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11100D11(Vn:4)(Vd:4)101(sz)N0M0(Vm:4) {ne(cond,0xf)} VADD_fp_A2 */
	dis2_optstrings_0x1dcb68(PARAMS PARAMSCOMMA dis2_args,"VADD","FADD");
	return;
}
static RETURNTYPE dis2_leaf_VMOV_1fp_A1_0xebf28(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_1fp_A1_0xebf28(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1110000(op)(Vn:4)(Rt:4)1010N(00)1(0000) {ne(cond,0xf)} VMOV_1fp_A1 */
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t Vn_N = dis2_args->dis2_argf_16_4_7_1;
	const uint32_t op = dis2_args->dis2_argf_20_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = dis2_args->dis2_argn_6f_0;
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	_UNPREDICTABLE(Rt==15);
	const char *cc = condition(JUSTPARAMS,cond);
	if(op)
		sprintf(params->buf,(params->opt->vfpual?"VMOV%s\t%s,S%d":"FMRS%s\t%s,S%d"),cc,REG(Rt),Vn_N);
	else
		sprintf(params->buf,(params->opt->vfpual?"VMOV%s\tS%d,%s":"FMSR%s\tS%d,%s"),cc,Vn_N,REG(Rt));
	return;
}
static RETURNTYPE dis2_leaf_VMOV_arm_A1_0x1c0e50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_arm_A1_0x1c0e50(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11100(opc1:2)0(Vd:4)(Rt:4)1011D(opc2:2)1(0000) {ne(cond,0xf)} {lnot(land(eq(opc2,0x2),lnot(band(opc1,0x2))))} VMOV_arm_A1 */
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t opc1 = dis2_args->dis2_argf_21_2;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t opc2 = dis2_args->dis2_argf_5_2;
	const uint32_t D_Vd = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = dis2_args->dis2_argn_f_0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rt==15);
	uint32_t size,index;
	const char *cc = condition(JUSTPARAMS,cond);
	if(opc1 & 2)
	{
		size = 8;
		index = ((opc1&1)<<2) | opc2;
	}
	else if(opc2 & 1)
	{
		size = 16;
		index = ((opc1&1)<<1) | (opc2>>1);
	}
	else
	{
		size = 32;
		index = (opc1 & 1);
		ONLY1(VFP_ASIMD_common);
	}
	if(params->opt->vfpual || (size != 32))
	{
		sprintf(params->buf,"VMOV%s.%d\tD%d[%d],%s",cc,size,D_Vd,index,REG(Rt));
	}
	else
	{
		sprintf(params->buf,"FMD%cR%s\tD%d,%s",(index?'H':'L'),cc,D_Vd,REG(Rt));
	}
	return;
}
static RETURNTYPE dis2_leaf_VMOV_scalar_A1_0x1c1bf8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_scalar_A1_0x1c1bf8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)1110U(opc1:2)1(Vn:4)(Rt:4)1011N(opc2:2)1(0000) {ne(cond,0xf)} {lnot(land(lor(land(U,lnot(opc2)),eq(opc2,0x2)),lnot(band(opc1,0x2))))} VMOV_scalar_A1 */
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t opc1 = dis2_args->dis2_argf_21_2;
	const uint32_t U = dis2_args->dis2_argf_23_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t opc2 = dis2_args->dis2_argf_5_2;
	const uint32_t N_Vn = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = dis2_args->dis2_argn_f_0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rt==15);
	uint32_t size,index;
	const char *cc = condition(JUSTPARAMS,cond);
	if(opc1 & 2)
	{
		size = 8;
		index = ((opc1&1)<<2) | opc2;
	}
	else if(opc2 & 1)
	{
		size = 16;
		index = ((opc1&1)<<1) | (opc2>>1);
	}
	else
	{
		size = 32;
		index = (opc1 & 1);
		ONLY1(VFP_ASIMD_common);
	}
	if(params->opt->vfpual || (size != 32))
	{
		sprintf(params->buf,"VMOV%s.%s%d\t%s,D%d[%d]",cc,(size==32?"":(U?"U":"S")),size,REG(Rt),N_Vn,index);
	}
	else
	{
		sprintf(params->buf,"FMRD%c%s\t%s,D%d",(index?'H':'L'),cc,REG(Rt),N_Vn);
	}
	return;
}
static RETURNTYPE dis2_leaf_VNMLA_VNMLS_VNMUL_A2_0x1c3e38(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VNMLA_VNMLS_VNMUL_A2_0x1c3e38(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11100D10(Vn:4)(Vd:4)101(sz)N1M0(Vm:4) {ne(cond,0xf)} VNMLA_VNMLS_VNMUL_A2 */
	dis2_optstrings_0x1dcb68(PARAMS PARAMSCOMMA dis2_args,"VNMUL","FNMUL");
	return;
}
static RETURNTYPE dis2_leaf_VSUB_fp_A2_0x1c3eb0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSUB_fp_A2_0x1c3eb0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11100D11(Vn:4)(Vd:4)101(sz)N1M0(Vm:4) {ne(cond,0xf)} VSUB_fp_A2 */
	dis2_optstrings_0x1dcb68(PARAMS PARAMSCOMMA dis2_args,"VSUB","FSUB");
	return;
}
static RETURNTYPE dis2_leaf_VSELxx_A1_0x137e00(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSELxx_A1_0x137e00(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111111100D(cc:2)(Vn:4)(Vd:4)101(sz)N0M0(Vm:4) VSELxx_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t Vn = dis2_args->dis2_argf_16_4;
	const uint32_t cc = dis2_args->dis2_argf_20_2;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t N = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	const char conds[4] = {0,6,10,12};
	VFP_CC_VD_VN_VM(JUSTPARAMS,"VSEL","VSEL",conds[cc],sz,Vd,D,Vn,N,Vm,M);
	return;
}
static RETURNTYPE dis2_leaf_VDIV_A1_0x1c50c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VDIV_A1_0x1c50c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D00(Vn:4)(Vd:4)101(sz)N0M0(Vm:4) {ne(cond,0xf)} VDIV_A1 */
	dis2_optstrings_0x1dcb68(PARAMS PARAMSCOMMA dis2_args,"VDIV","FDIV");
	return;
}
static RETURNTYPE dis2_leaf_VDUP_arm_A1_0x1c65f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VDUP_arm_A1_0x1c65f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101bQ0(Vd:4)(Rt:4)1011D0e1(0000) {ne(cond,0xf)} {lnot(band(Q,Vd))} {lnot(band(b,e))} VDUP_arm_A1 */
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t Q = dis2_args->dis2_argf_21_1;
	const uint32_t b = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t e = dis2_args->dis2_argf_5_1;
	const uint32_t D_Vd = dis2_args->dis2_argf_7_1_16_4;
	const uint32_t nonstandard = dis2_args->dis2_argn_f_0;
	COMMON
	ONLY1(ASIMD);
	_UNPREDICTABLE(Rt==15);
	uint32_t esize;
	if(b)
		esize = 8;
	else if(e)
		esize = 16;
	else
		esize = 32;
	sprintf(params->buf,"VDUP%s.%d\t%c%d,%s",condition(JUSTPARAMS,cond),esize,(Q?'Q':'D'),D_Vd>>Q,REG(Rt));
	return;
}
static RETURNTYPE dis2_leaf_VMAXNM_VMINNM_A2_0x1c5140(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMAXNM_VMINNM_A2_0x1c5140(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111111101D00(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) VMAXNM_VMINNM_A2 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t Vn = dis2_args->dis2_argf_16_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t op = dis2_args->dis2_argf_6_1;
	const uint32_t N = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	VFP_CC_VD_VN_VM(JUSTPARAMS,(op?"VMINNM":"VMAXNM"),(op?"VMINNM":"VMAXNM"),14,sz,Vd,D,Vn,N,Vm,M);
	return;
}
static RETURNTYPE dis2_leaf_VFNMA_VFNMS_A1_0x1c68f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1dc908(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1,const char *dis2_args_2,const char *dis2_args_3)
{
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t Vn = dis2_args->dis2_argf_16_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t op = dis2_args->dis2_argf_6_1;
	const uint32_t N = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY1(VFPv4);
	VFP_CC_VD_VN_VM(JUSTPARAMS,(op?dis2_args_0:dis2_args_1),(op?dis2_args_2:dis2_args_3),cond,sz,Vd,D,Vn,N,Vm,M);
	return;
}
RETURNTYPE dis2_leaf_VFNMA_VFNMS_A1_0x1c68f8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D01(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VFNMA_VFNMS_A1 */
	dis2_optstrings_0x1dc908(PARAMS PARAMSCOMMA dis2_args,"VFNMA","VFNMS","VFNMA","VFNMS");
	return;
}
static RETURNTYPE dis2_leaf_VFMA_VFMS_A2_0x1c7c30(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VFMA_VFMS_A2_0x1c7c30(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D10(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VFMA_VFMS_A2 */
	dis2_optstrings_0x1dc908(PARAMS PARAMSCOMMA dis2_args,"VFMS","VFMA","VFMS","VFMA");
	return;
}
static RETURNTYPE dis2_leaf_VMOV_imm_A2_0x1c93c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMOV_imm_A2_0x1c93c0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D11(imm4H:4)(Vd:4)101(sz)(0)0(0)0(imm4L:4) {ne(cond,0xf)} VMOV_imm_A2 */
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t imm4H_imm4L = dis2_args->dis2_argf_16_4_0_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = dis2_args->dis2_argn_a0_0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY2(VFPv3,VFPv4);
	VFP_CC_VD_IMM(JUSTPARAMS,"VMOV","FCONST",cond,sz,Vd,D,imm4H_imm4L);
	return;
}
static RETURNTYPE dis2_leaf_VMOV_reg_A2_0x1ca238(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
static RETURNTYPE dis2_optstrings_0x1deb78(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args,const char *dis2_args_0,const char *dis2_args_1)
{
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	VFP_CC_VD_VM(JUSTPARAMS,dis2_args_0,dis2_args_1,cond,sz,Vd,D,Vm,M);
	return;
}
RETURNTYPE dis2_leaf_VMOV_reg_A2_0x1ca238(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110000(Vd:4)101(sz)01M0(Vm:4) {ne(cond,0xf)} VMOV_reg_A2 */
	dis2_optstrings_0x1deb78(PARAMS PARAMSCOMMA dis2_args,"VMOV","FCPY");
	return;
}
static RETURNTYPE dis2_leaf_VABS_A2_0x1ca2b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VABS_A2_0x1ca2b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110000(Vd:4)101(sz)11M0(Vm:4) {ne(cond,0xf)} VABS_A2 */
	dis2_optstrings_0x1deb78(PARAMS PARAMSCOMMA dis2_args,"VABS","FABS");
	return;
}
static RETURNTYPE dis2_leaf_VNEG_A2_0x1ca650(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VNEG_A2_0x1ca650(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110001(Vd:4)101(sz)01M0(Vm:4) {ne(cond,0xf)} VNEG_A2 */
	dis2_optstrings_0x1deb78(PARAMS PARAMSCOMMA dis2_args,"VNEG","FNEG");
	return;
}
static RETURNTYPE dis2_leaf_VSQRT_A1_0x1ca6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VSQRT_A1_0x1ca6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110001(Vd:4)101(sz)11M0(Vm:4) {ne(cond,0xf)} VSQRT_A1 */
	dis2_optstrings_0x1deb78(PARAMS PARAMSCOMMA dis2_args,"VSQRT","FSQRT");
	return;
}
static RETURNTYPE dis2_leaf_VCVTB_VCVTT_hp_sp_VFP_A1_0x1caac0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVTB_VCVTT_hp_sp_VFP_A1_0x1caac0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D11001(op)(Vd:4)101(0)T1M0(Vm:4) {ne(cond,0xf)} {lnot(opcode<8>)} VCVTB_VCVTT_hp_sp_VFP_A1 */
	const uint32_t Vm_M = dis2_args->dis2_argf_0_4_5_1;
	const uint32_t Vd_D = dis2_args->dis2_argf_12_4_22_1;
	const uint32_t op = dis2_args->dis2_argf_16_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t T = dis2_args->dis2_argf_7_1;
	const uint32_t nonstandard = dis2_args->dis2_argn_100_0;
	COMMON
	ONLY2(VFPv3HP,VFPv4);
	// TODO - Find non-UAL syntax for this
	sprintf(params->buf,"VCVT%c%s.F%d.F%d\tS%d,S%d",(T?'T':'B'),condition(JUSTPARAMS,cond),(op?16:32),(op?32:16),Vd_D,Vm_M);
	return;
}
static RETURNTYPE dis2_leaf_VCVTB_VCVTT_A1_0x1cab38(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVTB_VCVTT_A1_0x1cab38(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D11001(op)(Vd:4)101(sz)T1M0(Vm:4) {ne(cond,0xf)} {sz} VCVTB_VCVTT_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t op = dis2_args->dis2_argf_16_1;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t T = dis2_args->dis2_argf_7_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	if (op)
	{
		sprintf(params->buf,"VCVT%c%s.F16.F64\tS%d,D%d",(T?'T':'B'),condition(JUSTPARAMS,cond),(Vd<<1)|D,(M<<4)|Vm);
	}
	else
	{
		sprintf(params->buf,"VCVT%c%s.F64.F16\tD%d,S%d",(T?'T':'B'),condition(JUSTPARAMS,cond),(D<<4)|Vd,(Vm<<1)|M);
	}
	return;
}
static RETURNTYPE dis2_leaf_VCMP_VCMPE_A1_0x1cb1b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCMP_VCMPE_A1_0x1cb1b0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110100(Vd:4)101(sz)E1M0(Vm:4) {ne(cond,0xf)} VCMP_VCMPE_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t E = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	VFP_CC_VD_VM(JUSTPARAMS,(E?"VCMPE":"VCMP"),(E?"FCMPE":"FCMP"),cond,sz,Vd,D,Vm,M);
	return;
}
static RETURNTYPE dis2_leaf_VCMP_VCMPE_A2_0x1cb3f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCMP_VCMPE_A2_0x1cb3f0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110101(Vd:4)101(sz)E1(0)0(0000) {ne(cond,0xf)} VCMP_VCMPE_A2 */
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t E = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = dis2_args->dis2_argn_2f_0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	VFP_CC_VD_F(JUSTPARAMS,(E?"VCMPE":"VCMP"),(E?"FCMPEZ":"FCMPZ"),cond,sz,Vd,D,0);
	return;
}
static RETURNTYPE dis2_leaf_VRINTR_VRINTZ_fp_A1_0x1cb630(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRINTR_VRINTZ_fp_A1_0x1cb630(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110110(Vd:4)101(sz)(op)1M0(Vm:4) {ne(cond,0xf)} VRINTR_VRINTZ_fp_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t op = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	char opstr[16];
	sprintf(opstr,"VRINT%c%s.F%d",(op?'Z':'R'),condition(JUSTPARAMS,cond),(sz?64:32));
	VFP_CC_VD_VM(JUSTPARAMS,opstr,opstr,14,sz,Vd,D,Vm,M);
	return;
}
static RETURNTYPE dis2_leaf_VRINTX_fp_A1_0x1cb9a0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRINTX_fp_A1_0x1cb9a0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110111(Vd:4)101(sz)01M0(Vm:4) {ne(cond,0xf)} VRINTX_fp_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	char opstr[16];
	sprintf(opstr,"VRINTX%s.F%d",condition(JUSTPARAMS,cond),(sz?64:32));
	VFP_CC_VD_VM(JUSTPARAMS,opstr,opstr,14,sz,Vd,D,Vm,M);
	return;
}
static RETURNTYPE dis2_leaf_VCVT_dp_sp_A1_0x1cba18(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVT_dp_sp_A1_0x1cba18(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D110111(Vd:4)101(sz)11M0(Vm:4) {ne(cond,0xf)} VCVT_dp_sp_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(!VFPDP);
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	const char *cc = condition(JUSTPARAMS,cond);
	if(sz)
		sprintf(params->buf,(params->opt->vfpual?"VCVT%s.F32.F64\tS%d,D%d":"FCVTSD%s\tS%d,D%d"),cc,(Vd<<1)|D,(M<<4)|Vm);
	else
		sprintf(params->buf,(params->opt->vfpual?"VCVT%s.F64.F32\tD%d,S%d":"FCVTDS%s\tD%d,S%d"),cc,(D<<4)|Vd,(Vm<<1)|M);
	return;
}
static RETURNTYPE dis2_leaf_VCVT_VCVTR_fp_int_VFP_A1_0x1cc198(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVT_VCVTR_fp_int_VFP_A1_0x1cc198(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D111(opc2:3)(Vd:4)101(sz)(op)1M0(Vm:4) {ne(cond,0xf)} {lnot(land(opc2,ne(band(opc2,0x6),0x4)))} VCVT_VCVTR_fp_int_VFP_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t opc2 = dis2_args->dis2_argf_16_3;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t op = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(sz && !VFPDP);
	COMMON
	ONLY3(VFPv2,VFPv3,VFPv4);
	const char *cc = condition(JUSTPARAMS,cond);
	if(!(opc2 & 4))
	{
		if(params->opt->vfpual)
			sprintf(params->buf,"VCVT%s.F%d.%c32\t",cc,(sz?64:32),(op?'S':'U'));
		else
			sprintf(params->buf,"F%cITO%c%s\t",(op?'S':'U'),(sz?'D':'S'),cc);
		if(sz)
			scatf(params->buf,"D%d,S%d",(D<<4)|Vd,(Vm<<1)|M);
		else
			scatf(params->buf,"S%d,S%d",(Vd<<1)|D,(Vm<<1)|M);
	}
	else
	{
		if(params->opt->vfpual)
			sprintf(params->buf,"VCVT%s%s.%c32.F%d\t",(op?"":"R"),cc,((opc2&1)?'S':'U'),(sz?64:32));
		else
			sprintf(params->buf,"FTO%cI%s%c%s\t",((opc2&1)?'S':'U'),(op?"Z":""),(sz?'D':'S'),cc);
		if(sz)
			scatf(params->buf,"S%d,D%d",(Vd<<1)|D,(M<<4)|Vm);
		else
			scatf(params->buf,"S%d,S%d",(Vd<<1)|D,(Vm<<1)|M);
	}
	return;
}
static RETURNTYPE dis2_leaf_VRINTx_fp_A1_0x1cca18(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VRINTx_fp_A1_0x1cca18(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111111101D1110(RM:2)(Vd:4)101(sz)01M0(Vm:4) VRINTx_fp_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t RM = dis2_args->dis2_argf_16_2;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	const char rms[4] = {'A','N','P','M'};
	char opstr[12];
	sprintf(opstr,"VRINT%c.F%d",rms[RM],(sz?64:32));
	VFP_CC_VD_VM(JUSTPARAMS,opstr,opstr,14,sz,Vd,D,Vm,M);
	return;
}
static RETURNTYPE dis2_leaf_VCVT_fp_fx_VFP_A1_0x1ccfb8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVT_fp_fx_VFP_A1_0x1ccfb8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101D111(op)1U(Vd:4)101(sf)(sx)1i0(imm4:4) {ne(cond,0xf)} VCVT_fp_fx_VFP_A1 */
	const uint32_t imm4 = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t U = dis2_args->dis2_argf_16_1;
	const uint32_t op = dis2_args->dis2_argf_18_1;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t i = dis2_args->dis2_argf_5_1;
	const uint32_t sx = dis2_args->dis2_argf_7_1;
	const uint32_t sf = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	_UNDEFINED(sf && !VFPDP);
	COMMON
	ONLY2(VFPv3,VFPv4);
	const char *cc = condition(JUSTPARAMS,cond);
	if(params->opt->vfpual)
	{
		if(op)
			sprintf(params->buf,"VCVT%s.%c%d.F%d\t",cc,(U?'U':'S'),(sx?32:16),(sf?64:32));
		else
			sprintf(params->buf,"VCVT%s.F%d.%c%d\t",cc,(sf?64:32),(U?'U':'S'),(sx?32:16));
		if(sf)
			scatf(params->buf,"D%d,D%d,#%d",(D<<4)|Vd,(D<<4)|Vd,(sx?32:16)-((imm4<<1)|i));
		else
			scatf(params->buf,"S%d,S%d,#%d",(Vd<<1)|D,(Vd<<1)|D,(sx?32:16)-((imm4<<1)|i));
	}
	else
	{
		sprintf(params->buf,(op?"FTO%c%c":"F%c%cTO"),(U?'U':'S'),(sx?'L':'H'));
		if(sf)
			scatf(params->buf,"D%s\tD%d,#%d",cc,(D<<4)|Vd,(sx?32:16)-((imm4<<1)|i));
		else
			scatf(params->buf,"S%s\tS%d,#%d",cc,(Vd<<1)|D,(sx?32:16)-((imm4<<1)|i));
	}
	return;
}
static RETURNTYPE dis2_leaf_VCVTx_fp_A1_0x1cd6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VCVTx_fp_A1_0x1cd6c8(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* 111111101D1111(RM:2)(Vd:4)101(sz)(op)1M0(Vm:4) VCVTx_fp_A1 */
	const uint32_t Vm = dis2_args->dis2_argf_0_4;
	const uint32_t Vd = dis2_args->dis2_argf_12_4;
	const uint32_t RM = dis2_args->dis2_argf_16_2;
	const uint32_t D = dis2_args->dis2_argf_22_1;
	const uint32_t M = dis2_args->dis2_argf_5_1;
	const uint32_t op = dis2_args->dis2_argf_7_1;
	const uint32_t sz = dis2_args->dis2_argf_8_1;
	const uint32_t nonstandard = 0;
	COMMON
	ONLY1(ARMv8);
	const char rms[4] = {'A','N','P','M'};
	if (sz)
	{
		sprintf(params->buf,"VCVT%c.%c32.F64\tS%d,D%d",rms[RM],(op?'S':'U'),(Vd<<1)|D,(M<<4)|Vm);
	}
	else
	{
		sprintf(params->buf,"VCVT%c.%c32.F32\tS%d,S%d",rms[RM],(op?'S':'U'),(Vd<<1)|D,(Vm<<1)|M);
	}
	return;
}
static RETURNTYPE dis2_leaf_VMSR_A1_0x1ce5d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMSR_A1_0x1ce5d0(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101110(reg:4)(Rt:4)1010(000)1(0000) {ne(cond,0xf)} VMSR_A1 */
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t reg = dis2_args->dis2_argf_16_4;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = dis2_args->dis2_argn_ef_0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	if(!vfp_msr[reg].valid)
		warning(JUSTPARAMS,WARN_BAD_VFP_MRS_MSR);
	sprintf(params->buf,(params->opt->vfpual?"VMSR%s\t%s,%s":"FMXR%s\t%s,%s"),condition(JUSTPARAMS,cond),vfp_msr[reg].str,REG(Rt));
	return;
}
static RETURNTYPE dis2_leaf_VMRS_A1_0x1cfb10(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args);
RETURNTYPE dis2_leaf_VMRS_A1_0x1cfb10(PARAMDECL PARAMSCOMMA const dis2_argstruct *dis2_args)
{ /* (cond:4)11101111(reg:4)(Rt:4)1010(000)1(0000) {ne(cond,0xf)} VMRS_A1 */
	const uint32_t Rt = dis2_args->dis2_argf_12_4;
	const uint32_t reg = dis2_args->dis2_argf_16_4;
	const uint32_t cond = dis2_args->dis2_argf_28_4;
	const uint32_t nonstandard = dis2_args->dis2_argn_ef_0;
	COMMON
	ONLY1(VFP_ASIMD_common);
	_UNPREDICTABLE((Rt==15) && (reg != 1));
	if(!vfp_mrs[reg].valid)
		warning(JUSTPARAMS,WARN_BAD_VFP_MRS_MSR);
	const char *rt=REG(Rt);
	const char *fmt;
	if(params->opt->vfpual)
	{
		fmt = "VMRS%s\t%s,%s";
		if(Rt==15)
			rt = "APSR_nzcv";
	}
	else
	{
		if((Rt==15) && (reg==1))
			fmt = "FMSTAT%s";
		else
			fmt = "FMRX%s\t%s,%s";
	}
	sprintf(params->buf,fmt,condition(JUSTPARAMS,cond),rt,vfp_mrs[reg].str);
	return;
}
typedef RETURNTYPE (*dis2_leaffunction)(PARAMDECL, const dis2_argstruct *dis2_args);
static const dis2_leaffunction dis2_leaves[] = {
	dis2_leaf_UNDEFINED_0x87078,
	dis2_leaf_UNPREDICTABLE_0x8c420,
	dis2_leaf_UNALLOCATED_HINT_0x9b160,
	dis2_leaf_VHADD_VHSUB_A1_0xf0ce8,
	dis2_leaf_VRHADD_A1_0xf0d60,
	dis2_leaf_VQADD_A1_0xf1288,
	dis2_leaf_VBIC_reg_A1_0xf13f0,
	dis2_leaf_VBIF_VBIT_VBSL_A1_0xf1468,
	dis2_leaf_VAND_reg_A1_0xf1558,
	dis2_leaf_VEOR_A1_0xf15d0,
	dis2_leaf_VORR_reg_A1_0xf32a8,
	dis2_leaf_VMOV_reg_A1_0xf3320,
	dis2_leaf_VORN_reg_A1_0xf3500,
	dis2_leaf_VADDL_VADDW_A1_0xf7c48,
	dis2_leaf_VSHR_A1_0xf5918,
	dis2_leaf_VMOV_imm_A1_0xf83d8,
	dis2_leaf_VSRA_A1_0xf8210,
	dis2_leaf_VORR_imm_A1_0xf8288,
	dis2_leaf_VMVN_imm_A1_0xf5be8,
	dis2_leaf_VBIC_imm_A1_0xf95a8,
	dis2_leaf_VMLxx_scalar_A1_0xfa478,
	dis2_leaf_VEXT_A1_0xfcee8,
	dis2_leaf_VREV16_VREV32_VREV64_A1_0xfcf60,
	dis2_leaf_VCGT_imm_0_A1_0xfd420,
	dis2_leaf_VSWP_A1_0xfd8c0,
	dis2_leaf_VCVTx_ASIMD_A1_0xff060,
	dis2_leaf_VCGE_imm_0_A1_0x106b80,
	dis2_leaf_VTRN_A1_0x1063f8,
	dis2_leaf_VCEQ_imm_0_A1_0x111900,
	dis2_leaf_VUZP_A1_0x10d928,
	dis2_leaf_VCLE_imm_0_A1_0x10d738,
	dis2_leaf_VZIP_A1_0x10dab8,
	dis2_leaf_VCGT_reg_A1_0x108550,
	dis2_leaf_VQSUB_A1_0x123278,
	dis2_leaf_VCGE_reg_A1_0x12b0f8,
	dis2_leaf_VSUBL_VSUBW_A1_0x12e170,
	dis2_leaf_VRSHR_A1_0x123080,
	dis2_leaf_VRSRA_A1_0x11d110,
	dis2_leaf_VQDMLAL_VQDMLSL_A2_0xf5b60,
	dis2_leaf_VMLxx_scalar_A2_0x11dd28,
	dis2_leaf_VPADDL_A1_0x12ffa0,
	dis2_leaf_VCLT_imm_0_A1_0x11ea68,
	dis2_leaf_VMOVN_A1_0x11f340,
	dis2_leaf_VQMOVN_VQMOVUN_A1_0x126aa0,
	dis2_leaf_VABS_A1_0x11f4a0,
	dis2_leaf_VSHLL_A2_0x1340b0,
	dis2_leaf_VNEG_A1_0x120a90,
	dis2_leaf_VSHL_reg_A1_0x165e78,
	dis2_leaf_VRSHL_A1_0x1635f0,
	dis2_leaf_VQSHL_reg_A1_0xf51c8,
	dis2_leaf_VQRSHL_A1_0x130d10,
	dis2_leaf_VADDHN_A1_0x11ca50,
	dis2_leaf_VABA_VABAL_A2_0x120928,
	dis2_leaf_VSHL_imm_A1_0x12d4e8,
	dis2_leaf_VRADDHN_A1_0x12dfb0,
	dis2_leaf_VSRI_A1_0x15db18,
	dis2_leaf_VSLI_A1_0x142d00,
	dis2_leaf_VCLS_A1_0x156668,
	dis2_leaf_VCLZ_A1_0x156fe8,
	dis2_leaf_VCNT_A1_0x16a2e0,
	dis2_leaf_VMVN_reg_A1_0x16b8b0,
	dis2_leaf_VRINTx_ASIMD_A1_0x16da40,
	dis2_leaf_VRINTX_ASIMD_A1_0x16e728,
	dis2_leaf_VRINTZ_ASIMD_A1_0x1707f8,
	dis2_leaf_VRECPE_A1_0x16f4b0,
	dis2_leaf_VRSQRTE_A1_0x16f6f0,
	dis2_leaf_VMAX_VMIN_int_A1_0x14c820,
	dis2_leaf_VABD_VABDL_A1_0x163a28,
	dis2_leaf_VABA_VABAL_A1_0x1509d0,
	dis2_leaf_VSUBHN_A1_0x14dc50,
	dis2_leaf_VRSUBHN_A1_0x158ab8,
	dis2_leaf_VABD_VABDL_A2_0x14e700,
	dis2_leaf_VQSHL_VQSHLU_imm_A1_0x14f318,
	dis2_leaf_VPADAL_A1_0x131120,
	dis2_leaf_VQABS_A1_0x17f510,
	dis2_leaf_VQNEG_A1_0x178ac8,
	dis2_leaf_VCVT_hp_sp_ASIMD_A1_0x1751e8,
	dis2_leaf_VCVT_fp_int_ASIMD_A1_0x190168,
	dis2_leaf_VADD_int_A1_0x159b78,
	dis2_leaf_VMLxx_int_A1_0x1825d8,
	dis2_leaf_VTST_A1_0x14b540,
	dis2_leaf_VMUL_VMULL_int_poly_A1_0x18c328,
	dis2_leaf_VMLxx_int_A2_0xf3f30,
	dis2_leaf_VQDMLAL_VQDMLSL_A1_0x158738,
	dis2_leaf_VSHRN_A1_0x17d310,
	dis2_leaf_VQSHRN_VQSHRUN_A1_0x1840d8,
	dis2_leaf_VMUL_VMULL_scalar_A1_0x180cf0,
	dis2_leaf_VRSHRN_A1_0x175ec8,
	dis2_leaf_VQRSHRN_VQRSHRUN_A1_0x19a5f8,
	dis2_leaf_VSUB_int_A1_0x14d6c8,
	dis2_leaf_VCEQ_reg_A1_0x17f2b0,
	dis2_leaf_VTBL_VTBX_A1_0x1a3708,
	dis2_leaf_VPMAX_VPMIN_int_A1_0x1862c0,
	dis2_leaf_VQDMULH_A1_0x1856e0,
	dis2_leaf_VQRDMULH_A1_0x18f098,
	dis2_leaf_VPADD_int_A1_0x151010,
	dis2_leaf_VSHLL_A1_0x156218,
	dis2_leaf_VMOVL_A1_0x15f498,
	dis2_leaf_VMUL_VMULL_scalar_A2_0x19a0b0,
	dis2_leaf_VQDMULL_A2_0x196db0,
	dis2_leaf_VFMA_VFMS_A1_0x18ecb8,
	dis2_leaf_VADD_fp_A1_0x18c908,
	dis2_leaf_VMLA_VMLS_fp_A1_0x194968,
	dis2_leaf_VSUB_fp_A1_0x19f8b0,
	dis2_leaf_VMUL_VMULL_int_poly_A2_0x190f58,
	dis2_leaf_VQDMULL_A1_0x1936e8,
	dis2_leaf_VQDMULH_A2_0x1a8830,
	dis2_leaf_VQRDMULH_A2_0x1a88a8,
	dis2_leaf_VPADD_fp_A1_0x1aa330,
	dis2_leaf_VMUL_fp_A1_0x1abed8,
	dis2_leaf_VABD_fp_A1_0x1ae0a8,
	dis2_leaf_VDUP_scalar_A1_0x1aee70,
	dis2_leaf_VCEQ_reg_A2_0x19ac90,
	dis2_leaf_VMAX_VMIN_fp_A1_0x194898,
	dis2_leaf_VRECPS_A1_0x195238,
	dis2_leaf_VRSQRTS_A1_0x1a0480,
	dis2_leaf_VCVT_fp_fx_ASIMD_A1_0x1b1fd8,
	dis2_leaf_VCGE_reg_A2_0x1ba178,
	dis2_leaf_VPMAX_VPMIN_fp_A1_0x1b74c0,
	dis2_leaf_VACxx_A1_0x1bae90,
	dis2_leaf_VMAXNM_VMINNM_A1_0x1baf08,
	dis2_leaf_VCGT_reg_A2_0x1b0f50,
	dis2_leaf_VST4_mult_A1_0x1852a0,
	dis2_leaf_VST1_mult_A1_0x1b50c0,
	dis2_leaf_VST2_mult_A1_0x1b85d0,
	dis2_leaf_VST3_mult_A1_0x1bd4e0,
	dis2_leaf_VST1_onelane_A1_0xf1b00,
	dis2_leaf_VST2_onelane_A1_0x127fa8,
	dis2_leaf_VST3_onelane_A1_0x133e40,
	dis2_leaf_VST4_onelane_A1_0xf8ea8,
	dis2_leaf_UNALLOCATED_MEM_HINT_0x181528,
	dis2_leaf_VLD2_mult_A1_0x1a47f0,
	dis2_leaf_VLD4_mult_A1_0x17c818,
	dis2_leaf_VLD1_mult_A1a_0x1a9c10,
	dis2_leaf_VLD3_mult_A1_0x1b4850,
	dis2_leaf_VLD1_onelane_A1_0x150068,
	dis2_leaf_VLD2_onelane_A1_0x197620,
	dis2_leaf_VLD3_onelane_A1_0x1b07f0,
	dis2_leaf_VLD4_onelane_A1_0x1b7180,
	dis2_leaf_VLD1_alllanes_A1_0xf6ff8,
	dis2_leaf_VLD2_alllanes_A1_0x141280,
	dis2_leaf_VLD3_alllanes_A1_0x16c358,
	dis2_leaf_VLD4_alllanes_A1_0xd6ac0,
	dis2_leaf_PERMA_UNDEFINED_0x159780,
	dis2_leaf_VMOV_2fp_A1_0x1bf0d8,
	dis2_leaf_VSTM_A2_0xd38c0,
	dis2_leaf_VSTR_A2_0x1080d0,
	dis2_leaf_VLDM_A2_0x190810,
	dis2_leaf_VLDR_A2_0x1be190,
	dis2_leaf_VPUSH_A2_0x8ebc8,
	dis2_leaf_VPOP_A2_0x8f0d8,
	dis2_leaf_VMOV_dbl_A1_0x1bfbd8,
	dis2_leaf_VSTM_A1_0x153b38,
	dis2_leaf_VSTR_A1_0x18b6c8,
	dis2_leaf_VLDM_A1_0xeb968,
	dis2_leaf_VLDR_A1_0xeba98,
	dis2_leaf_VPUSH_A1_0x1c1ca0,
	dis2_leaf_VPOP_A1_0x1c2b58,
	dis2_leaf_VMLA_VMLS_fp_A2_0x9b440,
	dis2_leaf_VNMLA_VNMLS_VNMUL_A1_0x1a2270,
	dis2_leaf_VMUL_fp_A2_0x87120,
	dis2_leaf_VADD_fp_A2_0xb6ee0,
	dis2_leaf_VMOV_1fp_A1_0xebf28,
	dis2_leaf_VMOV_arm_A1_0x1c0e50,
	dis2_leaf_VMOV_scalar_A1_0x1c1bf8,
	dis2_leaf_VNMLA_VNMLS_VNMUL_A2_0x1c3e38,
	dis2_leaf_VSUB_fp_A2_0x1c3eb0,
	dis2_leaf_VSELxx_A1_0x137e00,
	dis2_leaf_VDIV_A1_0x1c50c8,
	dis2_leaf_VDUP_arm_A1_0x1c65f8,
	dis2_leaf_VMAXNM_VMINNM_A2_0x1c5140,
	dis2_leaf_VFNMA_VFNMS_A1_0x1c68f8,
	dis2_leaf_VFMA_VFMS_A2_0x1c7c30,
	dis2_leaf_VMOV_imm_A2_0x1c93c0,
	dis2_leaf_VMOV_reg_A2_0x1ca238,
	dis2_leaf_VABS_A2_0x1ca2b0,
	dis2_leaf_VNEG_A2_0x1ca650,
	dis2_leaf_VSQRT_A1_0x1ca6c8,
	dis2_leaf_VCVTB_VCVTT_hp_sp_VFP_A1_0x1caac0,
	dis2_leaf_VCVTB_VCVTT_A1_0x1cab38,
	dis2_leaf_VCMP_VCMPE_A1_0x1cb1b0,
	dis2_leaf_VCMP_VCMPE_A2_0x1cb3f0,
	dis2_leaf_VRINTR_VRINTZ_fp_A1_0x1cb630,
	dis2_leaf_VRINTX_fp_A1_0x1cb9a0,
	dis2_leaf_VCVT_dp_sp_A1_0x1cba18,
	dis2_leaf_VCVT_VCVTR_fp_int_VFP_A1_0x1cc198,
	dis2_leaf_VRINTx_fp_A1_0x1cca18,
	dis2_leaf_VCVT_fp_fx_VFP_A1_0x1ccfb8,
	dis2_leaf_VCVTx_fp_A1_0x1cd6c8,
	dis2_leaf_VMSR_A1_0x1ce5d0,
	dis2_leaf_VMRS_A1_0x1cfb10,
};
static const uint8_t dis2_fields[] = {
	0x7c,
	0xd0,
	0x51,
	0x02,
	0x05,
	0x6c,
	0x10,
	0x81,
	0x41,
	0x05,
	0x16,
	0xc0,
	0x01,
	0x8e,
	0x01,
	0x60,
	0xd0,
	0x70,
	0x40,
	0x01,
	0x08,
	0xc0,
	0x82,
	0x86,
	0x0c,
	0x0a,
	0xc0,
	0x30,
	0xc5,
	0x11,
	0x04,
	0x24,
	0x30,
	0x09,
	0x19,
	0x26,
	0x90,
	0xa0,
	0x02,
	0x35,
	0x94,
	0x14,
	0x71,
	0x41,
	0x15,
	0x72,
	0x24,
	0x01
};
static const uint8_t dis2_consts[] = {
	0xf,
	0x5,
	0x7,
	0x2,
	0x1,
	0x6,
	0xf0,
	0x3,
	0xc,
	0x8,
	0x9,
	0xb,
	0x16,
	0xe,
	0x20,
	0x27,
	0xa,
	0x77,
	0x41,
	0x4,
	0x57,
	0x61,
	0x1f,
	0xd,
};
#ifndef dis2_func_ne
#define dis2_func_ne(X,Y) (X)!=(Y)
#endif
#ifndef dis2_func_lor
#define dis2_func_lor(X,Y) (X)||(Y)
#endif
#ifndef dis2_func_eq
#define dis2_func_eq(X,Y) (X)==(Y)
#endif
#ifndef dis2_func_band
#define dis2_func_band(X,Y) (X)&(Y)
#endif
#ifndef dis2_func_lnot
#define dis2_func_lnot(X) !(X)
#endif
#ifndef dis2_func_gt
#define dis2_func_gt(X,Y) (X)>(Y)
#endif
#ifndef dis2_func_lt
#define dis2_func_lt(X,Y) (X)<(Y)
#endif
#ifndef dis2_func_bor
#define dis2_func_bor(X,Y) (X)|(Y)
#endif
#ifndef dis2_func_land
#define dis2_func_land(X,Y) (X)&&(Y)
#endif
#ifndef dis2_func_beor
#define dis2_func_beor(X,Y) (X)^(Y)
#endif
#ifndef dis2_func_ispow2
#define dis2_func_ispow2(X) !((X) & ((X)-1))
#endif
#ifndef dis2_func_ge
#define dis2_func_ge(X,Y) (X)>=(Y)
#endif
#ifndef dis2_func_lsl
#define dis2_func_lsl(X,Y) (X)<<(Y)
#endif
#ifndef dis2_func_leor
#define dis2_func_leor(X,Y) ((X)!=0) ^ ((Y)!=0)
#endif
#ifndef dis2_func_lsr
#define dis2_func_lsr(X,Y) (X)>>(Y)
#endif
static const uint8_t dis2_funcs[] = {
	0x00,
	0xc0,
	0x44,
	0x00,
	0x09,
	0x22,
	0x01,
	0x4e,
	0x48,
	0x00,
	0x14,
	0x23,
	0x20,
	0x05,
	0x0d,
	0x00,
	0x40,
	0x45,
	0x00,
	0x0c,
	0x01,
	0x15,
	0x52,
	0x60,
	0x45,
	0x18,
	0x40,
	0x42,
	0x07,
	0x00,
	0x10,
	0x02,
	0x00,
	0x94,
	0x00,
	0x40,
	0x29,
	0x38,
	0x61,
	0x0a,
	0x58,
	0x90,
	0x13,
	0x00,
	0xb3,
	0xe0,
	0xc9,
	0x41,
	0x61,
	0x70,
	0x04,
	0x12,
	0x90,
	0x14,
	0x00,
	0xe1,
	0x64,
	0x8a,
	0x34,
	0x68,
	0x11,
	0x55,
	0xac,
	0x80,
	0x83,
	0x07,
	0x90,
	0x80,
	0x01,
	0x61,
	0x01,
	0x30,
	0x59,
	0x54,
	0x1c,
	0x01,
	0x2d,
	0x03,
	0x21,
	0x41,
	0x38,
	0xe0,
	0x52,
	0x11,
	0x50,
	0x90,
	0x17,
	0x00,
	0xf1,
	0x65,
	0x4c,
	0x80,
	0x09,
	0x43,
	0x0d,
	0x00,
	0x20,
	0x04,
	0x31,
	0xd2,
	0x40,
	0xc5,
	0x18,
	0x80,
	0x42,
	0x65,
	0x00,
	0xcc,
	0x02,
	0x02,
	0x74,
	0x06,
	0xc0,
	0x2c,
	0x40,
	0x73,
	0x04,
	0x18,
	0x90,
	0x1a,
	0x00,
	0xb8,
	0xc6,
	0x0d,
	0xb2,
	0x69,
	0x43,
	0x0f,
	0x00,
	0x8c,
	0x04,
	0x15,
	0xf0,
	0xc6,
	0xc5,
	0x48,
	0x70,
	0x41,
	0x71,
	0x00,
	0x84,
	0x9c,
	0x33,
	0x31,
	0x87,
	0x8e,
	0x4c,
	0x68,
	0x81,
	0x14,
	0xea,
	0xc0,
	0x84,
	0x14,
	0x74,
	0x07,
	0x40,
	0x38,
	0xc1,
	0x83,
	0x79,
	0xf4,
	0xd0,
	0x02,
	0x00,
	0x23,
	0xe1,
	0x05,
	0xf1,
	0x01,
	0x10,
	0x53,
	0x9c,
	0x90,
	0x1f,
	0x00,
	0x01,
	0xa6,
	0x88,
	0x00,
	0x6a,
	0x31,
	0x12,
	0x5a,
	0x90,
	0x20,
	0x00,
	0x31,
	0x67,
	0xd0,
	0x30,
	0x50,
	0x21,
	0x15,
	0x54,
	0x90,
	0x21,
	0x00,
	0x31,
	0xa7,
	0x08,
	0x21,
	0x02,
	0x30,
	0x0b,
	0x12,
	0x1d,
	0x9a,
	0x04,
	0xd0,
	0xa0,
	0x05,
	0x31,
	0x02,
	0x30,
	0x8d,
	0x54,
	0x5c,
	0x02,
	0x06,
	0xe1,
	0xc0,
	0x02,
	0x41,
	0x02,
	0x10,
	0x73,
	0xce,
	0x90,
	0x24,
	0x00,
	0x71,
	0xa6,
	0x0e,
	0x51,
	0x02,
	0x10,
	0x95,
	0xce,
	0x90,
	0x25,
	0x00,
	0x61,
	0x00,
	0x02,
	0x61,
	0x02,
	0x10,
	0x99,
	0x38,
	0x85,
	0xa6,
	0x4d,
	0x30,
	0x41,
	0xc5,
	0x40,
	0x20,
	0x30,
	0x9d,
	0x18,
	0x24,
	0x04,
	0x15,
	0xf1,
	0x29,
	0x14,
	0x81,
	0x02,
	0x30,
	0x17,
	0x4e,
	0x08,
	0xa8,
	0x13,
	0x34,
	0x0a,
	0x40,
	0xd4,
	0x39,
	0x43,
	0x83,
	0x00,
	0x90,
	0x29,
	0x00,
	0x71,
	0x6a,
	0x4c,
	0x80,
	0x41,
	0x25,
	0x10,
	0x1a,
	0x90,
	0x2a,
	0x00,
	0xb1,
	0xca,
	0x49,
	0x4c,
	0x61,
	0x85,
	0x06,
	0x1a,
	0x88,
	0x2b,
	0x18,
	0x23,
	0x01,
	0x06,
	0xc1,
	0x02,
	0x10,
	0x53,
	0x16,
	0x90,
	0x2c,
	0x00,
	0x31,
	0x6b,
	0x4a,
	0x38,
	0x01,
	0x23,
	0x12,
	0x62,
	0x90,
	0x2d,
	0x00,
	0x1a,
	0x01,
	0x80,
	0x48,
	0x70,
	0x11,
	0xb9,
	0x0c,
	0x10,
	0x06,
	0x00,
	0xb4,
	0x0b,
	0x40,
	0x38,
	0x19,
	0x40,
	0xbd,
	0x00,
	0x84,
	0xaf,
	0x22,
	0x98,
	0xe1,
	0x57,
	0x18,
	0x68,
	0x40,
	0xc1,
	0x00,
	0xc4,
	0x80,
	0x05,
	0x25,
	0xc1,
	0x85,
	0x10,
	0x93,
	0x31,
	0x1a,
	0x64,
	0xcc,
	0x86,
	0x17,
	0x93,
	0x00,
	0x05,
	0x21,
	0x03,
	0x10,
	0x63,
	0xc0,
	0x90,
	0x32,
	0x00,
	0x31,
	0xc0,
	0x89,
	0x48,
	0x98,
	0x41,
	0xcd,
	0x00,
	0xe0,
	0x03,
	0x67,
	0x20,
	0x61,
	0x86,
	0x48,
	0x30,
	0x41,
	0xd1,
	0x00,
	0xcc,
	0x06,
	0x15,
	0x35,
	0xad,
	0x46,
	0x46,
	0xa0,
	0x31,
	0x11,
	0x68,
	0x90,
	0x35,
	0x00,
	0xc2,
	0xa1,
	0x05,
	0x61,
	0x03,
	0x10,
	0xd6,
	0xb2,
	0x4d,
	0x87,
	0x14,
	0xb4,
	0x0d,
	0x40,
	0x70,
	0xfb,
	0x86,
	0xdd,
	0xb2,
	0x89,
	0xb7,
	0x15,
	0x23,
	0x61,
	0x06,
	0x82,
	0x0b,
	0x27,
	0x12,
	0x6c,
	0x48,
	0x87,
	0x16,
	0x34,
	0x0e,
	0x40,
	0x58,
	0x23,
	0x87,
	0xe5,
	0xc2,
	0x89,
	0xb7,
	0x17,
	0x2b,
	0x21,
	0x06,
	0xa1,
	0x03,
	0x10,
	0xe9,
	0xd4,
	0x89,
	0x87,
	0x16,
	0xb1,
	0xae,
	0xdd,
	0x6c,
	0x60,
	0xc7,
	0x2a,
	0x3c,
	0xa0,
	0xbb,
	0x77,
	0xe2,
	0x21,
	0x45,
	0x47,
	0x83,
	0x37,
	0x1b,
	0x52,
	0x90,
	0x3c,
	0x00,
	0x91,
	0x6e,
	0x1e,
	0xba,
	0x83,
	0x47,
	0xf5,
	0x00,
	0x44,
	0x3a,
	0x7b,
	0x11,
	0xed,
	0x1e,
	0xba,
	0xc3,
	0x37,
	0x1b,
	0x5a,
	0x90,
	0x3e,
	0x00,
	0x91,
	0x6e,
	0x1f,
	0xba,
	0xe3,
	0x27,
	0xf8,
	0x5a,
	0x88,
	0x3f,
	0x1c,
	0xf3,
	0xe1,
	0x86,
	0x24,
	0x30,
	0x11,
	0xe5,
	0x02,
	0x8a,
	0x84,
	0x16,
	0x14,
	0x0e,
	0x00,
	0x65,
	0x03,
	0x40,
	0x05,
	0x01,
	0x60,
	0x34,
	0x83,
	0xe4,
	0x01,
	0x00,
	0x21,
	0x04,
	0x80,
	0x09,
	0xdd,
	0x85,
	0xc2,
	0x85,
	0xb3,
	0x21,
	0xc7,
	0x30,
	0x54,
	0x91,
	0x1b,
	0x1a,
	0xfa,
	0x06,
	0x15,
	0xf4,
	0x10,
	0x00,
	0xc2,
	0x73,
	0x47,
	0x11,
	0x01,
	0x60,
	0x34,
	0x89,
	0x34,
	0x11,
	0xc0,
	0x78,
	0x48,
	0x41,
	0x15,
	0x01,
	0x20,
	0x3e,
	0x77,
	0x74,
	0x11,
	0x00,
	0xf2,
	0x73,
	0x47,
	0x19,
	0x01,
	0x20,
	0x3c,
	0x8d,
	0xe2,
	0x41,
	0x05,
	0x78,
	0x68,
	0x41,
	0x1d,
	0x01,
	0x84,
	0x35,
	0x8f,
	0xf8,
	0x11,
	0x03,
	0x71,
	0x00,
	0x40,
	0x21,
	0x01,
	0x84,
	0x35,
	0x0c,
	0x34,
	0x12,
	0x00,
	0xe6,
	0xb2,
	0x26,
	0x1f,
	0x74,
	0xc0,
	0x06,
	0x15,
	0x71,
	0x12,
	0xa5,
	0x6d,
	0xc8,
	0x51,
	0x1b,
	0x56,
	0x88,
	0xbf,
	0x1d,
	0x06,
	0x60,
	0x86,
	0x80,
	0xe0,
	0x21,
	0x21,
	0x50,
	0x90,
	0x4b,
	0x00,
	0xb3,
	0xa1,
	0x47,
	0x6d,
	0x68,
	0x41,
	0x31,
	0x01,
	0xe0,
	0x01,
	0x99,
	0x62,
	0x40,
	0x04,
	0xd1,
	0x04,
	0x80,
	0x35,
	0x6f,
	0xa2,
	0x01,
	0x9b,
	0x24,
	0x02,
	0x00,
	0x1e,
	0xc0,
	0x29,
	0x09,
	0x7a,
	0x90,
	0x4e,
	0x00,
	0xb8,
	0x53,
	0x26,
	0xf2,
	0x3c,
	0x00,
	0x09,
	0x4c,
	0x90,
	0x4f,
	0x00,
	0x18,
	0xf3,
	0x1f,
	0x01,
	0x05,
	0x80,
	0x41,
	0x6f,
	0xa2,
	0x50,
	0x11,
	0x64,
	0x00,
	0x00,
	0x48,
	0x88,
	0x41,
	0x10,
	0x00,
	0x90,
	0x51,
	0x00,
	0x73,
	0x20,
	0x01,
	0x21,
	0x05,
	0x80,
	0x49,
	0x9d,
	0xa2,
	0xd2,
	0xa6,
	0xb8,
	0x94,
	0xa9,
	0x88,
	0x50,
	0x21,
	0x24,
	0x66,
	0x48,
	0x89,
	0x13,
	0xc2,
	0x41,
	0x05
};
static const uint8_t dis2_funcargs[] = {
	0xaa,
	0xa9,
	0x9a,
	0x2a
};
static uint32_t dis2_readbits(const uint8_t *array,uint32_t offset,uint32_t count)
{
	uint32_t result=0;
	offset += count;
	while(count--) {
		offset--;
		result <<= 1;
		result |= ((array[offset>>3])>>(offset&7)) & 1;
	}
	return result;
}
static uint32_t dis2_evalconstraint(const uint32_t opcode,const uint32_t id)
{
	if(id < 38) {
		/* Field constraint */
		uint32_t bitoffset = id*10;
		const uint32_t startbit = dis2_readbits(dis2_fields,bitoffset,5); bitoffset += 5;
		const uint32_t bitcount = dis2_readbits(dis2_fields,bitoffset,5)+1;
		return (opcode>>startbit) & ((((uint32_t)1)<<bitcount)-1);
	} else if(id < 62) {
		/* Const constraint */
		return dis2_consts[id-38];
	} else {
		/* Function constraint */
		uint32_t bitoffset = (id-62)*22;
		const uint32_t function = dis2_readbits(dis2_funcs,bitoffset,4); bitoffset += 4;
		uint32_t args[2];
		const uint32_t numargs = dis2_readbits(dis2_funcargs,function*2,2);
		for(uint32_t i=0;i<numargs;i++) {
			args[i] = dis2_evalconstraint(opcode,dis2_readbits(dis2_funcs,bitoffset,9));
			bitoffset += 9;
		}
		switch(function) {
		default:
		case 0:
			return dis2_func_ne(args[0],args[1]);
		case 1:
			return dis2_func_lor(args[0],args[1]);
		case 2:
			return dis2_func_eq(args[0],args[1]);
		case 3:
			return dis2_func_band(args[0],args[1]);
		case 4:
			return dis2_func_lnot(args[0]);
		case 5:
			return dis2_func_gt(args[0],args[1]);
		case 6:
			return dis2_func_lt(args[0],args[1]);
		case 7:
			return dis2_func_bor(args[0],args[1]);
		case 8:
			return dis2_func_land(args[0],args[1]);
		case 9:
			return dis2_func_beor(args[0],args[1]);
		case 10:
			return dis2_func_ispow2(args[0]);
		case 11:
			return dis2_func_ge(args[0],args[1]);
		case 12:
			return dis2_func_lsl(args[0],args[1]);
		case 13:
			return dis2_func_leor(args[0],args[1]);
		case 14:
			return dis2_func_lsr(args[0],args[1]);
		}
	}
}
static const uint8_t dis2_constraintnodes[] = {
	0x3e,
	0x80,
	0x01,
	0x00,
	0xe0,
	0x07,
	0x00,
	0x10,
	0x0c,
	0x08,
	0x11,
	0x06,
	0x00,
	0x80,
	0x21,
	0xc3,
	0x00,
	0x00,
	0x40,
	0x84,
	0x18,
	0x00,
	0x00,
	0x8c,
	0x00,
	0x00,
	0xc5,
	0xc0,
	0x11,
	0x00,
	0x20,
	0x4e,
	0x48,
	0x72,
	0x0c,
	0x00,
	0x00,
	0x4a,
	0x90,
	0x01,
	0x00,
	0x60,
	0x49,
	0x32,
	0x00,
	0x00,
	0x30,
	0xc1,
	0x14,
	0x00,
	0x00,
	0x1f,
	0xd0,
	0x82,
	0xbc,
	0xa0,
	0x84,
	0x19,
	0x00,
	0x00,
	0x96,
	0x34,
	0x03,
	0x00,
	0x00,
	0x93,
	0x70,
	0x01,
	0x00,
	0x68,
	0x32,
	0x30,
	0x00,
	0x00,
	0x0d,
	0x24,
	0x86,
	0x8b,
	0xa1,
	0x09,
	0xc7,
	0x00,
	0x00,
	0x44,
	0x41,
	0x18,
	0x00,
	0x00,
	0x2a,
	0x0a,
	0xc0,
	0x02,
	0x70,
	0xa5,
	0x01,
	0x00,
	0x00,
	0xb6,
	0x38,
	0x00,
	0x0f,
	0xc0,
	0x16,
	0x08,
	0x20,
	0x02,
	0xd8,
	0xe2,
	0x00,
	0x48,
	0x00,
	0x5b,
	0x20,
	0x80,
	0x09,
	0xa0,
	0x0b,
	0x05,
	0x00,
	0x00,
	0x90,
	0xd1,
	0x06,
	0x00,
	0x80,
	0x2d,
	0xdb,
	0x00,
	0x37,
	0x60,
	0x86,
	0x77,
	0x00,
	0x00,
	0xd2,
	0x3c,
	0x00,
	0x11,
	0x00,
	0x19,
	0x6f,
	0x00,
	0x00,
	0xd8,
	0xb2,
	0x0d,
	0x7c,
	0x03,
	0x6d,
	0x26,
	0x00,
	0x09,
	0xc0,
	0x8c,
	0x03,
	0x00,
	0x00,
	0xc0,
	0x69,
	0x21,
	0x00,
	0x00,
	0x38,
	0x3c,
	0x04,
	0x00,
	0x00,
	0xc7,
	0x88,
	0x00,
	0x00,
	0xcc,
	0x40,
	0x11,
	0x00,
	0x80,
	0x1d,
	0x09,
	0x02,
	0x00,
	0x80,
	0x83,
	0x49,
	0x00,
	0x00,
	0x70,
	0x44,
	0x09,
	0x00,
	0xc0,
	0x0c,
	0x04,
	0x00,
	0x00,
	0xc0,
	0x11,
	0x28,
	0x00,
	0x00,
	0x38,
	0x0c,
	0x05,
	0x00,
	0x00,
	0xc7,
	0xa2,
	0x00,
	0x00,
	0xcc,
	0xa4,
	0x14,
	0x00,
	0x00,
	0x9c,
	0xb8,
	0x02,
	0x00,
	0x80,
	0xb3,
	0x57,
	0x00,
	0x00,
	0x3e,
	0xa0,
	0x05,
	0xc7,
	0x62,
	0xcf,
	0x67,
	0x01,
	0x00,
	0x34,
	0x91,
	0x07,
	0x00,
	0x80,
	0x3d,
	0x9f,
	0x85,
	0x6b,
	0x71,
	0x65,
	0x04,
	0x00,
	0x00,
	0xb6,
	0x90,
	0x00,
	0x0f,
	0xc0,
	0x96,
	0x12,
	0x20,
	0x02,
	0xd8,
	0x42,
	0x02,
	0x48,
	0x00,
	0x5b,
	0x4a,
	0x80,
	0x09,
	0xa0,
	0x4f,
	0x3e,
	0x00,
	0x00,
	0xfc,
	0xd1,
	0x07,
	0x4e,
	0x00,
	0x03,
	0x00,
	0x80,
	0x09,
	0x40,
	0x86,
	0x1f,
	0x00,
	0x00,
	0xb6,
	0xf4,
	0x03,
	0xdc,
	0x80,
	0x99,
	0xed,
	0x02,
	0x00,
	0x20,
	0xf3,
	0x0f,
	0x00,
	0x00,
	0x5b,
	0xfa,
	0x81,
	0x6f,
	0x20,
	0x90,
	0x0a,
	0x00,
	0x00,
	0xf4,
	0xa1,
	0x31,
	0x00,
	0x00,
	0x33,
	0x24,
	0x00,
	0x00,
	0x10,
	0x28,
	0xc7,
	0x00,
	0x00,
	0xec,
	0x08,
	0x19,
	0x00,
	0x00,
	0x1c,
	0x26,
	0x03,
	0x00,
	0xb0,
	0x63,
	0x65,
	0x80,
	0x19,
	0x66,
	0xd4,
	0x0c,
	0x00,
	0x20,
	0xd0,
	0x9b,
	0x01,
	0x00,
	0x98,
	0xc1,
	0x33,
	0x00,
	0x00,
	0x33,
	0x82,
	0x06,
	0x00,
	0x10,
	0x68,
	0x05,
	0x00,
	0x00,
	0x02,
	0x29,
	0x1b,
	0x00,
	0x80,
	0x9d,
	0x23,
	0x03,
	0x00,
	0xb0,
	0x53,
	0x01,
	0x00,
	0x00,
	0x81,
	0xba,
	0x0d,
	0x00,
	0xc0,
	0x8c,
	0xb9,
	0x01,
	0x00,
	0x10,
	0x02,
	0x00,
	0xca,
	0x81,
	0x42,
	0x2d,
	0x00,
	0x00,
	0xd0,
	0xa7,
	0xe3,
	0x00,
	0x00,
	0xcc,
	0xcc,
	0x1c,
	0x00,
	0x80,
	0x99,
	0xa0,
	0x03,
	0x00,
	0x30,
	0x53,
	0x02,
	0x00,
	0x00,
	0x7d,
	0x02,
	0x0f,
	0x00,
	0x00,
	0xce,
	0xe5,
	0x01,
	0x00,
	0xc0,
	0x29,
	0x3d,
	0x00,
	0x00,
	0x1f,
	0xaa,
	0x07,
	0xf3,
	0xa1,
	0x84,
	0x23,
	0x00,
	0x00,
	0x96,
	0x74,
	0x04,
	0x00,
	0x00,
	0x93,
	0xdd,
	0x03,
	0x00,
	0x38,
	0x54,
	0x7d,
	0x00,
	0x00,
	0x8a,
	0xea,
	0x8f,
	0x0a,
	0x60,
	0xd1,
	0x0c,
	0x00,
	0x00,
	0x10,
	0xa1,
	0x01,
	0x00,
	0x00,
	0x47,
	0x00,
	0xc0,
	0x03,
	0xb0,
	0xa5,
	0x06,
	0x88,
	0x00,
	0x1c,
	0x01,
	0x00,
	0x12,
	0xc0,
	0x96,
	0x1a,
	0x60,
	0x02,
	0x70,
	0x04,
	0x00,
	0x9c,
	0x04,
	0x64,
	0x1e,
	0x00,
	0x00,
	0x80,
	0x4c,
	0x4a,
	0x00,
	0x00,
	0x6c,
	0x51,
	0x09,
	0x22,
	0x00,
	0x33,
	0x35,
	0x00,
	0x00,
	0xe0,
	0x08,
	0x00,
	0x60,
	0x09,
	0xc8,
	0x48,
	0x00,
	0x00,
	0x00,
	0x19,
	0x97,
	0x00,
	0x00,
	0xd8,
	0xa2,
	0x12,
	0x4c,
	0x00,
	0x8b,
	0x6c,
	0x00,
	0x00,
	0x80,
	0x8c,
	0x14,
	0x02,
	0x00,
	0x98,
	0x01,
	0x43,
	0x00,
	0x00,
	0x32,
	0x6e,
	0x08,
	0x00,
	0x60,
	0x86,
	0x0f,
	0x01,
	0x00,
	0xcc,
	0x04,
	0x22,
	0x00,
	0x80,
	0x99,
	0x1b,
	0x00,
	0x00,
	0x30,
	0x83,
	0x03,
	0x00,
	0x00,
	0x8f,
	0xb8,
	0x11,
	0x00,
	0xe0,
	0x91,
	0x3a,
	0x02,
	0x00,
	0x98,
	0xc1,
	0x47,
	0x00,
	0x00,
	0x33,
	0x0e,
	0x09,
	0x00,
	0xf0,
	0xc8,
	0x28,
	0x01,
	0x00,
	0x1e,
	0x2d,
	0x25,
	0x00,
	0x00,
	0x9c,
	0xb0,
	0x04,
	0x00,
	0x80,
	0x63,
	0x96,
	0x00,
	0x00,
	0x70,
	0xd6,
	0x12,
	0x00,
	0x00,
	0x0e,
	0x5c,
	0x02,
	0x00,
	0x98,
	0xa9,
	0x4b,
	0x00,
	0x80,
	0x48,
	0x83,
	0x09,
	0x00,
	0x60,
	0xa6,
	0x31,
	0x01,
	0x00,
	0x7c,
	0x00,
	0x00,
	0x45,
	0x41,
	0x93,
	0xd1,
	0x04,
	0x00,
	0x50,
	0x74,
	0x14,
	0x00,
	0x00,
	0x3e,
	0x90,
	0x82,
	0xa2,
	0x40,
	0x49,
	0x52,
	0x00,
	0x00,
	0x2c,
	0x51,
	0x0a,
	0x00,
	0x00,
	0x26,
	0xba,
	0x02,
	0x00,
	0xe0,
	0x03,
	0x00,
	0x60,
	0x0a,
	0xa2,
	0x8c,
	0x26,
	0x00,
	0x80,
	0x0f,
	0x00,
	0xa0,
	0x35,
	0x59,
	0x34,
	0x9c,
	0x00,
	0x00,
	0x44,
	0x8e,
	0x00,
	0x00,
	0x60,
	0x4b,
	0x54,
	0xf0,
	0x00,
	0x4c,
	0x42,
	0x02,
	0x00,
	0x80,
	0x2d,
	0x48,
	0x40,
	0x04,
	0xb0,
	0x25,
	0x2a,
	0x90,
	0x00,
	0xb6,
	0x20,
	0x01,
	0x13,
	0x00,
	0x19,
	0xab,
	0x00,
	0x00,
	0xd8,
	0x12,
	0x15,
	0x70,
	0x03,
	0x64,
	0xb0,
	0x02,
	0x00,
	0x60,
	0x4b,
	0x54,
	0xf0,
	0x0d,
	0xf8,
	0x00,
	0x00,
	0xb4,
	0x93,
	0x49,
	0xfc,
	0x09,
	0x57,
	0xb0,
	0xc8,
	0x08,
	0x00,
	0x00,
	0x16,
	0x05,
	0x28,
	0x00,
	0x40,
	0x1f,
	0x03,
	0x05,
	0x00,
	0xe8,
	0x03,
	0xa1,
	0x00,
	0x00,
	0x8f,
	0x2a,
	0x14,
	0x00,
	0xc0,
	0x8e,
	0x86,
	0x02,
	0x00,
	0x3c,
	0x8a,
	0x51,
	0x00,
	0x80,
	0x4b,
	0x49,
	0x0a,
	0x00,
	0x60,
	0x67,
	0x4b,
	0x01,
	0x00,
	0xcc,
	0x80,
	0x29,
	0x00,
	0xc0,
	0xa4,
	0x38,
	0xc5,
	0x4e,
	0x99,
	0x14,
	0xa7,
	0x00,
	0x00,
	0x93,
	0xf6,
	0x14,
	0x3b,
	0x65,
	0xd2,
	0x9e,
	0x02,
	0x00,
	0xd8,
	0xf1,
	0x54,
	0x00,
	0x00,
	0x4f,
	0x3d,
	0x00,
	0x00,
	0x20,
	0x0a,
	0x55,
	0x01,
	0x00,
	0x7c,
	0xa8,
	0x1e,
	0xb7,
	0x4a,
	0x13,
	0xb7,
	0x00,
	0x00,
	0x88,
	0x02,
	0xac,
	0x3c,
	0x2b,
	0x8a,
	0xe0,
	0x02,
	0x00,
	0x80,
	0x88,
	0xba,
	0x02,
	0x00,
	0xf4,
	0x99,
	0x02,
	0x00,
	0x00,
	0x2e,
	0x73,
	0x01,
	0xbe,
	0x42,
	0xea,
	0x5d,
	0x01,
	0x00,
	0xb8,
	0xcc,
	0x05,
	0x01,
	0x4b,
	0x29,
	0x2b,
	0x00,
	0x00,
	0xe0,
	0x72,
	0x17,
	0xe0,
	0x05,
	0xa4,
	0x26,
	0x16,
	0x00,
	0x80,
	0x0c,
	0xbe,
	0x02,
	0x00,
	0x70,
	0xb9,
	0x0b,
	0xf4,
	0x02,
	0x32,
	0x01,
	0x0b,
	0x00,
	0xd0,
	0x84,
	0x63,
	0x01,
	0x00,
	0xa2,
	0x3c,
	0x01,
	0x00,
	0xc0,
	0x1e,
	0x93,
	0x05,
	0x00,
	0x48,
	0x15,
	0x05,
	0x00,
	0x00,
	0x8a,
	0x00,
	0x83,
	0x2d,
	0xa0,
	0x15,
	0x00,
	0x10,
	0x18,
	0x10,
	0x91,
	0x02,
	0x00,
	0x00,
	0x2e,
	0x83,
	0xc1,
	0x03,
	0x40,
	0xaa,
	0x0a,
	0x00,
	0x00,
	0xb8,
	0x0c,
	0x06,
	0x11,
	0x00,
	0x97,
	0xc1,
	0x40,
	0x02,
	0xe0,
	0x32,
	0x18,
	0x4c,
	0x00,
	0x8a,
	0xea,
	0x82,
	0x2d,
	0x80,
	0x8b,
	0xd3,
	0x82,
	0x17,
	0x90,
	0xc2,
	0x02,
	0x00,
	0x00,
	0x2e,
	0x4e,
	0x8b,
	0x5e,
	0xe0,
	0x03,
	0x00,
	0x60,
	0x0c,
	0x5e,
	0xd5,
	0x2d,
	0x00,
	0x40,
	0xac,
	0x2e,
	0x00,
	0x00,
	0xf0,
	0x01,
	0x00,
	0xbc,
	0x05,
	0xaf,
	0x20,
	0x03,
	0x00,
	0xc0,
	0x47,
	0x64,
	0xb0,
	0xb8,
	0x28,
	0x91,
	0x0c,
	0x00,
	0x80,
	0x25,
	0x7a,
	0x0b,
	0x00,
	0x10,
	0xcb,
	0x0b,
	0x00,
	0x00,
	0x7c,
	0x00,
	0x00,
	0x95,
	0xc1,
	0xab,
	0xc5,
	0x05,
	0x00,
	0xf0,
	0x01,
	0x00,
	0xfc,
	0x05,
	0x3e,
	0x00,
	0x00,
	0xcc,
	0x80,
	0x56,
	0x66,
	0xc0,
	0x05,
	0x18,
	0x00,
	0x00,
	0xbe,
	0x80,
	0x57,
	0x9b,
	0x01,
	0x00,
	0xe0,
	0x83,
	0x33,
	0xc0,
	0x0c,
	0x94,
	0xe8,
	0x0a,
	0x00,
	0x80,
	0x0f,
	0x00,
	0xc0,
	0x33,
	0x78,
	0x85,
	0x19,
	0x00,
	0x00,
	0x3e,
	0x00,
	0x80,
	0xd0,
	0x85,
	0x4b,
	0x68,
	0xf0,
	0x00,
	0x10,
	0x11,
	0x0d,
	0x00,
	0x80,
	0x5a,
	0x60,
	0x40,
	0x18,
	0xe0,
	0x08,
	0x00,
	0x88,
	0x00,
	0x7c,
	0x00,
	0x00,
	0xa1,
	0xc1,
	0x2b,
	0xd3,
	0x00,
	0x00,
	0xf0,
	0x71,
	0x1a,
	0x2c,
	0x2e,
	0x4a,
	0xf4,
	0x16,
	0x00,
	0xc0,
	0x07,
	0x00,
	0x50,
	0xbd,
	0x70,
	0x09,
	0x0d,
	0x24,
	0x00,
	0x47,
	0x00,
	0xc0,
	0x04,
	0xe0,
	0x03,
	0x00,
	0x60,
	0x0d,
	0x62,
	0xbd,
	0x2f,
	0x00,
	0x80,
	0x0f,
	0x00,
	0xc0,
	0x35,
	0xe8,
	0xf3,
	0x1a,
	0x00,
	0x00,
	0x8a,
	0xe8,
	0x17,
	0x87,
	0xc0,
	0x07,
	0x00,
	0x10,
	0x1b,
	0xc4,
	0xda,
	0x60,
	0x00,
	0x00,
	0x1f,
	0x02,
	0x40,
	0x6c,
	0xe0,
	0x03,
	0x00,
	0xa0,
	0x0d,
	0x14,
	0xd5,
	0x06,
	0x5b,
	0xc0,
	0x1f,
	0x00,
	0xc0,
	0x36,
	0xe8,
	0x23,
	0x06,
	0x00,
	0x00,
	0x3e,
	0x00,
	0x00,
	0xdc,
	0x80,
	0x4c,
	0x0c,
	0x03,
	0x00,
	0xf8,
	0xd0,
	0x0d,
	0x00,
	0x80,
	0x24,
	0xbb,
	0x01,
	0x00,
	0xa0,
	0xc4,
	0x86,
	0x01,
	0x00,
	0x7c,
	0x00,
	0x00,
	0xbd,
	0x01,
	0x19,
	0x2c,
	0x06,
	0x00,
	0xf0,
	0xf1,
	0x1b,
	0x00,
	0x00,
	0x49,
	0x80,
	0x03,
	0x00,
	0x40,
	0x49,
	0x70,
	0x00,
	0x00,
	0x30,
	0xb1,
	0x61,
	0x00,
	0x00,
	0x1f,
	0x00,
	0x80,
	0x1b,
	0x73,
	0x8b,
	0x38,
	0x28,
	0x0e,
	0x70,
	0x01,
	0x00,
	0x64,
	0x40,
	0x93,
	0x3b,
	0x06,
	0x00,
	0xb8,
	0x45,
	0x1c,
	0x1c,
	0x07,
	0xba,
	0xf8,
	0x18,
	0x00,
	0xc0,
	0x07,
	0x00,
	0x10,
	0xc8,
	0x28,
	0x52,
	0x0e,
	0x00,
	0x00,
	0x5e,
	0x92,
	0x0c,
	0x00,
	0xd0,
	0x27,
	0x0d,
	0x00,
	0x00,
	0x7c,
	0x00,
	0x00,
	0xcd,
	0xc1,
	0x2d,
	0x00,
	0xc0,
	0x39,
	0xd0,
	0x65,
	0xcb,
	0x00,
	0x00,
	0xc0,
	0xd8,
	0x00,
	0x00,
	0x80,
	0x49,
	0x74,
	0x00,
	0x00,
	0xf8,
	0x90,
	0x0e,
	0xa8,
	0x03,
	0x25,
	0xd3,
	0x01,
	0x00,
	0xb0,
	0x44,
	0x00,
	0x00,
	0x00,
	0x6e,
	0x01,
	0x00,
	0xd5,
	0x01,
	0x06,
	0x00,
	0xc0,
	0x3a,
	0x68,
	0xe2,
	0x06,
	0x00,
	0x00,
	0x3e,
	0x00,
	0x00,
	0xea,
	0xc0,
	0x07,
	0x00,
	0x90,
	0x1d,
	0xdc,
	0x02,
	0x00,
	0x76,
	0x19,
	0x1f,
	0x00,
	0x00,
	0x31,
	0x23,
	0x0c,
	0x00,
	0xe0,
	0x0e,
	0x86,
	0x75,
	0x07,
	0xdf,
	0x41,
	0x31,
	0x00,
	0xc0,
	0x3b,
	0x30,
	0xf6,
	0x06,
	0x00,
	0x00,
	0xbc,
	0xd0,
	0x00,
	0x00,
	0x80,
	0x4c,
	0x35,
	0x03,
	0x00,
	0x1c,
	0x03,
	0x65,
	0x00,
	0x00,
	0x61,
	0x00,
	0x40,
	0x77,
	0xe0,
	0xc3,
	0x9b,
	0x01,
	0x68,
	0x94,
	0x94,
	0x07,
	0x00,
	0xc0,
	0x12,
	0xf3,
	0x00,
	0x00,
	0x60,
	0x22,
	0x00,
	0x00,
	0x00,
	0xc9,
	0xd0,
	0x03,
	0x00,
	0x60,
	0x59,
	0x7a,
	0x20,
	0xd1,
	0x60,
	0x00,
	0x00,
	0xe0,
	0x80,
	0x65,
	0x00,
	0xc0,
	0x7a,
	0xa0,
	0xeb,
	0xa2,
	0x01,
	0x00,
	0x98,
	0xb5,
	0x07,
	0x00,
	0x00,
	0x99,
	0x96,
	0x06,
	0x00,
	0x78,
	0x06,
	0x00,
	0x7c,
	0x07,
	0x0e,
	0x00,
	0x80,
	0x07,
	0xe0,
	0x19,
	0x00,
	0x10,
	0x1f,
	0xf0,
	0xf2,
	0x69,
	0x00,
	0x00,
	0x07,
	0x00,
	0xc0,
	0x7c,
	0x60,
	0x06,
	0xa9,
	0x01,
	0x00,
	0xcc,
	0x34,
	0x35,
	0x00,
	0x80,
	0x1d,
	0x3b,
	0x05,
	0x00,
	0x68,
	0xb2,
	0xd5,
	0x00,
	0x00,
	0xc0,
	0xec,
	0x00,
	0x00,
	0x00,
	0x1a,
	0x00,
	0x90,
	0x1f,
	0x38,
	0x00,
	0x00,
	0xf4,
	0x03,
	0x69,
	0x00,
	0xc0,
	0x7e,
	0x40,
	0x86,
	0x3f,
	0x00,
	0x00,
	0xa8,
	0xf5,
	0x07,
	0xfe,
	0x81,
	0x19,
	0x3a,
	0x00,
	0x00,
	0x60,
	0xf6,
	0x00,
	0x00,
	0x00,
	0x3e,
	0x00,
	0x00,
	0xc7,
	0xa6,
	0x9a,
	0x1e,
	0x00,
	0x00,
	0x5c,
	0xeb,
	0x03,
	0x00,
	0x00,
	0x6d,
	0x7b,
	0x00,
	0x00,
	0x20,
	0x8e,
	0x0f,
	0x00,
	0x00,
	0xcc,
	0x01,
	0x00,
	0x02,
	0xc2,
	0x39,
	0x3f,
	0x00,
	0x00,
	0x88,
	0xf7,
	0x07,
	0x00,
	0x00,
	0xf4,
	0x00,
	0x01,
	0x00,
	0x20,
	0x5f,
	0x20,
	0x00,
	0x00,
	0xf4,
	0x13,
	0x04,
	0x14,
	0x84,
	0x7f,
	0x01,
	0x00,
	0x00,
	0x20,
	0x8e,
	0x41,
	0x00,
	0x00,
	0x00,
	0x0e,
	0x02,
	0x84,
	0x00,
	0x38,
	0x07,
	0xa1,
	0x10,
	0x10,
	0x58,
	0x08,
	0x00,
	0x00,
	0xe6,
	0x00,
	0x00,
	0x08,
	0x41,
	0xdc,
	0x20,
	0x00,
	0x00,
	0x98,
	0x03,
	0x00,
	0x24,
	0x84,
	0x6b,
	0x86,
	0x00,
	0x00,
	0x60,
	0x0e,
	0x00,
	0xa0,
	0x10,
	0x06,
	0x16,
	0x02,
	0x00,
	0x00,
	0x41,
	0x0b,
	0x01,
	0x00,
	0x38,
	0x78,
	0x08,
	0x00,
	0x00,
	0x0e,
	0x11,
	0x01,
	0x00,
	0x00,
	0x62,
	0x86,
	0x00,
	0x00,
	0x50,
	0x4c,
	0x04,
	0x00,
	0x00,
	0x8b,
	0x8a,
	0x00,
	0x00,
	0x80,
	0x91,
	0x43,
	0x00,
	0x00,
	0x36,
	0x1e,
	0x02,
	0x1d,
	0x02,
	0xc7,
	0x45,
	0x00,
	0x00,
	0xd8,
	0x88,
	0x08,
	0x7c,
	0x08,
	0xd5,
	0x18,
	0x01,
	0x00,
	0x00,
	0x62,
	0x88,
	0x00,
	0x00,
	0x6c,
	0x4c,
	0x04,
	0x44,
	0x04,
	0x90,
	0x8d,
	0x00,
	0x00,
	0xb0,
	0x51,
	0x11,
	0x20,
	0x11,
	0x44,
	0x3a,
	0x02,
	0x00,
	0x00,
	0x49,
	0x13,
	0x21,
	0x00,
	0x28,
	0x79,
	0x22,
	0x00,
	0x00,
	0x26,
	0x03,
	0x00,
	0x00,
	0xc0,
	0x07,
	0x00,
	0x90,
	0x22,
	0xa4,
	0x54,
	0x11,
	0x00,
	0x00,
	0x68,
	0x82,
	0x00,
	0x00,
	0xe0,
	0x03,
	0x00,
	0x60,
	0x11,
	0xa2,
	0x01,
	0x00,
	0x01,
	0x80,
	0x0f,
	0x00,
	0x20,
	0x00,
	0x50,
	0xf9,
	0x22,
	0x00,
	0x00,
	0x2b,
	0x61,
	0x04,
	0x00,
	0x80,
	0xe5,
	0x23,
	0x00,
	0x00,
	0xf8,
	0x00,
	0x71,
	0x00,
	0x80,
	0x96,
	0x00,
	0xc0,
	0x8c,
	0xf0,
	0x12,
	0x00,
	0x98,
	0x72,
	0x60,
	0x62,
	0x39,
	0x00,
	0x00,
	0xcc,
	0x3e,
	0x07,
	0x00,
	0x98,
	0x19,
	0x09,
	0x54,
	0x02,
	0x39,
	0xe7,
	0x1c,
	0x00,
	0x20,
	0x67,
	0x8e,
	0x00,
	0x00,
	0xf4,
	0x14,
	0x74,
	0x00,
	0x80,
	0x9f,
	0x93,
	0x80,
	0x25,
	0x30,
	0x14,
	0x00,
	0x38,
	0x74,
	0x5a,
	0x02,
	0x00,
	0x3d,
	0xc2,
	0x4b,
	0x00,
	0xe0,
	0x12,
	0x80,
	0x89,
	0x09,
	0x00,
	0x00,
	0x33,
	0x31,
	0x01,
	0x4e,
	0x20,
	0xa7,
	0x26,
	0x00,
	0x00,
	0xfc,
	0xd4,
	0x04,
	0x3a,
	0x01,
	0x1f,
	0xee,
	0x8e,
	0xc5,
	0x43,
	0x94,
	0x48,
	0x40,
	0x78,
	0x46,
	0x00,
	0x00,
	0xa2,
	0x00,
	0x51,
	0x22,
	0x01,
	0x00,
	0xf0,
	0x71,
	0xf2,
	0x58,
	0x3c,
	0x44,
	0x01,
	0x00,
	0x84,
	0xc7,
	0x47,
	0xd2,
	0xa3,
	0xf5,
	0x10,
	0x05,
	0x00,
	0x52,
	0x01,
	0x1f,
	0x5f,
	0x0f,
	0x00,
	0x40,
	0x14,
	0x00,
	0x20,
	0x05,
	0x7c,
	0xa0,
	0x3d,
	0x00,
	0x00,
	0x51,
	0x00,
	0xc0,
	0x49,
	0x28,
	0x9a,
	0x0a,
	0x00,
	0x00,
	0x3e,
	0xf2,
	0x1e,
	0x00,
	0x80,
	0xa8,
	0x2c,
	0x30,
	0x0b,
	0xf8,
	0x68,
	0x05,
	0x00,
	0x00,
	0x1f,
	0x4b,
	0x02,
	0x00,
	0xe0,
	0x23,
	0x17,
	0xa0,
	0x12,
	0x8e,
	0x02,
	0x00,
	0xba,
	0xc0,
	0x51,
	0x00,
	0xc0,
	0x4a,
	0xf0,
	0x01,
	0x00,
	0xe8,
	0x02,
	0x3e,
	0x76,
	0x01,
	0x2a,
	0xc1,
	0x47,
	0x2e,
	0xc0,
	0x0b,
	0xf8,
	0xd8,
	0x05,
	0x78,
	0x01,
	0x1f,
	0xdd,
	0x8f,
	0xd6,
	0xe3,
	0xc3,
	0xfd,
	0x01,
	0x00,
	0x7c,
	0xcc,
	0x3f,
	0x00,
	0x00,
	0x04,
	0x00,
	0xa0,
	0x17,
	0xf0,
	0xe1,
	0x00,
	0x01,
	0x00,
	0x3e,
	0x3e,
	0x20,
	0x00,
	0x00
};
static const uint8_t dis2_masknodes[] = {
	0xd9,
	0x5f,
	0xe0,
	0x50,
	0xe8,
	0x6b,
	0xfc,
	0x1b,
	0x00,
	0x00,
	0x00,
	0x88,
	0x11,
	0x98,
	0x9d,
	0x22,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x08,
	0x0a,
	0x01,
	0x00,
	0x01,
	0x00,
	0x08,
	0x00,
	0xb8,
	0xc6,
	0x80,
	0x31,
	0x60,
	0x0c,
	0x18,
	0x03,
	0xc6,
	0x80,
	0x31,
	0x60,
	0x0c,
	0xfc,
	0x0a,
	0xd2,
	0x54,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x80,
	0x2a,
	0x00,
	0xa0,
	0x2b,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x06,
	0x00,
	0x10,
	0x00,
	0x92,
	0xca,
	0xc0,
	0x3b,
	0xa0,
	0x11,
	0x48,
	0x26,
	0x6c,
	0xc1,
	0xd4,
	0xd2,
	0xc5,
	0x8c,
	0x07,
	0x55,
	0x00,
	0x60,
	0x19,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xa9,
	0xae,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x40,
	0xd5,
	0x19,
	0x80,
	0x06,
	0x9c,
	0x01,
	0x68,
	0x20,
	0x73,
	0x08,
	0x1e,
	0x32,
	0x87,
	0xe0,
	0x81,
	0x80,
	0x30,
	0x34,
	0x0c,
	0x88,
	0x01,
	0x80,
	0x00,
	0x40,
	0x14,
	0x00,
	0xcf,
	0x00,
	0xc6,
	0x00,
	0x38,
	0x00,
	0x30,
	0x08,
	0x40,
	0x02,
	0x20,
	0x8c,
	0x06,
	0xa2,
	0x81,
	0x68,
	0x20,
	0x1a,
	0x68,
	0x19,
	0x90,
	0x86,
	0xb1,
	0xc1,
	0x6f,
	0x40,
	0x14,
	0x00,
	0x32,
	0x03,
	0xe6,
	0x66,
	0x38,
	0x00,
	0xa4,
	0xd2,
	0x80,
	0x02,
	0xa0,
	0x00,
	0x28,
	0x00,
	0x0c,
	0x00,
	0x03,
	0xc0,
	0x00,
	0x30,
	0x00,
	0x88,
	0x02,
	0xa0,
	0x69,
	0xc0,
	0x48,
	0x0d,
	0x07,
	0x80,
	0x54,
	0x01,
	0x90,
	0x06,
	0x14,
	0x00,
	0x05,
	0x80,
	0x01,
	0x60,
	0x00,
	0x18,
	0x00,
	0x06,
	0x00,
	0x51,
	0x00,
	0xa0,
	0x0d,
	0x98,
	0xb6,
	0xe1,
	0x00,
	0x90,
	0x2a,
	0x00,
	0x0a,
	0x80,
	0x34,
	0xa0,
	0x00,
	0x30,
	0x00,
	0x0c,
	0x00,
	0x03,
	0xc0,
	0x00,
	0x20,
	0x0a,
	0x80,
	0xc1,
	0x01,
	0x83,
	0x38,
	0x1c,
	0x00,
	0x52,
	0x05,
	0x40,
	0x01,
	0x50,
	0x00,
	0xa4,
	0x01,
	0x06,
	0x80,
	0x01,
	0x60,
	0x00,
	0x18,
	0x00,
	0xe2,
	0x34,
	0xa0,
	0x3a,
	0x4c,
	0x03,
	0xb3,
	0x03,
	0x36,
	0x90,
	0x0d,
	0x60,
	0x03,
	0xdd,
	0xc0,
	0x89,
	0x1a,
	0x70,
	0x00,
	0xaa,
	0x01,
	0x08,
	0xe0,
	0x64,
	0x0d,
	0x38,
	0x00,
	0xd7,
	0x00,
	0x04,
	0x80,
	0x70,
	0x00,
	0x20,
	0x00,
	0xa3,
	0xf4,
	0x70,
	0x41,
	0x54,
	0x11,
	0x87,
	0x04,
	0x2b,
	0xc1,
	0x4e,
	0xb8,
	0x14,
	0x60,
	0x05,
	0xe1,
	0x7a,
	0x70,
	0x00,
	0xa4,
	0xd3,
	0xc0,
	0x34,
	0x30,
	0x0d,
	0x4c,
	0x03,
	0xe8,
	0x83,
	0xfd,
	0x40,
	0x40,
	0x48,
	0x10,
	0x98,
	0x0a,
	0xa0,
	0x7d,
	0x80,
	0x59,
	0x00,
	0x17,
	0x00,
	0x06,
	0x00,
	0x00,
	0x60,
	0x2a,
	0x80,
	0xfd,
	0x01,
	0x66,
	0x01,
	0x5c,
	0x00,
	0x00,
	0x00,
	0x00,
	0x80,
	0xa9,
	0x00,
	0x12,
	0x08,
	0x98,
	0x05,
	0x70,
	0x01,
	0x00,
	0x00,
	0x19,
	0x00,
	0xa6,
	0x02,
	0x00,
	0x00,
	0xa4,
	0x28,
	0x04,
	0x0a,
	0x81,
	0x42,
	0xa0,
	0x10,
	0xe1,
	0x80,
	0x38,
	0x30,
	0x0e,
	0x90,
	0x03,
	0x04,
	0x6c,
	0x00,
	0x1c,
	0x20,
	0xc8,
	0x10,
	0x0e,
	0x00,
	0xe6,
	0x86,
	0x68,
	0x1f,
	0x20,
	0x15,
	0x00,
	0x00,
	0x40,
	0x08,
	0x22,
	0x1c,
	0x00,
	0xcc,
	0x0d,
	0xb1,
	0x3f,
	0x10,
	0x96,
	0x08,
	0x07,
	0x00,
	0x73,
	0x43,
	0x24,
	0x10,
	0x84,
	0x72,
	0xc0,
	0x01,
	0x20,
	0x68,
	0x11,
	0x0e,
	0x80,
	0x74,
	0x1a,
	0x98,
	0x06,
	0xa6,
	0x81,
	0x69,
	0x60,
	0x8d,
	0x58,
	0x23,
	0xf2,
	0x08,
	0x09,
	0x02,
	0x53,
	0x01,
	0xc0,
	0x11,
	0x30,
	0x0b,
	0x40,
	0x03,
	0xd8,
	0x00,
	0x00,
	0x00,
	0x4c,
	0x05,
	0xe0,
	0x47,
	0xc0,
	0x00,
	0x00,
	0x0d,
	0x60,
	0x03,
	0xc8,
	0x00,
	0xa4,
	0x28,
	0x04,
	0x0a,
	0x81,
	0x42,
	0xa0,
	0x10,
	0xe6,
	0x80,
	0x39,
	0x70,
	0x0e,
	0x90,
	0x03,
	0x84,
	0x4e,
	0xc2,
	0x01,
	0xc0,
	0xdc,
	0x10,
	0x70,
	0x04,
	0xe1,
	0x94,
	0x70,
	0x00,
	0x30,
	0x37,
	0x84,
	0x1f,
	0x41,
	0x88,
	0x25,
	0x20,
	0x00,
	0xe9,
	0x34,
	0x30,
	0x0d,
	0x4c,
	0x03,
	0xd3,
	0x80,
	0x30,
	0x01,
	0x4d,
	0x78,
	0x13,
	0x12,
	0x04,
	0xa6,
	0x02,
	0x38,
	0x26,
	0x60,
	0x16,
	0x00,
	0x07,
	0xd0,
	0x01,
	0x00,
	0x00,
	0x98,
	0x0a,
	0xa0,
	0x9a,
	0x80,
	0x01,
	0x00,
	0x1c,
	0x40,
	0x07,
	0x00,
	0x00,
	0x60,
	0x2a,
	0x80,
	0x71,
	0x02,
	0x06,
	0x00,
	0x70,
	0x00,
	0x00,
	0x40,
	0x06,
	0x20,
	0xed,
	0x27,
	0xfa,
	0x89,
	0x7e,
	0xa2,
	0x9f,
	0x48,
	0x07,
	0xd4,
	0x81,
	0x75,
	0x80,
	0x1d,
	0x20,
	0x60,
	0x03,
	0xe8,
	0x00,
	0xe1,
	0xa0,
	0x80,
	0x00,
	0x30,
	0x37,
	0xc4,
	0x31,
	0x41,
	0x88,
	0x28,
	0x20,
	0x00,
	0xcc,
	0x0d,
	0x51,
	0x4d,
	0x10,
	0x36,
	0x0a,
	0x08,
	0x00,
	0x73,
	0x43,
	0x80,
	0x14,
	0x30,
	0x00,
	0x80,
	0x03,
	0xe8,
	0x00,
	0x32,
	0x00,
	0x42,
	0x39,
	0x00,
	0x01,
	0x10,
	0x66,
	0x0a,
	0x08,
	0x40,
	0x3a,
	0x0d,
	0x4c,
	0x03,
	0xd3,
	0xc0,
	0x34,
	0x40,
	0x54,
	0x10,
	0x15,
	0x52,
	0x85,
	0x04,
	0x81,
	0xa9,
	0x00,
	0x92,
	0x0a,
	0x18,
	0x00,
	0xe0,
	0x01,
	0x7c,
	0x00,
	0x00,
	0x00,
	0xa6,
	0x02,
	0xb8,
	0x2a,
	0x60,
	0x00,
	0x80,
	0x07,
	0x00,
	0x00,
	0x64,
	0x00,
	0xd2,
	0x7e,
	0xa2,
	0x9f,
	0xe8,
	0x27,
	0xfa,
	0x89,
	0x76,
	0xa0,
	0x1d,
	0x70,
	0x07,
	0xd8,
	0x01,
	0x82,
	0x5d,
	0x01,
	0x01,
	0x60,
	0x6e,
	0x88,
	0xa4,
	0x82,
	0x00,
	0x58,
	0x40,
	0x00,
	0x98,
	0x1b,
	0xa2,
	0xb0,
	0x80,
	0x01,
	0x00,
	0x1e,
	0xc0,
	0x07,
	0x90,
	0x01,
	0x54,
	0xe1,
	0x81,
	0x78,
	0x00,
	0x1e,
	0x88,
	0x07,
	0x70,
	0x0b,
	0xf0,
	0x02,
	0xb7,
	0x00,
	0x2f,
	0x08,
	0xa4,
	0x45,
	0x6a,
	0x81,
	0x18,
	0x00,
	0x40,
	0x00,
	0x44,
	0x08,
	0x20,
	0x02,
	0x20,
	0x66,
	0x0b,
	0x00,
	0x80,
	0x00,
	0x00,
	0x84,
	0x00,
	0xc4,
	0x79,
	0x20,
	0xb9,
	0x98,
	0x07,
	0xa4,
	0x0b,
	0x7c,
	0x60,
	0x1f,
	0xc0,
	0x07,
	0xfc,
	0x81,
	0x13,
	0x3d,
	0x40,
	0x02,
	0xd4,
	0x03,
	0x25,
	0xc0,
	0xc9,
	0x1e,
	0x20,
	0x01,
	0xee,
	0x81,
	0x12,
	0x00,
	0x41,
	0x02,
	0x94,
	0x00,
	0xc6,
	0xf8,
	0x62,
	0xc4,
	0x38,
	0x34,
	0x72,
	0x8d,
	0x75,
	0x63,
	0x22,
	0x78,
	0x3a,
	0x2e,
	0x02,
	0x82,
	0x7d,
	0x41,
	0x02,
	0x48,
	0xe7,
	0x81,
	0x79,
	0x60,
	0x1e,
	0x98,
	0x07,
	0x0e,
	0x8c,
	0x03,
	0xa3,
	0xc2,
	0x90,
	0x20,
	0x30,
	0x15,
	0x00,
	0x83,
	0x01,
	0x43,
	0x01,
	0x52,
	0x00,
	0x80,
	0x00,
	0x00,
	0xc0,
	0x54,
	0x00,
	0x1a,
	0x06,
	0x0c,
	0x05,
	0x48,
	0x01,
	0x00,
	0x82,
	0x0c,
	0x40,
	0x1a,
	0x10,
	0x04,
	0x04,
	0x01,
	0x41,
	0x40,
	0x30,
	0x10,
	0x0c,
	0x04,
	0x08,
	0x81,
	0x42,
	0x40,
	0x38,
	0x01,
	0x04,
	0x02,
	0x18,
	0x41,
	0x50,
	0x10,
	0x18,
	0x04,
	0x07,
	0x01,
	0xe1,
	0xc8,
	0x20,
	0x01,
	0x30,
	0x15,
	0x00,
	0x0a,
	0x40,
	0x88,
	0x32,
	0x48,
	0x00,
	0x0c,
	0x00,
	0x90,
	0x02,
	0x10,
	0xb6,
	0x0c,
	0x12,
	0x00,
	0x53,
	0x01,
	0xac,
	0x00,
	0x18,
	0x00,
	0xa0,
	0xcc,
	0x20,
	0xac,
	0x00,
	0x00,
	0x00,
	0x01,
	0x00,
	0x20,
	0x01,
	0x60,
	0x04,
	0x41,
	0x41,
	0x60,
	0x10,
	0x24,
	0x04,
	0x84,
	0x3e,
	0x83,
	0x04,
	0xc0,
	0x00,
	0x00,
	0x19,
	0x00,
	0xa1,
	0x1c,
	0x20,
	0x01,
	0x08,
	0x8c,
	0x06,
	0x09,
	0x20,
	0x9d,
	0x07,
	0xe6,
	0x81,
	0x79,
	0x60,
	0x1e,
	0xe8,
	0x34,
	0x3a,
	0x8d,
	0x55,
	0x43,
	0x82,
	0xc0,
	0x54,
	0x00,
	0xa2,
	0x06,
	0x0c,
	0x05,
	0x00,
	0x00,
	0x16,
	0x02,
	0x00,
	0x00,
	0x53,
	0x01,
	0xc0,
	0x1a,
	0x30,
	0x14,
	0x00,
	0x00,
	0x58,
	0x08,
	0x32,
	0x00,
	0x69,
	0x40,
	0x10,
	0x10,
	0x04,
	0x04,
	0x01,
	0x01,
	0x43,
	0xc0,
	0x10,
	0x3c,
	0x04,
	0x10,
	0x01,
	0xe1,
	0xd9,
	0x10,
	0x08,
	0x60,
	0x0d,
	0x01,
	0x00,
	0x80,
	0x6d,
	0x00,
	0x00,
	0x18,
	0x87,
	0x60,
	0x05,
	0x80,
	0x11,
	0x04,
	0x07,
	0x81,
	0x41,
	0x90,
	0x10,
	0x10,
	0x22,
	0x02,
	0x12,
	0x80,
	0x00,
	0x6f,
	0x94,
	0x00,
	0xd2,
	0x79,
	0x60,
	0x1e,
	0x98,
	0x07,
	0xe6,
	0x81,
	0x80,
	0x23,
	0xe0,
	0x78,
	0x38,
	0x24,
	0x08,
	0x4c,
	0x05,
	0x60,
	0x70,
	0xc0,
	0x00,
	0x00,
	0x16,
	0x40,
	0x22,
	0x00,
	0x00,
	0x30,
	0x15,
	0x00,
	0xc5,
	0x01,
	0x03,
	0x00,
	0x58,
	0x00,
	0x89,
	0x20,
	0x03,
	0x20,
	0x88,
	0x1c,
	0x16,
	0x81,
	0x54,
	0x1f,
	0xd0,
	0x07,
	0xf4,
	0x01,
	0x7d,
	0x80,
	0x22,
	0xa0,
	0x08,
	0x2a,
	0x82,
	0x72,
	0x00,
	0x26,
	0x41,
	0xf0,
	0x1c,
	0x12,
	0x04,
	0x00,
	0x80,
	0x01,
	0x00,
	0x58,
	0x00,
	0xcc,
	0x0d,
	0x61,
	0x74,
	0xc0,
	0x00,
	0x00,
	0x16,
	0x00,
	0x00,
	0xc8,
	0x00,
	0x08,
	0x54,
	0x47,
	0x09,
	0x20,
	0x9d,
	0x07,
	0xe6,
	0x81,
	0x79,
	0x60,
	0x1e,
	0x28,
	0x3b,
	0xca,
	0x8e,
	0xb9,
	0x43,
	0x82,
	0xc0,
	0x54,
	0x00,
	0x6a,
	0x07,
	0x0c,
	0x00,
	0x70,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x53,
	0x01,
	0xe0,
	0x1d,
	0x30,
	0x00,
	0xc0,
	0x05,
	0x00,
	0x00,
	0x32,
	0x00,
	0x82,
	0xe1,
	0x61,
	0x11,
	0x48,
	0xf5,
	0x01,
	0x7d,
	0x40,
	0x1f,
	0xd0,
	0x07,
	0x30,
	0x02,
	0x8c,
	0x20,
	0x23,
	0x28,
	0x07,
	0x60,
	0x12,
	0x04,
	0xe8,
	0x21,
	0x41,
	0x00,
	0x00,
	0x18,
	0x00,
	0xc0,
	0x05,
	0xc0,
	0xdc,
	0x10,
	0x78,
	0x87,
	0x15,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x60,
	0x23,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x60,
	0x0a,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x20,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x70,
	0xf3,
	0x08,
	0xc8,
	0x0f,
	0x8f,
	0xe0,
	0x04,
	0x21,
	0x68,
	0x1f,
	0xdf,
	0x07,
	0xe2,
	0x05,
	0x80,
	0x01,
	0x10,
	0x31,
	0x80,
	0x0c,
	0x40,
	0xfc,
	0x08,
	0xf4,
	0x8f,
	0x8f,
	0x60,
	0x00,
	0x61,
	0x40,
	0x2a,
	0x10,
	0x06,
	0xc4,
	0x03,
	0x41,
	0x80,
	0x04,
	0x21,
	0xc1,
	0x49,
	0x24,
	0x00,
	0x00,
	0x46,
	0x82,
	0x1a,
	0xe0,
	0x44,
	0x12,
	0x00,
	0x00,
	0x25,
	0x41,
	0x0d,
	0x40,
	0x03,
	0x00,
	0xb0,
	0x01,
	0x0a,
	0xc0,
	0x21,
	0x38,
	0x99,
	0x04,
	0x00,
	0x00,
	0x4a,
	0xa0,
	0x12,
	0x9c,
	0x56,
	0x02,
	0x00,
	0xa0,
	0x25,
	0x50,
	0x09,
	0xa6,
	0x38,
	0x08,
	0x4d,
	0x50,
	0x89,
	0x54,
	0x22,
	0xb0,
	0x08,
	0x2c,
	0xb2,
	0x8c,
	0x90,
	0x24,
	0xc6,
	0x24,
	0x04,
	0x26,
	0xd8,
	0x42,
	0x62,
	0x82,
	0x32,
	0x44,
	0x26,
	0xb8,
	0x43,
	0x66,
	0x02,
	0xd2,
	0x4b,
	0xf0,
	0x00,
	0xbc,
	0x04,
	0x12,
	0x00,
	0x09,
	0x00,
	0x78,
	0x00,
	0x00,
	0x00,
	0x09,
	0x80,
	0xf0,
	0x12,
	0xdc,
	0x00,
	0x04,
	0x00,
	0xe0,
	0x06,
	0x20,
	0x85,
	0x04,
	0x11,
	0x40,
	0x48,
	0x30,
	0x01,
	0x90,
	0x00,
	0x80,
	0x08,
	0x00,
	0x00,
	0x98,
	0x00,
	0x08,
	0x21,
	0x01,
	0x0e,
	0x40,
	0x00,
	0x00,
	0x70,
	0x00,
	0x82,
	0x21,
	0x02,
	0x89,
	0x18,
	0x16,
	0x11,
	0x00,
	0x00,
	0xf1,
	0x12,
	0x84,
	0x04,
	0x88,
	0x1b,
	0x00,
	0x07,
	0x30,
	0x6e,
	0x21,
	0xa6,
	0xc8,
	0x16,
	0x62,
	0x8a,
	0xdc,
	0x21,
	0x33,
	0xc1,
	0x1d,
	0x32,
	0x13,
	0x30,
	0x56,
	0x11,
	0x00,
	0x80,
	0x80,
	0x0d,
	0xd4,
	0x04,
	0xc6,
	0x2d,
	0xc4,
	0x14,
	0xd9,
	0x42,
	0x4c,
	0x91,
	0x3b,
	0x24,
	0x18,
	0xb9,
	0x43,
	0x82,
	0x11,
	0x86,
	0x31,
	0x02,
	0x00,
	0x10,
	0xb0,
	0x01,
	0x9b,
	0xc0,
	0xc8,
	0x8d,
	0xdc,
	0x04,
	0xea,
	0x08,
	0x4e,
	0x80,
	0x8f,
	0xe4,
	0x04,
	0x0e,
	0x89,
	0x4e,
	0x40,
	0x08,
	0x47,
	0x6e,
	0x00,
	0x58,
	0x0e,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xe1,
	0x1d,
	0xb9,
	0x01,
	0x60,
	0x3a,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x84,
	0x7e,
	0x04,
	0x07,
	0x80,
	0xee,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x10,
	0x26,
	0x12,
	0x1c,
	0x00,
	0xca,
	0x03,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xad,
	0x49,
	0xa0,
	0x92,
	0xa0,
	0x40,
	0x28,
	0x18,
	0x0a,
	0x86,
	0x82,
	0xa1,
	0x60,
	0x28,
	0x30,
	0x1a,
	0x25,
	0x3b,
	0xc1,
	0x52,
	0xc2,
	0x13,
	0xf0,
	0x21,
	0x33,
	0x01,
	0x1f,
	0x32,
	0x13,
	0x10,
	0x72,
	0x80,
	0x1b,
	0x80,
	0xa0,
	0x03,
	0xdc,
	0x00,
	0xc6,
	0xb0,
	0xa4,
	0x27,
	0x30,
	0x4b,
	0x7c,
	0x82,
	0xb5,
	0xe4,
	0x27,
	0x80,
	0x4b,
	0x80,
	0x02,
	0xc2,
	0x05,
	0x70,
	0x03,
	0x10,
	0x34,
	0x80,
	0x1b,
	0x80,
	0xc0,
	0x01,
	0xe0,
	0x00,
	0x04,
	0x0f,
	0x00,
	0x07,
	0x20,
	0xe8,
	0x25,
	0x90,
	0xc8,
	0xa9,
	0x07,
	0xf0,
	0x01,
	0x7a,
	0x80,
	0x1f,
	0x80,
	0x80,
	0x98,
	0x40,
	0x22,
	0x07,
	0x20,
	0x20,
	0x08,
	0x20,
	0x00,
	0x00,
	0x90,
	0x48,
	0x95,
	0x28,
	0x30,
	0x0a,
	0x88,
	0x82,
	0xa5,
	0xa0,
	0x29,
	0xc8,
	0x0a,
	0x9a,
	0x82,
	0xac,
	0x00,
	0x21,
	0x04,
	0xa0,
	0x26,
	0x84,
	0x21,
	0x80,
	0x08,
	0x20,
	0xfa,
	0x26,
	0xc8,
	0x89,
	0x6f,
	0x12,
	0x9d,
	0xe0,
	0x03,
	0x55,
	0x01,
	0x3e,
	0x70,
	0x15,
	0x20,
	0x9c,
	0x82,
	0xa7,
	0x00,
	0x53,
	0x04,
	0x18,
	0x01,
	0x27,
	0xa8,
	0x20,
	0x2a,
	0x90,
	0x0a,
	0x90,
	0x80,
	0xd3,
	0x54,
	0x10,
	0x15,
	0x50,
	0x05,
	0x48,
	0x80,
	0x74,
	0x3d,
	0x59,
	0x4f,
	0xd6,
	0x93,
	0xf5,
	0xe4,
	0x2b,
	0x08,
	0x0b,
	0xa4,
	0x14,
	0x59,
	0xc5,
	0xa8,
	0x15,
	0x74,
	0x05,
	0x5a,
	0x41,
	0x57,
	0xb0,
	0xa0,
	0x78,
	0x05,
	0x0b,
	0x8a,
	0x57,
	0x40,
	0xd8,
	0x0a,
	0x90,
	0x00,
	0x42,
	0x11,
	0x00,
	0x00,
	0x10,
	0x4e,
	0x80,
	0xa8,
	0x80,
	0xf0,
	0x14,
	0x20,
	0x01,
	0x04,
	0x7d,
	0x20,
	0x2a,
	0x20,
	0x80,
	0x05,
	0x51,
	0x01,
	0xa6,
	0x02,
	0xf8,
	0x50,
	0x60,
	0x28,
	0x0a,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xa7,
	0x24,
	0x20,
	0x09,
	0x50,
	0x02,
	0x96,
	0x00,
	0x82,
	0x8d,
	0x12,
	0x15,
	0xc0,
	0x7e,
	0x94,
	0x72,
	0x80,
	0x48,
	0x29,
	0x07,
	0x30,
	0x15,
	0x00,
	0x8a,
	0x82,
	0xa9,
	0x00,
	0xc4,
	0x02,
	0x13,
	0x13,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x6c,
	0x2c,
	0x20,
	0x0b,
	0xd2,
	0x82,
	0xb5,
	0x80,
	0xf0,
	0xa3,
	0x44,
	0x05,
	0xc6,
	0xb2,
	0xc0,
	0x2c,
	0x38,
	0x0b,
	0xd0,
	0x02,
	0x40,
	0x45,
	0x51,
	0x79,
	0x54,
	0x32,
	0x15,
	0x42,
	0x0a,
	0x80,
	0x04,
	0x10,
	0x2a,
	0x00,
	0x00,
	0x80,
	0x00,
	0x00,
	0x20,
	0x01,
	0x84,
	0x42,
	0x05,
	0x09,
	0xc0,
	0x54,
	0x00,
	0x2c,
	0x00,
	0x81,
	0xe7,
	0x40,
	0x02,
	0x08,
	0x94,
	0x0a,
	0x12,
	0x80,
	0xa9,
	0x00,
	0x5c,
	0x00,
	0x02,
	0xe8,
	0x81,
	0x04,
	0x10,
	0x46,
	0x95,
	0xa8,
	0x00,
	0x53,
	0x01,
	0xa8,
	0x05,
	0x84,
	0x56,
	0x25,
	0x2a,
	0xc0,
	0x38,
	0x04,
	0x4d,
	0x00,
	0xa1,
	0x1c,
	0x88,
	0x0a,
	0x6e,
	0x6d,
	0x41,
	0xb6,
	0xb2,
	0x17,
	0xac,
	0x2c,
	0x84,
	0x62,
	0x45,
	0x59,
	0x41,
	0x38,
	0x01,
	0x4f,
	0x00,
	0x02,
	0x0a,
	0x88,
	0x02,
	0x10,
	0xd4,
	0x0a,
	0x00,
	0x40,
	0x70,
	0x02,
	0x00,
	0x00,
	0xe2,
	0x5b,
	0x20,
	0x17,
	0xbc,
	0x05,
	0x74,
	0x81,
	0xc2,
	0x62,
	0x17,
	0x28,
	0x2c,
	0x79,
	0x01,
	0x42,
	0x0a,
	0x88,
	0x0b,
	0x4e,
	0x54,
	0x00,
	0x00,
	0x50,
	0x05,
	0x00,
	0x00,
	0xa7,
	0x07,
	0x00,
	0x00,
	0x88,
	0x00,
	0x00,
	0x80,
	0x93,
	0x04,
	0x00,
	0x00,
	0x4c,
	0x00,
	0x00,
	0x00,
	0x0d,
	0x00,
	0xa8,
	0x0b,
	0xac,
	0x00,
	0x87,
	0xe0,
	0x74,
	0x05,
	0x00,
	0x00,
	0x58,
	0x00,
	0x00,
	0x40,
	0x08,
	0x59,
	0xfa,
	0x02,
	0x44,
	0x16,
	0xc0,
	0x17,
	0x20,
	0xb4,
	0x00,
	0xbf,
	0x80,
	0xf8,
	0x17,
	0xf0,
	0x2c,
	0x7f,
	0x41,
	0xd1,
	0x72,
	0x18,
	0x20,
	0x06,
	0x87,
	0x81,
	0x62,
	0x70,
	0x12,
	0x0c,
	0x00,
	0x00,
	0xc2,
	0x00,
	0x00,
	0x38,
	0x15,
	0x06,
	0x00,
	0x80,
	0x61,
	0x00,
	0x00,
	0x1c,
	0x12,
	0x03,
	0x00,
	0x80,
	0x48,
	0xb6,
	0x40,
	0x2e,
	0xb3,
	0x0b,
	0xf1,
	0xe2,
	0xbd,
	0x80,
	0x30,
	0xde,
	0xcb,
	0x11,
	0x63,
	0x5d,
	0x0c,
	0x16,
	0x03,
	0xc7,
	0xc0,
	0x31,
	0x78,
	0x0c,
	0x28,
	0x03,
	0xcb,
	0xc0,
	0x32,
	0x40,
	0x70,
	0x01,
	0x8d,
	0xc1,
	0x14,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x40,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xc1,
	0x05,
	0x4c,
	0x06,
	0xd5,
	0xcb,
	0x40,
	0x33,
	0xb8,
	0x0c,
	0x3a,
	0x83,
	0xcf,
	0x40,
	0x75,
	0xf9,
	0x0c,
	0x54,
	0x97,
	0x13,
	0x68,
	0x00,
	0x00,
	0x8c,
	0x06,
	0x00,
	0xc0,
	0x89,
	0x34,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xc0,
	0xba,
	0x18,
	0x2c,
	0x06,
	0x8e,
	0x81,
	0x63,
	0x50,
	0x1a,
	0x50,
	0x06,
	0x96,
	0x81,
	0x65,
	0x50,
	0xbd,
	0x0c,
	0x34,
	0x83,
	0xcb,
	0xa0,
	0x33,
	0x40,
	0x0d,
	0x54,
	0x17,
	0xd4,
	0x40,
	0x75,
	0x39,
	0xa5,
	0x06,
	0x00,
	0x80,
	0x6a,
	0x00,
	0x00,
	0x58,
	0x57,
	0x83,
	0xd5,
	0xa0,
	0x35,
	0x68,
	0x0d,
	0xf2,
	0x17,
	0xd8,
	0x60,
	0x36,
	0x98,
	0x0d,
	0x10,
	0x00,
	0x40,
	0x17,
	0x80,
	0x10,
	0x03,
	0xc6,
	0x00,
	0xa8,
	0x02,
	0x03,
	0x00,
	0xc0,
	0x06,
	0x00,
	0x00,
	0x6c,
	0x00,
	0x00,
	0xc0,
	0x06,
	0x00,
	0xc0,
	0x14,
	0x00,
	0x00,
	0x00,
	0x60,
	0x03,
	0xd8,
	0x40,
	0x36,
	0x80,
	0x0d,
	0x00,
	0x00,
	0x00,
	0x00,
	0x01,
	0x00,
	0x78,
	0x01,
	0xd3,
	0xdb,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x80,
	0xdc,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x80,
	0x0b,
	0x00,
	0x80,
	0xaf,
	0x58,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x04,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xa6,
	0xbc,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xbe,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x17,
	0x00,
	0x20,
	0x60,
	0xb1,
	0x0a,
	0x07,
	0xc2,
	0x01,
	0x72,
	0x80,
	0x1c,
	0x94,
	0x32,
	0xd8,
	0x81,
	0x76,
	0xa0,
	0x1d,
	0xd0,
	0x86,
	0x03,
	0x00,
	0xc0,
	0x38,
	0x00,
	0x00,
	0x08,
	0x65,
	0x80,
	0x19,
	0x40,
	0x38,
	0x03,
	0xcc,
	0x00,
	0x62,
	0x72,
	0x20,
	0x12,
	0x24,
	0x07,
	0x24,
	0xc1,
	0x25,
	0x63,
	0x12,
	0x5c,
	0x32,
	0x2b,
	0x01,
	0x02,
	0x0d,
	0x58,
	0x0e,
	0x68,
	0x00,
	0x00,
	0x28,
	0x03,
	0xca,
	0x38,
	0x04,
	0x08,
	0x35,
	0x60,
	0x0d,
	0x98,
	0x32,
	0x07,
	0xcc,
	0x01,
	0x00,
	0x00,
	0x00,
	0x40,
	0x07,
	0xd7,
	0x01,
	0x00,
	0x00,
	0x00,
	0x10,
	0x9e,
	0x83,
	0x36,
	0x80,
	0xe6,
	0x1c,
	0x00,
	0x00,
	0xd5,
	0x01,
	0x00,
	0x40,
	0xdc,
	0x0e,
	0x44,
	0x82,
	0xed,
	0x80,
	0x24,
	0x00,
	0x0f,
	0x4c,
	0x02,
	0xf0,
	0x60,
	0x25,
	0xa0,
	0x01,
	0x00,
	0xe1,
	0x41,
	0x78,
	0x20,
	0x1e,
	0x58,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xde,
	0x19,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xa6,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xe4,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xb7,
	0x84,
	0x86,
	0xa3,
	0xb1,
	0x0f,
	0xf0,
	0x03,
	0xda,
	0x79,
	0x00,
	0x00,
	0xa8,
	0x07,
	0x00,
	0x00,
	0x21,
	0x0e,
	0x90,
	0x03,
	0x08,
	0x71,
	0xc0,
	0x1c,
	0x30,
	0x65,
	0x0f,
	0xe0,
	0x03,
	0x00,
	0x00,
	0x00,
	0x90,
	0x0f,
	0xe4,
	0x03,
	0xfa,
	0x80,
	0x3e,
	0x20,
	0xba,
	0x07,
	0xef,
	0xc1,
	0x77,
	0xf0,
	0x1e,
	0x00,
	0x00,
	0xef,
	0x01,
	0x00,
	0xf0,
	0x1e,
	0x10,
	0x86,
	0x1a,
	0x00,
	0xc0,
	0x80,
	0x06,
	0x00,
	0x00,
	0x04,
	0x00,
	0x80,
	0x0e,
	0x30,
	0x21,
	0x35,
	0x56,
	0x0d,
	0x00,
	0x50,
	0x1f,
	0x10,
	0x1c,
	0x02,
	0x3a,
	0x80,
	0x46,
	0xd6,
	0x00,
	0x00,
	0x73,
	0x0d,
	0x00,
	0x40,
	0x48,
	0x6b,
	0xdc,
	0x1a,
	0x44,
	0x1d,
	0x70,
	0x1f,
	0x20,
	0xee,
	0x00,
	0x3c,
	0x80,
	0x80,
	0xd7,
	0xb8,
	0x35,
	0x88,
	0x3c,
	0xe0,
	0x3e,
	0xe0,
	0x02,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xf0,
	0x1f,
	0x50,
	0x3f,
	0x9b,
	0x04,
	0x61,
	0xba,
	0x09,
	0x00,
	0x3e,
	0x1b,
	0x00,
	0x60,
	0xba,
	0x29,
	0x11,
	0x6e,
	0xa8,
	0x8d,
	0x72,
	0x03,
	0x00,
	0x00,
	0x00,
	0x49,
	0x00,
	0x21,
	0xb7,
	0x09,
	0x10,
	0x04,
	0x84,
	0x01,
	0x81,
	0x40,
	0x00,
	0x00,
	0x00,
	0x00,
	0xe3,
	0x1e,
	0xb0,
	0x07,
	0xec,
	0x01,
	0x7b,
	0x00,
	0x1f,
	0xc0,
	0x07,
	0xf0,
	0x01,
	0x00,
	0x00,
	0xaa,
	0x40,
	0x30,
	0x10,
	0x0e,
	0x04,
	0x04,
	0xe1,
	0xc6,
	0xdd,
	0xb4,
	0x37,
	0x00,
	0x00,
	0x00,
	0x80,
	0x5c,
	0x10,
	0x16,
	0x84,
	0x06,
	0xe1,
	0x41,
	0x88,
	0x10,
	0x22,
	0x84,
	0x09,
	0x61,
	0x42,
	0x40,
	0x56,
	0x08,
	0x17,
	0x02,
	0x86,
	0xa0,
	0x21,
	0x6c,
	0x08,
	0x1e,
	0x02,
	0x88,
	0x30,
	0x22,
	0x50,
	0x01,
	0x00,
	0x14,
	0x01,
	0x00,
	0x58,
	0x11,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x78,
	0x70,
	0x88,
	0x2d,
	0x02,
	0x00,
	0xd0,
	0x22,
	0x00,
	0x00,
	0x2d,
	0x02,
	0x00,
	0xd0,
	0x22,
	0xb8,
	0x08,
	0x48,
	0x00,
	0x00,
	0x00,
	0x88,
	0x71,
	0x76,
	0x04,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x80,
	0xa9,
	0x90,
	0x23,
	0xe4,
	0x88,
	0x39,
	0x62,
	0x0e,
	0x8d,
	0x50,
	0x23,
	0xdc,
	0x08,
	0x38,
	0x82,
	0x15,
	0x00,
	0x90,
	0x11,
	0xb0,
	0x1c,
	0x2c,
	0xa7,
	0xcb,
	0xe9,
	0x72,
	0xba,
	0x9c,
	0x2e,
	0x67,
	0x01,
	0x00,
	0x40,
	0x02,
	0x0b,
	0x00,
	0x20,
	0x12,
	0x58,
	0x00,
	0x00,
	0x92,
	0x80,
	0x15,
	0x00,
	0x90,
	0x11,
	0xe6,
	0x9c,
	0x39,
	0x07,
	0xcf,
	0xc1,
	0x73,
	0xf0,
	0x1c,
	0x3c,
	0x67,
	0x01,
	0x00,
	0x4c,
	0x02,
	0x0b,
	0x00,
	0x80,
	0x12,
	0x58,
	0x00,
	0x00,
	0x36,
	0xc2,
	0x02,
	0x00,
	0xd0,
	0x11,
	0xa6,
	0x98,
	0x0e,
	0xa6,
	0x93,
	0xea,
	0xa4,
	0x3a,
	0x3e,
	0x82,
	0xae,
	0x03,
	0x24,
	0x0c,
	0x3b,
	0x56,
	0x00,
	0x80,
	0x47,
	0xc0,
	0x04,
	0x30,
	0x81,
	0x4c,
	0x20,
	0x13,
	0xc8,
	0x04,
	0x32,
	0x01,
	0x2b,
	0x00,
	0xc0,
	0x23,
	0x68,
	0x02,
	0x9a,
	0xc0,
	0x26,
	0xb0,
	0x09,
	0x6c,
	0x02,
	0x9b,
	0xc0,
	0x0d,
	0x00,
	0xc0,
	0x04,
	0x7e,
	0x04,
	0x00,
	0xe0,
	0x06,
	0x00,
	0x04,
	0x09,
	0x9a,
	0x00,
	0x00,
	0x90,
	0x04,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0xba,
	0x1d,
	0x00,
	0x00,
	0x00,
	0xb0,
	0x0a,
	0x09,
	0x46,
	0x02,
	0xce,
	0xc3,
	0xfc,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x10,
	0xff,
	0x9d,
	0x21,
	0xe1,
	0xdf,
	0x19,
	0x12,
	0x1a,
	0x9e,
	0x22,
	0xa1,
	0xe1,
	0x19,
	0x12,
	0x68,
	0x9e,
	0xc0,
	0x27,
	0x00,
	0x0a,
	0x84,
	0x02,
	0x94,
	0x51,
	0x80,
	0x14,
	0xa0,
	0x79,
	0x02,
	0x9f,
	0x40,
	0x29,
	0x60,
	0x0a,
	0x10,
	0x4f,
	0x01,
	0x00,
	0xe0,
	0x14,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x88,
	0xff,
	0xce,
	0x91,
	0xf0,
	0xef,
	0x1c,
	0x09,
	0x0d,
	0xcf,
	0x91,
	0xd0,
	0xf0,
	0x1c,
	0x09,
	0x53,
	0x24,
	0x01,
	0x49,
	0x50,
	0x12,
	0x94,
	0x04,
	0x26,
	0x81,
	0x49,
	0x78,
	0x12,
	0x54,
	0x1f,
	0x22,
	0x2a,
	0x90,
	0x24,
	0xa0,
	0x02,
	0x49,
	0x02,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x41,
	0x15,
	0x00,
	0x00,
	0x48,
	0xab,
	0x00,
	0x00,
	0xb0,
	0x0a,
	0x2c,
	0x09,
	0x44,
	0x56,
	0xa0,
	0x49,
	0x60,
	0x05,
	0x9a,
	0x04,
	0x56,
	0x00,
	0x00,
	0x60,
	0x05,
	0x00,
	0x00,
	0x62,
	0x2b,
	0x00,
	0x00,
	0xb4,
	0x02,
	0x4b,
	0x82,
	0xe2,
	0x03,
	0x00,
	0x28,
	0x3e,
	0x4b,
	0x02,
	0x74,
	0xf3,
	0x01,
	0x7d,
	0xa0,
	0x04,
	0x28,
	0x81,
	0x16,
	0xa8,
	0x05,
	0x6c,
	0x81,
	0xd2,
	0xe7,
	0xe0,
	0x0a,
	0xbc,
	0x02,
	0x07,
	0x58,
	0x20,
	0x16,
	0x38,
	0xdc,
	0x02,
	0xb8,
	0x00,
	0x31,
	0x4a,
	0x00,
	0x00,
	0xa2,
	0x04,
	0x29,
	0x61,
	0xf7,
	0x01,
	0x00,
	0x76,
	0x1f,
	0x29,
	0x01,
	0x3a,
	0x25,
	0x54,
	0x09,
	0x57,
	0xc2,
	0x95,
	0x80,
	0x25,
	0x60,
	0x09,
	0x59,
	0x42,
	0x96,
	0x30,
	0xd5,
	0x12,
	0xb4,
	0x84,
	0x2d,
	0x61,
	0x4b,
	0xe0,
	0x12,
	0xb8,
	0x04,
	0x2f,
	0x81,
	0x04,
	0x22,
	0xa2,
	0x02,
	0x49,
	0x02,
	0x2a,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x10,
	0x56,
	0x81,
	0x25,
	0x81,
	0xc8,
	0x0a,
	0x10,
	0x40,
	0xac,
	0x40,
	0x02,
	0xc4,
	0x0a,
	0x74,
	0x09,
	0xac,
	0x40,
	0x97,
	0x80,
	0xe8,
	0x05,
	0x9c,
	0x04,
	0x44,
	0x2f,
	0x00,
	0x00,
	0x10,
	0x5b,
	0x81,
	0x0f,
	0xa8,
	0x15,
	0xf8,
	0x80,
	0x14,
	0x9f,
	0x0f,
	0x48,
	0xf1,
	0xf9,
	0x80,
	0x10,
	0xbe,
	0x00,
	0x29,
	0x40,
	0x8c,
	0x12,
	0xbe,
	0x84,
	0x28,
	0xe1,
	0x4b,
	0xd8,
	0x7d,
	0xbe,
	0x84,
	0xdd,
	0xe7,
	0x4b,
	0x00
};
RETURNTYPE dis2(PARAMDECL)
{
	const uint32_t dis2_opcode = OPCODE;
	dis2_argstruct *dis2_args,dis2_theargs;
	dis2_theargs.dis2_argf_0_4 = (((dis2_opcode >> 0) & 0xf)<<0);
	dis2_theargs.dis2_argf_0_4_5_1 = (((dis2_opcode >> 5) & 0x1)<<0) | (((dis2_opcode >> 0) & 0xf)<<1);
	dis2_theargs.dis2_argf_0_8 = (((dis2_opcode >> 0) & 0xff)<<0);
	dis2_theargs.dis2_argf_10_1 = (((dis2_opcode >> 10) & 0x1)<<0);
	dis2_theargs.dis2_argf_10_2 = (((dis2_opcode >> 10) & 0x3)<<0);
	dis2_theargs.dis2_argf_12_4 = (((dis2_opcode >> 12) & 0xf)<<0);
	dis2_theargs.dis2_argf_12_4_22_1 = (((dis2_opcode >> 22) & 0x1)<<0) | (((dis2_opcode >> 12) & 0xf)<<1);
	dis2_theargs.dis2_argf_16_1 = (((dis2_opcode >> 16) & 0x1)<<0);
	dis2_theargs.dis2_argf_16_2 = (((dis2_opcode >> 16) & 0x3)<<0);
	dis2_theargs.dis2_argf_16_3 = (((dis2_opcode >> 16) & 0x7)<<0);
	dis2_theargs.dis2_argf_16_4 = (((dis2_opcode >> 16) & 0xf)<<0);
	dis2_theargs.dis2_argf_16_4_0_4 = (((dis2_opcode >> 0) & 0xf)<<0) | (((dis2_opcode >> 16) & 0xf)<<4);
	dis2_theargs.dis2_argf_16_4_7_1 = (((dis2_opcode >> 7) & 0x1)<<0) | (((dis2_opcode >> 16) & 0xf)<<1);
	dis2_theargs.dis2_argf_16_6 = (((dis2_opcode >> 16) & 0x3f)<<0);
	dis2_theargs.dis2_argf_18_1 = (((dis2_opcode >> 18) & 0x1)<<0);
	dis2_theargs.dis2_argf_18_2 = (((dis2_opcode >> 18) & 0x3)<<0);
	dis2_theargs.dis2_argf_19_3 = (((dis2_opcode >> 19) & 0x7)<<0);
	dis2_theargs.dis2_argf_20_1 = (((dis2_opcode >> 20) & 0x1)<<0);
	dis2_theargs.dis2_argf_20_2 = (((dis2_opcode >> 20) & 0x3)<<0);
	dis2_theargs.dis2_argf_21_1 = (((dis2_opcode >> 21) & 0x1)<<0);
	dis2_theargs.dis2_argf_21_2 = (((dis2_opcode >> 21) & 0x3)<<0);
	dis2_theargs.dis2_argf_22_1 = (((dis2_opcode >> 22) & 0x1)<<0);
	dis2_theargs.dis2_argf_22_1_12_4 = (((dis2_opcode >> 12) & 0xf)<<0) | (((dis2_opcode >> 22) & 0x1)<<4);
	dis2_theargs.dis2_argf_23_1 = (((dis2_opcode >> 23) & 0x1)<<0);
	dis2_theargs.dis2_argf_24_1 = (((dis2_opcode >> 24) & 0x1)<<0);
	dis2_theargs.dis2_argf_24_1_16_3_0_4 = (((dis2_opcode >> 0) & 0xf)<<0) | (((dis2_opcode >> 16) & 0x7)<<4) | (((dis2_opcode >> 24) & 0x1)<<7);
	dis2_theargs.dis2_argf_28_4 = (((dis2_opcode >> 28) & 0xf)<<0);
	dis2_theargs.dis2_argf_4_1 = (((dis2_opcode >> 4) & 0x1)<<0);
	dis2_theargs.dis2_argf_4_2 = (((dis2_opcode >> 4) & 0x3)<<0);
	dis2_theargs.dis2_argf_4_4 = (((dis2_opcode >> 4) & 0xf)<<0);
	dis2_theargs.dis2_argf_5_1 = (((dis2_opcode >> 5) & 0x1)<<0);
	dis2_theargs.dis2_argf_5_1_0_4 = (((dis2_opcode >> 0) & 0xf)<<0) | (((dis2_opcode >> 5) & 0x1)<<4);
	dis2_theargs.dis2_argf_5_2 = (((dis2_opcode >> 5) & 0x3)<<0);
	dis2_theargs.dis2_argf_6_1 = (((dis2_opcode >> 6) & 0x1)<<0);
	dis2_theargs.dis2_argf_6_2 = (((dis2_opcode >> 6) & 0x3)<<0);
	dis2_theargs.dis2_argf_7_1 = (((dis2_opcode >> 7) & 0x1)<<0);
	dis2_theargs.dis2_argf_7_1_16_4 = (((dis2_opcode >> 16) & 0xf)<<0) | (((dis2_opcode >> 7) & 0x1)<<4);
	dis2_theargs.dis2_argf_7_2 = (((dis2_opcode >> 7) & 0x3)<<0);
	dis2_theargs.dis2_argf_7_3 = (((dis2_opcode >> 7) & 0x7)<<0);
	dis2_theargs.dis2_argf_8_1 = (((dis2_opcode >> 8) & 0x1)<<0);
	dis2_theargs.dis2_argf_8_1_24_1 = (((dis2_opcode >> 24) & 0x1)<<0) | (((dis2_opcode >> 8) & 0x1)<<1);
	dis2_theargs.dis2_argf_8_2 = (((dis2_opcode >> 8) & 0x3)<<0);
	dis2_theargs.dis2_argf_8_4 = (((dis2_opcode >> 8) & 0xf)<<0);
	dis2_theargs.dis2_argf_9_1 = (((dis2_opcode >> 9) & 0x1)<<0);
	dis2_theargs.dis2_argn_100_0 = ((dis2_opcode & 0x100) ^ 0x0);
	dis2_theargs.dis2_argn_2f_0 = ((dis2_opcode & 0x2f) ^ 0x0);
	dis2_theargs.dis2_argn_6f_0 = ((dis2_opcode & 0x6f) ^ 0x0);
	dis2_theargs.dis2_argn_a0_0 = ((dis2_opcode & 0xa0) ^ 0x0);
	dis2_theargs.dis2_argn_ef_0 = ((dis2_opcode & 0xef) ^ 0x0);
	dis2_theargs.dis2_argn_f_0 = ((dis2_opcode & 0xf) ^ 0x0);
	dis2_args = &dis2_theargs;
	uint32_t dis2_nodeid = 608;
	while(dis2_nodeid >= 191) {
		if(dis2_nodeid >= 608) {
			/* Mask node */
			uint32_t dis2_bitoffset = (dis2_nodeid-608)*7;
			uint32_t dis2_startbit = dis2_readbits(dis2_masknodes,dis2_bitoffset,5); dis2_bitoffset += 5;
			uint32_t dis2_bitcount = dis2_readbits(dis2_masknodes,dis2_bitoffset,2)+1; dis2_bitoffset += 2;
			dis2_bitoffset += 14*((dis2_opcode>>dis2_startbit) & ((((uint32_t)1)<<dis2_bitcount)-1));
			dis2_nodeid = dis2_readbits(dis2_masknodes,dis2_bitoffset,14);
		} else {
			/* Constraint node */
			uint32_t dis2_bitoffset = (dis2_nodeid-191)*37;
			uint32_t dis2_constraint = dis2_readbits(dis2_constraintnodes,dis2_bitoffset,9); dis2_bitoffset += 9;
			if(dis2_evalconstraint(dis2_opcode,dis2_constraint) == 0) dis2_bitoffset += 14;
			dis2_nodeid = dis2_readbits(dis2_constraintnodes,dis2_bitoffset,14);
		}
	}
	(dis2_leaves[dis2_nodeid])(PARAMS PARAMSCOMMA dis2_args);
}
