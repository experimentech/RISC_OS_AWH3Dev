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
#ifndef DIS2_H
#define DIS2_H

/* Definitions required by the C disassembler */

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include "kernel.h"
#include "swis.h"

typedef enum {
	USR32 = 0x10,
	FIQ32 = 0x11,
	IRQ32 = 0x12,
	SVC32 = 0x13,
	MON32 = 0x16,
	ABT32 = 0x17,
	HYP32 = 0x1a,
	UND32 = 0x1b,
	SYS32 = 0x1f,
} eprocmode;

typedef enum {
	/* The first four match the way they are encoded in the instruction */
	SHIFT_LSL,
	SHIFT_LSR,
	SHIFT_ASR,
	SHIFT_ROR,
	SHIFT_RRX,
} eshift;

typedef struct {
	eshift type;
	uint8_t amt;
} decshift;

/* Warnings */

typedef enum {
	WARN_SUBS_PC_LR, /* Deprecated SUBS PC,LR-like instruction */
	WARN_UNPREDICTABLE, /* Something about this instruction is unpredictable */
	WARN_UNPREDICTABLE_LT_6, /* Something about this instruction is unpredictable on < ARMv6 */
	WARN_UNPREDICTABLE_GE_7, /* Something about this instruction is unpredictable on >= ARMv7 */
	WARN_NONSTANDARD_PC_OFFSET, /* Non-standard way of encoding a PC-relative offset */
	WARN_BAD_DMB_DSB_ISB_OPTION, /* Unrecognised DMB/DSB/ISB option */
	WARN_UNPREDICTABLE_PC_WRITEBACK, /* Use of PC as base register with writeback */
	WARN_LDM_SP, /* Deprecated use of SP in LDM/POP */
	WARN_LDM_LR_PC, /* Deprecated use of LR & PC in the same LDM/POP */
	WARN_STM_SP, /* Deprecated use of SP in STM/PUSH */
	WARN_STM_PC, /* Deprecated use of PC in STM/PUSH */
	WARN_STC_PC, /* Deprecated use of PC in STC */
	WARN_STM_WB, /* STM with writeback, base register in list, and base register not lowest register in list */
	WARN_STR_PC, /* Deprecated use of PC in STR */
	WARN_SWP_SWPB, /* SWP/SWPB deprecated */
	WARN_CPS_NONSTANDARD, /* Nonstandard CPS encoding, may be NOP or unpredictable */
	WARN_BAD_VFP_MRS_MSR, /* Bad VFP/NEON special register in VMRS/MSR */ 
	WARN_PC_POSTINDEXED, /* Use of PC as postindexed base register (but not necessarily with writeback!) */

	WARN_MAX
} ewarning;

#ifndef MODULE

extern const char *warnmessages[WARN_MAX];
#define WARNMSG(X) warnmessages[X]

#else

extern const char *getwarnmessage(int i);
#define WARNMSG(X) getwarnmessage(X)

#endif

#define PSR_N		0x80000000
#define PSR_Z		0x40000000
#define PSR_C		0x20000000
#define PSR_V		0x10000000
#define PSR_Q		0x08000000
#define PSR_IT10	0x06000000
#define PSR_J		0x01000000
#define PSR_GE		0x000f0000
#define PSR_IT72	0x0000fc00
#define PSR_E		0x00000200
#define PSR_A		0x00000100
#define PSR_I		0x00000080
#define PSR_F		0x00000040
#define PSR_T		0x00000020
#define PSR_M		0x0000001f

/* PSR bits which define the instruction set */
#define PSR_ISET		(PSR_J | PSR_E)
#define PSR_ISET_ARM		0
#define PSR_ISET_THUMB		PSR_E
#define PSR_ISET_JAZELLE	PSR_J
#define PSR_ISET_THUMBEE	(PSR_J | PSR_E)

#define PSR26_N		0x80000000
#define PSR26_Z		0x40000000
#define PSR26_C		0x20000000
#define PSR26_V		0x10000000
#define PSR26_I		0x08000000
#define PSR26_F		0x04000000
#define PSR26_M		0x00000003

typedef enum {
	SWIMODE_NAME, /* Show SWI names */
	SWIMODE_NUM, /* Show SWI numbers */
	SWIMODE_QUOTED, /* Quoted SWI names */
} eswimode;

typedef enum {
	LFMSFM_FORM1, /* LFM F1,3,[R13],#&024, LFM F1,3,addr */
	LFMSFM_FORM2, /* LFMIA F1,3,[R13]! */
	LFMSFM_LDMSTM, /* LFMIA R13!,{F1-F4} */
} elfmsfmmode;

typedef struct {
	char *regs[16]; /* Name to use for each main register */
	const char **cond; /* Condition code names */
	uint32_t reggroups; /* Register groups for LDM/STM. Set bit to 0 for start of group, 1 for in middle/end */
	uint32_t warnversions; /* Produce warnings for any instructions which require these architecture versions (earch flags) */
	bool ual; /* Whether to use UAL syntax or not */
	bool vfpual; /* Whether to use UAL for VFP or not */
	bool dci; /* Use DCI instead of "undefined instruction" */
	bool bashex; /* Use & for hex numbers instead of 0x */
	bool nonstandard_undefined; /* Report nonstandard encodings as being undefined instructions */
	bool allhex; /* Show (almost) all numbers in hex instead of decimal/hex misc */
	bool swihash; /* Show '#' infront of SWI name/number */
	bool positionind; /* Whether to generate position-independent disassembly */
	uint8_t cols[2]; /* Column positions */
	eswimode swimode; /* How to show SWIs */
	elfmsfmmode lfmsfmmode; /* How to show LFM/SFM */
	char comment; /* Char to use at start of comment */
} dis_options;

typedef struct {
	uint32_t opcode;
	uint32_t addr; /* PC value to use; assumed to be correctly aligned, and including +8 offset */
	uint32_t psr; /* 32bit PSR */
	uint32_t nonstandard; /* nonstandard bits */
	uint32_t num; /* Number to comment on */
	bool commentnum; /* Whether to comment on the number or not */
	uint8_t width; /* Width of instruction: 0 (first halfword of 32bit Thumb encoding), 16 (16bit Thumb), 32 (32bit Thumb, ARM) */
	bool itset; /* ITSTATE has been updated by the instruction */
#ifdef MODULE
	bool undefined; /* True for undefined instructions - to get them passed back to the assembler code */
#endif
	uint32_t warnflags[(WARN_MAX+31)>>5]; /* Raised warnings */
	uint32_t only; /* If nonzero, the architecture veriants that are required */
	uint32_t nop; /* If nonzero, the architecture variants in which this instruction is a NOP */
	const dis_options *opt;
	char buf[128]; /* Output buffer */
} dis_param;

#define RETURNTYPE void
#ifdef PASS_OPCODE
#define PARAMDECL dis_param *params, uint32_t opcode
#define PARAMS params, opcode
#define PARAMSCOMMA ,
#define OPCODE opcode
#else
#define PARAMDECL dis_param *params
#define PARAMS params
#define PARAMSCOMMA ,
#define OPCODE params->opcode
#endif

#define JUSTPARAMDECL dis_param *params
#define JUSTPARAMS params

/* Misc arrays of stuff */
typedef struct {
	char *str;
	bool valid;
} optval;

extern const optval dmb_dsb_opt[16]; /* DMB/DSB option names & validity flags */
extern const optval isb_opt[16]; /* ISB option names & validity flags */
extern const optval vfp_mrs[16]; /* VMRS reg names & validity flags */
extern const optval vfp_msr[16]; /* VMSR reg names & validity flags */

/* Messages */

typedef enum {
	MSG_UNDEFINEDINSTRUCTION,
	MSG_UNPREDICTABLEINSTRUCTION,
	MSG_UNALLOCATEDHINT,
	MSG_PERMAUNDEFINED,
	MSG_UNALLOCATEDMEMHINT,
	MSG_THUMB32,

	MSG_MAX
} emessages;

#ifdef MODULE

extern const char *getmessage(int i);
#define MSG(X) getmessage(X)

#else

extern const char *messages[MSG_MAX];
#define MSG(X) messages[X]

#endif

/* Architecture versions */

typedef enum {
	ARMv5Tstar,
	ARMv5TEstar,
	ARMv6star,
	ARMv6Tstar,
	ARMv6K,
	ARMv6T2,
	ARMv7,
	ARMv7MP,
	ARMv7VE,
	ARMv7opt,
	SecExt,
	VFP_ASIMD_common,
	VFPv2,
	VFPv3,
	VFPv3HP,
	VFPv4,
	ASIMD,
	ASIMDHFP,
	ASIMDFP,
	ASIMDv2FP,
	FPA,
	XScaleDSP,
	ARMv8,

	ARCH_MAX
} earch;

#ifdef MODULE

extern const char *getarchwarning(int i);
#define ARCHWARN(X) getarchwarning(X)

#else

extern const char *archwarnings[ARCH_MAX];
#define ARCHWARN(X) archwarnings[X]

#endif

/* Disassembler functions */

extern RETURNTYPE dis2(PARAMDECL);

/* Helper functions/macros */

/* Sign extend a value */
static inline int32_t sextend(uint32_t val,uint32_t size)
{
	return ((int32_t)(val<<(32-size)))>>(32-size);
}

/* sprintf to end of string */
extern int scatf(char *out,const char *format,...);

/* Return correct hex prefix */
#define HEX (params->opt->bashex?"&":"0x")

/* Return register name */
#define REG(R) (params->opt->regs[R])

/* Append an unsigned number in correct decimal/hex format */
extern void scatu(dis_param *params,uint32_t num);

/* Append a signed number in correct decimal/hex format */
extern void scati(dis_param *params,int32_t num);

/* Decode a 12 bit immediate constant */
extern uint32_t decodeimm12(uint32_t imm12);

/* Decode an immediate shift */
extern decshift DecodeImmShift(uint32_t type,uint32_t imm5);

/* Return condition code string */
#define condition(P,CC) (params->opt->cond[CC])

/* Indicate which architecture variants the instruction requires */
#define ONLY1(A) { params->only = 1<<(A); }
#define ONLY2(A,B) { params->only = (1<<(A)) | (1<<(B)); }
#define ONLY3(A,B,C) { params->only = (1<<(A)) | (1<<(B)) | (1<<(C)); }
#define ONLY4(A,B,C,D) { params->only = (1<<(A)) | (1<<(B)) | (1<<(C)) | (1<<(D)); }

/* Indicate which architecture variants the instruction acts as a NOP on */
#define NOP1(A) { params->nop = 1<<(A); }
#define NOP2(A,B) { params->nop = (1<<(A)) | (1<<(B)); }
#define NOP3(A,B,C) { params->nop = (1<<(A)) | (1<<(B)) | (1<<(C)); }
#define NOP4(A,B,C,D) { params->nop = (1<<(A)) | (1<<(B)) | (1<<(C)) | (1<<(D)); }

/* Raise a warning */
static inline void warning(JUSTPARAMDECL,ewarning w)
{
	params->warnflags[w>>5] |= 1<<(w&31);
}

/* Output a deprecation warning about SUBS PC,LR if appropriate */
#define SUBS_PC_LR(P,S,RD,RN) { if(S && (RD==15) && (RN==14)) warning(JUSTPARAMS,WARN_SUBS_PC_LR); }

/* Output an 'unpredictable' warning if condition is true */
#define _UNPREDICTABLE(COND) { if(COND) warning(JUSTPARAMS,WARN_UNPREDICTABLE); }

/* Output an 'unpredictable' warning if condition is true, for certain architectures */
#define _UNPREDICTABLE_ARCH_LT(COND,ARCH) { if(COND) warning(JUSTPARAMS,WARN_UNPREDICTABLE_LT_ ## ARCH); }
#define _UNPREDICTABLE_ARCH_GE(COND,ARCH) { if(COND) warning(JUSTPARAMS,WARN_UNPREDICTABLE_GE_ ## ARCH); }

/* Handles UNDEFINED */
extern void doundefined(PARAMDECL);

/* Mark an instruction as undefined if condition is true */
#define _UNDEFINED(COND) if(COND) { doundefined(PARAMS); return; }

/* Handle common stuff - must be in every action! */
#define COMMON if(nonstandard) { params->nonstandard = nonstandard; }

/* Common stuff for 16bit thumb; sets up 'cond' and 'S' */
#define COMMONT16 { params->nonstandard = nonsdandard; params->width = 16; } uint32_t S,cond; cond = THUMBCOND(JUSTPARAMS,&S);

/* Common stuff for 32bit thumb; sets up 'cond' and 'S' */
#define COMMONT32 { params->nonstandard = nonsdandard; params->width = 32; } uint32_t S,cond; cond = THUMBCOND(JUSTPARAMS,&S);

/* Version of COMMON for CMN, CMP, TEQ, TST to cope with 'P' versions
   Sets P to true if 'P' is used */
#define COMMONP \
const bool P = (nonstandard & 0xF000)==0xF000;\
params->nonstandard = (P?nonstandard&~0xF000:nonstandard);

/* Set post1 and post2 to an instruction postfix based around UAL/non-UAL
   ordering */
#define UALIFY(post,cc) \
const char *post1,*post2; \
{ \
  const char *temp1 = post; \
  const char *temp2 = condition(JUSTPARAMS,cc); \
  if(params->opt->ual) \
  { \
    post1 = temp1; \
    post2 = temp2; \
  } \
  else \
  { \
    post1 = temp2; \
    post2 = temp1; \
  } \
}

/* Alternate isprint() that matches the debugger module */
extern bool disprint(uint32_t c);

/* Return LDM/STM/SRS/RFE mode from P & U bits */
extern const char *ldmmode(bool P,bool U);

/* Thumb helpers */

/* Get current thumb condition code, and set S if outside of IT block */
extern uint32_t THUMBCOND(JUSTPARAMDECL,uint32_t *S);

/* Get current thumb condition code, or AL if in ARM state */
extern uint32_t THUMBCOND2(JUSTPARAMDECL);

/* True if in IT block */
#define INITBLOCK (params->psr & (PSR_IT10 | PSR_IT72))

/* True if last in IT block */
#define LASTINITBLOCK ((params->psr & (PSR_IT10 | 0xc00)) == 0x800)

/* ARM helpers */

/* Print out an LDM-style register list, without the enclosing brackets */
extern void doreglist(JUSTPARAMDECL,uint32_t reglist);

/* Output an optional immediate shift */
extern void doimmshift(JUSTPARAMDECL,uint32_t type,uint32_t imm5);

/* Output a 12-bit immediate constant */
extern void doimm12(JUSTPARAMDECL,uint32_t imm12);

/* Output a banked MSR register */
extern void dobankedmsr(JUSTPARAMDECL,uint32_t SYSm,uint32_t R);

/* Output an immediate LDR/STR offset
   i.e. ,#(-)<OFFS>](!)
   or   ],#(-)<OFFS> */
extern void doldrstrimm(JUSTPARAMDECL,uint32_t P,uint32_t U,uint32_t W,uint32_t offset);

/* Output a literal LDR/STR offset
   i.e. <ADDR>
   or   [PC,#(-)<OFFSET>]
*/
extern void doldrstrlit(JUSTPARAMDECL,uint32_t U,uint32_t W,uint32_t imm,bool warn_minus_0);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RN>,#<IMM12>
*/
extern void OP_S_CC_RD_RN_IMM12(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rn,uint32_t imm12);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RN>,<RM>{,SHIFT #...}
*/
extern void OP_S_CC_RD_RN_RM_SHIFT(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rn,uint32_t rm,uint32_t type,uint32_t imm5);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RM>{,SHIFT #...}
*/
extern void OP_S_CC_RD_RM_SHIFT(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rm,uint32_t type,uint32_t imm5);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RN>,<RM>,SHIFT <RS>
*/
extern void OP_S_CC_RD_RN_RM_RS(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rn,uint32_t rm,uint32_t type,uint32_t rs);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RM>,SHIFT <RS>
*/
extern void OP_S_CC_RD_RM_RS(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rm,uint32_t type,uint32_t rs);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<ADDR>
*/
extern void OP_S_CC_RD_ADDR(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t addr);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RM>,#<IMM>
*/
extern void OP_S_CC_RD_RM_IMM(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rm,int32_t imm);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RN>,<RM>
*/
extern void OP_S_CC_RD_RN_RM(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rn,uint32_t rm);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RM>,<RN>
*/
#define OP_S_CC_RD_RM_RN OP_S_CC_RD_RN_RM

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RM>
*/
extern void OP_S_CC_RD_RM(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rm);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,#<IMM12>
*/
extern void OP_S_CC_RD_IMM12(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t imm12);

/* Output an instruction of the form:
   <OP><S><CC> <RD>,<RN>,<RM>,<RA>
*/
extern void OP_S_CC_RD_RN_RM_RA(JUSTPARAMDECL,const char *op,bool S,uint32_t cc,uint32_t rd,uint32_t rn,uint32_t rm,uint32_t ra);

/* Output an instruction of the form:
   <OP><P><CC> <RD>,#<IMM12>
*/
extern void OP_P_CC_RD_IMM12(JUSTPARAMDECL,const char *op,bool P,uint32_t cc,uint32_t rd,uint32_t imm12);

/* Output an instruction of the form:
   <OP><P><CC> <RD>,<RM>{,SHIFT #...}
*/
extern void OP_P_CC_RD_RM_SHIFT(JUSTPARAMDECL,const char *op,bool P,uint32_t cc,uint32_t rd,uint32_t rm,uint32_t type,uint32_t imm5);

/* Output an instruction of the form:
   <OP><P><CC> <RD>,<RM>,SHIFT <RS>
*/
extern void OP_P_CC_RD_RM_RS(JUSTPARAMDECL,const char *op,bool P,uint32_t cc,uint32_t rd,uint32_t rm,uint32_t type,uint32_t rs);

/* Output a branch instruction of the form:
   <OP><CC> <ADDR>
*/
extern void OP_CC_ADDR(JUSTPARAMDECL,const char *op,uint32_t cc,int32_t ofs,int32_t bias);

/* FPA helpers */

extern const char *fpa_precision; /* FPA precision specifiers */
extern const char *fpa_round[4]; /* FPA rounding modes */
extern const char *fpa_imm[8]; /* FPA immediate constants */

/* Return precision char (S,D,E,P) */
static inline char fpaprecision(uint32_t T0,uint32_t T1)
{
	return fpa_precision[T0 | (T1<<1)];
}

/* Outputs an instruction of the form:
   <OP><CC><S|D|E><P|M|Z> <FD>,<FN>,<FM>
   or
   <OP><CC><S|D|E><P|M|Z> <FD>,<FN>,#IMM
*/
extern void FPA_CC_FD_FN_FMIMM(JUSTPARAMDECL,const char *op,uint32_t cc,uint32_t ef,uint32_t gh,uint32_t fd,uint32_t fn,uint32_t i,uint32_t fm);

/* Outputs an instruction of the form:
   <OP><CC><S|D|E><P|M|Z> <FD>,<FM>
   or
   <OP><CC><S|D|E><P|M|Z> <FD>,#IMM
*/
extern void FPA_CC_FD_FMIMM(JUSTPARAMDECL,const char *op,uint32_t cc,uint32_t ef,uint32_t gh,uint32_t fd,uint32_t i,uint32_t fm);

/* VFP helpers */

/* Whether double precision is supported or not */
#define VFPDP (true)

/* Outputs an instruction of the form:
   <OP><CC>.F32/.F64 <VD>,#%f
   'f' parameter is IEEE float
*/
extern void VFP_CC_VD_F(JUSTPARAMDECL,const char *opual,const char *op,uint32_t cc,uint32_t sz,uint32_t Vd,uint32_t D,uint32_t f);

/* Outputs an instruction of the form:
   <OP><CC>.F32/.F64 <VD>,#<IMM>
*/
extern void VFP_CC_VD_IMM(JUSTPARAMDECL,const char *opual,const char *op,uint32_t cc,uint32_t sz,uint32_t Vd,uint32_t D,uint32_t imm);

/* Outputs an instruction of the form:
   <OP><CC>.F32/.F64 <VD>,<VM>
*/
extern void VFP_CC_VD_VM(JUSTPARAMDECL,const char *opual,const char *op,uint32_t cc,uint32_t sz,uint32_t Vd,uint32_t D,uint32_t Vm,uint32_t M);

/* Outputs an instruction of the form:
   <OP><CC>.F32/.F64 <VD>,<VN>,<VM>
*/
extern void VFP_CC_VD_VN_VM(JUSTPARAMDECL,const char *opual,const char *op,uint32_t cc,uint32_t sz,uint32_t Vd,uint32_t D,uint32_t Vn,uint32_t N,uint32_t Vm,uint32_t M);

/* ASIMD helpers */

typedef struct {
	uint64_t imm; /* Fully expanded 64 bit value */
	uint8_t size; /* Size in bits, 0 if F32 */
	bool unpredictable; /* True if decode was unpredictable */
	bool undefined; /* True if decode was undefined (shouldn't happen!) */
} asimdimm;

/* Expand an immediate constant */
extern asimdimm AdvSIMDExpandImm(uint32_t op,uint32_t cmode,uint32_t imm8);

/* Get ASIMD condition code string */
#ifdef DISASSEMBLE_THUMB
#define ASIMDCOND condition(JUSTPARAMS,THUMBCOND2(JUSTPARAMS))
#else
#define ASIMDCOND ""
#endif

/* Outputs an instruction of the form:
   <OP><CC>.<S|U><8|16|32> <D>,<N>,<M>
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_D_N_M(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t U,uint32_t Q,uint32_t D_Vd,uint32_t N_Vn,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.<S|U><8|16|32> <D>,<M>
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_D_M(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t U,uint32_t Q,uint32_t D_Vd,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.I<8|16|32|64> <D>,<M>
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_I_D_M(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t Q,uint32_t D_Vd,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.<S|U><8|16|32> <D>,<N>,<M>
   Condition code is worked out automatically
   Operand size is QDD (w=0) or QQD (w=1)
*/
extern void ASIMD_LW_D_N_M(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t U,uint32_t w,uint32_t D_Vd,uint32_t N_Vn,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.I<8|16|32|64> <D>,<N>,<M>
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_I_D_N_M(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t Q,uint32_t D_Vd,uint32_t N_Vn,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.<S|U><8|16|32> <QD>,<DN>,<DM>
   Condition code is worked out automatically
*/
extern void ASIMD_QD_DN_DM(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t U,uint32_t D_Vd,uint32_t N_Vn,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.I<8|16|32> <DD>,<QN>,<QM>
   Condition code is worked out automatically
*/
extern void ASIMD_I_DD_QN_QM(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t D_Vd,uint32_t N_Vn,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.F32 <D>,<N>,<M>
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_F32_D_N_M(JUSTPARAMDECL,const char *op,uint32_t Q,uint32_t D_Vd,uint32_t N_Vn,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC> <D>,<N>,<M>
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_GEN_D_N_M(JUSTPARAMDECL,const char *op,uint32_t Q,uint32_t D_Vd,uint32_t N_Vn,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.F32 <D>,<M>
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_F32_D_M(JUSTPARAMDECL,const char *op,uint32_t Q,uint32_t D_Vd,uint32_t M_Vm);

/* Outputs an instruction of the form:
   <OP><CC>.<I|F><8|16|32|64> <D>,#IMM
   Condition code is worked out automatically
   Operand size (Q or D) is worked out automatically
*/
extern void ASIMD_D_IMM(JUSTPARAMDECL,const char *mnemonic,uint32_t Q,uint32_t D_Vd,uint32_t op,uint32_t cmode,uint32_t imm);

/* Outputs an instruction of the form:
   <OP><CC>.<8|16|32|64> {<D0>[,<D1>[,<D2>[,<D3>]]]},[<Rn>[@<ALIGN>]][<!|,Rm>]
   Condition code is worked out automatically
   Automatically marked as unpredictable if reg index goes out of range
   lane of -1 is none, -2 is all
*/
extern void ASIMD_VLD_VST(JUSTPARAMDECL,const char *op,uint32_t size,uint32_t D_Vd,int lane,int count,int stride,uint32_t Rn,uint32_t align,uint32_t Rm);

/* Main interface */

extern char *arm_engine(uint32_t instr,uint32_t addr,dis_options *opt,char *buf,size_t bufsize);

#endif
