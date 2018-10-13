/*
 * Copyright (c) 2014, RISC OS Open Ltd
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#include "classify.h"

/* This file has the generated disassembler source appended to it */
static inline RETURNTYPE classify_mask_0_0_9_3_0x844d8(PARAMDECL);
static RETURNTYPE classify_leaf_UNDEFINED_0x84238(PARAMDECL);
static inline RETURNTYPE classify_mask_a00_e00_25_3_0x9a198(PARAMDECL);
static inline RETURNTYPE classify_mask_c000a00_e000e00_22_3_0x8cbd8(PARAMDECL);
static inline RETURNTYPE classify_constraint_0_0_1a00000_0xb0538(PARAMDECL);
static inline RETURNTYPE classify_constraint_0_0_f0000000_0x8f7b8(PARAMDECL);
static inline RETURNTYPE classify_constraint_0_0_f0_0x9bde8(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_6_3_0xa5a48(PARAMDECL);
static inline RETURNTYPE classify_leaf_VMOV_2fp_A1_0x9a608(PARAMDECL);
static inline RETURNTYPE classify_leaf_VMOV_dbl_A1_0xa68e0(PARAMDECL);
#ifndef classify_func_lnot
#define classify_func_lnot(X) !(X)
#endif
#ifndef classify_func_band
#define classify_func_band(X,Y) (X)&(Y)
#endif
#ifndef classify_func_ne
#define classify_func_ne(X,Y) (X)!=(Y)
#endif
#ifndef classify_func_lor
#define classify_func_lor(X,Y) (X)||(Y)
#endif
static RETURNTYPE classify_constraint_c800a00_fc00e00_f0000000_0x9a7f8(PARAMDECL);
static inline RETURNTYPE classify_mask_c800a00_fc00e00_8_1_0x8b6c0(PARAMDECL);
static inline RETURNTYPE classify_constraint_c800a00_fc00f00_1af0000_0xa5560(PARAMDECL);
static RETURNTYPE classify_leaf_VLDM_A2_0xa8ff8(PARAMDECL);
static inline RETURNTYPE classify_mask_c800a00_fc00f00_18_3_0xa2ae8(PARAMDECL);
static RETURNTYPE classify_leaf_VPOP_A2_0x8b868(PARAMDECL);
#ifndef classify_func_land
#define classify_func_land(X,Y) (X)&&(Y)
#endif
#ifndef classify_func_eq
#define classify_func_eq(X,Y) (X)==(Y)
#endif
static inline RETURNTYPE classify_constraint_c800b00_fc00f00_1af0000_0x8f5b8(PARAMDECL);
static RETURNTYPE classify_leaf_VLDM_A1_0x8db00(PARAMDECL);
static inline RETURNTYPE classify_mask_c800b00_fc00f00_18_3_0x8d078(PARAMDECL);
static RETURNTYPE classify_leaf_VPOP_A1_0x8e1e8(PARAMDECL);
static RETURNTYPE classify_constraint_d000a00_fc00e00_f0000000_0xb00f8(PARAMDECL);
static inline RETURNTYPE classify_mask_d000a00_fc00e00_19_3_0xb0250(PARAMDECL);
static RETURNTYPE classify_mask_d000a00_ff80e00_8_1_0xb03d0(PARAMDECL);
static inline RETURNTYPE classify_leaf_VLDR_A2_0xb0448(PARAMDECL);
static inline RETURNTYPE classify_leaf_VLDR_A1_0xb04c0(PARAMDECL);
static RETURNTYPE classify_mask_d200a00_ff80e00_8_1_0xb0970(PARAMDECL);
static inline RETURNTYPE classify_constraint_d280a00_ff80e00_1af0000_0xb0ad8(PARAMDECL);
static inline RETURNTYPE classify_mask_d280a00_ff80e00_8_1_0xb0cb8(PARAMDECL);
static RETURNTYPE classify_constraint_d800a00_fc00e00_f0000000_0xb08d0(PARAMDECL);
static inline RETURNTYPE classify_constraint_d800a00_fc00e00_200000_0xb1348(PARAMDECL);
static inline RETURNTYPE classify_constraint_0_0_f0000000_0xa97d0(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_22_3_0xb42d0(PARAMDECL);
static inline RETURNTYPE classify_mask_e000a00_fc00e00_4_3_0x8d0f0(PARAMDECL);
static RETURNTYPE classify_leaf_VADD_fp_A2_0x9b610(PARAMDECL);
static RETURNTYPE classify_constraint_e000a10_fc00e70_100_0xa60f8(PARAMDECL);
static RETURNTYPE classify_constraint_e000a10_fc00e70_e00000_0x811a8(PARAMDECL);
static inline RETURNTYPE classify_leaf_VMOV_1fp_A1_0xa9848(PARAMDECL);
static RETURNTYPE classify_mask_e000a10_fc00e70_20_1_0xb0d30(PARAMDECL);
static inline RETURNTYPE classify_leaf_VMOV_arm_A1_0xb0e60(PARAMDECL);
static RETURNTYPE classify_leaf_VMOV_scalar_A1_0xb0ed8(PARAMDECL);
static inline RETURNTYPE classify_constraint_e000a50_fc00e70_100_0xb14b0(PARAMDECL);
static inline RETURNTYPE classify_mask_e400a00_fc00e00_4_1_0xb0640(PARAMDECL);
static inline RETURNTYPE classify_constraint_e400a10_fc00e70_100_0xb13c0(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_19_3_0xa27f8(PARAMDECL);
static RETURNTYPE classify_mask_e800a00_ff80e00_4_3_0xb1df0(PARAMDECL);
static RETURNTYPE classify_leaf_VDIV_A1_0xb1f70(PARAMDECL);
static RETURNTYPE classify_mask_e900a00_ff80e00_4_2_0xb2580(PARAMDECL);
static RETURNTYPE classify_leaf_VFMA_VFMS_A2_0xb2700(PARAMDECL);
static RETURNTYPE classify_constraint_e900a30_ff80e70_100_0xb2868(PARAMDECL);
static RETURNTYPE classify_mask_ea00a00_ff80e00_4_1_0xb2ef0(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_4_3_0xb3c38(PARAMDECL);
static RETURNTYPE classify_leaf_VMOV_imm_A2_0xb3800(PARAMDECL);
static RETURNTYPE classify_mask_0_0_16_3_0xb44b0(PARAMDECL);
static RETURNTYPE classify_leaf_VABS_A2_0xb3f88(PARAMDECL);
static inline RETURNTYPE classify_mask_eb10a40_fff0e70_7_1_0xb40f0(PARAMDECL);
static inline RETURNTYPE classify_leaf_VSQRT_A1_0xb41e0(PARAMDECL);
static RETURNTYPE classify_leaf_VCVTB_VCVTT_hp_sp_VFP_A1_0xb4348(PARAMDECL);
static inline RETURNTYPE classify_leaf_VCMP_VCMPE_A2_0xb4780(PARAMDECL);
static inline RETURNTYPE classify_constraint_eb70a40_fff0e70_c0_0xb4960(PARAMDECL);
static inline RETURNTYPE classify_leaf_VCVT_dp_sp_A1_0xb4a50(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_4_3_0x8fa20(PARAMDECL);
static RETURNTYPE classify_mask_eb80a40_ff80e70_16_3_0xb4c98(PARAMDECL);
static RETURNTYPE classify_leaf_VCVT_VCVTR_fp_int_VFP_A1_0xb4e18(PARAMDECL);
static RETURNTYPE classify_leaf_VCVT_fp_fx_VFP_A1_0xb4f08(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_19_3_0xa9ad8(PARAMDECL);
static RETURNTYPE classify_mask_ed00a00_ff80e00_4_1_0xb23e8(PARAMDECL);
static RETURNTYPE classify_mask_ee00a00_ff80e00_4_3_0xb53c0(PARAMDECL);
static RETURNTYPE classify_leaf_VMSR_A1_0xb55b8(PARAMDECL);
static RETURNTYPE classify_constraint_ee00a50_ff80e70_100_0xb5798(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_4_3_0xb3bc0(PARAMDECL);
static RETURNTYPE classify_mask_ef00a10_ff80e70_8_1_0xb60b0(PARAMDECL);
static inline RETURNTYPE classify_leaf_VMRS_A1_0xb6128(PARAMDECL);
static inline RETURNTYPE classify_mask_0_0_4_3_0xb5540(PARAMDECL);
RETURNTYPE classify_leaf_UNDEFINED_0x84238(PARAMDECL)
{ /* (cond:4)0000(op:4)(:12)1001(:4) {ne(cond,0xf)} {lor(eq(op,0x5),eq(op,0x7))} UNDEFINED
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
     (cond:4)1110(opc1:4)(opc2:4)(:4)101(:1)(opc3:2)(:1)0(opc4:4) {ne(cond,0xf)} {eq(band(opc1,0xb),0xb)} {eq(opc3,0x1)} {eq(opc2,0x7)} UNDEFINED_CDP_CDP2_A1 (as UNDEFINED)
     (cond:4)1110(opc1:4)(opc2:4)(:4)101(:1)(opc3:2)(:1)0(opc4:4) {ne(cond,0xf)} {eq(band(opc1,0xb),0xb)} {band(opc3,0x1)} {eq(opc2,0x6)} UNDEFINED_CDP_CDP2_A1 (as UNDEFINED)
     (cond:4)1110(opc1:4)(opc2:4)(:4)101(:1)(opc3:2)(:1)0(opc4:4) {ne(cond,0xf)} {eq(band(opc1,0xb),0x8)} {band(opc3,0x1)} UNDEFINED_CDP_CDP2_A1 (as UNDEFINED)
     11110100A(:1)L0(:8)(B:4)(:8) UNDEFINED
     1111001U(A:5)(:7)(B:4)(C:4)(:4) UNDEFINED
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
     (cond:4)110PUDW0(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {ne(coproc,0xa)} {ne(coproc,0xb)} STC_STC2_A1 (as UNDEFINED)
     (cond:4)11000000(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} UNDEFINED
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
     (cond:4)11000101(Rt2:4)(Rt:4)(coproc:4)(opc1:4)(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} MRRC_MRRC2_A1 (as UNDEFINED)
     11111110(opc1:3)1(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) MRC_MRC2_A2 (as UNDEFINED)
     (cond:4)1110(opc1:3)1(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} MRC_MRC2_A1 (as UNDEFINED)
     (cond:4)00110100(imm4:4)(Rd:4)(imm12:12) {ne(cond,0xf)} MOVT_A1 (as UNDEFINED)
     (cond:4)0001101S(0000)(Rd:4)00000000(Rm:4) {ne(cond,0xf)} MOV_reg_A1 (as UNDEFINED)
     (cond:4)00110000(imm4:4)(Rd:4)(imm12:12) {ne(cond,0xf)} MOV_imm_A2 (as UNDEFINED)
     (cond:4)0011101S(0000)(Rd:4)(imm12:12) {ne(cond,0xf)} MOV_imm_A1 (as UNDEFINED)
     (cond:4)00000110(Rd:4)(Ra:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} MLS_A1 (as UNDEFINED)
     (cond:4)0000001S(Rd:4)(Ra:4)(Rm:4)1001(Rn:4) {ne(cond,0xf)} MLA_A1 (as UNDEFINED)
     111111000100(Rt2:4)(Rt:4)(coproc:4)(opc1:4)(CRm:4) MCRR_MCRR2_A2 (as UNDEFINED)
     (cond:4)11000100(Rt2:4)(Rt:4)(coproc:4)(opc1:4)(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} MCRR_MCRR2_A1 (as UNDEFINED)
     11111110(opc1:3)0(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) MCR_MCR2_A2 (as UNDEFINED)
     (cond:4)1110(opc1:3)0(CRn:4)(Rt:4)(coproc:4)(opc2:3)1(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} MCR_MCR2_A1 (as UNDEFINED)
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
     (cond:4)110PUDW11111(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {lor(lor(P,U),W)} LDC_LDC2_lit_A1 (as UNDEFINED)
     (cond:4)110000011111(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} UNDEFINED
     1111110PUDW1(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(Rn,0xf)} {lor(lor(P,U),W)} LDC_LDC2_imm_A2 (as UNDEFINED)
     111111000001(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(Rn,0xf)} UNDEFINED
     (cond:4)110PUDW1(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(Rn,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} {lor(lor(P,U),W)} LDC_LDC2_imm_A1 (as UNDEFINED)
     (cond:4)11000001(Rn:4)(CRd:4)(coproc:4)(imm8:8) {ne(cond,0xf)} {ne(Rn,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} UNDEFINED
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
     11111110(opc1:4)(CRn:4)(CRd:4)(coproc:4)(opc2:3)0(CRm:4) CDP_CDP2_A2 (as UNDEFINED)
     (cond:4)1110(opc1:4)(CRn:4)(CRd:4)(coproc:4)(opc2:3)0(CRm:4) {ne(cond,0xf)} {ne(coproc,0xa)} {ne(coproc,0xb)} CDP_CDP2_A1 (as UNDEFINED)
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
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x63),0x63)} {lnot(band(op2,0x1))} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x61),0x61)} {band(op2,0x1)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x61),0x60)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x61)} {lnot(band(op2,0x1))} UNALLOCATED_MEM_HINT
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x63),0x43)} {ne(op1,0x57)} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(op1,0x57)} {ne(op2,0x1)} {lor(lt(op2,0x4),gt(op2,0x6))} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {ge(band(op1,0x77),0x52)} {le(band(op1,0x77),0x56)} {lnot(band(op1,0x1))} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x51)} {eq(Rn,0xf)} UNPREDICTABLE
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x50)} UNDEFINED
     11110(op1:7)(Rn:4)(:8)(op2:4)(:4) {eq(band(op1,0x77),0x41)} UNALLOCATED_MEM_HINT
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
     (cond:4)011(op1:5)(:4)(Rd:4)(:4)(op2:3)1(Rn:4) {lt(cond,0xe)} {eq(op1,0x1f)} {eq(op2,0x7)} PERMA_UNDEFINED
     (cond:4)00010(op:2)0(op1:4)(:8)0(op2:3)(:4) {ne(cond,0xf)} {eq(op2,0x6)} {ne(op,0x3)} UNDEFINED
     (cond:4)00010(op:2)0(op1:4)(:8)0(op2:3)(:4) {ne(cond,0xf)} {eq(band(op2,0x6),0x2)} {ne(op,0x1)} UNDEFINED
     (cond:4)00010(op:2)0(op1:4)(:8)0(op2:3)(:4) {ne(cond,0xf)} {eq(op2,0x1)} {lnot(band(op,0x1))} UNDEFINED
     (cond:4)00110(op)10(op1:4)(:8)(op2:8) {ne(cond,0xf)} {lnot(op)} {lnot(op1)} {gt(op2,0x5)} {lt(op2,0xf0)} UNALLOCATED_HINT
     (cond:4)0001(op:4)(:12)1001(:4) {ne(cond,0xf)} {lt(op,0x8)} {band(op,0x3)} UNDEFINED
     (cond:4)0000(:2)1(op)(:4)(Rt:4)(:4)1(op2:2)1(:4) {ne(cond,0xf)} {band(op2,0x2)} {lnot(op)} {band(Rt,0x1)} UNDEFINED
     (cond:4)0000(:2)1(op)(:4)(Rt:4)(:4)1(op2:2)1(:4) {ne(cond,0xf)} {band(op2,0x2)} {lnot(op)} {lnot(band(Rt,0x1))} UNPREDICTABLE */
	(void) OPCODE;
	return CLASS_NOT_VFP;
}
RETURNTYPE classify_constraint_0_0_1a00000_0xb0538(PARAMDECL)
{
	if(classify_func_lor(classify_func_lor(((OPCODE >> 24) & 0x1),((OPCODE >> 23) & 0x1)),((OPCODE >> 21) & 0x1)))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_constraint_0_0_f0000000_0x8f7b8(PARAMS);
	}
}
RETURNTYPE classify_constraint_0_0_f0000000_0x8f7b8(PARAMDECL)
{
	if(classify_func_ne(((OPCODE >> 28) & 0xf),0xf))
	{
		return classify_constraint_0_0_f0_0x9bde8(PARAMS);
	}
	else
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_constraint_0_0_f0_0x9bde8(PARAMDECL)
{
	if(classify_func_lnot(classify_func_band(((OPCODE >> 4) & 0xf),0xd)))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_mask_0_0_6_3_0xa5a48(PARAMS);
	}
}
RETURNTYPE classify_leaf_VMOV_2fp_A1_0x9a608(PARAMDECL)
{ /* (cond:4)1100010(op)(Rt2:4)(Rt:4)101000M1(Vm:4) {ne(cond,0xf)} VMOV_2fp_A1 */
	const uint32_t Vm_M = (((OPCODE >> 5) & 0x1)<<0) | (((OPCODE >> 0) & 0xf)<<1);
	const uint32_t Rt = (((OPCODE >> 12) & 0xf)<<0);
	const uint32_t Rt2 = (((OPCODE >> 16) & 0xf)<<0);
	const uint32_t op = (((OPCODE >> 20) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	_UNPREDICTABLE((Rt==15) || (Rt2==15) || (Vm_M==31));
	if(op)
	{
		_UNPREDICTABLE(Rt==Rt2);
	}
	return class;
}
RETURNTYPE classify_leaf_VMOV_dbl_A1_0xa68e0(PARAMDECL)
{ /* (cond:4)1100010(op)(Rt2:4)(Rt:4)101100M1(Vm:4) {ne(cond,0xf)} VMOV_dbl_A1 */
	const uint32_t Rt = (((OPCODE >> 12) & 0xf)<<0);
	const uint32_t Rt2 = (((OPCODE >> 16) & 0xf)<<0);
	const uint32_t op = (((OPCODE >> 20) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	_UNPREDICTABLE((Rt==15) || (Rt2==15));
	if(op)
	{
		_UNPREDICTABLE(Rt==Rt2);
	}
	if(M)
		class |= CLASS_D32;
	return class;
}
RETURNTYPE classify_mask_0_0_6_3_0xa5a48(PARAMDECL)
{
	/* 0x0 -> 0x9a608 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0x84238 */
	/* 0x3 -> 0x84238 */
	/* 0x4 -> 0xa68e0 */
	/* 0x5 -> 0x84238 */
	/* 0x6 -> 0x84238 */
	/* 0x7 -> 0x84238 */
	static const uint32_t classify_cases = 0x5654;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x1c0)>>5)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0x9a608 */
		return classify_leaf_VMOV_2fp_A1_0x9a608(PARAMS);
	case 0x1:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	default:
	/* 0xa68e0 */
		return classify_leaf_VMOV_dbl_A1_0xa68e0(PARAMS);
	}
}
RETURNTYPE classify_constraint_c800a00_fc00e00_f0000000_0x9a7f8(PARAMDECL)
{
	if(classify_func_ne(((OPCODE >> 28) & 0xf),0xf))
	{
		return classify_mask_c800a00_fc00e00_8_1_0x8b6c0(PARAMS);
	}
	else
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_constraint_c800a00_fc00f00_1af0000_0xa5560(PARAMDECL)
{
	if(classify_func_lnot(classify_func_land(classify_func_land(classify_func_lnot(((OPCODE >> 24) & 0x1)),((OPCODE >> 23) & 0x1)),classify_func_land(((OPCODE >> 21) & 0x1),classify_func_eq(((OPCODE >> 16) & 0xf),0xd)))))
	{
		return classify_leaf_VLDM_A2_0xa8ff8(PARAMS);
	}
	else
	{
		return classify_mask_c800a00_fc00f00_18_3_0xa2ae8(PARAMS);
	}
}
RETURNTYPE classify_leaf_VLDM_A2_0xa8ff8(PARAMDECL)
{ /* (cond:4)110PUDW1(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(lnot(P),U),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(land(ne(Rn,0xf),W),eq(P,U)))} {lnot(land(land(W,eq(P,U)),eq(Rn,0xf)))} VLDM_A2
     (cond:4)110PUDW0(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(P,lnot(U)),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(W,eq(P,U)))} VSTM_A2 */
	const uint32_t imm8 = (((OPCODE >> 0) & 0xff)<<0);
	const uint32_t Vd_D = (((OPCODE >> 22) & 0x1)<<0) | (((OPCODE >> 12) & 0xf)<<1);
	const uint32_t Rn = (((OPCODE >> 16) & 0xf)<<0);
	const uint32_t W = (((OPCODE >> 21) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	uint32_t regs = imm8;
	_UNPREDICTABLE((Rn==15) && W);
	_UNPREDICTABLE(!regs || ((Vd_D+regs) > 32));
	return class;
}
RETURNTYPE classify_leaf_VPOP_A2_0x8b868(PARAMDECL)
{ /* (cond:4)11001D111101(Vd:4)1010(imm8:8) {ne(cond,0xf)} VPOP_A2
     (cond:4)11010D101101(Vd:4)1010(imm8:8) {ne(cond,0xf)} VPUSH_A2 */
	const uint32_t imm8 = (((OPCODE >> 0) & 0xff)<<0);
	const uint32_t Vd_D = (((OPCODE >> 22) & 0x1)<<0) | (((OPCODE >> 12) & 0xf)<<1);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	uint32_t regs = imm8;
	_UNPREDICTABLE(!regs || ((Vd_D+regs) > 32));
	return class;
}
RETURNTYPE classify_mask_c800a00_fc00f00_18_3_0xa2ae8(PARAMDECL)
{
	/* 0x0 -> 0x0 */
	/* 0x1 -> 0x0 */
	/* 0x2 -> 0x0 */
	/* 0x3 -> 0xa8ff8 */
	/* 0x4 -> 0x0 */
	/* 0x5 -> 0x0 */
	/* 0x6 -> 0x0 */
	/* 0x7 -> 0x8b868 */
	if((OPCODE & 0x1c0000)==0x1c0000)
	{ /* 0x8b868 */
		return classify_leaf_VPOP_A2_0x8b868(PARAMS);
	}
	else
	{ /* 0xa8ff8 */
		return classify_leaf_VLDM_A2_0xa8ff8(PARAMS);
	}
}
RETURNTYPE classify_constraint_c800b00_fc00f00_1af0000_0x8f5b8(PARAMDECL)
{
	if(classify_func_lnot(classify_func_land(classify_func_land(classify_func_lnot(((OPCODE >> 24) & 0x1)),((OPCODE >> 23) & 0x1)),classify_func_land(((OPCODE >> 21) & 0x1),classify_func_eq(((OPCODE >> 16) & 0xf),0xd)))))
	{
		return classify_leaf_VLDM_A1_0x8db00(PARAMS);
	}
	else
	{
		return classify_mask_c800b00_fc00f00_18_3_0x8d078(PARAMS);
	}
}
RETURNTYPE classify_leaf_VLDM_A1_0x8db00(PARAMDECL)
{ /* (cond:4)110PUDW1(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(lnot(P),U),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(land(ne(Rn,0xf),W),eq(P,U)))} {lnot(land(land(W,eq(P,U)),eq(Rn,0xf)))} VLDM_A1
     (cond:4)110PUDW0(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} {lor(lor(P,U),W)} {lnot(land(land(P,lnot(U)),land(W,eq(Rn,0xd))))} {lor(lnot(P),W)} {lnot(land(W,eq(P,U)))} VSTM_A1 */
	const uint32_t imm8 = (((OPCODE >> 0) & 0xff)<<0);
	const uint32_t Rn = (((OPCODE >> 16) & 0xf)<<0);
	const uint32_t W = (((OPCODE >> 21) & 0x1)<<0);
	const uint32_t D_Vd = (((OPCODE >> 12) & 0xf)<<0) | (((OPCODE >> 22) & 0x1)<<4);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	uint32_t regs = imm8>>1;
	_UNPREDICTABLE((Rn==15) && W);
	_UNPREDICTABLE(!regs || (regs > 16) || ((D_Vd+regs) > 32));
	if(imm8 & 1)
	{
		_UNPREDICTABLE(D_Vd+regs > 16);
	}
	if(D_Vd+regs > 16)
		class |= CLASS_D32;
	return class;
}
RETURNTYPE classify_leaf_VPOP_A1_0x8e1e8(PARAMDECL)
{ /* (cond:4)11001D111101(Vd:4)1011(imm8:8) {ne(cond,0xf)} VPOP_A1
     (cond:4)11010D101101(Vd:4)1011(imm8:8) {ne(cond,0xf)} VPUSH_A1 */
	const uint32_t imm8 = (((OPCODE >> 0) & 0xff)<<0);
	const uint32_t D_Vd = (((OPCODE >> 12) & 0xf)<<0) | (((OPCODE >> 22) & 0x1)<<4);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	uint32_t regs = imm8>>1;
	_UNPREDICTABLE(!regs || (regs > 16) || ((D_Vd+regs) > 32));
	if(imm8 & 1)
	{
		_UNPREDICTABLE(D_Vd+regs > 16);
	}
	if(D_Vd+regs > 16)
		class |= CLASS_D32;
	return class;
}
RETURNTYPE classify_mask_c800b00_fc00f00_18_3_0x8d078(PARAMDECL)
{
	/* 0x0 -> 0x0 */
	/* 0x1 -> 0x0 */
	/* 0x2 -> 0x0 */
	/* 0x3 -> 0x8db00 */
	/* 0x4 -> 0x0 */
	/* 0x5 -> 0x0 */
	/* 0x6 -> 0x0 */
	/* 0x7 -> 0x8e1e8 */
	if((OPCODE & 0x1c0000)==0x1c0000)
	{ /* 0x8e1e8 */
		return classify_leaf_VPOP_A1_0x8e1e8(PARAMS);
	}
	else
	{ /* 0x8db00 */
		return classify_leaf_VLDM_A1_0x8db00(PARAMS);
	}
}
RETURNTYPE classify_mask_c800a00_fc00e00_8_1_0x8b6c0(PARAMDECL)
{
	/* 0x0 -> 0xa5560 */
	/* 0x1 -> 0x8f5b8 */
	if(OPCODE & 0x100)
	{ /* 0x8f5b8 */
		return classify_constraint_c800b00_fc00f00_1af0000_0x8f5b8(PARAMS);
	}
	else
	{ /* 0xa5560 */
		return classify_constraint_c800a00_fc00f00_1af0000_0xa5560(PARAMS);
	}
}
RETURNTYPE classify_constraint_d000a00_fc00e00_f0000000_0xb00f8(PARAMDECL)
{
	if(classify_func_ne(((OPCODE >> 28) & 0xf),0xf))
	{
		return classify_mask_d000a00_fc00e00_19_3_0xb0250(PARAMS);
	}
	else
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_leaf_VLDR_A2_0xb0448(PARAMDECL)
{ /* (cond:4)1101UD01(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} VLDR_A2
     (cond:4)1101UD00(Rn:4)(Vd:4)1010(imm8:8) {ne(cond,0xf)} VSTR_A2 */
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	return class;
}
RETURNTYPE classify_leaf_VLDR_A1_0xb04c0(PARAMDECL)
{ /* (cond:4)1101UD01(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} VLDR_A1
     (cond:4)1101UD00(Rn:4)(Vd:4)1011(imm8:8) {ne(cond,0xf)} VSTR_A1 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_NOT_CDP)
	if(D)
		class |= CLASS_D32;
	return class;
}
RETURNTYPE classify_mask_d000a00_ff80e00_8_1_0xb03d0(PARAMDECL)
{
	/* 0x0 -> 0xb0448 */
	/* 0x1 -> 0xb04c0 */
	if(OPCODE & 0x100)
	{ /* 0xb04c0 */
		return classify_leaf_VLDR_A1_0xb04c0(PARAMS);
	}
	else
	{ /* 0xb0448 */
		return classify_leaf_VLDR_A2_0xb0448(PARAMS);
	}
}
RETURNTYPE classify_mask_d200a00_ff80e00_8_1_0xb0970(PARAMDECL)
{
	/* 0x0 -> 0xa8ff8 */
	/* 0x1 -> 0x8db00 */
	if(OPCODE & 0x100)
	{ /* 0x8db00 */
		return classify_leaf_VLDM_A1_0x8db00(PARAMS);
	}
	else
	{ /* 0xa8ff8 */
		return classify_leaf_VLDM_A2_0xa8ff8(PARAMS);
	}
}
RETURNTYPE classify_constraint_d280a00_ff80e00_1af0000_0xb0ad8(PARAMDECL)
{
	if(classify_func_lnot(classify_func_land(classify_func_land(((OPCODE >> 24) & 0x1),classify_func_lnot(((OPCODE >> 23) & 0x1))),classify_func_land(((OPCODE >> 21) & 0x1),classify_func_eq(((OPCODE >> 16) & 0xf),0xd)))))
	{
		return classify_mask_d200a00_ff80e00_8_1_0xb0970(PARAMS);
	}
	else
	{
		return classify_mask_d280a00_ff80e00_8_1_0xb0cb8(PARAMS);
	}
}
RETURNTYPE classify_mask_d280a00_ff80e00_8_1_0xb0cb8(PARAMDECL)
{
	/* 0x0 -> 0x8b868 */
	/* 0x1 -> 0x8e1e8 */
	if(OPCODE & 0x100)
	{ /* 0x8e1e8 */
		return classify_leaf_VPOP_A1_0x8e1e8(PARAMS);
	}
	else
	{ /* 0x8b868 */
		return classify_leaf_VPOP_A2_0x8b868(PARAMS);
	}
}
RETURNTYPE classify_mask_d000a00_fc00e00_19_3_0xb0250(PARAMDECL)
{
	/* 0x0 -> 0xb03d0 */
	/* 0x1 -> 0xb03d0 */
	/* 0x2 -> 0xb03d0 */
	/* 0x3 -> 0xb03d0 */
	/* 0x4 -> 0xb0970 */
	/* 0x5 -> 0xb0ad8 */
	/* 0x6 -> 0xb0970 */
	/* 0x7 -> 0xb0970 */
	static const uint32_t classify_cases = 0x5900;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x380000)>>18)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb03d0 */
		return classify_mask_d000a00_ff80e00_8_1_0xb03d0(PARAMS);
	case 0x1:
	/* 0xb0970 */
		return classify_mask_d200a00_ff80e00_8_1_0xb0970(PARAMS);
	default:
	/* 0xb0ad8 */
		return classify_constraint_d280a00_ff80e00_1af0000_0xb0ad8(PARAMS);
	}
}
RETURNTYPE classify_constraint_d800a00_fc00e00_f0000000_0xb08d0(PARAMDECL)
{
	if(classify_func_ne(((OPCODE >> 28) & 0xf),0xf))
	{
		return classify_constraint_d800a00_fc00e00_200000_0xb1348(PARAMS);
	}
	else
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_constraint_d800a00_fc00e00_200000_0xb1348(PARAMDECL)
{
	if(((OPCODE >> 21) & 0x1))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_mask_d000a00_ff80e00_8_1_0xb03d0(PARAMS);
	}
}
RETURNTYPE classify_mask_c000a00_e000e00_22_3_0x8cbd8(PARAMDECL)
{
	/* 0x0 -> 0x84238 */
	/* 0x1 -> 0xb0538 */
	/* 0x2 -> 0x9a7f8 */
	/* 0x3 -> 0x9a7f8 */
	/* 0x4 -> 0xb00f8 */
	/* 0x5 -> 0xb00f8 */
	/* 0x6 -> 0xb08d0 */
	/* 0x7 -> 0xb08d0 */
	static const uint32_t classify_cases = 0x91b488;
	uint32_t classify_case = (classify_cases>>(((OPCODE & 0x1c00000)>>22)*3)) & 7;
	switch(classify_case)
	{
	case 0x0:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	case 0x1:
	/* 0xb0538 */
		return classify_constraint_0_0_1a00000_0xb0538(PARAMS);
	case 0x2:
	/* 0x9a7f8 */
		return classify_constraint_c800a00_fc00e00_f0000000_0x9a7f8(PARAMS);
	case 0x3:
	/* 0xb00f8 */
		return classify_constraint_d000a00_fc00e00_f0000000_0xb00f8(PARAMS);
	default:
	/* 0xb08d0 */
		return classify_constraint_d800a00_fc00e00_f0000000_0xb08d0(PARAMS);
	}
}
RETURNTYPE classify_constraint_0_0_f0000000_0xa97d0(PARAMDECL)
{
	if(classify_func_ne(((OPCODE >> 28) & 0xf),0xf))
	{
		return classify_mask_0_0_22_3_0xb42d0(PARAMS);
	}
	else
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_leaf_VADD_fp_A2_0x9b610(PARAMDECL)
{ /* (cond:4)11100D11(Vn:4)(Vd:4)101(sz)N0M0(Vm:4) {ne(cond,0xf)} VADD_fp_A2
     (cond:4)11100D11(Vn:4)(Vd:4)101(sz)N1M0(Vm:4) {ne(cond,0xf)} VSUB_fp_A2
     (cond:4)11100D10(Vn:4)(Vd:4)101(sz)N1M0(Vm:4) {ne(cond,0xf)} VNMLA_VNMLS_VNMUL_A2
     (cond:4)11100D01(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VNMLA_VNMLS_VNMUL_A1
     (cond:4)11100D10(Vn:4)(Vd:4)101(sz)N0M0(Vm:4) {ne(cond,0xf)} VMUL_fp_A2
     (cond:4)11100D00(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VMLA_VMLS_fp_A2 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t N = (((OPCODE >> 7) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_sz_nonstandard(0)
	D32_CHECK(sz,D)
	D32_CHECK(sz,N)
	D32_CHECK(sz,M)
	return class;
}
RETURNTYPE classify_constraint_e000a10_fc00e70_100_0xa60f8(PARAMDECL)
{
	if(classify_func_lnot(((OPCODE >> 8) & 0x1)))
	{
		return classify_constraint_e000a10_fc00e70_e00000_0x811a8(PARAMS);
	}
	else
	{
		return classify_mask_e000a10_fc00e70_20_1_0xb0d30(PARAMS);
	}
}
RETURNTYPE classify_constraint_e000a10_fc00e70_e00000_0x811a8(PARAMDECL)
{
	if(((OPCODE >> 21) & 0x7))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_leaf_VMOV_1fp_A1_0xa9848(PARAMS);
	}
}
RETURNTYPE classify_leaf_VMOV_1fp_A1_0xa9848(PARAMDECL)
{ /* (cond:4)1110000(op)(Vn:4)(Rt:4)1010N(00)1(0000) {ne(cond,0xf)} VMOV_1fp_A1 */
	const uint32_t Rt = (((OPCODE >> 12) & 0xf)<<0);
	const uint32_t nonstandard = ((OPCODE & 0x6f) ^ 0x0);
	COMMON_nonstandard(CLASS_NOT_CDP)
	_UNPREDICTABLE(Rt==15);
	return class;
}
RETURNTYPE classify_leaf_VMOV_arm_A1_0xb0e60(PARAMDECL)
{ /* (cond:4)11100(opc1:2)0(Vd:4)(Rt:4)1011D(opc2:2)1(0000) {ne(cond,0xf)} {lnot(land(eq(opc2,0x2),lnot(band(opc1,0x2))))} VMOV_arm_A1 */
	const uint32_t Rt = (((OPCODE >> 12) & 0xf)<<0);
	const uint32_t opc1 = (((OPCODE >> 21) & 0x3)<<0);
	const uint32_t opc2 = (((OPCODE >> 5) & 0x3)<<0);
	const uint32_t D = (((OPCODE >> 7) & 0x1)<<0);
	const uint32_t nonstandard = ((OPCODE & 0xf) ^ 0x0);
	int class = CLASS_NOT_CDP;
	if(nonstandard || (opc1 & 2) || (opc2 & 3))
		return CLASS_NOT_VFP;
	if(D)
		class |= CLASS_D32;
	_UNPREDICTABLE(Rt==15);
	return class;
}
RETURNTYPE classify_leaf_VMOV_scalar_A1_0xb0ed8(PARAMDECL)
{ /* (cond:4)1110U(opc1:2)1(Vn:4)(Rt:4)1011N(opc2:2)1(0000) {ne(cond,0xf)} {lnot(land(lor(land(U,lnot(opc2)),eq(opc2,0x2)),lnot(band(opc1,0x2))))} VMOV_scalar_A1 */
	const uint32_t Rt = (((OPCODE >> 12) & 0xf)<<0);
	const uint32_t opc1 = (((OPCODE >> 21) & 0x3)<<0);
	const uint32_t U = (((OPCODE >> 23) & 0x1)<<0);
	const uint32_t opc2 = (((OPCODE >> 5) & 0x3)<<0);
	const uint32_t N = (((OPCODE >> 7) & 0x1)<<0);
	const uint32_t nonstandard = ((OPCODE & 0xf) ^ 0x0);
	int class = CLASS_NOT_CDP;
	if(nonstandard || U || (opc1 & 2) || (opc2 & 3))
		return CLASS_NOT_VFP;
	if(N)
		class |= CLASS_D32;
	_UNPREDICTABLE(Rt==15);
	return class;
}
RETURNTYPE classify_mask_e000a10_fc00e70_20_1_0xb0d30(PARAMDECL)
{
	/* 0x0 -> 0xb0e60 */
	/* 0x1 -> 0xb0ed8 */
	if(OPCODE & 0x100000)
	{ /* 0xb0ed8 */
		return classify_leaf_VMOV_scalar_A1_0xb0ed8(PARAMS);
	}
	else
	{ /* 0xb0e60 */
		return classify_leaf_VMOV_arm_A1_0xb0e60(PARAMS);
	}
}
RETURNTYPE classify_constraint_e000a50_fc00e70_100_0xb14b0(PARAMDECL)
{
	if(classify_func_lnot(((OPCODE >> 8) & 0x1)))
	{
		return classify_constraint_e000a10_fc00e70_e00000_0x811a8(PARAMS);
	}
	else
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_mask_e000a00_fc00e00_4_3_0x8d0f0(PARAMDECL)
{
	/* 0x0 -> 0x9b610 */
	/* 0x1 -> 0xa60f8 */
	/* 0x2 -> 0x9b610 */
	/* 0x3 -> 0xa60f8 */
	/* 0x4 -> 0x9b610 */
	/* 0x5 -> 0xb14b0 */
	/* 0x6 -> 0x9b610 */
	/* 0x7 -> 0xa60f8 */
	static const uint32_t classify_cases = 0x4844;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70)>>3)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0x9b610 */
		return classify_leaf_VADD_fp_A2_0x9b610(PARAMS);
	case 0x1:
	/* 0xa60f8 */
		return classify_constraint_e000a10_fc00e70_100_0xa60f8(PARAMS);
	default:
	/* 0xb14b0 */
		return classify_constraint_e000a50_fc00e70_100_0xb14b0(PARAMS);
	}
}
RETURNTYPE classify_constraint_e400a10_fc00e70_100_0xb13c0(PARAMDECL)
{
	if(classify_func_lnot(((OPCODE >> 8) & 0x1)))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_mask_e000a10_fc00e70_20_1_0xb0d30(PARAMS);
	}
}
RETURNTYPE classify_mask_e400a00_fc00e00_4_1_0xb0640(PARAMDECL)
{
	/* 0x0 -> 0x9b610 */
	/* 0x1 -> 0xb13c0 */
	if(OPCODE & 0x10)
	{ /* 0xb13c0 */
		return classify_constraint_e400a10_fc00e70_100_0xb13c0(PARAMS);
	}
	else
	{ /* 0x9b610 */
		return classify_leaf_VADD_fp_A2_0x9b610(PARAMS);
	}
}
RETURNTYPE classify_leaf_VDIV_A1_0xb1f70(PARAMDECL)
{ /* (cond:4)11101D00(Vn:4)(Vd:4)101(sz)N0M0(Vm:4) {ne(cond,0xf)} VDIV_A1 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t N = (((OPCODE >> 7) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_sz_nonstandard(CLASS_DIV)
	D32_CHECK(sz,D)
	D32_CHECK(sz,N)
	D32_CHECK(sz,M)
	return class;
}
RETURNTYPE classify_mask_e800a00_ff80e00_4_3_0xb1df0(PARAMDECL)
{
	/* 0x0 -> 0xb1f70 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0xb1f70 */
	/* 0x3 -> 0x84238 */
	/* 0x4 -> 0x84238 */
	/* 0x5 -> 0x84238 */
	/* 0x6 -> 0x84238 */
	/* 0x7 -> 0x84238 */
	static const uint32_t classify_cases = 0xfa;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70)>>4)) & 1;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb1f70 */
		return classify_leaf_VDIV_A1_0xb1f70(PARAMS);
	default:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_leaf_VFMA_VFMS_A2_0xb2700(PARAMDECL)
{ /* (cond:4)11101D10(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VFMA_VFMS_A2
     (cond:4)11101D01(Vn:4)(Vd:4)101(sz)N(op)M0(Vm:4) {ne(cond,0xf)} VFNMA_VFNMS_A1 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t N = (((OPCODE >> 7) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_sz_nonstandard(CLASS_VFP4)
	D32_CHECK(sz,D)
	D32_CHECK(sz,N)
	D32_CHECK(sz,M)
	return class;
}
RETURNTYPE classify_constraint_e900a30_ff80e70_100_0xb2868(PARAMDECL)
{
	if(classify_func_lnot(((OPCODE >> 8) & 0x1)))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_leaf_VMOV_scalar_A1_0xb0ed8(PARAMS);
	}
}
RETURNTYPE classify_mask_e900a00_ff80e00_4_2_0xb2580(PARAMDECL)
{
	/* 0x0 -> 0xb2700 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0xb2700 */
	/* 0x3 -> 0xb2868 */
	static const uint32_t classify_cases = 0x84;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x30)>>3)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb2700 */
		return classify_leaf_VFMA_VFMS_A2_0xb2700(PARAMS);
	case 0x1:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	default:
	/* 0xb2868 */
		return classify_constraint_e900a30_ff80e70_100_0xb2868(PARAMS);
	}
}
RETURNTYPE classify_mask_ea00a00_ff80e00_4_1_0xb2ef0(PARAMDECL)
{
	/* 0x0 -> 0xb2700 */
	/* 0x1 -> 0x84238 */
	if(OPCODE & 0x10)
	{ /* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{ /* 0xb2700 */
		return classify_leaf_VFMA_VFMS_A2_0xb2700(PARAMS);
	}
}
RETURNTYPE classify_leaf_VMOV_imm_A2_0xb3800(PARAMDECL)
{ /* (cond:4)11101D11(imm4H:4)(Vd:4)101(sz)(0)0(0)0(imm4L:4) {ne(cond,0xf)} VMOV_imm_A2 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = ((OPCODE & 0xa0) ^ 0x0);
	COMMON_sz_nonstandard(CLASS_VFP3)
	D32_CHECK(sz,D)
	return class;
}
RETURNTYPE classify_leaf_VABS_A2_0xb3f88(PARAMDECL)
{ /* (cond:4)11101D110000(Vd:4)101(sz)11M0(Vm:4) {ne(cond,0xf)} VABS_A2
     (cond:4)11101D110001(Vd:4)101(sz)01M0(Vm:4) {ne(cond,0xf)} VNEG_A2
     (cond:4)11101D110000(Vd:4)101(sz)01M0(Vm:4) {ne(cond,0xf)} VMOV_reg_A2
     (cond:4)11101D110100(Vd:4)101(sz)E1M0(Vm:4) {ne(cond,0xf)} VCMP_VCMPE_A1 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_sz_nonstandard(0)
	D32_CHECK(sz,D)
	D32_CHECK(sz,M)
	return class;
}
RETURNTYPE classify_leaf_VSQRT_A1_0xb41e0(PARAMDECL)
{ /* (cond:4)11101D110001(Vd:4)101(sz)11M0(Vm:4) {ne(cond,0xf)} VSQRT_A1 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_sz_nonstandard(CLASS_SQRT)
	D32_CHECK(sz,D)
	D32_CHECK(sz,M)
	return class;
}
RETURNTYPE classify_mask_eb10a40_fff0e70_7_1_0xb40f0(PARAMDECL)
{
	/* 0x0 -> 0xb3f88 */
	/* 0x1 -> 0xb41e0 */
	if(OPCODE & 0x80)
	{ /* 0xb41e0 */
		return classify_leaf_VSQRT_A1_0xb41e0(PARAMS);
	}
	else
	{ /* 0xb3f88 */
		return classify_leaf_VABS_A2_0xb3f88(PARAMS);
	}
}
RETURNTYPE classify_leaf_VCVTB_VCVTT_hp_sp_VFP_A1_0xb4348(PARAMDECL)
{ /* (cond:4)11101D11001(op)(Vd:4)101(0)T1M0(Vm:4) {ne(cond,0xf)} VCVTB_VCVTT_hp_sp_VFP_A1 */
	const uint32_t nonstandard = ((OPCODE & 0x100) ^ 0x0);
	int class = CLASS_VFP3 | CLASS_HP;
	if(nonstandard)
		return CLASS_NOT_VFP;
	return class;
}
RETURNTYPE classify_leaf_VCMP_VCMPE_A2_0xb4780(PARAMDECL)
{ /* (cond:4)11101D110101(Vd:4)101(sz)E1(0)0(0000) {ne(cond,0xf)} VCMP_VCMPE_A2 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = ((OPCODE & 0x2f) ^ 0x0);
	COMMON_sz_nonstandard(0)
	D32_CHECK(sz,D)
	return class;
}
RETURNTYPE classify_constraint_eb70a40_fff0e70_c0_0xb4960(PARAMDECL)
{
	if(classify_func_eq(((OPCODE >> 6) & 0x3),0x1))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_leaf_VCVT_dp_sp_A1_0xb4a50(PARAMS);
	}
}
RETURNTYPE classify_leaf_VCVT_dp_sp_A1_0xb4a50(PARAMDECL)
{ /* (cond:4)11101D110111(Vd:4)101(sz)11M0(Vm:4) {ne(cond,0xf)} VCVT_dp_sp_A1 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_S | CLASS_D);
	D32_CHECK(sz,M)
	D32_CHECK(!sz,D)
	return class;
}
RETURNTYPE classify_mask_0_0_16_3_0xb44b0(PARAMDECL)
{
	/* 0x0 -> 0xb3f88 */
	/* 0x1 -> 0xb40f0 */
	/* 0x2 -> 0xb4348 */
	/* 0x3 -> 0xb4348 */
	/* 0x4 -> 0xb3f88 */
	/* 0x5 -> 0xb4780 */
	/* 0x6 -> 0x84238 */
	/* 0x7 -> 0xb4960 */
	static const uint32_t classify_cases = 0xb18488;
	uint32_t classify_case = (classify_cases>>(((OPCODE & 0x70000)>>16)*3)) & 7;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb3f88 */
		return classify_leaf_VABS_A2_0xb3f88(PARAMS);
	case 0x1:
	/* 0xb40f0 */
		return classify_mask_eb10a40_fff0e70_7_1_0xb40f0(PARAMS);
	case 0x2:
	/* 0xb4348 */
		return classify_leaf_VCVTB_VCVTT_hp_sp_VFP_A1_0xb4348(PARAMS);
	case 0x3:
	/* 0xb4780 */
		return classify_leaf_VCMP_VCMPE_A2_0xb4780(PARAMS);
	case 0x4:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	default:
	/* 0xb4960 */
		return classify_constraint_eb70a40_fff0e70_c0_0xb4960(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_4_3_0xb3c38(PARAMDECL)
{
	/* 0x0 -> 0xb3800 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0xb3800 */
	/* 0x3 -> 0xb2868 */
	/* 0x4 -> 0xb44b0 */
	/* 0x5 -> 0x84238 */
	/* 0x6 -> 0xb44b0 */
	/* 0x7 -> 0xb2868 */
	static const uint32_t classify_cases = 0xb784;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70)>>3)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb3800 */
		return classify_leaf_VMOV_imm_A2_0xb3800(PARAMS);
	case 0x1:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	case 0x2:
	/* 0xb2868 */
		return classify_constraint_e900a30_ff80e70_100_0xb2868(PARAMS);
	default:
	/* 0xb44b0 */
		return classify_mask_0_0_16_3_0xb44b0(PARAMS);
	}
}
RETURNTYPE classify_leaf_VCVT_VCVTR_fp_int_VFP_A1_0xb4e18(PARAMDECL)
{ /* (cond:4)11101D111(opc2:3)(Vd:4)101(sz)(op)1M0(Vm:4) {ne(cond,0xf)} {lnot(land(opc2,ne(band(opc2,0x6),0x4)))} VCVT_VCVTR_fp_int_VFP_A1 */
	const uint32_t opc2 = (((OPCODE >> 16) & 0x7)<<0);
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t M = (((OPCODE >> 5) & 0x1)<<0);
	const uint32_t sz = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_sz_nonstandard(0)
	if(!(opc2 & 4))
	{
		/* Int to float */
		D32_CHECK(sz,D);
	}
	else
	{
		/* Float to int */
		D32_CHECK(sz,M);
	}
	return class;
}
RETURNTYPE classify_leaf_VCVT_fp_fx_VFP_A1_0xb4f08(PARAMDECL)
{ /* (cond:4)11101D111(op)1U(Vd:4)101(sf)(sx)1i0(imm4:4) {ne(cond,0xf)} VCVT_fp_fx_VFP_A1 */
	const uint32_t D = (((OPCODE >> 22) & 0x1)<<0);
	const uint32_t sf = (((OPCODE >> 8) & 0x1)<<0);
	const uint32_t nonstandard = 0;
	COMMON_nonstandard(CLASS_VFP3)
	if(sf)
		class |= CLASS_D;
	else
		class |= CLASS_S;
	D32_CHECK(sf,D)
	return class;
}
RETURNTYPE classify_mask_eb80a40_ff80e70_16_3_0xb4c98(PARAMDECL)
{
	/* 0x0 -> 0xb4e18 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0xb4f08 */
	/* 0x3 -> 0xb4f08 */
	/* 0x4 -> 0xb4e18 */
	/* 0x5 -> 0xb4e18 */
	/* 0x6 -> 0xb4f08 */
	/* 0x7 -> 0xb4f08 */
	static const uint32_t classify_cases = 0xa0a4;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70000)>>15)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb4e18 */
		return classify_leaf_VCVT_VCVTR_fp_int_VFP_A1_0xb4e18(PARAMS);
	case 0x1:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	default:
	/* 0xb4f08 */
		return classify_leaf_VCVT_fp_fx_VFP_A1_0xb4f08(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_4_3_0x8fa20(PARAMDECL)
{
	/* 0x0 -> 0xb3800 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0xb3800 */
	/* 0x3 -> 0xb2868 */
	/* 0x4 -> 0xb4c98 */
	/* 0x5 -> 0x84238 */
	/* 0x6 -> 0xb4c98 */
	/* 0x7 -> 0xb2868 */
	static const uint32_t classify_cases = 0xb784;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70)>>3)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb3800 */
		return classify_leaf_VMOV_imm_A2_0xb3800(PARAMS);
	case 0x1:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	case 0x2:
	/* 0xb2868 */
		return classify_constraint_e900a30_ff80e70_100_0xb2868(PARAMS);
	default:
	/* 0xb4c98 */
		return classify_mask_eb80a40_ff80e70_16_3_0xb4c98(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_19_3_0xa27f8(PARAMDECL)
{
	/* 0x0 -> 0xb1df0 */
	/* 0x1 -> 0xb1df0 */
	/* 0x2 -> 0xb2580 */
	/* 0x3 -> 0xb2580 */
	/* 0x4 -> 0xb2ef0 */
	/* 0x5 -> 0xb2ef0 */
	/* 0x6 -> 0xb3c38 */
	/* 0x7 -> 0x8fa20 */
	static const uint32_t classify_cases = 0x8d2240;
	uint32_t classify_case = (classify_cases>>(((OPCODE & 0x380000)>>19)*3)) & 7;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb1df0 */
		return classify_mask_e800a00_ff80e00_4_3_0xb1df0(PARAMS);
	case 0x1:
	/* 0xb2580 */
		return classify_mask_e900a00_ff80e00_4_2_0xb2580(PARAMS);
	case 0x2:
	/* 0xb2ef0 */
		return classify_mask_ea00a00_ff80e00_4_1_0xb2ef0(PARAMS);
	case 0x3:
	/* 0xb3c38 */
		return classify_mask_0_0_4_3_0xb3c38(PARAMS);
	default:
	/* 0x8fa20 */
		return classify_mask_0_0_4_3_0x8fa20(PARAMS);
	}
}
RETURNTYPE classify_mask_ed00a00_ff80e00_4_1_0xb23e8(PARAMDECL)
{
	/* 0x0 -> 0xb2700 */
	/* 0x1 -> 0xb2868 */
	if(OPCODE & 0x10)
	{ /* 0xb2868 */
		return classify_constraint_e900a30_ff80e70_100_0xb2868(PARAMS);
	}
	else
	{ /* 0xb2700 */
		return classify_leaf_VFMA_VFMS_A2_0xb2700(PARAMS);
	}
}
RETURNTYPE classify_leaf_VMSR_A1_0xb55b8(PARAMDECL)
{ /* (cond:4)11101110(reg:4)(Rt:4)1010(000)1(0000) {ne(cond,0xf)} VMSR_A1 */
	const uint32_t reg = (((OPCODE >> 16) & 0xf)<<0);
	const uint32_t nonstandard = ((OPCODE & 0xef) ^ 0x0);
	COMMON_nonstandard(CLASS_NOT_CDP)
	if(!(VMSR_MASK & (1<<reg)))
		return CLASS_NOT_VFP;
	/* Follow ARMv7 rules and limit user mode to only the FPSCR register */
	if((reg != REG_FPSCR) && !privileged_mode())
		return CLASS_NOT_VFP;
	return class;
}
RETURNTYPE classify_constraint_ee00a50_ff80e70_100_0xb5798(PARAMDECL)
{
	if(((OPCODE >> 8) & 0x1))
	{
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else
	{
		return classify_leaf_VMSR_A1_0xb55b8(PARAMS);
	}
}
RETURNTYPE classify_mask_ee00a00_ff80e00_4_3_0xb53c0(PARAMDECL)
{
	/* 0x0 -> 0xb2700 */
	/* 0x1 -> 0xb55b8 */
	/* 0x2 -> 0xb2700 */
	/* 0x3 -> 0xb55b8 */
	/* 0x4 -> 0xb2700 */
	/* 0x5 -> 0xb5798 */
	/* 0x6 -> 0xb2700 */
	/* 0x7 -> 0xb5798 */
	static const uint32_t classify_cases = 0x8844;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70)>>3)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb2700 */
		return classify_leaf_VFMA_VFMS_A2_0xb2700(PARAMS);
	case 0x1:
	/* 0xb55b8 */
		return classify_leaf_VMSR_A1_0xb55b8(PARAMS);
	default:
	/* 0xb5798 */
		return classify_constraint_ee00a50_ff80e70_100_0xb5798(PARAMS);
	}
}
RETURNTYPE classify_leaf_VMRS_A1_0xb6128(PARAMDECL)
{ /* (cond:4)11101111(reg:4)(Rt:4)1010(000)1(0000) {ne(cond,0xf)} VMRS_A1 */
	const uint32_t Rt = (((OPCODE >> 12) & 0xf)<<0);
	const uint32_t reg = (((OPCODE >> 16) & 0xf)<<0);
	const uint32_t nonstandard = ((OPCODE & 0xef) ^ 0x0);
	COMMON_nonstandard(CLASS_NOT_CDP)
	_UNPREDICTABLE((Rt==15) && (reg != REG_FPSCR));
	if(!(VMRS_MASK & (1<<reg)))
		return CLASS_NOT_VFP;
	/* Follow ARMv7 rules and limit user mode to only the FPSCR register */
	if((reg != REG_FPSCR) && !privileged_mode())
		return CLASS_NOT_VFP;
	return class;
}
RETURNTYPE classify_mask_ef00a10_ff80e70_8_1_0xb60b0(PARAMDECL)
{
	/* 0x0 -> 0xb6128 */
	/* 0x1 -> 0xb0ed8 */
	if(OPCODE & 0x100)
	{ /* 0xb0ed8 */
		return classify_leaf_VMOV_scalar_A1_0xb0ed8(PARAMS);
	}
	else
	{ /* 0xb6128 */
		return classify_leaf_VMRS_A1_0xb6128(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_4_3_0xb3bc0(PARAMDECL)
{
	/* 0x0 -> 0xb3800 */
	/* 0x1 -> 0xb60b0 */
	/* 0x2 -> 0xb3800 */
	/* 0x3 -> 0xb60b0 */
	/* 0x4 -> 0xb44b0 */
	/* 0x5 -> 0xb60b0 */
	/* 0x6 -> 0xb44b0 */
	/* 0x7 -> 0xb60b0 */
	static const uint32_t classify_cases = 0x6644;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70)>>3)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb3800 */
		return classify_leaf_VMOV_imm_A2_0xb3800(PARAMS);
	case 0x1:
	/* 0xb60b0 */
		return classify_mask_ef00a10_ff80e70_8_1_0xb60b0(PARAMS);
	default:
	/* 0xb44b0 */
		return classify_mask_0_0_16_3_0xb44b0(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_4_3_0xb5540(PARAMDECL)
{
	/* 0x0 -> 0xb3800 */
	/* 0x1 -> 0xb60b0 */
	/* 0x2 -> 0xb3800 */
	/* 0x3 -> 0xb60b0 */
	/* 0x4 -> 0xb4c98 */
	/* 0x5 -> 0xb60b0 */
	/* 0x6 -> 0xb4c98 */
	/* 0x7 -> 0xb60b0 */
	static const uint32_t classify_cases = 0x6644;
	uint32_t classify_case = (classify_cases>>((OPCODE & 0x70)>>3)) & 3;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb3800 */
		return classify_leaf_VMOV_imm_A2_0xb3800(PARAMS);
	case 0x1:
	/* 0xb60b0 */
		return classify_mask_ef00a10_ff80e70_8_1_0xb60b0(PARAMS);
	default:
	/* 0xb4c98 */
		return classify_mask_eb80a40_ff80e70_16_3_0xb4c98(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_19_3_0xa9ad8(PARAMDECL)
{
	/* 0x0 -> 0xb1df0 */
	/* 0x1 -> 0xb1df0 */
	/* 0x2 -> 0xb23e8 */
	/* 0x3 -> 0xb23e8 */
	/* 0x4 -> 0xb53c0 */
	/* 0x5 -> 0xb53c0 */
	/* 0x6 -> 0xb3bc0 */
	/* 0x7 -> 0xb5540 */
	static const uint32_t classify_cases = 0x8d2240;
	uint32_t classify_case = (classify_cases>>(((OPCODE & 0x380000)>>19)*3)) & 7;
	switch(classify_case)
	{
	case 0x0:
	/* 0xb1df0 */
		return classify_mask_e800a00_ff80e00_4_3_0xb1df0(PARAMS);
	case 0x1:
	/* 0xb23e8 */
		return classify_mask_ed00a00_ff80e00_4_1_0xb23e8(PARAMS);
	case 0x2:
	/* 0xb53c0 */
		return classify_mask_ee00a00_ff80e00_4_3_0xb53c0(PARAMS);
	case 0x3:
	/* 0xb3bc0 */
		return classify_mask_0_0_4_3_0xb3bc0(PARAMS);
	default:
	/* 0xb5540 */
		return classify_mask_0_0_4_3_0xb5540(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_22_3_0xb42d0(PARAMDECL)
{
	/* 0x0 -> 0x8d0f0 */
	/* 0x1 -> 0xb0640 */
	/* 0x2 -> 0xa27f8 */
	/* 0x3 -> 0xa9ad8 */
	/* 0x4 -> 0x84238 */
	/* 0x5 -> 0x84238 */
	/* 0x6 -> 0x84238 */
	/* 0x7 -> 0x84238 */
	static const uint32_t classify_cases = 0x924688;
	uint32_t classify_case = (classify_cases>>(((OPCODE & 0x1c00000)>>22)*3)) & 7;
	switch(classify_case)
	{
	case 0x0:
	/* 0x8d0f0 */
		return classify_mask_e000a00_fc00e00_4_3_0x8d0f0(PARAMS);
	case 0x1:
	/* 0xb0640 */
		return classify_mask_e400a00_fc00e00_4_1_0xb0640(PARAMS);
	case 0x2:
	/* 0xa27f8 */
		return classify_mask_0_0_19_3_0xa27f8(PARAMS);
	case 0x3:
	/* 0xa9ad8 */
		return classify_mask_0_0_19_3_0xa9ad8(PARAMS);
	default:
	/* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify_mask_a00_e00_25_3_0x9a198(PARAMDECL)
{
	/* 0x0 -> 0x84238 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0x84238 */
	/* 0x3 -> 0x84238 */
	/* 0x4 -> 0x84238 */
	/* 0x5 -> 0x84238 */
	/* 0x6 -> 0x8cbd8 */
	/* 0x7 -> 0xa97d0 */
	const uint32_t classify_bits = OPCODE & 0xe000000;
	if(classify_bits < 0xc000000)
	{ /* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
	else if(classify_bits == 0xc000000)
	{ /* 0x8cbd8 */
		return classify_mask_c000a00_e000e00_22_3_0x8cbd8(PARAMS);
	}
	else
	{ /* 0xa97d0 */
		return classify_constraint_0_0_f0000000_0xa97d0(PARAMS);
	}
}
RETURNTYPE classify_mask_0_0_9_3_0x844d8(PARAMDECL)
{
	/* 0x0 -> 0x84238 */
	/* 0x1 -> 0x84238 */
	/* 0x2 -> 0x84238 */
	/* 0x3 -> 0x84238 */
	/* 0x4 -> 0x84238 */
	/* 0x5 -> 0x9a198 */
	/* 0x6 -> 0x84238 */
	/* 0x7 -> 0x84238 */
	if((OPCODE & 0xe00)==0xa00)
	{ /* 0x9a198 */
		return classify_mask_a00_e00_25_3_0x9a198(PARAMS);
	}
	else
	{ /* 0x84238 */
		return classify_leaf_UNDEFINED_0x84238(PARAMS);
	}
}
RETURNTYPE classify(PARAMDECL)
{
		return classify_mask_0_0_9_3_0x844d8(PARAMS);
}
