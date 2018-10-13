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

/* Common code for dealing with code generation and pixel format conversion

   The code here is used by both PutScaled and SprTrans

 */

#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include "swis.h"

#include "Global/Sprite.h"
#include "Global/VduExt.h"
#include "Interface/BlendTable.h"

#define JPEG_INTERNALS
#include "jinclude.h"
#include "jpeglib.h"
#include "putscaled.h"
#ifdef DEBUG
#include "tracing.c"
#endif

/**************************************************************************
*                                                                         *
*    Macros.                                                              *
*                                                                         *
**************************************************************************/

#define SOURCE_32_BIT  (wp->save_inlog2bpp == 5)
#define SOURCE_16_BIT  (wp->save_inlog2bpp == 4)
#define SOURCED_16_BIT (wp->save_inlog2bpc == 4) /* like SOURCE_16_BIT but includes 16-bit double-pixels */
#define SOURCE_MASK    (ws->masktype != MaskType_None)
#define SOURCE_OLDMASK (ws->masktype == MaskType_Old)
#define SOURCE_BPPMASK (ws->masktype == MaskType_1bpp)
#define SOURCE_ALPHAMASK (ws->masktype == MaskType_8bpp)
#define SOURCE_TRICKYMASK (ws->masktype > MaskType_Old)
#define SOURCE_TABLE   (wp->ColourTTR != 0)

#define DPIXEL_INPUT   (wp->save_inlog2bpp != wp->save_inlog2bpc)
#define DPIXEL_OUTPUT  (wp->BPP != wp->BPC)

#define PLOTMASK       ((wp->spritecode & 255) == SpriteReason_PlotMaskScaled)
#define TRANSMASK       ((wp->spritecode & 255) == SpriteReason_PlotMaskTransformed)
#define ISTRANS        (TRANSMASK || ((wp->spritecode & 255) == SpriteReason_PutSpriteTransformed))

#define DEST_32_BIT    (wp->BPP == 32)
#define DEST_16_BIT    (wp->BPP == 16)
#define DEST_1_BIT     (wp->BPC == 1)
#define DESTD_16_BIT   (wp->BPC == 16) /* like DEST_16_BIT but includes 16-bit double-pixels */

#define COMPONENT_NAME(i) ((i==0?"red":(i==1?"green":(i==2?"blue":"alpha"))))

/* Make a string constant unique to avoid Norcroft messing it up
   This is something we can fall back to if we decide calling __RelocCode is a
   bad thing (but it would involve touching lots of strings to add the call, so
   for now laziness wins) */
#define UQ(X) (X "\000" RUNMACRO(__LINE__,TOSTRING))
#define TOSTRING(X) #X
#define RUNMACRO(X,Y) Y(X)

/**************************************************************************
*                                                                         *
*    C Workspace declarations.                                            *
*                                                                         *
**************************************************************************/

/* Code buffers */
#define NBUFFERS 8       /* Number of code buffers */
#define BUFSIZE 256      /* words per buffer */
typedef struct
{
  int key_word;              /* descriptor for this code, or -1 if empty */
  int xadd;                  /* precise scale factors compiled into this code */
  int xdiv;
  int yadd;
  int ydiv;
  int outoffset;             /* output row offset compiled into this code */
  int code[BUFSIZE];         /* the code itself */
} code_buffer;
#define FOR_EACH_BUFFER(ptr) for (ptr = &ws->buffers[0]; ptr < &ws->buffers[NBUFFERS]; ptr++)

/* Labels - there's one of these for each label in the source we generate. */
typedef struct
{
  int *def;          /* where the label is, or 0 if not yet defined. */
  int *ref;          /* a reference to the label, to be filled in when it's defined. */
#ifdef DEBUG
  char *name;        /* textual name of the label - same as field name */
#endif
} label;

/* Each label must be added as a field to this structure. */
typedef struct
{
  #define FIRST_LABEL loop_y_repeat
  label loop_y_repeat;
#ifdef TESTDEBUG
  label test1;
  label test2;
#endif
  label loop_x_enter;
  label loop_x_repeat;
  label loop_x_exit;
  label l_masked;
  label loop_put_pixel_repeat;
  label loop_put_masked_repeat;
  label y_loop;
  label y_loop_enter;
  label y_loop_exit;
  label loop_delay;

  label x_evenstart;
  label x_oddmask;
  label x_aligned_loop;
  label x_aligned_enter;
  label x_alignmask1;
  label x_alignmask2;
  label x_misaligned;
  label x_misaligned_loop;
  label x_misaligned_enter;
  label x_misalignmask1;
  label x_misalignmask2;
  label x_2atatime_exit;
  label x_lastmask;
  label loop_x_exit1;
  label loop_x_exitskip;
  label loop1;
  label loop2;
  label plot_loopa;
  label plot_loop1;
  label plot_loop1a;
  label plot_loop1b;
  label plot_loop1c;
  label plot_loop2;
  label plot_loop3;
  label plot_loop4;
  label plot_loop4a;
  label plot_loop4b;
  label plot_loop4c;

  label blend_nodestalpha;
  label translate_noalpha;
  label translate_noalpha2;

  label last;
  #define LAST_LABEL last
  /* If you add a label, add giving it a name in check_workspace */
} labels_rec;
#define FOR_EACH_LABEL(ptr) for (ptr = &ws->labels.FIRST_LABEL; ptr <= &ws->labels.LAST_LABEL; ptr++)
#define L(name) (&(ws->labels.name))

/* Register names - one for each register name (the register numbers are allocated at compile time) */
typedef struct
{
  int regno;     /* the physical register number, negative if not allocated/paged out */
  int flags;     /* usage flags */
  int spindex;   /* index into stack frame where register is saved, -1 if not saved */
#ifdef DEBUG
  char *name;    /* the name, for trace output */
  char *describe;/* description, for trace output */
#endif
} regname;

#define REGFLAG_TEMPORARY  0x01 /* Only used for temporary calculations, doesn't need saving/restoring */
#define REGFLAG_CONSTANT   0x02 /* Constant value - once initialised, doesn't need saving */
#define REGFLAG_GLOBAL     0x04 /* Register must always be available  */
#define REGFLAG_PERPIXEL   0x08 /* Register needed for per-pixel block */
#define REGFLAG_XLOOP      0x10 /* Register needed for x-loop block */
#define REGFLAG_YLOOP      0x20 /* Register needed for y-loop block */
#define REGFLAG_INPUT      0x40 /* Register needed for input block */
#define REGFLAG_USED       0x80 /* Dummy flag for some global regs (sp, lr, etc.) */
#define REGFLAG_XLOOPVAR  0x100 /* Restore initial value at end of x loop */

#define REGFLAG_USAGE_MASK 0x7c /* All the interesting usage flags */

/* Each register name must be added as a field to this structure. */
typedef struct
{
  #define FIRST_REGISTER r_pixel

  /* Common registers */
  regname r_pixel;         /* In/out pixel value */
  regname r_temp1;         /* Temp regs for pixel format conversion */
  regname r_temp2;
  regname r_expansionmask1;/* Constant for BPP expansion */
  regname r_expansionmask2;/* Secondary mask for rare situations */
  regname r_oditheradd;    /* Current dither pattern */
  regname r_table;         /* Palette/colour translation table ptr */
  regname r_alpha;         /* Computed alpha for sprite blending */
  regname r_translucency;  /* User-supplied translucency for sprite blending, inverted to make alpha */
  regname r_blendtable;    /* Pointer to blend table(s) */
  regname r_screenpalette; /* 8bpp -> 15bpp LUT from InverseTable */
  regname r_inversetable;  /* 15bpp -> 8bpp LUT from InverseTable */

  /* PutScaled registers */
  regname r_inptr;
  regname r_inshift;
  regname r_inword;
  regname r_maskinptr;
  regname r_maskinword;
  regname r_maskinshift;
  regname r_masko;
  regname r_blockroutine;
  regname r_ecfindex;
  regname r_bgcolour;
  regname r_fetchroutine;
  regname r_outptr;
  regname r_outword;
  regname r_outshift;
  regname r_outmask;
  regname r_xsize;
  regname r_xcount;
  regname r_ysize;
  regname r_ycount;
  regname r_inoffset;
  regname r_maskinoffset;
  regname r_in_pixmask;    /* only used by 2-at-a-time loop */

  /* SprTrans registers */
  regname r_xsize_spr_left;
  regname r_X;
  regname r_Y;
  regname r_inc_X_x;
  regname r_inc_Y_x;
  regname r_byte_width;
  regname r_spr_height_right;
  regname r_out_x;

  /* Generic registers */
  regname wp;
  regname sp;
  regname lr;
  regname pc;
  #define LAST_REGISTER pc
} regnames_rec;
#define FOR_EACH_REGISTER_NAME(ptr) for (ptr = &ws->regnames.FIRST_REGISTER; ptr <= &ws->regnames.LAST_REGISTER; ptr++)

#define R(reg) rr(&ws->regnames.reg)
static int rr(const regname *r)
{
  /* Assert that the register is at least set */
#ifdef DEBUG
  if (r->regno & 0x80000000) dprintf(("", "%x %s\n", r->regno, r->name));
#endif
  assert(!(r->regno & 0x80000000), ERROR_FATAL);
  return r->regno;
}

/* Must be kept in sync with corresponding definitions in Sources.PutScaled! */
typedef enum
{
  /* This block is assumed to match the mode log2bpp */
  PixelFormat_1bpp=0,
  PixelFormat_2bpp=1,
  PixelFormat_4bpp=2,
  PixelFormat_8bpp=3,

  /* I can't remember if this needs to be in the middle! */
  PixelFormat_24bpp_Grey=4,

  /* This block is assumed to be in order of increasing bit count */
  PixelFormat_12bpp=5,
  PixelFormat_15bpp=6,
  PixelFormat_16bpp=7,
  PixelFormat_24bpp=8,
  PixelFormat_32bpp=9,
  PixelFormat_32bpp_Hi=10, /* &BBGGRR00, i.e. palette entry */

  PixelFormat_BPPMask = 15,

  /* Extra flags, only for the true colour entries */
  PixelFormat_RGB = 16, /* &RGB order, not &BGR */
  PixelFormat_Alpha = 32, /* Alpha, not supremacy/transfer */
} PixelFormat;

/* Must be kept in sync with corresponding definitions in Sources.PutScaled! */
typedef struct
{
  char bits[4]; /* Number of bits in this channel */
  char top[4]; /* The bit above the end of the channel */
  char hints;
  char unused_pad;
  unsigned short alphaimm12;
} PixelFormatInfo;

#define HINT_HIGHEST 1

typedef enum
{
  MaskType_None, /* No mask, or we're not using it */
  MaskType_Old, /* Old style mask */
  MaskType_1bpp, /* New style 1bpp mask */
  MaskType_8bpp, /* 8bpp alpha mask */
} MaskType;

typedef enum
{
  BlendImpl_None, /* No blending required */
  BlendImpl_BlendTable, /* Use single blendtable */
  BlendImpl_InverseTable, /* Use InverseTable for 8bpp -> 15bpp -> 8bpp */
  BlendImpl_True, /* True colour blend, no tables required */
  BlendImpl_BlendTables, /* Lots of blend tables for <=4bpp output */
} BlendImpl;

/* The structure containing all workspace - essentially our static variables. */
#define CHECK_CODE 123456789
typedef struct
{
  /* Initialisation */
  int  check_code;

  /* Code buffer management */
  int  build_buffer;             /* Buffer currently being built, or next to build */
  int *compile_base;
  int *compile_ptr;              /* where to put next instruction */
  int *compile_lim;

  /* Label control and allocation */
  labels_rec labels;             /* each label, and where it is in the generated code */

  /* Register control and allocation */
  regnames_rec regnames;         /* physical assignment of each register name */
  int  regframesize;             /* size of stack frame holding regs */
  int  regframeoffset;           /* sp offset to apply to get the register stack frame */

  int  gcol;                     /* GCOL action */
  MaskType masktype;             /* Mask type to use */

  int  odither;                  /* If 0, then there's no ordered dither. If non-0, number of bits - 1 being truncated by dither. */

  int pixel_expansion_mask[2];   /* Pixel expansion masks. Only rarely are both needed. */

  /* Assemble-time constants */
  int  in_bpp;
  int  in_bpc;                   /* Same as bpp unless double-pixel, in which case double bpp */
  int  in_pixmask;
  PixelFormat in_pixelformat;
  int  mask_bpp;
  int  mask_bpc;
  int  mask_pixmask;
  int  out_pixmask;              /* mask for one pixel */
  int  out_dpixmask;
  int  out_ppw;                  /* pixels per word */
  int  out_l2ppw;
  PixelFormat out_pixelformat;
  BOOL cal_table_simple;         /* If true, a simple table lookup is possible */
  PixelFormat ColourTTRFormat;   /* Input format of ColourTTR (output format assumed to be out_pixelformat) */
  int  compiled_routine_stacked; /* Offset to apply to LDR_SP/STR_SP */
  BlendImpl blendimpl;           /* Blending method/implementation to use */

  /* Space for compiled code, near the end so most field accesses have only a small offset. */
  code_buffer buffers[NBUFFERS];

  /* Check for workspace overwritten */
  int  check_code2;
} workspace;

static void check_workspace(workspace *ws)
/* Basic validity checks, and initialise if this is the first time. */
{
  assert(ws != 0, ERROR_NO_MEMORY);
  if (ws->check_code != CHECK_CODE)
  {
    code_buffer *p;
    dprintf(("", "Initialising workspace.\n"));
    ws->check_code = CHECK_CODE;
    ws->check_code2 = CHECK_CODE;
    ws->build_buffer = 0;
    FOR_EACH_BUFFER(p) p->key_word = -1;

#ifdef DEBUG
    {
      label *l;

      /* Set up textual names of all the labels */
      FOR_EACH_LABEL(l) l->name = 0;
      #define LN(lname) ws->labels.lname.name = #lname;
      LN(loop_y_repeat)
#ifdef TESTDEBUG
      LN(test1)
      LN(test2)
#endif
      LN(loop_x_enter)
      LN(loop_x_repeat)
      LN(loop_x_exit)
      LN(l_masked)
      LN(loop_put_pixel_repeat)
      LN(loop_put_masked_repeat)
      LN(y_loop)
      LN(y_loop_enter)
      LN(y_loop_exit)
      LN(loop_delay)

      LN(x_evenstart)
      LN(x_oddmask)
      LN(x_aligned_loop)
      LN(x_aligned_enter)
      LN(x_alignmask1)
      LN(x_alignmask2)
      LN(x_misaligned)
      LN(x_misaligned_loop)
      LN(x_misaligned_enter)
      LN(x_misalignmask1)
      LN(x_misalignmask2)
      LN(x_2atatime_exit)
      LN(x_lastmask)
      LN(loop_x_exit1)
      LN(loop_x_exitskip)
      LN(loop1)
      LN(loop2)
      LN(plot_loopa)
      LN(plot_loop1)
      LN(plot_loop1a)
      LN(plot_loop1b)
      LN(plot_loop1c)
      LN(plot_loop2)
      LN(plot_loop3)
      LN(plot_loop4)
      LN(plot_loop4a)
      LN(plot_loop4b)
      LN(plot_loop4c)

      LN(blend_nodestalpha)
      LN(translate_noalpha)
      LN(translate_noalpha2)

      LN(last)
      /* Check he's got them all */
      FOR_EACH_LABEL(l) assert(l->name != 0, ERROR_FATAL);
    }
    {
      regname *r;

      FOR_EACH_REGISTER_NAME(r) r->name = 0;
      #define RNN(rname) ws->regnames.rname.name = #rname;
      RNN(r_pixel)
      RNN(r_temp1)
      RNN(r_temp2)
      RNN(r_expansionmask1)
      RNN(r_expansionmask2)
      RNN(r_oditheradd)
      RNN(r_alpha)
      RNN(r_translucency)
      RNN(r_blendtable)
      RNN(r_screenpalette)
      RNN(r_inversetable)

      RNN(r_inptr)
      RNN(r_inshift)
      RNN(r_inword)
      RNN(r_maskinptr)
      RNN(r_maskinword)
      RNN(r_maskinshift)
      RNN(r_masko)
      RNN(r_blockroutine)
      RNN(r_ecfindex)
      RNN(r_bgcolour)
      RNN(r_fetchroutine)
      RNN(r_outptr)
      RNN(r_outword)
      RNN(r_outshift)
      RNN(r_outmask)
      RNN(r_table)
      RNN(r_xsize)
      RNN(r_xcount)
      RNN(r_ysize)
      RNN(r_ycount)
      RNN(r_inoffset)
      RNN(r_maskinoffset)
      RNN(r_in_pixmask)

      RNN(r_xsize_spr_left)
      RNN(r_X)
      RNN(r_Y)
      RNN(r_inc_X_x)
      RNN(r_inc_Y_x)
      RNN(r_byte_width)
      RNN(r_spr_height_right)
      RNN(r_out_x)

      RNN(wp)
      RNN(sp)
      RNN(lr)
      RNN(pc)
      FOR_EACH_REGISTER_NAME(r) assert(r->name != 0, ERROR_FATAL);
    }
#endif
  }
  assert(ws->check_code2 == CHECK_CODE, ERROR_FATAL);
}

#ifdef DEBUG
static void dump_asm_workspace(asm_workspace *wp)
{
  /* Oddly spaced out to allow it to be easily lined up with the structure definition */
  dprintf(("", "Assembler workspace at %x:\n", wp));
  dprintf(("", "save_outoffset=%i        %t32. byte offset between output rows - SUBTRACT for next row.\n", wp->save_outoffset));
  dprintf(("", "save_inoffset=%i         %t32. byte offset between input rows - SUBTRACT for next row.\n", wp->save_inoffset));
  dprintf(("", "save_inptr=0x%x          %t32. word address of input pixels.\n", wp->save_inptr));
  dprintf(("", "save_outptr=0x%x         %t32. address of word containing first output pixel.\n", wp->save_outptr));
  dprintf(("", "save_ydiv=%i             %t32. subtracter value for y scale.\n", wp->save_ydiv));
  dprintf(("", "save_yadd=%i             %t32. adder value for y scale.\n", wp->save_yadd));
  dprintf(("", "save_ysize=%i            %t32. number of output rows.\n", wp->save_ysize));
  dprintf(("", "save_ycount=%i           %t32. total of ymag/ydiv sum, for y scale factor\n", wp->save_ycount));
  newline();
  
  dprintf(("", "save_inshift=%i          %t32. bit shift of first pixel.\n", wp->save_inshift));


  dprintf(("", "save_xsize=%i            %t32. number of output pixels per row.\n", wp->save_xsize));
  dprintf(("", "save_xcount=%i           %t32. total of xmag/xdiv sum, for x scale factor\n", wp->save_xcount));
  dprintf(("", "save_ecfptr=0x%x         %t32. ECF pointer - only useful if plotting the mask.\n", wp->save_ecfptr));
  dprintf(("", "save_ecflimit=0x%x       %t32. ECF limit - only useful if plotting the mask.\n", wp->save_ecflimit));

  dprintf(("", "save_xdiv=%i             %t32. subtracter value for x scale.\n", wp->save_xdiv));
  dprintf(("", "save_xadd=%i             %t32. adder value for x scale\n", wp->save_xadd));
  newline();
  dprintf(("", "save_masko=%i            %t32. if not 1bpp mask then this is mask data offset from inptr. Otherwise...\n", wp->save_masko));
  dprintf(("", "save_xcoord=%i           %t32. pixel x coordinate of first output pixel.\n", wp->save_xcoord));
  dprintf(("", "save_ycoord=%i           %t32. pixel y coordinate of first output pixel.\n", wp->save_ycoord));





  dprintf(("", "save_xmag=%i             %t32. adder value for x scale?\n", wp->save_xmag));
  dprintf(("", "save_ymag=%i             %t32. adder value for y scale?\n", wp->save_ymag));
  newline();

  dprintf(("", "save_inlog2bpp=%i        %t32. log 2 bits per pixel of input.\n", wp->save_inlog2bpp));
  dprintf(("", "save_inlog2bpc=%i        %t32. log 2 bits per character of input (only different for double-pixels).\n"
                                  , wp->save_inlog2bpc));
  dprintf(("", "save_mode=%i (>>27 = %i) %t32. mode number/pointer of sprite - 1bpp sprites have hi bits set.\n", wp->save_mode, wp->save_mode >> 27));
  newline();

  dprintf(("", "save_maskinshift=%i      %t32. initial bit shift within mask word.\n", wp->save_maskinshift));
  dprintf(("", "save_maskinptr=0x%x      %t32. word address of mask (or 0 if there isn't one).\n", wp->save_maskinptr));
  dprintf(("", "save_maskinoffset=%i     %t32. byte offset between mask rows - SUBTRACT for next row.\n", wp->save_maskinoffset));
  newline();

  dprintf(("", "BPP=%i                   %t32. bits per pixel of output.\n", wp->BPP));
  dprintf(("", "BPC=%i                   %t32. bits per character of output (only different for double pixels).\n", wp->BPC));
  dprintf(("", "ColourTTR=0x%x           %t32. translation table or palette.\n", wp->ColourTTR));
  dprintf(("", "TTRType=0x%x             %t32. translation table type.\n", wp->TTRType));
  dprintf(("", "spritecode=%i (& 255 = %i) %t32. SpriteOp - 52 for PutSpriteScaled, 50 for PlotMaskScaled.\n", wp->spritecode, wp->spritecode & 255));
  dprintf(("", "blending=%i              %t32. b0: translucency blending, b1: alpha mask/channel blending\n", wp->blending));
  newline();
}
#endif

#ifdef TESTDEBUG
static void dump_workspace(workspace *ws)
{
  code_buffer *p;

  dprintf(("", "Dumping workspace.\n"));
  #define DUMPINT(field) dprintf(("", "%s = %i.\n", #field, ws->field));
  DUMPINT(build_buffer)
  FOR_EACH_BUFFER(p) dprintf(("", "buffer->keyword = %i.\n", p->key_word));
}
#endif

/**************************************************************************
*                                                                         *
*    Low-level instruction generation.                                    *
*                                                                         *
**************************************************************************/

/* Condition codes */
#define EQ 0xf0000000      /* It's 0 really - frigged so that 0 can be 'always' - the usual case. */
#define NE 0x10000000
#define CS 0x20000000
#define CC 0x30000000
#define MI 0x40000000
#define PL 0x50000000
#define VS 0x60000000
#define VC 0x70000000
#define HI 0x80000000
#define LS 0x90000000
#define GE 0xa0000000
#define LT 0xb0000000
#define GT 0xc0000000
#define LE 0xd0000000
#define AL 0xe0000000
#define HS CS
#define LO CC

/* Branches */
#define B  0x0a000000
#define BL 0x0b000000
#define B_OFFSET_MASK 0x00ffffff /* and with this for negative offsets */
#define BLX(reg,str) ins(ws,0x012FFF30 | reg,str)

/* ALU ops */
#define S  (1<<20)
#define AND(dst,op1,rest,str)      ins(ws,(0x0 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define EOR(dst,op1,rest,str)      ins(ws,(0x1 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define SUB(dst,op1,rest,str)      ins(ws,(0x2 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define RSB(dst,op1,rest,str)      ins(ws,(0x3 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define ADD(dst,op1,rest,str)      ins(ws,(0x4 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define ADC(dst,op1,rest,str)      ins(ws,(0x5 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define SBC(dst,op1,rest,str)      ins(ws,(0x6 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define RSC(dst,op1,rest,str)      ins(ws,(0x7 << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define TST(op1,rest,str)          ins(ws,(0x8 << 21) | S | OP1R(op1) | (rest), str)
#define TEQ(op1,rest,str)          ins(ws,(0x9 << 21) | S | OP1R(op1) | (rest), str)
#define CMP(op1,rest,str)          ins(ws,(0xa << 21) | S | OP1R(op1) | (rest), str)
#define CMN(op1,rest,str)          ins(ws,(0xb << 21) | S | OP1R(op1) | (rest), str)
#define ORR(dst,op1,rest,str)      ins(ws,(0xc << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define MOV(dst,rest,str)          ins(ws,(0xd << 21) | DSTR(dst) | (rest), str)
#define BIC(dst,op1,rest,str)      ins(ws,(0xe << 21) | DSTR(dst) | OP1R(op1) | (rest), str)
#define MVN(dst,rest,str)          ins(ws,(0xf << 21) | DSTR(dst) | (rest), str)

#define MUL(dst,op1,op2,rest,str)  ins(ws,(9<<4) | ((dst)<<16) | (op1) | ((op2)<<8) | (rest), str)

/* CPUFlag_T2 instructions */
#define MOVW(dst,rest,str)         ins(ws,(3<<24) | DSTR(dst) | (rest), str)
#define MOVT(dst,rest,str)         ins(ws,(0x34<<20) | DSTR(dst) | (rest), str)
#define UBFX(dst,src,lsb,width,rest,str) ins(ws,0x07e00050 | DSTR(dst) | (src) | (((width)-1)<<16) | ((lsb)<<7) | (rest), str)
#define BFC(dst,lsb,width,rest,str) ins(ws,0x07c0001f | DSTR(dst) | (((lsb)+(width)-1)<<16) | ((lsb)<<7) | (rest), str)
#define BFI(dst,src,lsb,width,rest,str) ins(ws,0x07c00010 | DSTR(dst) | (src) | (((lsb)+(width)-1)<<16) | ((lsb)<<7) | (rest), str)

#define REV(dst,src,rest,str)      ins(ws,0x06bf0f30 | DSTR(dst) | (src) | (rest), str)

#define ADD_OPCODE (0x4 << 21)
#define SUB_OPCODE (0x2 << 21)
#define MOV_OPCODE (0xd << 21)

#define DSTR(x) ((x) << 12)          /* destination - ignored by TST/TEQ/CMP/CMN */
#define OP1R(x) ((x) << 16)          /* first operand */
#define OP2R(x) ((x) << 0)           /* if !IMM */
#define IMM(x) ((x) | (1<<25))       /* an 8-bit unsigned field */
#define IMMROR(x) ((x) << 7)         /* an EVEN number to rotate right IMM by */

static int IMM12(unsigned int imm)   /* generate immediate constant for ALU ops */
{
  int ror = 0;
  while(imm >= 256)
  {
    assert(ror < 32, ERROR_FATAL);
    imm = (imm<<2) | (imm>>30);
    ror += 2;
  }
  return IMM(imm) | IMMROR(ror);
}

#define IMM16(x) (((x) & 0xFFF) | (((x) & 0xF000)<<4)) /* encode 16 bit immediate constant for MOVW/MOVT */ 

#define LSLI(x) (((x) << 7) | 0x00)   /* 5-bit immed shift applied to OP2R */
#define LSRI(x) (((x) << 7) | 0x20)
#define ASRI(x) (((x) << 7) | 0x40)
#define RORI(x) (((x) << 7) | 0x60)

#define LSLR(x) (((x) << 8) | 0x10)   /* shift register applied to OP2R */
#define LSRR(x) (((x) << 8) | 0x30)
#define ASRR(x) (((x) << 8) | 0x50)
#define RORR(x) (((x) << 8) | 0x70)

/* Load and store ops */
#define LDR(reg,basereg)  (0x04100000 | ((reg) << 12)| ((basereg) << 16))
#define STR(reg,basereg)  (0x04000000 | ((reg) << 12)| ((basereg) << 16))
#define LDRB(reg,basereg) (0x04500000 | ((reg) << 12)| ((basereg) << 16))
#define STRB(reg,basereg) (0x04400000 | ((reg) << 12)| ((basereg) << 16))

#define WRITEBACK (1 << 21)
#define ADDOFFSET (1 << 23) /* else subtract */
#define PREADD (1 << 24) /* else post */

#define OFFSET(x) (PREADD | ADDOFFSET | (x))        /* normal simple index */
#define NEGOFFSET(x) (PREADD | (x))                 /* subtract offset */
#define PREINC(x) (WRITEBACK | ADDOFFSET | PREADD | (x))
#define PREDEC(x) (WRITEBACK | PREADD | (x))
#define POSTINC(x) (ADDOFFSET | (x))                /* The manual says, do not set WRITEBACK if doing post-addition */
#define POSTDEC(x) ((x))                            /* writeback will always occur, setting it is does LDRT/LDRBT */

#define PUSH (0x08000000 | (13<<16) /* register 13 */ \
                         | (1<<21) /* write-back */ \
                         | (1<<24) /* add offset before transfer */)
#define POP  (0x08000000 | (13<<16) /* register 13 */ \
                         | (1<<20) /* load from memory */ \
                         | (1<<21) /* write-back */ \
                         | (1<<23) /* add, not subtract */ )

#define LDMIA(reg) (0x08000000 | (reg<<16) /* register to load from */ \
                               | (1<<20) /* load from memory */ \
                               | (1<<23) /* add, not subtract */ )

#define STMIA(reg) (0x08000000 | (reg<<16) /* register to load from */ \
                               | (1<<23) /* add, not subtract */ )

/* Supervisor call */
#define SWI(swino) (0x0F000000 | swino)

/* Indexed load - LSL shift assumed - writeback or negative not covered */
#define INDEX(reg, shift) ((1<<25) | OFFSET(0) | OP2R(reg) | LSLI(shift))

/* Indexed load - LSR shift - writeback or negative not covered */
#define INDEX_LSR(reg, shift) ((1<<25) | OFFSET(0) | OP2R(reg) | LSRI(shift))

/* Offset in assembler workspace */
#define WP_OFFSET(field) OFFSET(((char*)&(wp->field)) - ((char*)&(wp->WP_FIRST_FIELD)))

/* Offset in stack workspace */
#define SP_OFFSET(field) OFFSET((int) (((char*)&(((stack_ws *)0)->field)) + ws->compiled_routine_stacked))

/* Define an assembler register */
#define RN(name,no,flags,describe) set_regname(ws, &ws->regnames.name, no, flags, describe);

#ifdef DEBUG
static void ldm_reg_list(workspace *ws, char *a, int regmask, BOOL lastname)
/* Construct a string in a which can be placed in curly brackets, describing
 * a LDM/STM instruction. If lastname then find the last such register name in
 * the case of duplicates - eg. the y-loop name rather than the x-loop name
 * for the same physical register.
 */
{
  int i;
  regname *r;
  BOOL found;
  char *aptr;

  a[0] = 0;
  for (i = 0; i <= 15; i++) /* for each physical register */
  {
    if ((regmask & (1<<i)) != 0) /* find a name for this register */
    {
      found = FALSE;
      aptr = a;
      while (*aptr != 0) aptr++; /* points at the null at the end of the string */
      FOR_EACH_REGISTER_NAME(r)
      {
        if (r->regno == i)
        {
          *aptr = 0; /* If lastname and finding it again, delete last one */
          if (a[0] != 0) strcat(aptr, ",");
          strcat(aptr, r->name);
          found = TRUE;
          if (!lastname) break;
        }
      }
      assert(found, ERROR_FATAL);
    }
  }
}
#endif

#ifdef DEBUG
static void ins(workspace *ws, int w, char *description)
#else
#define ins(ws,w,description) do_ins(ws,w)
static void do_ins(workspace *ws, int w)
#endif
/* Put an instruction into the output buffer.
 * When debugging an assembler listings is generated too. These can be fed through
 * objasm, and the results compared with the opcodes that I generate.
 * Columns of assembler output:
 * addressX  opcodeXX  label   opcodes regs                            comment
 * ^0        ^10       ^20     ^28     ^36                             ^68
 */
{
  int ccode = w & 0xf0000000;

  /* Handle the AL/EQ condition codes being wrong, so that 0 can be AL elsewhere. */
  if (ccode == 0xf0000000) w = w & 0x0fffffff;   /* EQ code */
  else if (ccode == 0) w = w | 0xe0000000;       /* AL code */
  /* All others are per the ARM expects */
  dprintf(("", "%x  %x  %t28.%s\n", 
    (ws->compile_ptr - ws->compile_base) * sizeof(int), 
    w, description)); /* pseudo-assembler format of output */

  assert(ws->compile_ptr < ws->compile_lim, ERROR_NO_MEMORY); /* Check the buffer is big enough */
  *(ws->compile_ptr)++ = w; /* Store at then increment P% */
}

#ifdef DEBUG
#define DEFINE_LABEL(lab,describe) define_label(ws, L(lab), describe);
static void define_label(workspace *ws, label *lab, char *description)
#else
#define DEFINE_LABEL(lab,describe) define_label(ws, L(lab));
static void define_label(workspace *ws, label *lab)
#endif
/* Define a label, and fill in a forward reference to it if necessary. */
{
   assert(lab->def == 0, ERROR_FATAL); /* Check not defined twice */
   lab->def = ws->compile_ptr;
   dprintf(("", "%t20.%s%t68.); %s\n", lab->name, description));
   if (lab->ref != 0)
   {
     int newvalue = *(lab->ref) | (B_OFFSET_MASK & (lab->def - (lab->ref + 2))); /* compute offset */
     dprintf(("", "%t20.); Zapping forward ref instruction at %x to be %x.\n", 
       sizeof(int) * (lab->ref - ws->compile_base), newvalue));
     *(lab->ref) = newvalue;
     lab->ref = 0;
   }
}

#ifdef DEBUG
static void branch(workspace *ws, unsigned int opcode, label *lab, char *description)
#else
#define branch(ws,opcode,lab,description) do_branch(ws,opcode,lab)
static void do_branch(workspace *ws, unsigned int opcode, label *lab)
#endif
/* Compile a branch instruction to a label. The opcode includes the condition code. */
{
  if (lab->def == 0) /* Forward reference */
  {
#ifdef DEBUG
    if (lab->ref != 0)
      dprintf(("", "Already referenced at 0x%x\n", sizeof(int) * (lab->ref - ws->compile_base)));
#endif
    assert(lab->ref == 0, ERROR_FATAL); /* Check for two forward refs to same label */
    lab->ref = ws->compile_ptr;
    ins(ws, opcode, description); /* Just give as offset 0 for now */
  }
  else
  {
    assert(lab->ref == 0, ERROR_FATAL);
    ins(ws,
      opcode | (B_OFFSET_MASK & (lab->def - (ws->compile_ptr + 2))), description);
  }
}

#ifdef DEBUG
static void set_regname(workspace *ws, regname *r, int regno, int flags, char *describe)
#else
#define set_regname(ws,r,regno,flags,describe) do_set_regname(ws,r,regno,flags)
static void do_set_regname(workspace *ws, regname *r, int regno, int flags)
#endif
/* Allocate a physical register number. If regno is -1 then allocate an
 * as-yet-unused one, otherwise it's a specific register number.
 */
{
  UNUSED(ws);
  if(regno != -1)
  {
    assert((r->regno == -1) || (r->regno == regno), ERROR_FATAL);
    r->regno = regno;
  }
  r->flags |= flags;
#ifdef DEBUG
  r->describe = describe;
#endif
}

static void align16(asm_workspace *wp, workspace *ws)
/* Align next instruction to quadword boundary */
{
  UNUSED(wp);
  while (((int)ws->compile_ptr & 15) != 0)
    MOV(R(r_pixel), OP2R(R(r_pixel)),                        "MOV     r_pixel,r_pixel                 ; align to 16-byte boundary");
}

/* Loading a constant index from the workspace pointer */
#define LDR_WP(reg,value) ins(ws, LDR(R(reg),R(wp)) + WP_OFFSET(value), \
                              "LDR     " #reg "," #value);

#ifdef DEBUG
  #define LDR_WP_C(reg,value, comment)                                \
  {                                                                   \
    char a[256];                                                      \
    do_sprintf(a, "LDR     " #reg "," #value " %t40.; " comment);        \
    ins(ws, LDR(R(reg),R(wp)) + WP_OFFSET(value), a);                 \
  }
#else
  #define LDR_WP_C(reg,value, comment) ins(ws, LDR(R(reg),R(wp)) + WP_OFFSET(value), 0);
#endif

/* Loading a constant index from a register */
#ifdef DEBUG
  #define LDR_INDEX(destreg,indexreg,offset,comment)                                      \
  {                                                                                       \
    char a[256];                                                                          \
    do_sprintf(a, "LDR     " #destreg ",[" #indexreg ", #%i] %t40.; " comment, offset);      \
    ins(ws, LDR(R(destreg),R(indexreg)) | OFFSET(offset), a);                             \
  }
#else
  #define LDR_INDEX(destreg,indexreg,offset,comment) ins(ws, LDR(R(destreg),R(indexreg)) | OFFSET(offset), 0);
#endif

/* Loading/storing a constant index from the stack */
#define LDR_SP(reg,value) ins(ws, LDR(R(reg),R(sp)) + SP_OFFSET(value), \
                              "LDR     " #reg "," #value " + compiled_routine_stacked");
#define STR_SP(reg,value) ins(ws, STR(R(reg),R(sp)) + SP_OFFSET(value), \
                              "STR     " #reg "," #value " + compiled_routine_stacked");

#define ADD_A(reg,value) arbitrary_add(ws, TRUE, FALSE, &ws->regnames.reg, value);
#define ADDS_A(reg,value) arbitrary_add(ws, TRUE, TRUE, &ws->regnames.reg, value);
#define SUB_A(reg,value) arbitrary_add(ws, FALSE, FALSE, &ws->regnames.reg, value);
#define SUBS_A(reg,value) arbitrary_add(ws, FALSE, TRUE, &ws->regnames.reg, value);

static void arbitrary_add(workspace *ws, BOOL add, BOOL s, regname *r, int value)
/* Add/subtract an arbitrary constant to a register - could be more than 8 bits. */
{
#ifdef DEBUG
  char a[256];
#endif
  if (value < 0) {value = -value; add = !add;}
  if (value == 0) /* special case with 0 constant */
  {
    if (s)
    {
      dsprintf((a, "CMP     %s,#0", r->name));
      CMP(r->regno, IMM(0), a);
    }
    /* else, nothing */
  }
  else
  {
    int opcode = add ? ADD_OPCODE : SUB_OPCODE;
    int sopcode = s ? S : 0;
    int shift_it = 0;

    while (value != 0)
    {
      BOOL last;
      int valuebyte;

      if (value > 255)
        while ((value & 3) == 0) {value >>= 2; shift_it += 2;}
      valuebyte = value & 0xff;
      value &= 0xffffff00;
      last = value == 0; /* the last instruction needed */
      dsprintf((a,
          (last && sopcode ? "%sS%t8.%s,%s,#&%x" : "%s%t8.%s,%s,#&%x"),
          (add ? "ADD" : "SUB"), r->name, r->name, valuebyte << shift_it));
      ins(ws, opcode | (last ? sopcode : 0)
            | DSTR(r->regno) | OP1R(r->regno)
            | IMM(valuebyte) | IMMROR ((32 - shift_it) & 0x1e),
            a);
    }
  }
}

static int countbits(unsigned int bits)
/* Return count of how many bits are set */
{
  bits -= (bits & 0xaaaaaaaa)>>1;
  bits = (bits & 0x33333333) + ((bits>>2) & 0x33333333);
  bits += bits>>4;
  bits &= 0x0f0f0f0f;
  bits += bits>>8;
  bits += bits>>16;
  return (bits & 0xff);
}

/**************************************************************************
*                                                                         *
*    Register management                                                  *
*                                                                         *
**************************************************************************/
#ifdef DEBUG
static void dump_registers(asm_workspace *wp, workspace *ws)
{
  UNUSED(wp);
  regname *r;
  FOR_EACH_REGISTER_NAME(r)
  {
    dprintf(("", "%s: %x %x\n", r->name, r->regno, r->flags));
  }
}
#endif

static void allocate_registers(asm_workspace *wp, workspace *ws)
{
  UNUSED(wp);
  regname *r;
  /* Iterate through all registers and assign register numbers
     For registers that must be saved to stack, allocate stack space */
  int usedregs[15];
  for(int i=0;i<15;i++)
    usedregs[i] = 0;
  FOR_EACH_REGISTER_NAME(r)
  {
    if((r->regno >= 0) && (r->regno < 15))
    {
      usedregs[r->regno] |= r->flags & REGFLAG_USAGE_MASK;
    }
  }
  /* Allocate in order of importance - global, then per-pixel, then x-loop, etc. */
  for(int i=REGFLAG_GLOBAL;i<=REGFLAG_YLOOP;i<<=1)
  {
    FOR_EACH_REGISTER_NAME(r)
    {
      if(!(r->flags & i) || (r->regno != -1))
        continue;
      /* Look for a free register
         We prefer a completely free register, or if none is available, the first one that doesn't clash with this allocation
         Additionally, temporary registers are allocated from the top, non-temporary from the bottom, as I think this may help in some situations */
      int regno=-1,nextbest=-1;
      int blocking = (r->flags & REGFLAG_USAGE_MASK) | REGFLAG_GLOBAL;
      if(r->flags & REGFLAG_TEMPORARY)
      {
        for(int j=14;j>=0;j--)
        {
          if(!usedregs[j])
          {
            regno = j;
            break;
          }
          if(!(usedregs[j] & blocking) && (nextbest == -1))
          {
            nextbest = j;
          }
        }
      }
      else
      {
        for(int j=0;j<15;j++)
        {
          if(!usedregs[j])
          {
            regno = j;
            break;
          }
          if(!(usedregs[j] & blocking) && (nextbest == -1))
          {
            nextbest = j;
          }
        }
      }
      if(regno == -1)
      {
        regno = nextbest;
        assert(regno != -1, ERROR_FATAL);
      }
      r->regno = regno;
      usedregs[regno] |= r->flags & REGFLAG_USAGE_MASK;
      dprintf(("", "%s -> %i in %i\n", r->name, r->regno, i));
    }
  }
  /* Work out which registers need saving on the stack */
  regname *frame[4][15];
  for(int i=0;i<4;i++)
  {
    for(int j=0;j<15;j++)
      frame[i][j] = 0;
  }
  FOR_EACH_REGISTER_NAME(r)
  {
    if((r->regno < 0) || (r->regno >= 16) || (r->flags & REGFLAG_GLOBAL))
      continue;
    for(int i=0;i<4;i++)
    {
      if(r->flags & (REGFLAG_PERPIXEL<<i))
      {
#ifdef DEBUG
        if (frame[i][r->regno]) dprintf(("", "%s %x vs. %s %x\n", frame[i][r->regno]->name, frame[i][r->regno]->regno, r->name, r->regno));
#endif        
        assert(!frame[i][r->regno], ERROR_FATAL);
        frame[i][r->regno] = r;
      }
    }
  }
  ws->regframesize = 0;
  for(int i=0;i<4;i++)
  {
    for(int j=0;j<15;j++)
    {
      if(!frame[i][j] || (frame[i][j]->flags & REGFLAG_TEMPORARY) || (frame[i][j]->spindex != -1))
        continue;
      for(int k=0;k<4;k++)
      {
        if((k != i) && frame[k][j] && (frame[k][j] != frame[i][j]))
        {
          /* Need to save this reg */
#ifdef DEBUG
          if(!ws->regframesize) dprintf(("", "%t20.; Stack frame layout:\n"));
          dprintf(("", "%20.; +%x %s R%i\n", ws->regframesize, frame[i][j]->name, frame[i][j]->regno & 15));
#endif
          frame[i][j]->spindex = ws->regframesize;
          ws->regframesize += 4;
          break;
        }
      }
    }
  }
  FOR_EACH_REGISTER_NAME(r)
  {
    assert(!(r->flags && (r->regno == -1)), ERROR_FATAL); /* All used regs must be assigned */
    /* Resolve any aliased registers */
    if((r->regno < -1) || (r->regno >= 16))
    {
      regname *rr = (regname *) r->regno;
      r->regno = rr->regno;
      assert((r->regno & 0xff) < 16, ERROR_FATAL);
      r->flags = rr->flags;
      r->spindex = rr->spindex;
    }
    /* Set availability */
    if(!(r->flags & (REGFLAG_GLOBAL | REGFLAG_INPUT | REGFLAG_USED)))
      r->regno |= 0x80000000;
#ifdef DEBUG
    /* Output definition */
    if((r->regno & 0xff) < 16)
    {
      dprintf(("", "%t20.%s%t27 RN %t36.%i %t68.; %s\n", r->name, (r->regno & 0xff), r->describe));
    }
#endif
  }
#ifdef DEBUG
  dump_registers(wp,ws);
#endif  
}

static void reserve_regstackframe(asm_workspace *wp, workspace *ws)
{
  UNUSED(wp);
  /* Reserve stack space */
  if(ws->regframesize)
    SUB_A(sp, ws->regframesize)
}

static void discard_regstackframe(asm_workspace *wp, workspace *ws)
{
  UNUSED(wp);
  /* Pop all saved registers off the stack */
  if(ws->regframesize)
    ADD_A(sp, ws->regframesize)
}

static void begin_init_bank(asm_workspace *wp, workspace *ws, int bank)
{
  UNUSED(wp);
  /* Mark regs in 'bank' as switched in */
  regname *r;
  bank |= REGFLAG_GLOBAL | REGFLAG_USED;
  FOR_EACH_REGISTER_NAME(r)
  {
    if(r->flags & bank)
    {
      r->regno &= ~0x80000000;
    }
    else
    {
      r->regno |= 0x80000000;
    }
  }
  dprintf(("", "begin_init_bank %x\n", bank));
}

static void save_bank(asm_workspace *wp, workspace *ws, regname **savelist, int temp, BOOL allow_auto_temp)
{
  UNUSED(wp);
  /* Optimised save of given list */
#ifdef DEBUG
  char a[256];
  char b[256];
#endif  
  int base=-1;
  int count=0;
  int mask=0;
  int offset = ws->regframeoffset;
  for(int i=0;i<15;i++)
  {
    if(!savelist[i])
      continue;
    if((temp == -1) && (savelist[i]->spindex+offset))
    {
      dsprintf((a,"STR     %s,[sp,#%i+%i]",savelist[i]->name,savelist[i]->spindex,offset));
      ins(ws, STR(savelist[i]->regno & 0xff, R(sp)) | OFFSET(savelist[i]->spindex+offset), a);
      /* If we're in end_init_bank, disallow selection of temp register here, as we assume that any regs we're saving in end_init_bank will remain valid in the future */
      if(allow_auto_temp)
      {
        temp = savelist[i]->regno;
      }
    }
    else if(base == -1)
    {
      base = i;
      count = 1;
      mask = 1<<i;
#ifdef DEBUG
      b[0] = 0;
      strcat(b,savelist[i]->name);
#endif      
    }
    else if(savelist[i]->spindex == savelist[base]->spindex + count*4)
    {
      count++;
      mask |= 1<<i;
#ifdef DEBUG
      strcat(b,",");
      strcat(b,savelist[i]->name);
#endif      
    }
    else
    {
      if(count == 1)
      {
        dsprintf((a,"STR     %s,[sp,#%i+%i]",savelist[base]->name,savelist[base]->spindex,offset));
        ins(ws, STR(savelist[base]->regno & 0xff, R(sp)) | OFFSET(savelist[base]->spindex+offset), a);
      }
      else if(savelist[base]->spindex+offset)
      {
        assert((savelist[base]->spindex+offset) < 256, ERROR_FATAL);
        dsprintf((a,"ADD     R%i,sp,#%i+%i",temp,savelist[base]->spindex,offset));
        ADD(temp,R(sp),IMM(savelist[base]->spindex+offset),a);
        dsprintf((a,"STMIA   R%i,{%s}",temp,b));
        ins(ws, STMIA(temp) | mask, a);
      }
      else
      {
        dsprintf((a,"STMIA   sp,{%s}",b));
        ins(ws, STMIA(R(sp)) | mask, a);
      }
      base = i;
      count = 1;
      mask = 1<<i;
    }
  }
  if(!count)
    return;
  if(count == 1)
  {
    dsprintf((a,"STR     %s,[sp,#%i+%i]",savelist[base]->name,savelist[base]->spindex,offset));
    ins(ws, STR(savelist[base]->regno & 0xff, R(sp)) | OFFSET(savelist[base]->spindex+offset), a);
  }
  else if(savelist[base]->spindex+offset)
  {
    assert((savelist[base]->spindex+offset) < 256, ERROR_FATAL);
    dsprintf((a,"ADD     R%i,sp,#%i+%i",temp,savelist[base]->spindex,offset));
    ADD(temp,R(sp),IMM(savelist[base]->spindex+offset),a);
    dsprintf((a,"STMIA   R%i,{%s}",temp,b));
    ins(ws, STMIA(temp) | mask, a);
  }
  else
  {
    dsprintf((a,"STMIA   sp,{%s}",b));
    ins(ws, STMIA(R(sp)) | mask, a);
  }
}

static void load_bank(asm_workspace *wp, workspace *ws, regname **loadlist)
{
  UNUSED(wp);
  /* Optimised load of given list */
#ifdef DEBUG
  char a[256];
  char b[256];
#endif  
  int base=-1;
  int count=0;
  int mask=0;
  int offset = ws->regframeoffset;
  for(int i=0;i<15;i++)
  {
    if(!loadlist[i])
      continue;
    if(base == -1)
    {
      base = i;
      count = 1;
      mask = 1<<i;
#ifdef DEBUG
      b[0] = 0;
      strcat(b,loadlist[i]->name);
#endif      
    }
    else if(loadlist[i]->spindex == loadlist[base]->spindex + count*4)
    {
      count++;
      mask |= 1<<i;
#ifdef DEBUG
      strcat(b,",");
      strcat(b,loadlist[i]->name);
#endif      
    }
    else
    {
      if(count == 1)
      {
        dsprintf((a,"LDR     %s,[sp,#%i+%i]",loadlist[base]->name,loadlist[base]->spindex,offset));
        ins(ws, LDR(loadlist[base]->regno & 0xff, R(sp)) | OFFSET(loadlist[base]->spindex+offset), a);
      }
      else if(loadlist[base]->spindex+offset)
      {
        assert((loadlist[base]->spindex+offset) < 256, ERROR_FATAL);
        dsprintf((a,"ADD     %s,sp,#%i+%i",loadlist[base]->name,loadlist[base]->spindex,offset));
        ADD(loadlist[base]->regno,R(sp),IMM(loadlist[base]->spindex+offset),a);
        dsprintf((a,"LDMIA   %s,{%s}",loadlist[base]->name,b));
        ins(ws, LDMIA(loadlist[base]->regno) | mask, a);
      }
      else
      {
        dsprintf((a,"LDMIA   sp,{%s}",b));
        ins(ws, LDMIA(R(sp)) | mask, a);
      }
      base = i;
      count = 1;
      mask = 1<<i;
    }
  }
  if(!count)
    return;
  if(count == 1)
  {
    dsprintf((a,"LDR     %s,[sp,#%i+%i]",loadlist[base]->name,loadlist[base]->spindex,offset));
    ins(ws, LDR(loadlist[base]->regno & 0xff, R(sp)) | OFFSET(loadlist[base]->spindex+offset), a);
  }
  else if(loadlist[base]->spindex+offset)
  {
    assert((loadlist[base]->spindex+offset) < 256, ERROR_FATAL);
    dsprintf((a,"ADD     %s,sp,#%i+%i",loadlist[base]->name,loadlist[base]->spindex,offset));
    ADD(loadlist[base]->regno,R(sp),IMM(loadlist[base]->spindex+offset),a);
    dsprintf((a,"LDMIA   %s,{%s}",loadlist[base]->name,b));
    ins(ws, LDMIA(loadlist[base]->regno) | mask, a);
  }
  else
  {
    dsprintf((a,"LDMIA   sp,{%s}",b));
    ins(ws, LDMIA(R(sp)) | mask, a);
  }
}

static void end_init_bank(asm_workspace *wp, workspace *ws, int bank)
{
  /* Save all 'bank' registers (including constants) */
  regname *r;
  regname *savelist[15];
  for(int i=0;i<15;i++)
    savelist[i] = 0;
  BOOL dosave = FALSE;
  int temp = -1;
  FOR_EACH_REGISTER_NAME(r)
  {
    if((r->flags & bank) && (r->spindex != -1) && !(r->flags & REGFLAG_INPUT))
    {
      savelist[r->regno & 15] = r;
      dosave = TRUE;
    }
    if((r->regno >= 0) && (r->regno < 16) && (r->flags & REGFLAG_TEMPORARY))
      temp = r->regno;
  }
  if(dosave)
  {
    save_bank(wp, ws, savelist, temp, FALSE);
  }
  dprintf(("", "end_init_bank %x\n", bank));
}

static void switch_bank(asm_workspace *wp, workspace *ws, int oldbank, int newbank)
{
  /* Save all non-constant 'oldbank', load all 'newbank'
     Special hack: if newbank == 0, also save constant oldbank (used to save input regs) */
  regname *r;
  regname *savelist[15];
  regname *loadlist[15];
  for(int i=0;i<15;i++)
  {
    savelist[i] = 0;
    loadlist[i] = 0;
  }
  BOOL dosave = FALSE;
  BOOL doload = FALSE;
  int temp = -1;
  FOR_EACH_REGISTER_NAME(r)
  {
    if(r->spindex != -1)
    {
      if((r->flags & oldbank) /* It's in the old bank */
      && !(r->flags & newbank) /* And it's not in the new bank */
      && (!(r->flags & REGFLAG_CONSTANT) || !newbank)) /* And it's non-constant */
      {
        savelist[r->regno & 15] = r; /* Then save it */
        dosave = TRUE;
      }
      else if((r->flags & newbank) /* It's in the new bank */
          && !(r->flags & oldbank)) /* And it's not in the old bank */
      {
        loadlist[r->regno & 15] = r; /* Then load it */
        doload = TRUE;
      }
    }
    if((r->regno >= 0) && (r->regno < 16) && (r->flags & REGFLAG_TEMPORARY) && !(r->flags & newbank))
      temp = r->regno;
  }
  /* Loop round again to update the flags, and to search harder for a temp register (temp reg search needs 2nd loop as we need to know we're not about to clobber a register we need to save) */
  FOR_EACH_REGISTER_NAME(r)
  {
    if(r->flags & (newbank | REGFLAG_GLOBAL | REGFLAG_USED))
    {
      if((r->regno & 0x80000000) && !savelist[r->regno & 15] && (loadlist[r->regno & 15] || ((r->flags & REGFLAG_TEMPORARY) && !(r->flags & oldbank))))
        temp = r->regno & 0xff;
      r->regno &= ~0x80000000;
    }
    else
      r->regno |= 0x80000000;
  }
  if(dosave)
  {
    save_bank(wp, ws, savelist, temp, TRUE);
  }
  if(doload)
  {
    load_bank(wp, ws, loadlist);
  }
  dprintf(("", "switch_bank %x -> %x\n", oldbank, newbank));
}

/**************************************************************************
*                                                                         *
*    Pixel format information                                             *
*                                                                         *
**************************************************************************/

extern const PixelFormatInfo *pixelformat_info(int format);

static int PIXELFORMAT_ALPHA_MASK(int format)
{
  const PixelFormatInfo *pf=pixelformat_info(format);
  return ((1<<pf->bits[3])-1)<<(pf->top[3]-pf->bits[3]);
}

#define PIXELFORMAT_ALPHA_IMM(format) (pixelformat_info(format)->alphaimm12 | (1<<25))

static PixelFormat compute_pixelformat(int ncolour,int modeflags,int log2bpp)
{
  dprintf(("", "compute_pixelformat: %x %x %d\n", ncolour, modeflags, log2bpp));
  if(log2bpp <= 3)
    return (PixelFormat) log2bpp;
  PixelFormat baseformat;
  if(log2bpp == 4)
  {
    if(modeflags & ModeFlag_64k)
    {
      baseformat = PixelFormat_16bpp;
      modeflags &= ~ModeFlag_DataFormatSub_Alpha;
    }
    else if(ncolour < 4096)
      baseformat = PixelFormat_12bpp;
    else
      baseformat = PixelFormat_15bpp;
  }
  else if(log2bpp == 6)
  {
    baseformat = PixelFormat_24bpp;
    modeflags &= ~ModeFlag_DataFormatSub_Alpha;
  }
  else
  {
    /* Assume 32bpp */
    baseformat = PixelFormat_32bpp;
  }
  if(modeflags & ModeFlag_DataFormatSub_RGB)
    baseformat = (PixelFormat) (baseformat | PixelFormat_RGB);
  if(modeflags & ModeFlag_DataFormatSub_Alpha)
    baseformat = (PixelFormat) (baseformat | PixelFormat_Alpha);
  return baseformat;
}

/**************************************************************************
*                                                                         *
*    Blending utility functions                                           *
*                                                                         *
**************************************************************************/

static BlendImpl compute_blendimpl(asm_workspace *wp, workspace *ws, BOOL *use_sprite_palette)
{
  if(!wp->blending)
    return BlendImpl_None;

  if((ws->out_pixelformat <= PixelFormat_8bpp) && !(wp->blending & 2))
  {
    /* Use blend table
       If src is true colour, use ColourTTR to convert to screen first */
    if(wp->TTRType == TTRType_Normal+TTRType_Optional)
    {
      /* Ignore TTR and use sprite palette directly for a higher quality blend. */
      wp->ColourTTR = 0; /* Nuke the pointer so that we don't attempt to allocate registers for it */
      wp->TTRType = TTRType_None;
      *use_sprite_palette = TRUE;
      dprintf(("", "** ignoring ColourTTR due to BlendTable usage **\n"));
    }
    return BlendImpl_BlendTable;
  }
  else if(ws->out_pixelformat >= PixelFormat_8bpp)
  {
    /* True colour blend */
    if(ws->out_pixelformat == PixelFormat_8bpp)
    {
      if(wp->TTRType == TTRType_32K+TTRType_Optional)
      {
        /* Ignore TTR if we're going to use InverseTable blending method with true colour source
           TODO - Allow to be ignored if palettised source, just need to look up via palette instead */
        wp->ColourTTR = 0;
        wp->TTRType = TTRType_None;
        dprintf(("", "** ignoring ColourTTR due to InverseTable usage with true colour source **\n"));
      }
      return BlendImpl_InverseTable;
    }
    else
    {
      return BlendImpl_True;
    }
  }
  else
  {
    /* Screen is <= 4bpp, use lots of blendtables
       If src is true colour, use ColourTTR to convert to screen
       Else use palette index directly */
    return BlendImpl_BlendTables;
  }
}

static void blendimpl_rn(asm_workspace *wp, workspace *ws)
{
  (void) wp;

  switch(ws->blendimpl)
  {
  case BlendImpl_InverseTable:
  case BlendImpl_True:
  case BlendImpl_BlendTables:
    if(wp->blending & 2)
    {
      RN(r_alpha, -1, REGFLAG_PERPIXEL+REGFLAG_TEMPORARY, "alpha for pixel blending temporary values");
    }
    if(wp->blending & 1)
    {
      RN(r_translucency, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "sprite translucency value");
      if(!(wp->blending & 2))
      {
        /* Set r_alpha == r_translucency */
        RN(r_alpha, (int) &ws->regnames.r_translucency, REGFLAG_USED, "sprite translucency again");
      }
    }
    break;
  }

  switch(ws->blendimpl)
  {
  default:
    assert(0, ERROR_FATAL);
  case BlendImpl_None:
    break;
  case BlendImpl_InverseTable:
    RN(r_screenpalette, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "Screen 8bpp -> 15bpp table");
    RN(r_inversetable, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "15bpp -> screen table");
    /* Fall through... */
  case BlendImpl_True:
    assert(ws->regnames.r_outword.flags, ERROR_FATAL);
    ws->regnames.r_outword.flags |= REGFLAG_PERPIXEL;
    if(SOURCE_ALPHAMASK && !ISTRANS)
    {
      assert(ws->regnames.r_maskinword.flags, ERROR_FATAL);
      ws->regnames.r_maskinword.flags |= REGFLAG_PERPIXEL;
    }
    if(DEST_32_BIT)
    {
      assert(ws->regnames.r_outptr.flags, ERROR_FATAL);
      ws->regnames.r_outptr.flags |= REGFLAG_PERPIXEL;
    }
    break;
  case BlendImpl_BlendTable:
    RN(r_blendtable, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "Blend table ptr");
    assert(ws->regnames.r_outword.flags, ERROR_FATAL);
    ws->regnames.r_outword.flags |= REGFLAG_PERPIXEL;
    break;
  case BlendImpl_BlendTables:
    RN(r_blendtable, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "Blend tables ptr");
    assert(ws->regnames.r_outword.flags, ERROR_FATAL);
    ws->regnames.r_outword.flags |= REGFLAG_PERPIXEL;
    if(SOURCE_ALPHAMASK && !ISTRANS)
    {
      assert(ws->regnames.r_maskinword.flags, ERROR_FATAL);
      ws->regnames.r_maskinword.flags |= REGFLAG_PERPIXEL;
    }
    break;
  }

  /* Extra case: Colour mapping to <=8bpp dest needs r_inversetable */
  if((ws->blendimpl != BlendImpl_InverseTable) && (wp->TTRType == TTRType_ColourMap) && (wp->BPP <= 8))
  {
    RN(r_inversetable, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "15bpp -> screen table");
  }
}

static void blendimpl_init(asm_workspace *wp, workspace *ws)
{
  switch(ws->blendimpl)
  {
  default:
    assert(0, ERROR_FATAL);
  case BlendImpl_None:
  case BlendImpl_True:
    break;
  case BlendImpl_BlendTable:
    LDR_WP(r_blendtable, blendtables);
    break;
  case BlendImpl_InverseTable:
    LDR_WP(r_screenpalette, screenpalette);
    LDR_WP(r_inversetable, inversetable);
    break;
  case BlendImpl_BlendTables:
    MOV(R(r_blendtable), OP2R(R(wp)), "MOV     r_blendtable, wp");
    ADD_A(r_blendtable, (((char *) wp->blendtables)-((char *) wp))-4); /* Offset by -4 so that alpha levels 1-6 index the tables */
    break;
  }

  /* Extra case: Colour mapping to <=8bpp dest needs r_inversetable */
  if((ws->blendimpl != BlendImpl_InverseTable) && (wp->TTRType == TTRType_ColourMap) && (wp->BPP <= 8))
  {
    LDR_WP(r_inversetable, inversetable);
  }
}

static void blendimpl_gettables(asm_workspace *wp, workspace *ws, BOOL use_sprite_palette)
{
  _kernel_oserror *e;
  int flags,src1,src2;

  /* Protect some sensitive workspace vars which will be overwritten by recursive SpriteExtend calls */
  int spritecode = wp->spritecode;

  /* Extra case: Colour mapping to <=8bpp dest needs r_inversetable
     In 8bpp modes this will actually be an inversetable, but in < 8bpp we use
     ColourTrans, as InverseTable doesn't support < 8bpp  */
  if((ws->blendimpl != BlendImpl_InverseTable) && (wp->TTRType == TTRType_ColourMap) && (wp->BPP <= 8))
  {
    if(wp->BPP == 8)
    {
      e = _swix(InverseTable_Calculate,_OUTR(0,1),&wp->screenpalette,&wp->inversetable);
    }
    else
    {
      int table[3];
      e = _swix(ColourTrans_SelectTable,_INR(0,7),(SpriteType_New16bpp<<27)+1,-1,-1,-1,table,0,0,0);
      wp->inversetable = table[1];
    }
    if(e)
    {
      EXIT_OSERROR(e);
    }
    wp->spritecode = spritecode;
  }

  if((ws->blendimpl == BlendImpl_None) || (ws->blendimpl == BlendImpl_True))
    return;

  /* As per translate_pixel(), the only time where we don't apply the TTR for a
     BlendTable/BlendTables blend is if it's an optional normal one.
     For BlendImpl_BlendTable any table like this will have been discarded
     already (and use_sprite_palette set to TRUE), but for BlendImpl_BlendTables
     we need to detect the case here.
  */
  if(use_sprite_palette || (wp->TTRType == TTRType_Normal+TTRType_Optional))
  {
    /* Generate tables for blending from sprite to screen */
    flags = BlendTable_Lock+BlendTable_SrcSpritePointer;
    src1 = 256;
    src2 = (int) wp->save_sprite;
  }
  else
  {
    /* Generate tables using just the screen palette */
    flags = BlendTable_Lock;
    src1 = src2 = -1;
  }    

  /* Verify that recursive SpriteExtend calls aren't modifying workspace more than expected */
#ifdef DEBUG
  int backup[sizeof(asm_workspace)/4];
  for(int i=0;i<sizeof(asm_workspace)/4;i++)
    backup[i] = ((int *) wp)[i];
#endif

  switch(ws->blendimpl)
  {
  default:
    assert(0, ERROR_FATAL);
    break;
  case BlendImpl_BlendTable:
    e = _swix(BlendTable_GenerateTable,_INR(0,6)|_OUT(6),flags,src1,src2,-1,-1,wp->trns_flags2>>4,0,&wp->blendtables[0]);
    if(e)
    {
      EXIT_OSERROR(e);
    }
    break;
  case BlendImpl_InverseTable:
    e = _swix(InverseTable_Calculate,_OUTR(0,1),&wp->screenpalette,&wp->inversetable);
    if(e)
    {
      EXIT_OSERROR(e);
    }
    break;
  case BlendImpl_BlendTables:
    {
      for(int i=1;i<7;i++)
      {
        e = _swix(BlendTable_GenerateTable,_INR(0,6)|_OUT(6),flags,src1,src2,-1,-1,256-i*32,0,&wp->blendtables[i-1]);
        if(e)
        {
          EXIT_OSERROR(e);
        }
      }
    }
    break;
  }

  wp->spritecode = spritecode;
#ifdef DEBUG
  BOOL ok = TRUE;
  for(int i=0;i<sizeof(asm_workspace)/4;i++)
  {
    if((backup[i] != ((int *) wp)[i]) && ((OFFSET(i*4) < WP_OFFSET(blendtables)) || (OFFSET(i*4) > WP_OFFSET(inversetable))))
    {
      dprintf(("", "workspace modified! offset %x was %x now %x\n", i*4, backup[i], ((int *) wp)[i]));
      ok = FALSE;
    }
  }
  assert(ok, ERROR_FATAL);
#endif
}

/**************************************************************************
*                                                                         *
*    Register allocation                                                  *
*                                                                         *
**************************************************************************/

static int get_expansion_mask(asm_workspace *wp, workspace *ws,const PixelFormatInfo *in_fmt,const PixelFormatInfo *out_fmt,int *shift)
/* Work out pixel expansion mask and shift value for a given conversion */
{
  int pixel_expansion_mask = 0;
  int pixel_expansion_shift = 0;
  int uses = 0;
  int failures = 0;
  
  for(int i=0;i<4;i++)
  {
    /* Skip alpha channel if it doesn't exist in one or the other */
    if(!out_fmt->bits[i] || !in_fmt->bits[i])
    {
      assert(i == 3, ERROR_FATAL);
      continue;
    }
    /* If we have 1 bit alpha, and we're wanting to expand it, it's better to store it in the PSR than to mask-and-shift (especially for this first channel)
       The same technique is also worthwhile when we're shrinking down to 1bpp alpha. But not with any formats we currently support, so ignore that potential optimisation for now. */
    if((i == 3) && (in_fmt->bits[i] == 1) && (out_fmt->bits[i] >= 1))
    {
      continue;          
    }
    if(in_fmt->bits[i] < out_fmt->bits[i])
    {
      /* This is a candidate for expansion */
      if(!pixel_expansion_shift || (pixel_expansion_shift == in_fmt->bits[i]))
      {
        int bits = out_fmt->bits[i]-in_fmt->bits[i];
        int mask = (1<<bits)-1;
        int shift = out_fmt->top[i]-bits;
        pixel_expansion_mask |= mask<<shift;
        pixel_expansion_shift = in_fmt->bits[i];
        uses++;
      }
      else
        failures |= 1<<i;
    }
  }
  assert(!(failures & 5), ERROR_FATAL); /* We don't cope with red or blue being unable to use it */
  /* Was it used enough times to make setting it up worthwhile? */
  if(uses > 1)
  {
    if(shift)
      *shift = pixel_expansion_shift;
    return pixel_expansion_mask;
  }
  else
  {
    if(shift)
      *shift = 0;
    return 0;
  }
}

static int convert_pixel_rn(asm_workspace *wp, workspace *ws,PixelFormat pixelformat,const PixelFormat out_pixelformat,int need_temps)
/* Allocate registers for translating r_pixel from pixelformat to
 * out_pixelformat, without using any lookup tables etc.
 *
 * Requirements:
 * wp->is_it_jpeg valid
 */
{
  if(pixelformat == out_pixelformat)
    return need_temps;
  if((pixelformat == PixelFormat_24bpp_Grey) && (out_pixelformat <= PixelFormat_4bpp))
  {
    assert(wp->is_it_jpeg, ERROR_FATAL);
    /* Hack for JPEG data in RISC OS 3
       JPEG has produced greyscale output, but we don't have a ColourTTR to
       map it to the current palette.
       Assuming default Wimp palettes, convert the output manually */
    pixelformat = out_pixelformat;
  }
  else if((pixelformat == PixelFormat_32bpp) && (out_pixelformat == PixelFormat_8bpp))
  {
    assert(wp->is_it_jpeg, ERROR_FATAL);
    need_temps = 2;
    pixelformat = PixelFormat_8bpp;
  }
  else if((pixelformat == PixelFormat_24bpp_Grey) && (out_pixelformat >= PixelFormat_12bpp))
  {
    /* 24bpp grey is equivalent 24bpp/32bpp colour with out_pixelformat RGB order */

    /* Minor optimisation, pick 24bpp/32bpp to allow the giant if() block below to be skipped */
    if((out_pixelformat & PixelFormat_BPPMask) == PixelFormat_24bpp)
      pixelformat = PixelFormat_24bpp;
    else
      pixelformat = PixelFormat_32bpp;

    /* And pick right RGB order */
    pixelformat = (PixelFormat) (pixelformat | (out_pixelformat & PixelFormat_RGB));

    /* TODO - 24 grey handling should be folded into the if() below, so that reducing 24 grey to <=16bpp can be optimised */
  }
  
  if(pixelformat != out_pixelformat)
  {
    assert((pixelformat > PixelFormat_8bpp) && (out_pixelformat > PixelFormat_8bpp), ERROR_FATAL);
    int flags = pixelformat & (PixelFormat_Alpha | PixelFormat_RGB);
    pixelformat = (PixelFormat) (pixelformat & PixelFormat_BPPMask);
    int out_flags = out_pixelformat & (PixelFormat_Alpha | PixelFormat_RGB);
    PixelFormat out_format = (PixelFormat) (out_pixelformat & PixelFormat_BPPMask);
    assert(out_format != PixelFormat_32bpp_Hi, ERROR_FATAL);
    if((pixelformat != out_format) && (pixelformat >= PixelFormat_24bpp) && (out_format >= PixelFormat_24bpp))
    {
      /* Source & dest are both 24bpp/32bpp, but need converting between subformats */
      switch(pixelformat)
      {
      case PixelFormat_24bpp:
        pixelformat = PixelFormat_32bpp;
        break;
      case PixelFormat_32bpp:
        if(flags & PixelFormat_Alpha)
        {
          flags -= PixelFormat_Alpha;
        }
        pixelformat = PixelFormat_24bpp;
        break;
      case PixelFormat_32bpp_Hi:
        assert(!(flags & PixelFormat_Alpha), ERROR_FATAL);
        pixelformat = out_format;
        break;
      }
    }
    if(pixelformat == out_format)
    {
      /* Only RGB order or alpha fixup needed */
      if((flags & PixelFormat_RGB) != (out_flags & PixelFormat_RGB))
      {
        switch(pixelformat)
        {
        case PixelFormat_12bpp:
        case PixelFormat_15bpp:
        case PixelFormat_16bpp:
          if(!need_temps)
            need_temps = 1;
          flags ^= PixelFormat_RGB;
          break;
        case PixelFormat_32bpp:
          if(flags & PixelFormat_Alpha)
          {
            if(out_flags & PixelFormat_Alpha)
            {
              if(!need_temps)
                need_temps = 1;
              flags ^= PixelFormat_RGB;
              break;
            }
            flags -= PixelFormat_Alpha;
          }
          /* Else fall through to 24bpp case */
        case PixelFormat_24bpp:
          if(!need_temps)
            need_temps = 1;
          flags ^= PixelFormat_RGB;
          break;
        }
      }
      /* RGB order should be good. Now deal with alpha. */
      if((flags & PixelFormat_Alpha) != (out_flags & PixelFormat_Alpha))
      {
        flags ^= PixelFormat_Alpha;
      }
    }
    else if((pixelformat == PixelFormat_15bpp) && (out_format == PixelFormat_16bpp) && !((flags ^ out_flags) & PixelFormat_RGB))
    {
      /* Trivial case - 15bpp to 16bpp */
      if(!need_temps)
        need_temps = 1;
      pixelformat = out_format;
      flags = out_flags;
    }
    else if((pixelformat == PixelFormat_16bpp) && (out_format == PixelFormat_15bpp) && !((flags ^ out_flags) & PixelFormat_RGB))
    {
      /* Trivial case - 16bpp to 15bpp */
      if(!need_temps)
        need_temps = 1;
      pixelformat = out_format;
      flags = out_flags;
    }
    else
    {
      /* Full processing needed, so 2 temp regs */
      need_temps = 2;
  
      const PixelFormatInfo *in_fmt = pixelformat_info(pixelformat | flags);
      const PixelFormatInfo *out_fmt = pixelformat_info(out_format | out_flags);
      dprintf(("", "in format: %x { %i, %i, %i, %i }, { %i, %i, %i, %i }, %x, %x\n", in_fmt, in_fmt->bits[0], in_fmt->bits[1], in_fmt->bits[2], in_fmt->bits[3], in_fmt->top[0], in_fmt->top[1], in_fmt->top[2], in_fmt->top[3], in_fmt->hints, in_fmt->alphaimm12));
      dprintf(("", "out format: %x { %i, %i, %i, %i }, { %i, %i, %i, %i }, %x, %x\n", out_fmt, out_fmt->bits[0], out_fmt->bits[1], out_fmt->bits[2], out_fmt->bits[3], out_fmt->top[0], out_fmt->top[1], out_fmt->top[2], out_fmt->top[3], out_fmt->hints, out_fmt->alphaimm12));

      /* Work out if we need r_expansionmask, and if so, what it should be */
      int pixel_expansion_mask;
      pixel_expansion_mask = get_expansion_mask(wp,ws,in_fmt,out_fmt,NULL);
      if(pixel_expansion_mask)
      {
        for(int i=0;i<2;i++)
        {
          if(!ws->pixel_expansion_mask[i])
          {
            if(i)
              RN(r_expansionmask2, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "constant for colour channel expansion")
            else
              RN(r_expansionmask1, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "constant for colour channel expansion")
            ws->pixel_expansion_mask[i] = pixel_expansion_mask;
            break;
          }
          else if(ws->pixel_expansion_mask[i] == pixel_expansion_mask)
          {
            /* An existing mask matches, use it */
            break;
          }
          else
          {
            /* If we've run out of mask registers we're in trouble, as there's currently no fallback case */
            assert(i != 1, ERROR_FATAL);
          }
        }
      }

      /* And that should be it */
      pixelformat = out_format;
      flags = out_flags;
    }
    /* Recombine pixelformat */
    pixelformat = (PixelFormat) (pixelformat | flags);
  }

  assert(pixelformat == out_pixelformat, ERROR_FATAL); /* If this hasn't happened, we haven't completed the transformation. */

  return need_temps;
}

static void blend_extract_alpha_rn(asm_workspace *wp, workspace *ws, PixelFormat in_pixelformat,int *alpha_top,int *alpha_bits)
/* Extract the sprite alpha channel into r_alpha, ready for blending later on */
{
  const PixelFormatInfo *in_fmt = pixelformat_info(in_pixelformat);
  if(in_fmt->bits[3] == 8)
  {
    assert(in_fmt->top[3] == 32, ERROR_FATAL);
    *alpha_top = *alpha_bits = 8;
  }
  else
  {
    assert(in_fmt->top[3] == 16, ERROR_FATAL);
    *alpha_top = 16;
    *alpha_bits = in_fmt->bits[3];
  }
}

static int blend_rgb_rn(asm_workspace *wp, workspace *ws, PixelFormat in_pixelformat, int alpha_top, int alpha_bits, BOOL have_dithered, int need_temps, PixelFormat *blend_pixelformat)
{
  UNUSED(alpha_top);
  /* Mirror the structure of blend_rgb */

  /* Work out which pixel format the blend calculation is performed in */
  *blend_pixelformat = ws->out_pixelformat;
  if(ws->odither && !have_dithered)
  {
    /* Dithering requested, blend in 32bpp */
    *blend_pixelformat = (PixelFormat) (PixelFormat_32bpp | (ws->out_pixelformat & (PixelFormat_RGB | PixelFormat_Alpha)));
  }
  else if(*blend_pixelformat == PixelFormat_8bpp)
  {
    /* 8bpp output, blend in 15bpp ready for table lookup */
    *blend_pixelformat = PixelFormat_15bpp;
  }

  if((alpha_bits == 1) && !(wp->blending & 1))
  {
    /* Special 1bpp case */
    return convert_pixel_rn(wp,ws,in_pixelformat,*blend_pixelformat,need_temps);
  }

  /* Standard code, 2 temps needed */
  if(need_temps < 2)
    need_temps = 2;

  return need_temps;
}

static PixelFormat apply_dither_rn(asm_workspace *wp, workspace *ws, PixelFormat pixelformat, BOOL *have_dithered, int *need_temps)
{
  if (ws->odither && !*have_dithered)
  {
    if(((pixelformat & PixelFormat_BPPMask) == PixelFormat_12bpp)
      && (ws->out_pixelformat >= PixelFormat_4bpp))
    {
      /* When dithering 12bpp down to 4bpp/8bpp, we need to
         convert to 32bpp to make it look good, and to fix
         bugs with the dither value writing into the wrong
         colour channels */
      PixelFormat ditherformat = (PixelFormat) (PixelFormat_32bpp | (pixelformat & (PixelFormat_RGB | PixelFormat_Alpha)));
      *need_temps = convert_pixel_rn(wp,ws,pixelformat,ditherformat,*need_temps);
      pixelformat = ditherformat;
    }
  }
  return pixelformat;
}

static PixelFormat apply_ttr_rn(asm_workspace *wp, workspace *ws, PixelFormat pixelformat, BOOL *have_dithered, int *need_temps)
/* Apply the TTR, and perform any dithering if necessary */
{
  switch(wp->TTRType & ~TTRType_Optional)
  {
  case TTRType_None:
    break;
  case TTRType_Normal:
    pixelformat = ws->out_pixelformat;
    break;
  case TTRType_Wide:
    pixelformat = ws->out_pixelformat;
    break;
  case TTRType_32K:
    /* Hack - skip if this is JPEG and we're already correct */
    if(wp->is_it_jpeg && (pixelformat <= PixelFormat_8bpp))
    {
      assert(pixelformat == ws->out_pixelformat,ERROR_FATAL);
      break;
    }
    /* If we're applying a 32K table, now is our last chance to perform dithering */
    pixelformat = apply_dither_rn(wp,ws,pixelformat,have_dithered,need_temps);
    if(pixelformat != ws->ColourTTRFormat)
      *need_temps = convert_pixel_rn(wp,ws,pixelformat,ws->ColourTTRFormat,*need_temps);
    pixelformat = ws->out_pixelformat;
    break;
  case TTRType_ColourMap:
    if(pixelformat != ws->ColourTTRFormat)
      *need_temps = convert_pixel_rn(wp,ws,pixelformat,ws->ColourTTRFormat,*need_temps);
    /* 1 temp needed if we need to preserve alpha
       However for sprtrans we claim we need two temps, as r_temp1 clashes with r12 */
    if((ws->ColourTTRFormat & PixelFormat_Alpha) && (ws->out_pixelformat & PixelFormat_Alpha))
    {
      if(ISTRANS)
        *need_temps = 2;
      else if(!*need_temps)
        *need_temps = 1;
    }
    /* 1-instruction translation from 32bpp_Hi to something closer to the output format */
    if(((ws->out_pixelformat & ~PixelFormat_Alpha) == PixelFormat_32bpp + PixelFormat_RGB) && (wp->CPUFlags & CPUFlag_REV))
    {
      pixelformat = (PixelFormat) (PixelFormat_32bpp+PixelFormat_RGB);
    }
    else
    {
      pixelformat = PixelFormat_32bpp;
    }
    /* Apply r_inversetable if we have <=8bpp output */
    if(wp->BPP <= 8)
    {
      pixelformat = apply_dither_rn(wp,ws,pixelformat,have_dithered,need_temps);
      *need_temps = convert_pixel_rn(wp,ws,pixelformat,PixelFormat_15bpp,*need_temps);
      pixelformat = ws->out_pixelformat;
    }
    break;
  case TTRType_Palette:
    pixelformat = PixelFormat_32bpp_Hi;
    break;
  }

  return pixelformat;
}

static int translate_pixel_rn(asm_workspace *wp, workspace *ws, int need_temps)
{
  /* Work out whether we need 16->32 or 32->16 transformations, with their temp registers
   * So, mirror the structure of translate_pixel
   */

  PixelFormat pixelformat = ws->in_pixelformat;

  BOOL ttr_before_blend = TRUE;
  switch(ws->blendimpl)
  {
  case BlendImpl_BlendTables:
    ttr_before_blend = FALSE;
    break;
  }

  int alpha_top = 0;
  int alpha_bits = 0;
  if((wp->blending & 2) && !(wp->save_mode & 0x80000000))
  {
    blend_extract_alpha_rn(wp,ws,pixelformat,&alpha_top,&alpha_bits);
  }

  BOOL have_dithered = FALSE;
  if(ttr_before_blend && wp->TTRType)
  {
    pixelformat = apply_ttr_rn(wp,ws,pixelformat,&have_dithered,&need_temps);
  }  

  /* Blending */
  int alpha_shift = 0;
  switch(ws->blendimpl)
  {
  case BlendImpl_BlendTable:
    /* Single blend table */
    /* JPEG might need translating to out_pixelformat before the blend can take place */
    if((wp->is_it_jpeg) && (pixelformat > PixelFormat_8bpp))
    {
      pixelformat = apply_dither_rn(wp,ws,pixelformat,&have_dithered,&need_temps);
      need_temps = convert_pixel_rn(wp,ws,pixelformat,ws->out_pixelformat,need_temps);
      pixelformat = ws->out_pixelformat;
    }
    if(!need_temps)
      need_temps = 1;
    pixelformat = ws->out_pixelformat;
    break;
  case BlendImpl_InverseTable:
    if(pixelformat == PixelFormat_8bpp)
    {
      pixelformat = PixelFormat_15bpp;
    }
    /* Fall through... */
  case BlendImpl_True:
    /* True colour blend */
    assert(pixelformat > PixelFormat_8bpp, ERROR_FATAL);
    need_temps = blend_rgb_rn(wp,ws,pixelformat,alpha_top,alpha_bits,have_dithered,need_temps,&pixelformat);
    break;
  case BlendImpl_BlendTables:
    /* Screen is <= 4bpp, use lots of blendtables
       If src is true colour, use ColourTTR to convert to screen
       Else use palette index directly */
    /* r_translucency (if used) assumed to be 0-256 alpha */
    assert(wp->blending & 2, ERROR_FATAL);
    if (SOURCE_ALPHAMASK)
    {
      /* Alpha mask */
      if (wp->blending & 1)
      {
      }
      else
      {
        alpha_shift = 5;
      }
      alpha_bits = 3;  
    }
    else if (alpha_bits)
    {
      /* Alpha channel */
      unsigned int chan_mask = ((1<<alpha_bits)-1)<<(alpha_top-alpha_bits);
      if (wp->blending & 1)
      {
        if (alpha_bits == 1)
        {
        }
        else
        {
          assert(alpha_bits >= 4, ERROR_FATAL);
          if(chan_mask == 0xff)
          {
          }
          else
          {
            assert(chan_mask == 0xf000, ERROR_FATAL);
          }  
        }
        alpha_bits = 3;  
      }
      else
      {
        chan_mask &= ~(chan_mask>>3);
        alpha_shift = alpha_top-3;
        alpha_bits = (alpha_bits>3?3:alpha_bits); /* Should be 1 or 3, asserted below */
      }
    }
    else
    {
      /* Ordinary translucent plotting */
      /* This shouldn't happen, should be handled by single blendtable case above */
      assert(0, ERROR_FATAL);
    }

    /* Apply TTR here, unless it's an optional normal TTR (in which case we
       only apply for full alpha pixels) */
    assert(!ttr_before_blend, ERROR_FATAL);
    if(wp->TTRType != TTRType_Normal+TTRType_Optional)
    {
      pixelformat = apply_ttr_rn(wp,ws,pixelformat,&have_dithered,&need_temps);
    }

    if(alpha_bits == 3)
    {
      if(!need_temps)
        need_temps = 1;
    }
    pixelformat = ws->out_pixelformat;
    break;
  }

  pixelformat = apply_dither_rn(wp,ws,pixelformat,&have_dithered,&need_temps);

  switch(ws->blendimpl)
  {
  case BlendImpl_InverseTable:
    /* Inverse table lookup for 15bpp -> palette */
    if(pixelformat != PixelFormat_8bpp)
    {
      if(pixelformat != PixelFormat_15bpp)
      {
        need_temps = convert_pixel_rn(wp,ws,pixelformat,PixelFormat_15bpp,need_temps);
      }
      pixelformat = PixelFormat_8bpp;              /* we've finished */
    }
    break;
  }

  /* Do any extra conversion necessary */
  if(pixelformat != ws->out_pixelformat)
  {
    need_temps = convert_pixel_rn(wp,ws,pixelformat,ws->out_pixelformat,need_temps);
    pixelformat = ws->out_pixelformat;
  }

  return need_temps;
}

/**************************************************************************
*                                                                         *
*    Register initialisation.                                             *
*                                                                         *
**************************************************************************/

static void dither_expansion_init(asm_workspace *wp, workspace *ws)
/* Initialise the ordered dither & pixel format expansion registers
 *
 * Requirements:
 * convert_pixel_rn() called
 * ws->odither valid
 * r_oditheradd allocated if necessary
 */
{
  for(int i=0;i<2;i++)
  {
    int mask = ws->pixel_expansion_mask[i];
    if(!mask)
      break;

#ifdef DEBUG
    char a[256];
    do_sprintf(a,"Generate expansion mask &%x",mask);
    comment(ws,a);
    const char *regname;
#endif
    int regno;
    if(i)
    {
      regno = R(r_expansionmask2);
#ifdef DEBUG
      regname = "r_expansionmask2";
#endif
    }
    else
    {
      regno = R(r_expansionmask1);
#ifdef DEBUG
      regname = "r_expansionmask1";
#endif
    }
 
    if(mask == 0xF0F0F0F0)
    {
      /* We can do this in two or three instructions */
      if(wp->CPUFlags & CPUFlag_T2)
      {
        dsprintf((a,  "MOVW    %s,#&f0f0",regname));
        MOVW(regno, IMM16(0xF0F0),a);
      }
      else
      {
        dsprintf((a,  "MOV     %s,#&f0",regname));
        MOV(regno, IMM(15) | IMMROR(28),a);
        dsprintf((a,  "ORR     %s,%s,LSL #8",regname,regname));
        ORR(regno, regno, OP2R(regno) | LSLI(8),a);
      }
      dsprintf((a,    "ORR     %s,%s,LSL #16",regname,regname));
      ORR(regno, regno, OP2R(regno) | LSLI(16),a);
    }
    else
    {
      /* Other masks may be anywhere between one and three instructions, do it a byte at a time */
      assert(mask & 0xff, ERROR_FATAL); /* We expect red & blue to need expansion, and for one of them to tbe in the bottom byte */
      assert(!(mask & 0xff000000), ERROR_FATAL); /* We don't expect 32bpp alpha to need expansion. We'll either be coming from 4bpp (in which case we'll use 0xF0F0F0F0) or from 1bpp (in which case we'll use TST) */
      if(wp->CPUFlags & CPUFlag_T2)
      {
        dsprintf((a,  "MOVW    %s,#&%x",regname,mask & 0xffff));
        MOVW(regno, IMM16(mask),a);
      }
      else
      {
        dsprintf((a,  "MOV     %s,#&%x",regname,mask & 0xff));
        MOV(regno, IMM(mask & 0xff),a);
        if(mask & 0xff00)
        {
          dsprintf((a,"ORR     %s,%s,#&%x",regname,regname,mask & 0xff00));
          ORR(regno, regno, IMM((mask>>8)&0xff) | IMMROR(24),a);
        }
      }
      if(mask & 0xff0000)
      {
        dsprintf((a,  "ORR     %s,%s,#&%x",regname,regname,mask & 0xff0000));
        ORR(regno, regno, IMM((mask>>16)&0xff) | IMMROR(16),a);
      }
    }
  }

  if (ws->odither)
  {
    /* We use ordered dither to attempt to increase the output resolution by almost two bits.
     * This only happens for a 16bpp or 32bpp source that's being truncated somewhat.
     * A square of output pixels has the following binary addition values:
     *              11    01
     *              00    10
     * These values are added to the value of each or R/G/B, just before those values are
     * truncated or looked up in a table, shifted so that we add to the bits which are
     * just about to be discarded.
     * We keep the value to add in r_oditheradd.
     * To proceed along the x axis we EOR by 10 every output pixel.
     * We must also EOR by 01 every line.
     * The starting value must be aligned with the origin of the output.
     */
    comment(ws, "Compute initial dither addition value - bit 0 changes every y, bit 1 every x");
    LDR_WP(r_pixel, save_xcoord)
    AND(R(r_pixel), R(r_pixel), IMM(1),                        "AND     r_pixel,r_pixel,#1               ; least sig bit of x, for dither");
    LDR_WP(r_oditheradd, save_ycoord)
    AND(R(r_oditheradd), R(r_oditheradd), IMM(1),              "AND     r_oditheradd,r_oditheradd,#1     ; least sig bit of y, for dither");
    EOR(R(r_pixel),R(r_pixel),OP2R(R(r_oditheradd)),           "EOR     r_pixel,r_pixel,r_oditheradd     ; if we start Y off on an odd footing, invert x as well");
    ORR(R(r_oditheradd), R(r_oditheradd),
    OP2R(R(r_pixel)) | LSLI(1),                                "ORR     r_oditheradd,r_oditheradd,r_pixel,LSL #1 ; dither add value");

    /* The dither should start based on the current ECF offset */
    LDR_WP(r_pixel, ecfyoffset_ptr)
    LDR_INDEX(r_pixel,r_pixel,0,"get kernel variable ECFYOffset")
    TST(R(r_pixel),IMM(1),                                     "TST     r_pixel,#1                       ; is Y ECF offset odd?");
    EOR(R(r_oditheradd),R(r_oditheradd),NE | IMM(3),           "EORNE   r_oditheradd,r_oditheradd,#3     ; if so, change ordered dither origin to match");

    LDR_WP(r_pixel, ecfshift_ptr)
    LDR_INDEX(r_pixel,r_pixel,0,"get kernel variable ECFShift")

    TST(R(r_pixel),IMM(wp->BPP),                               "TST     r_pixel,#out_bpp                 ; is ECF Shift an odd number of pixels?");
    EOR(R(r_oditheradd),R(r_oditheradd),NE | IMM(2),           "EORNE   r_oditheradd,r_oditheradd,#2     ; if so, change ordered dither origin to match");

    /* Shift the dither value to the top of the register. */
    {
#ifdef DEBUG
      char a[256];
#endif      
      dsprintf((a, "MOV     r_oditheradd,r_oditheradd,LSL #%i %t40; shift to top of word", 23 + ws->odither));
      MOV(R(r_oditheradd), OP2R(R(r_oditheradd)) | LSLI(23 + ws->odither), a);
    }
  }
}

/**************************************************************************
*                                                                         *
*    Pixel translation                                                    *
*                                                                         *
**************************************************************************/

#ifdef DEBUG
static void add_ordered_dither_gun(asm_workspace *wp, workspace *ws, int bits_per_gun, int offset, char *gun)
#else
#define add_ordered_dither_gun(a,b,c,d,e) do_add_ordered_dither_gun(a,b,c,d)
static void do_add_ordered_dither_gun(asm_workspace *wp, workspace *ws, int bits_per_gun, int offset)
#endif
/* Do one gun of the ordered dither - entirely local to add_ordered_dither below
 * Offset is the offset from bit 0 of the base of this field of the colour
 */
{
#ifdef DEBUG
  char a[128];
#endif
  int x = 32 - bits_per_gun - offset; /* amount to shift the colour field in question */
  dsprintf((a,                                  "CMN     r_oditheradd,r_pixel,LSL #%i %t40; %s below limit?", x, gun));
  CMN(R(r_oditheradd), OP2R(R(r_pixel)) | LSLI(x), a);

  dsprintf((a,                                  "ADDCC   r_pixel,r_pixel,r_oditheradd,LSR #%i %t40; if not, add.", x));
  ADD(R(r_pixel), R(r_pixel), CC | OP2R(R(r_oditheradd)) | LSRI(x), a);
  UNUSED(wp);
}

static void add_ordered_dither(asm_workspace *wp, workspace *ws,PixelFormat pixelformat)
/* The 32-bit RGB value in r_pixel should have r_oditheradd >> (32-bits_per_gun)
 * added to each of R/G/B, except that these additions should be 'sticky'
 * at 255 in each gun.
 * 
 * The resulting values are just about to be truncated somewhat, so the lo
 * bits of each answer do not matter much. Thus, if the value is currently
 * 254 we never add, but this doesn't matter.
 */
{
  int redblue_bits_per_gun, green_bits_per_gun;
  switch(pixelformat & PixelFormat_BPPMask)
  {
  case PixelFormat_12bpp:
    redblue_bits_per_gun = green_bits_per_gun = 4;
    break;
  case PixelFormat_15bpp:
    redblue_bits_per_gun = green_bits_per_gun = 5;
    break;
  case PixelFormat_16bpp:
    redblue_bits_per_gun = 5;
    green_bits_per_gun = 6;
    break;
  default:
    assert(0, ERROR_FATAL);
  case PixelFormat_24bpp_Grey:
  case PixelFormat_24bpp:
  case PixelFormat_32bpp:
/*  case PixelFormat_32bpp_Hi: - Not supported below */
    redblue_bits_per_gun = green_bits_per_gun = 8;
    break;
  }

  comment(ws, "Add current value for ordered dither");
  add_ordered_dither_gun(wp, ws, redblue_bits_per_gun, redblue_bits_per_gun+green_bits_per_gun, "blue");
  add_ordered_dither_gun(wp, ws, green_bits_per_gun, redblue_bits_per_gun, "green");
  add_ordered_dither_gun(wp, ws, redblue_bits_per_gun, 0, "red");
  newline();
}

static void convert_pixel(asm_workspace *wp, workspace *ws,PixelFormat pixelformat,const PixelFormat out_pixelformat)
/* Translate r_pixel from pixelformat to out_pixelformat, without using any
 * lookup tables etc.
 *
 * Requirements:
 * wp->is_it_jpeg valid
 * convert_pixel_rn() called
 * dither_expansion_init() called
 */
{
#ifdef DEBUG
  char a[256];
#endif
  if(pixelformat == out_pixelformat)
    return;
  if((pixelformat == PixelFormat_24bpp_Grey) && (out_pixelformat <= PixelFormat_4bpp))
  {
    assert(wp->is_it_jpeg, ERROR_FATAL);
    /* Hack for JPEG data in RISC OS 3
       JPEG has produced greyscale output, but we don't have a ColourTTR to
       map it to the current palette.
       Assuming default Wimp palettes, convert the output manually */
    if(out_pixelformat == PixelFormat_1bpp)
    {
      comment(ws, "Creating 0 or 1 from 24bit greyscale");
      MVN(R(r_pixel), OP2R(R(r_pixel)) | LSRI(7),                   "MVN     r_pixel,r_pixel,LSR #7          ; hi bit of R");
      AND(R(r_pixel), R(r_pixel), IMM(1),                           "AND     r_pixel,r_pixel,#1              ; 0->white, 1->black");
      pixelformat = PixelFormat_1bpp;
    }
    else if(out_pixelformat == PixelFormat_2bpp)
    {
      comment(ws, "Creating 0,1,2 or 3 from 24bit greyscale");
      MVN(R(r_pixel), OP2R(R(r_pixel)) | LSRI(6),                   "MVN     r_pixel,r_pixel,LSR #6           ; hi 2 bits of R");
      AND(R(r_pixel), R(r_pixel), IMM(3),                           "AND     r_pixel,r_pixel,#3               ; 0->white, 3->black");
      pixelformat = PixelFormat_2bpp;
    }
    else if (out_pixelformat == PixelFormat_4bpp)
    {
      comment(ws, "Creating wimp colour in 0..7 from 24bit greyscale");
      MVN(R(r_pixel), OP2R(R(r_pixel)) | LSRI(5),                   "MVN     r_pixel,r_pixel,LSR #5           ; hi 3 bits of R");
      AND(R(r_pixel), R(r_pixel), IMM(7),                           "AND     r_pixel,r_pixel,#7               ; 0->white, 7->black");
      pixelformat = PixelFormat_4bpp;
    }
#if 0 /* This case is currently impossible, 24bpp greyscale output is only produced for 8bpp if a greyscale palette is in use, and a greyscale 8bpp palette is impossible on VIDC1 */
    else
    {
      /* Default 256 colour VIDC1 palette; organisation is:
       * bit 0 - tint 0
       * bit 1 - tint 1
       * bit 2 - red 2
       * bit 3 - blue 2
       * bit 4 - red 3 (high)
       * bit 5 - green 2
       * bit 6 - green 3 (high)
       * bit 7 - blue 3 (high)
       */
      comment(ws, "Creating bggrbrtt from 24bit greyscale");
      TEQ(R(r_pixel),OP2R(R(r_pixel)) | LSLI(25),                   "TEQ     r_pixel,r_pixel,LSL #25          ; check high two bits of R");
      MOV(R(r_pixel),OP2R(R(r_pixel)) | LSR(4),                     "MOV     r_pixel,r_pixel,LSR #4           ; tint bits & red 2");
      AND(R(r_pixel),R(r_pixel),IMM(7),                             "AND     r_pixel,r_pixel,#7               ; mask off the rest")
      ORR(R(r_pixel),R(r_pixel),IMM(0x28) | MI,                     "ORRMI   r_pixel,r_pixel,#&28             ; set green 2 & blue 2");
      ORR(R(r_pixel),R(r_pixel),IMM(0xd0) | CS,                     "ORRCS   r_pixel,r_pixel,#&d0             ; set RGB high bits");
      pixelformat = PixelFormat_8bpp;
    }
#endif
  }
  else if((pixelformat == PixelFormat_32bpp) && (out_pixelformat == PixelFormat_8bpp))
  {
    assert(wp->is_it_jpeg, ERROR_FATAL);
    /* Hack for JPEG data in RISC OS 3
       We're producing colour output but don't have a ColourTTR to map it
       to the current palette.
       Assume the default VIDC1 256 colour palette and map it to that. */
    /* Default 256 colour VIDC1 palette; organisation is:
     * bit 0 - tint 0
     * bit 1 - tint 1
     * bit 2 - red 2
     * bit 3 - blue 2
     * bit 4 - red 3 (high)
     * bit 5 - green 2
     * bit 6 - green 3 (high)
     * bit 7 - blue 3 (high)
     */
    comment(ws, "Creating bggrbrtt from 32bit colour");
    /* Making the tint - the average of the lower 6 of RGB isn't a bad approximation. We make this
     * by adding them all up, multiplying by 9, and dividing by 512.
     */
    AND(R(r_temp1), R(r_pixel), IMM(0x3F) | IMMROR(16),           "AND     r_temp1,r_pixel,#&3F0000         ; bottom 6 bits of B");
    MOV(R(r_temp2), OP2R(R(r_temp1)) | LSRI(16),                  "MOV     r_temp2,r_temp1,LSR #16          ; at bottom of temp2");
    AND(R(r_temp1), R(r_pixel), IMM(0x3F) | IMMROR(24),           "AND     r_temp1,r_pixel,#&3F00           ; bottom 6 bits of G");
    ADD(R(r_temp2), R(r_temp2), OP2R(R(r_temp1)) | LSRI(5),       "ADD     r_temp2,r_temp2,r_temp1,LSR #5   ; add to bottom B bits");
    AND(R(r_temp1), R(r_pixel), IMM(0x3F),                        "AND     r_temp1,r_pixel,#&3F             ; bottom 6 bits of R");
    ADD(R(r_temp2), R(r_temp2), OP2R(R(r_temp1)),                 "ADD     r_temp2,r_temp2,r_temp1          ; add to bottom B+G bits");
    ADD(R(r_temp2), R(r_temp2), OP2R(R(r_temp2)) | LSLI(3),       "ADD     r_temp2,r_temp2,r_temp2,LSL #3   ; (lo R+G+B)*9, tint value in bits 9 & 10");

    /* The hi bits are just done by extracting from the 24bpp value */
    AND(R(r_temp1), R(r_pixel), IMM(3) | IMMROR(18),              "AND     r_temp1,r_pixel,#&C000           ; both green bits");
    ORR(R(r_temp2), R(r_temp2), OP2R(R(r_temp1)),                 "ORR     r_temp2,r_temp2,r_temp1          ; merge in with tint (no shifting needed!)");

    MOV(R(r_pixel), OP2R(R(r_pixel)) | LSLI(9) | S,               "MOVS    r_pixel,r_pixel,LSL #9           ; check blue bits");
    ORR(R(r_temp2), R(r_temp2), IMM(1) | IMMROR(20) | MI,         "ORRMI   r_temp2,r_temp2,#8<<9            ; blue 2");
    ORR(R(r_temp2), R(r_temp2), IMM(1) | IMMROR(16) | CS,         "ORRCS   r_temp2,r_temp2,#128<<9          ; blue 3");

    MOV(R(r_pixel), OP2R(R(r_pixel)) | LSLI(16) | S,              "MOVS    r_pixel,r_pixel,LSL #16          ; check red bits");
    ORR(R(r_temp2), R(r_temp2), IMM(2) | IMMROR(22) | MI,         "ORRMI   r_temp2,r_temp2,#4<<9            ; red 2");
    ORR(R(r_temp2), R(r_temp2), IMM(2) | IMMROR(20) | CS,         "ORRCS   r_temp2,r_temp2,#16<<9           ; red 3");

    MOV(R(r_pixel), OP2R(R(r_temp2)) | LSRI(9),                   "MOV     r_pixel,r_temp2,LSR #9           ; shift down to final position");

    pixelformat = PixelFormat_8bpp;
  }
  else if((pixelformat == PixelFormat_24bpp_Grey) && (out_pixelformat >= PixelFormat_12bpp))
  {
    /* 24bpp grey is equivalent 24bpp/32bpp colour with out_pixelformat RGB order */

    /* Minor optimisation, pick 24bpp/32bpp to allow the giant if() block below to be skipped */
    if((out_pixelformat & PixelFormat_BPPMask) == PixelFormat_24bpp)
      pixelformat = PixelFormat_24bpp;
    else
      pixelformat = PixelFormat_32bpp;

    /* And pick right RGB order */
    pixelformat = (PixelFormat) (pixelformat | (out_pixelformat & PixelFormat_RGB));
    dprintf(("", "%t20; Treating 24bpp greyscale as %x\n", pixelformat));

    /* TODO - 24 grey handling should be folded into the if() below, so that reducing 24 grey to <=16bpp can be optimised */
  }

  if(pixelformat != out_pixelformat)
  {
    /* Some kind of true colour transformation needed */
    assert((pixelformat >= PixelFormat_12bpp) && (out_pixelformat >= PixelFormat_12bpp), ERROR_FATAL);
    int flags = pixelformat & (PixelFormat_Alpha | PixelFormat_RGB);
    pixelformat = (PixelFormat) (pixelformat & PixelFormat_BPPMask);
    int out_flags = out_pixelformat & (PixelFormat_Alpha | PixelFormat_RGB);
    PixelFormat out_format = (PixelFormat) (out_pixelformat & PixelFormat_BPPMask);
    assert(out_format != PixelFormat_32bpp_Hi, ERROR_FATAL);
    if((pixelformat != out_format) && (pixelformat >= PixelFormat_24bpp) && (out_format >= PixelFormat_24bpp))
    {
      /* Source & dest are both 24bpp/32bpp, but need converting between subformats */
      switch(pixelformat)
      {
      case PixelFormat_24bpp:
        pixelformat = PixelFormat_32bpp;
        break;
      case PixelFormat_32bpp:
        if(flags & PixelFormat_Alpha)
        {
          dsprintf((a,                                  "BIC     r_pixel,r_pixel,#&%x ; Discard alpha",PIXELFORMAT_ALPHA_MASK(pixelformat | flags)));
          BIC(R(r_pixel),R(r_pixel),PIXELFORMAT_ALPHA_IMM(pixelformat | flags),a);
          flags -= PixelFormat_Alpha;
        }
        pixelformat = PixelFormat_24bpp;
        break;
      case PixelFormat_32bpp_Hi:
        assert(!(flags & PixelFormat_Alpha), ERROR_FATAL);
        if((wp->CPUFlags & CPUFlag_REV) && ((flags ^ out_flags) & PixelFormat_RGB))
        {
          REV(R(r_pixel), R(r_pixel), 0,                              "REV     r_pixel,r_pixel                  ; Palette entry -> &00RRGGBB");
          flags ^= PixelFormat_RGB;
        }
        else
        {
          MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(8),                 "MOV     r_pixel,r_pixel,LSR #8           ; Convert from palette entry");
        }
        pixelformat = out_format;
        break;
      }
    }
    if(pixelformat == out_format)
    {
      /* Only RGB order or alpha fixup needed */
      if((flags & PixelFormat_RGB) != (out_flags & PixelFormat_RGB))
      {
        comment(ws, "Red/blue swap");
        switch(pixelformat)
        {
        case PixelFormat_12bpp:
          EOR(R(r_temp1), R(r_pixel), OP2R(R(r_pixel)) | LSLI(8),     "EOR     r_temp1,r_pixel,r_pixel,LSL #8   ; R ^ B");
          AND(R(r_temp1), R(r_temp1), IMM(0xF) | IMMROR(24),          "AND     r_temp1,r_temp1,#&F00");
          EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)),               "EOR     r_pixel,r_pixel,r_temp1          ; Swap one");
          EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSRI(8),     "EOR     r_pixel,r_pixel,r_temp1,LSR #8   ; Swap the other");
          flags ^= PixelFormat_RGB;
          break;
        case PixelFormat_15bpp:
          EOR(R(r_temp1), R(r_pixel), OP2R(R(r_pixel)) | LSLI(10),    "EOR     r_temp1,r_pixel,r_pixel,LSL #10  ; R ^ B");
          AND(R(r_temp1), R(r_temp1), IMM(0x1F) | IMMROR(22),         "AND     r_temp1,r_temp1,#&1F<<10");
          EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)),               "EOR     r_pixel,r_pixel,r_temp1          ; Swap one");
          EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSRI(10),    "EOR     r_pixel,r_pixel,r_temp1,LSR #10  ; Swap the other");
          flags ^= PixelFormat_RGB;
          break;
        case PixelFormat_16bpp:
          EOR(R(r_temp1), R(r_pixel), OP2R(R(r_pixel)) | LSLI(11),    "EOR     r_temp1,r_pixel,r_pixel,LSL #11  ; R ^ B");
          AND(R(r_temp1), R(r_temp1), IMM(0x3E) | IMMROR(22),         "AND     r_temp1,r_temp1,#&1F<<11");
          EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)),               "EOR     r_pixel,r_pixel,r_temp1          ; Swap one");
          EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSRI(11),    "EOR     r_pixel,r_pixel,r_temp1,LSR #11  ; Swap the other");
          flags ^= PixelFormat_RGB;
          break;
        case PixelFormat_32bpp:
        case PixelFormat_24bpp:
          if(wp->CPUFlags & CPUFlag_REV)
          {
            REV(R(r_pixel), R(r_pixel), 0,                            "REV     r_pixel,r_pixel");
            if(out_flags & flags & PixelFormat_Alpha)
            {
              MOV(R(r_pixel), OP2R(R(r_pixel)) | RORI(8),             "MOV     r_pixel,r_pixel,ROR #8           ; Shift RGB down and preserve alpha");
            }
            else
            {
              MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(8),             "MOV     r_pixel,r_pixel,LSR #8           ; Shift RGB down and discard any alpha");
              if(out_flags & PixelFormat_Alpha)
              {
                ORR(R(r_pixel), R(r_pixel), IMM(255) | IMMROR(8),     "ORR     r_pixel,r_pixel,#&FF000000       ; Set alpha");
              }
            }
            flags = out_flags;
          }
          else
          {
            /* This is tricky depending on whether we have alpha or not */
            if(flags & PixelFormat_Alpha)
            {
              assert(pixelformat != PixelFormat_24bpp, ERROR_FATAL);
              if(out_flags & PixelFormat_Alpha)
              {
                /* Must preserve alpha, use the above 4-instruction sequences */
                EOR(R(r_temp1), R(r_pixel), OP2R(R(r_pixel)) | LSLI(16),  "EOR     r_temp1,r_pixel,r_pixel,LSL #16  ; R ^ B");
                AND(R(r_temp1), R(r_temp1), IMM(0xFF) | IMMROR(16),       "AND     r_temp1,r_temp1,#&FF0000");
                EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)),             "EOR     r_pixel,r_pixel,r_temp1          ; Swap one");
                EOR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSRI(16),  "EOR     r_pixel,r_pixel,r_temp1,LSR #16  ; Swap the other");
                flags ^= PixelFormat_RGB;
                break;
              }
              /* We're discarding alpha. Get rid of it here and then use the 3 instruction R/B swap sequence */
              BIC(R(r_pixel), R(r_pixel), IMM(255) | IMMROR(8),         "BIC     r_pixel,r_pixel,#&FF000000       ; Discard alpha");
              flags -= PixelFormat_Alpha;
            }
            AND(R(r_temp1), R(r_pixel), IMM(255) | IMMROR(24),          "AND     r_temp1,r_pixel,#&FF00           ; G");
            if(!(out_flags & PixelFormat_Alpha)) /* No need to mask out this byte if we know we're overwriting it later */
            {
              BIC(R(r_pixel), R(r_pixel), IMM(255) | IMMROR(24),        "BIC     r_pixel,r_pixel,#&FF00           ; R & B remain");
            }
            ORR(R(r_pixel), R(r_temp1), OP2R(R(r_pixel)) | RORI(16),    "ORR     r_pixel,r_temp1,r_pixel,ROR #16  ; Swapped");
            flags ^= PixelFormat_RGB;
          }
          break;
        }
      }
      /* RGB order should be good. Now deal with alpha. */
      if((flags & PixelFormat_Alpha) != (out_flags & PixelFormat_Alpha))
      {
        if(flags & PixelFormat_Alpha)
        {
          dsprintf((a,                                  "BIC     r_pixel,r_pixel,#&%x      ; Discard alpha",PIXELFORMAT_ALPHA_MASK(pixelformat | flags)));
          BIC(R(r_pixel),R(r_pixel),PIXELFORMAT_ALPHA_IMM(pixelformat | flags),a);
        }
        else
        {
          dsprintf((a,                                  "ORR     r_pixel,r_pixel,#&%x      ; Set alpha",PIXELFORMAT_ALPHA_MASK(pixelformat | out_flags)));
          ORR(R(r_pixel),R(r_pixel),PIXELFORMAT_ALPHA_IMM(pixelformat | out_flags),a);
        }
        flags ^= PixelFormat_Alpha;
      }
    }
    else if((pixelformat == PixelFormat_15bpp) && (out_format == PixelFormat_16bpp) && !((flags ^ out_flags) & PixelFormat_RGB))
    {
      /* Trivial case - 15bpp to 16bpp */
      MOV(R(r_temp1), OP2R(R(r_pixel)) | LSRI(5),                "MOV     r_temp1,r_pixel,LSR #5          ; B & G");
      TST(R(r_pixel), IMM(2) | IMMROR(24),                       "TST     r_pixel,#16<<5                  ; Top bit of green");
      AND(R(r_pixel), R(r_pixel), IMM(31),                       "AND     r_pixel,r_pixel,#31             ; R");
      ORR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSLI(6),    "ORR     r_pixel,r_pixel,r_temp1,LSL #6  ; B & G shifted across one bit");
      ORR(R(r_pixel), R(r_pixel), NE | IMM(32),                  "ORRNE   r_pixel,r_pixel,#32             ; Set low green bit to right value");
      pixelformat = out_format;
      if(flags & PixelFormat_Alpha)
        BIC(R(r_pixel), R(r_pixel), IMM(1) | IMMROR(16),         "BIC     r_pixel,r_pixel,#&10000         ; Discard alpha");
      flags = out_flags;
    }
    else if((pixelformat == PixelFormat_16bpp) && (out_format == PixelFormat_15bpp) && !((flags ^ out_flags) & PixelFormat_RGB))
    {
      /* Trivial case - 16bpp to 15bpp */
      MOV(R(r_temp1), OP2R(R(r_pixel)) | LSRI(6),                "MOV     r_temp1,r_pixel,LSR #6          ; B & G");
      AND(R(r_pixel), R(r_pixel), IMM(31),                       "AND     r_pixel,r_pixel,#31             ; R");
      ORR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSLI(5),    "ORR     r_pixel,r_pixel,r_temp1,LSL #5  ; recombined");
      pixelformat = out_format;
      if(out_flags & PixelFormat_Alpha)
        ORR(R(r_pixel), R(r_pixel), IMM(2) | IMMROR(18),         "ORR     r_pixel,r_pixel,#&8000          ; Set alpha");
      flags = out_flags;
    }
    else
    {
      /* Full processing needed. Pull it apart and put it back together in the right format.
         Basic procedure is:
         * use AND to extract a component
         * ORR it into the output pixel, shifting as appropriate
         * Repeat above for all channels
         * AND with bit expansion mask, and ORR that in at correct shift
         * If alpha needs expanding, and can't use main expansion mask, expand it manually using an immediate constant
         * Also if we've upgraded from 16bpp to 24/32bpp, green needs manual expansion */

      const PixelFormatInfo *in_fmt = pixelformat_info(pixelformat | flags);
      const PixelFormatInfo *out_fmt = pixelformat_info(out_format | out_flags);
      /* Try hard to eliminate an extra instruction by choosing the right component to start with */
      int done_channels = 0;
      for(int i=3;i>=0;i--)
      {
        /* Skip alpha channel if it doesn't exist in one or the other */
        if(!out_fmt->bits[i] || !in_fmt->bits[i])
        {
          assert(i == 3, ERROR_FATAL);
          done_channels = 8;
          continue;
        }
        /* If we have 1 bit alpha, and we're wanting to expand it, it's better to store it in the PSR than to mask-and-shift (especially for this first channel)
           The same technique is also worthwhile when we're shrinking down to 1bpp alpha. But not with any formats we currently support, so ignore that potential optimisation for now. */
        if((i == 3) && (in_fmt->bits[i] == 1) && (out_fmt->bits[i] >= 1))
        {
          dsprintf((a,                                  "TST     r_pixel,#1<<%i                  ; check alpha",in_fmt->top[3]-1));
          TST(R(r_pixel),IMM12(1<<(in_fmt->top[3]-1)),a);
          done_channels |= 1<<i;
          continue;          
        }
        BOOL shift_down_possible = (out_fmt->top[i] == out_fmt->bits[i]) && (out_fmt->bits[i] <= in_fmt->bits[i]);
        if(shift_down_possible && (in_fmt->hints & (HINT_HIGHEST<<i)))
        {
          /* We can merely shift this down into place */
          dsprintf((a,                                  "MOV     r_temp2,r_pixel,LSR #%i         ; reposition %s",in_fmt->top[i]-out_fmt->top[i],COMPONENT_NAME(i)));
          MOV(R(r_temp2), OP2R(R(r_pixel)) | LSRI(in_fmt->top[i]-out_fmt->top[i]),a);
          done_channels |= 1<<i;
          break;
        }
        else if(shift_down_possible && (wp->CPUFlags & CPUFlag_T2))
        {
          /* Use UBFX to extract and shift down */
          dsprintf((a,                                  "UBFX    r_temp2,r_pixel,#%i,#%i     ; extract & reposition %s",in_fmt->top[i]-out_fmt->bits[i],out_fmt->bits[i],COMPONENT_NAME(i)));
          UBFX(R(r_temp2),R(r_pixel),in_fmt->top[i]-out_fmt->bits[i],out_fmt->bits[i],0,a);
          done_channels |= 1<<i;
          break;          
        }
#if 0 /* No current output formats will satisfy these conditions */
        else if((in_fmt->top[i] == in_fmt->bits[i]) && (out_fmt->top[i] == 32) && (out_fmt->bits[i] >= in_fmt->bits[i]))
        {
          /* We can shift this up into place */
          dsprintf((a,                                  "MOV     r_temp2,r_pixel,LSL #%i         ; reposition %s",32-in_fmt->top[i],COMPONENT_NAME(i)));
          MOV(R(r_temp2), OP2R(R(r_pixel)) | LSLI(32-in_fmt->top[i]),a);
          done_channels |= 1<<i;
          break;
        }
#endif
        else if(in_fmt->top[i] == out_fmt->top[i])
        {
          /* A simple mask will do */
          int bits = MIN(in_fmt->bits[i],out_fmt->bits[i]);
          int mask = ((1<<bits)-1)<<(in_fmt->top[i]-bits);
          dsprintf((a,                                  "AND     r_temp2,r_pixel,#&%x           ; extract %s",mask,COMPONENT_NAME(i)));
          AND(R(r_temp2), R(r_pixel), IMM12(mask), a);
          done_channels |= 1<<i;
          break;
        }
        else if(!i)
        {
          /* No other choices left, just go with this one */
          int bits = MIN(in_fmt->bits[i],out_fmt->bits[i]);
          int mask = (1<<bits)-1;
          int shift = in_fmt->top[i]-bits;
          dsprintf((a,                                  "AND     r_temp1,r_pixel,#&%x<<%i       ; extract %s",mask,shift,COMPONENT_NAME(i)));
          AND(R(r_temp1), R(r_pixel), IMM12(mask<<shift), a);
          shift = out_fmt->top[i]-in_fmt->top[i];
          dsprintf((a,                                  "MOV     r_temp2,r_temp1,LS%c #%d        ; reposition %s",(shift>=0?'L':'R'),(shift>=0?shift:-shift),COMPONENT_NAME(i)));
          MOV(R(r_temp2), OP2R(R(r_temp1)) | (shift>=0?LSLI(shift):LSRI(-shift)), a);
          done_channels |= 1;
        }
      }
      /* Process remaining channels */
      for(int i=3;i>=0;i--)
      {
        if(done_channels & (1<<i))
          continue;
        done_channels |= 1<<i;
        int bits = MIN(in_fmt->bits[i],out_fmt->bits[i]);
        int mask = (1<<bits)-1;
        int shift = in_fmt->top[i]-bits;
        dsprintf((a,                                  "AND     r_temp1,r_pixel,#&%x<<%i       ; extract %s",mask,shift,COMPONENT_NAME(i)));
        AND(R(r_temp1), R(r_pixel), IMM12(mask<<shift), a);

        /* If this is the last channel to process, write to r_pixel */        
        int done = (done_channels == 15);

        shift = out_fmt->top[i]-in_fmt->top[i];
        dsprintf((a,                                  "ORR     %s,r_temp2,r_temp1,LS%c #%d        ; reposition %s",(done?"r_pixel":"r_temp2"),(shift>=0?'L':'R'),(shift>=0?shift:-shift),COMPONENT_NAME(i)));
        ORR((done?R(r_pixel):R(r_temp2)), R(r_temp2), OP2R(R(r_temp1)) | (shift>=0?LSLI(shift):LSRI(-shift)), a);
      }  
      /* Apply expansion mask */
      int pixel_expansion_mask,pixel_expansion_shift,regno=-1;
#ifdef DEBUG
      const char *regname;
#endif      
      pixel_expansion_mask = get_expansion_mask(wp,ws,in_fmt,out_fmt,&pixel_expansion_shift);
      if(pixel_expansion_mask)
      {
        if(ws->pixel_expansion_mask[0] == pixel_expansion_mask)
        {
          regno = R(r_expansionmask1);
#ifdef DEBUG
          regname = "r_expansionmask1";
#endif
        }
        else
        {
          assert(ws->pixel_expansion_mask[1] == pixel_expansion_mask, ERROR_FATAL);
          regno = R(r_expansionmask2);
#ifdef DEBUG
          regname = "r_expansionmask2";
#endif          
        }
        dsprintf((a,                                  "AND     r_temp1,r_pixel,%s ; get expansion bits %x",regname,pixel_expansion_mask));
        AND(R(r_temp1), R(r_pixel), OP2R(regno), a);
        dsprintf((a,                                  "ORR     r_pixel,r_pixel,r_temp1,LSR #%d ; apply expansion",pixel_expansion_shift));
        ORR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSRI(pixel_expansion_shift), a);
      }
      /* Manually expand green if needed */
      if((pixelformat == PixelFormat_16bpp) && (out_format > PixelFormat_16bpp))
      {
        assert((out_fmt->top[1] == 16) && (out_fmt->bits[1] == 8), ERROR_FATAL);
        AND(R(r_temp1), R(r_pixel), IMM(3) | IMMROR(18),       "AND     r_temp1,r_pixel,#&C000          ; get green expansion bits");
        ORR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSRI(6),"ORR     r_pixel,r_pixel,r_temp1,LSR #6  ; apply expansion");
      }
      /* Set alpha if needed */
      if((out_flags & PixelFormat_Alpha) && !(flags & PixelFormat_Alpha))
      {
        dsprintf((a,                                  "ORR     r_pixel,r_pixel,#&%x      ; Set alpha",PIXELFORMAT_ALPHA_MASK(out_format | out_flags)));
        ORR(R(r_pixel),R(r_pixel),out_fmt->alphaimm12 | (1<<25),a);
      }
      else if((out_fmt->bits[3] > in_fmt->bits[3]) && (in_fmt->bits[3] != pixel_expansion_shift))
      {
        /* Manual alpha expansion */
        if(in_fmt->bits[3] == 1)
        {
          /* Alpha flag will have been stored in the PSR earlier. Add it back in to the pixel. */
          dsprintf((a,                                "ORRNE   r_pixel,r_pixel,#&%x            ; Apply alpha",PIXELFORMAT_ALPHA_MASK(out_format | out_flags)));
          ORR(R(r_pixel),R(r_pixel),NE | out_fmt->alphaimm12 | (1<<25),a);
        }
        else
        {
          int bits = out_fmt->bits[3]-in_fmt->bits[3];
          int mask = (1<<bits)-1;
          int shift = out_fmt->top[3]-bits;
          dsprintf((a,                                  "AND     r_temp1,r_pixel,#&%x<<%i          ; extract alpha expansion bits",mask,shift));
          AND(R(r_temp1), R(r_pixel), IMM12(mask<<shift), a);
          shift = in_fmt->bits[3];
          dsprintf((a,                                  "ORR     r_pixel,r_pixel,r_temp1,LSR #%d   ; apply expansion",shift));
          ORR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSRI(shift), a);
        }
      }
      /* And that should be it */
      pixelformat = out_format;
      flags = out_flags;
    }
    /* Recombine pixelformat */
    pixelformat = (PixelFormat) (pixelformat | flags);
  }

  assert(pixelformat == out_pixelformat, ERROR_FATAL); /* If this hasn't happened, we haven't completed the transformation. */
}

static void blend_extract_alpha(asm_workspace *wp, workspace *ws, PixelFormat in_pixelformat,int *alpha_top,int *alpha_bits)
/* Extract the sprite alpha channel into r_alpha, ready for blending later on */
{
#ifdef DEBUG
  char a[128];
#endif  
  const PixelFormatInfo *in_fmt = pixelformat_info(in_pixelformat);
  /* Basic rules for extracting alpha are:
     * For 32bpp (i.e. alpha in top byte), shift it down
     * For 16bpp (i.e. alpha in top bit/nibble), just mask it
     All blending code assumes we've followed these rules!
  */
  if(in_fmt->bits[3] == 8)
  {
    assert(in_fmt->top[3] == 32, ERROR_FATAL);
    MOV(R(r_alpha), OP2R(R(r_pixel)) | LSRI(24) | S,"MOVS    r_alpha, r_pixel, LSR #24        ; Get alpha channel");
    *alpha_top = *alpha_bits = 8;
  }
  else
  {
    assert(in_fmt->top[3] == 16, ERROR_FATAL);
    dsprintf((a,"ANDS    r_alpha, r_pixel, #&%x     ; Get alpha channel",PIXELFORMAT_ALPHA_MASK(in_pixelformat)));
    AND(R(r_alpha), R(r_pixel), in_fmt->alphaimm12 | (1<<25) | S, a);
    *alpha_top = 16;
    *alpha_bits = in_fmt->bits[3];
  }
}

static PixelFormat blend_rgb(asm_workspace *wp, workspace *ws, PixelFormat in_pixelformat, int alpha_top, int alpha_bits, BOOL have_dithered)
/* Blend true colour r_pixel with a true colour r_outword pixel.
 *
 * Requirements:
 * ws->in_pixelformat valid
 * ws->in_bpp valid
 * ws->out_pixelformat valid
 * r_pixel allocated
 * r_outword allocated
 * r_alpha allocated if necessary
 * r_translucency allocated if necessary
 */
{
#ifdef DEBUG
  char a[128];
#endif  
  const PixelFormatInfo *in_fmt = pixelformat_info(in_pixelformat);

  /* Work out which pixel format the blend calculation is performed in */
  PixelFormat blend_pixelformat = ws->out_pixelformat;
  if(ws->odither && !have_dithered)
  {
    /* Dithering requested, blend in 32bpp */
    comment(ws, "Blending to 32bpp for dithering");
    blend_pixelformat = (PixelFormat) (PixelFormat_32bpp | (ws->out_pixelformat & (PixelFormat_RGB | PixelFormat_Alpha)));
  }
  else if(blend_pixelformat == PixelFormat_8bpp)
  {
    /* 8bpp output, blend in 15bpp ready for table lookup */
    comment(ws, "Blending to 15bpp for 8bpp output");
    blend_pixelformat = PixelFormat_15bpp;
  }
  else
  {
    comment(ws, "Blending straight to output format");
  }

  if((alpha_bits == 1) && !(wp->blending & 1))
  {
    /* Special case - 1bpp alpha, no translucency */
    /* We've already tested against zero alpha, so we know this pixel has
       full alpha. Skip the pointless blend calculation and just translate
       straight to dest.
       TODO - Skip converting to dither format if possible (i.e. dest is 16bpp)
       For that to work, we'd have to know to disable dithering when this case
       is to be taken. */
    comment(ws, "Skipping blend calculation as we only have 1bpp alpha");
    convert_pixel(wp,ws,in_pixelformat,blend_pixelformat);
    return blend_pixelformat;
  }

  /* Standard code */
  /* Calculate alpha value
     Pull apart r_pixel and r_outword one component at a time
     Blend them
     TODO - Use parallel multiply where possible */
  if(wp->blending & 2)
  {
    if(wp->save_mode & 0x80000000)
    {
      if(ISTRANS)
      {
        /* Transformed sprite alpha mask handling is somewhat sub-optimal */
        LDR_SP(r_alpha,trns_comp_mask_offset)
        LDR_SP(r_temp1,trns_comp_mask_base)
        ins(ws, LDRB(R(r_alpha),R(r_temp1)) | INDEX(R(r_alpha),0), "LDRB    r_alpha,[r_temp1,r_alpha] ; Fetch alpha mask");
        TST(R(r_alpha), IMM(128),                                 "TST     r_alpha, #128");
      }
      else
      {
        TST(R(r_maskinword), IMM(128),                            "TST     r_maskinword, #128");
        AND(R(r_alpha), R(r_maskinword), IMM(255),                "AND     r_alpha, r_maskinword, #255      ; Get alpha mask");
      }
      ADD(R(r_alpha), R(r_alpha), IMM(1) | NE,                    "ADDNE   r_alpha, r_alpha, #1             ; Expand alpha to 0-256");
      alpha_bits = 8;
      if(wp->blending & 1)
      {
        MUL(R(r_alpha), R(r_translucency), R(r_alpha), 0,         "MUL     r_alpha, r_translucency, r_alpha ; Combine with translucency");
        alpha_top = 16;
      }
      else
        alpha_top = 8;
    }
    else if(alpha_bits == 1)
    {
      /* Test against zero will have already skipped, so must be full alpha pixel. Just use translucency value as alpha. */
      assert(wp->blending & 1,ERROR_FATAL);
      MOV(R(r_alpha), OP2R(R(r_translucency)),                    "MOV     r_alpha, r_translucency");
      alpha_top = alpha_bits = 8;
    }
    else
    {
      dsprintf((a,"TST     r_alpha, #1<<%i",alpha_top-1));
      TST(R(r_alpha), IMM12(1<<(alpha_top-1)),a);
      
      assert((alpha_bits == 8) || (alpha_bits == 4), ERROR_FATAL);
      if(!(wp->blending & 1) && (alpha_bits == 4))
      {
        assert(alpha_top >= 4, ERROR_FATAL);
        ORR(R(r_alpha), R(r_alpha), OP2R(R(r_alpha)) | LSRI(4), "ORR     r_alpha, r_alpha, r_alpha, LSR #4");
        alpha_bits = 8;
      }
      
      dsprintf((a,"ADDNE   r_alpha, r_alpha, #1<<%i     ; Expand alpha to 0-256",alpha_top-alpha_bits));
      ADD(R(r_alpha), R(r_alpha), IMM12(1<<(alpha_top-alpha_bits)) | NE,a);
      if(wp->blending & 1)
      {
        MUL(R(r_alpha), R(r_translucency), R(r_alpha), 0,           "MUL     r_alpha, r_translucency, r_alpha ; Combine with translucency");
        alpha_top += 8;
      }
    }
  }
  else
  {
    assert(wp->blending & 1, ERROR_FATAL);
    assert(ws->regnames.r_alpha.regno == ws->regnames.r_translucency.regno, ERROR_FATAL);
    alpha_top = alpha_bits = 8;
  }
  /* Shift input down if it's going to cause problems
     TODO - Could skip this if we were smart enough to shift the topmost src entry down instead of masking, but that would complicate the code which tracks the calculations */
  if(in_pixelformat == PixelFormat_32bpp_Hi)
  {
    MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(8),                     "MOV     r_pixel, r_pixel, LSR #8         ; Shift input down to avoid overflow");
    in_pixelformat = PixelFormat_32bpp;
    in_fmt = pixelformat_info(in_pixelformat);
  }
  /* Work out which pixel format the screen is in */
  PixelFormat screen_pixelformat = ws->out_pixelformat;
  if(screen_pixelformat == PixelFormat_8bpp)
  {
    screen_pixelformat = PixelFormat_15bpp;
  }
  const PixelFormatInfo *blend_fmt = pixelformat_info(blend_pixelformat);
  const PixelFormatInfo *screen_fmt = pixelformat_info(screen_pixelformat);
  /* Perform the blend */
  /* TODO use parallel multiply where possible */
  /* Assuming that green is always between the red and blue channels! */
  int topmost = MAX(in_fmt->top[0],in_fmt->top[2]);
  int bits,mask;

  /* Process red or blue first - whatever is the lowest component in dest */
  /* TODO - if alpha shifted correctly, might be fastest to start with highest in dest? could AND to get src contribution of highest, then shifted ORR to add in lowest */ 
  int toggle = (blend_pixelformat & PixelFormat_RGB)?2:0;
  topmost = MAX(topmost,blend_fmt->top[toggle]);
  bits = in_fmt->bits[toggle];
  mask = ((1<<bits)-1)<<(in_fmt->top[toggle]-bits);
  dsprintf((a,  "AND     r_temp1,r_pixel,#&%x               ; Extract src %s",mask,COMPONENT_NAME(toggle)));
  AND(R(r_temp1),R(r_pixel),IMM12(mask),a);

  /* Shift alpha down to avoid overflow */
  if(topmost+alpha_top > 32)
  {
    assert((alpha_top > 8) && (topmost <= 24), ERROR_FATAL);
    dsprintf((a,"MOV     r_alpha,r_alpha,LSR #%i ; Shift alpha to avoid overflow",alpha_top-8));
    MOV(R(r_alpha),OP2R(R(r_alpha)) | LSRI(alpha_top-8),a);
    alpha_top = 8;
  }

  /* Extract the opposite component (highest in dest), compute contribution of 1st */
  mask = ((1<<bits)-1)<<(in_fmt->top[2-toggle]-bits);
  dsprintf((a,  "AND     r_temp2,r_pixel,#&%x               ; Extract src %s",mask,COMPONENT_NAME(2-toggle)));
  AND(R(r_temp2),R(r_pixel),IMM12(mask),a);
  dsprintf((a,  "MUL     r_temp1,r_alpha,r_temp1            ; src %s",COMPONENT_NAME(toggle)));
  MUL(R(r_temp1),R(r_alpha),R(r_temp1),0,a);

  /* Extract green */
  bits = in_fmt->bits[1];
  mask = ((1<<bits)-1)<<(in_fmt->top[1]-bits);
  dsprintf((a,  "AND     r_pixel,r_pixel,#&%x               ; Extract src green",mask));
  AND(R(r_pixel),R(r_pixel),IMM12(mask),a);

  /* Expand r_temp1 if necessary */
  if(in_fmt->bits[toggle] < blend_fmt->bits[toggle])
  {
    dsprintf((a,"ADD     r_temp1,r_temp1,r_temp1,LSR #%i    ; Expand src %s",in_fmt->bits[toggle],COMPONENT_NAME(toggle)));
    ADD(R(r_temp1),R(r_temp1),OP2R(R(r_temp1)) | LSRI(in_fmt->bits[toggle]),a);
  }

  /* Compute more */
  dsprintf((a,  "MUL     r_temp2,r_alpha,r_temp2            ; src %s",COMPONENT_NAME(2-toggle)));
  MUL(R(r_temp2),R(r_alpha),R(r_temp2),0,a);

  /* 1st component can just be shifted down, as we know it's the lowest in dest */
  bits = in_fmt->top[toggle] + alpha_top - blend_fmt->top[toggle];
  dsprintf((a,  "MOV     r_temp1,r_temp1,LSR #%i            ; Shift src %s down",bits,COMPONENT_NAME(toggle))); /* TODO keep fractional components to increase accuracy */
  MOV(R(r_temp1),OP2R(R(r_temp1)) | LSRI(bits),a);

  MUL(R(r_pixel),R(r_alpha),R(r_pixel),0,"MUL     r_pixel,r_alpha,r_pixel ; src green");

  /* Expand other two components if necessary */
  if(in_fmt->bits[2-toggle] < blend_fmt->bits[2-toggle])
  {
    dsprintf((a,"ADD     r_temp2,r_temp2,r_temp2,LSR #%i    ; Expand src %s",in_fmt->bits[2-toggle],COMPONENT_NAME(2-toggle)));
    ADD(R(r_temp2),R(r_temp2),OP2R(R(r_temp2)) | LSRI(in_fmt->bits[2-toggle]),a);
  }
  if(in_fmt->bits[1] < blend_fmt->bits[1])
  {
    dsprintf((a,"ADD     r_pixel,r_pixel,r_pixel,LSR #%i    ; Expand src green",in_fmt->bits[1]));
    ADD(R(r_pixel),R(r_pixel),OP2R(R(r_pixel)) | LSRI(in_fmt->bits[1]),a);
  }

  /* Add in the other two components via mask & shift */
  bits = blend_fmt->bits[2-toggle];
  mask = ((1<<bits)-1)<<(in_fmt->top[2-toggle]+alpha_top-bits);
  dsprintf((a,  "AND     r_temp2,r_temp2,#&%x               ; Mask src %s",mask,COMPONENT_NAME(2-toggle)));
  AND(R(r_temp2),R(r_temp2),IMM12(mask),a);

  bits = blend_fmt->bits[1];
  mask = ((1<<bits)-1)<<(in_fmt->top[1]+alpha_top-bits);
  dsprintf((a,  "AND     r_pixel,r_pixel,#&%x               ; Mask src green",mask));
  AND(R(r_pixel),R(r_pixel),IMM12(mask),a);

  /* Now the shift */
  bits = in_fmt->top[2-toggle] + alpha_top - blend_fmt->top[2-toggle];
  if(bits > 0)
  {
    dsprintf((a,"ORR     r_temp2,r_temp1,r_temp2,LSR #%i    ; Add in src %s",bits,COMPONENT_NAME(2-toggle)));
    ORR(R(r_temp2),R(r_temp1),OP2R(R(r_temp2)) | LSRI(bits),a);
  }
  else
  {
    dsprintf((a,"ORR     r_temp2,r_temp1,r_temp2,LSL #%i    ; Add in src %s",-bits,COMPONENT_NAME(2-toggle)));
    ORR(R(r_temp2),R(r_temp1),OP2R(R(r_temp2)) | LSLI(-bits),a);
  }

  /* Invert r_alpha ready for screen pixel calculation */
  dsprintf((a,  "RSBS    r_alpha,r_alpha,#1<<%i             ; Invert alpha ready for dest calculations",alpha_top));
  RSB(R(r_alpha),R(r_alpha),IMM12(1<<alpha_top) | S,a);

  /* We have a spare register, start extracting screen pixel components */
  if(ws->out_pixelformat == PixelFormat_8bpp)
  {
    /* Begin 8bpp -> 15bpp lookup */
    AND(R(r_temp1),R(r_outword),IMM(255) | NE,"ANDNE   r_temp1,r_outword,#255");
    ins(ws, LDR(R(r_temp1), R(r_screenpalette)) | INDEX(R(r_temp1), 2) | NE, "LDRNE   r_temp1,[r_screenpalette,r_temp1,LSL #2] ; Convert screen pixel to 15bpp");
  }
  else
  {
    /* Similar to the sprite pixel, we'll start with the lowest dest component */
    if(DEST_32_BIT)
    {
      /* r_outword not normally used. Must manually load the pixel */
      ins(ws, LDR(R(r_outword), R(r_outptr)) | OFFSET(0) | NE,"LDRNE   r_outword,[r_outptr]");
    }
    bits = screen_fmt->bits[toggle];
    mask = ((1<<bits)-1)<<(screen_fmt->top[toggle]-bits);
    dsprintf((a,  "ANDNE   r_temp1,r_outword,#&%x             ; Extract dest %s",mask,COMPONENT_NAME(toggle)));
    AND(R(r_temp1),R(r_outword),IMM12(mask) | NE,a);
  }

  /* Add in sprite green */
  bits = in_fmt->top[1] + alpha_top - blend_fmt->top[1];
  if(bits > 0)
  {
    dsprintf((a,"ORR     r_pixel,r_temp2,r_pixel,LSR #%i    ; Add in src green",bits));
    ORR(R(r_pixel),R(r_temp2),OP2R(R(r_pixel)) | LSRI(bits),a);
  }
  else
  {
    dsprintf((a,"ORR     r_pixel,r_temp2,r_pixel,LSL #%i    ; Add in src green",-bits));
    ORR(R(r_pixel),R(r_temp2),OP2R(R(r_pixel)) | LSLI(-bits),a);
  }

  /* Skip screen calculations if alpha == 0 */
  L(blend_nodestalpha)->def = 0;
  branch(ws, B | EQ, L(blend_nodestalpha), "BEQ     blend_nodestalpha");

  if(ws->out_pixelformat == PixelFormat_8bpp)
  {
    /* 8bpp is a special case as we need to read from r_temp1, not r_outword
       So start the blend calculation here and then fall through into the general code once we've read all the components */
    AND(R(r_temp2),R(r_temp1),IMM(31),             "AND     r_temp2,r_temp1,#31                ; dest red");
    MUL(R(r_temp2),R(r_alpha),R(r_temp2),0,        "MUL     r_temp2,r_alpha,r_temp2");
    if(screen_fmt->bits[0] < blend_fmt->bits[0])
    {
      dsprintf((a,                        "ADD     r_temp2,r_temp2,r_temp2,LSR #%i    ; Expand dest red",screen_fmt->bits[0]));
      ADD(R(r_temp2),R(r_temp2),OP2R(R(r_temp2)) | LSRI(screen_fmt->bits[0]),a);
    }
    bits = screen_fmt->top[0] + alpha_top - blend_fmt->top[0];
    assert(bits > 0, ERROR_FATAL);
    dsprintf((a,                          "ADD     r_pixel,r_pixel,r_temp2,LSR #%i    ; Add in dest red",bits));
    ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp2)) | LSRI(bits),a);

    AND(R(r_temp2),R(r_temp1),IMM(31)|IMMROR(22),  "AND     r_temp2,r_temp1,#31<<10            ; dest blue");
    AND(R(r_temp1),R(r_temp1),IMM(31*2)|IMMROR(28),"AND     r_temp1,r_temp1,#31<<5             ; dest green");
    MUL(R(r_temp2),R(r_alpha),R(r_temp2),0,        "MUL     r_temp2,r_alpha,r_temp2");
    toggle = 0;
  }
  else
  {
    /* Compute contribution of 1st screen component */
    dsprintf((a,  "MUL     r_temp1,r_alpha,r_temp1            ; dest %s",COMPONENT_NAME(toggle)));
    MUL(R(r_temp1),R(r_alpha),R(r_temp1),0,a);
  
    /* Extract opposite screen component */
    bits = screen_fmt->bits[2-toggle];
    mask = ((1<<bits)-1)<<(screen_fmt->top[2-toggle]-bits);
    dsprintf((a,  "AND     r_temp2,r_outword,#&%x             ; Extract dest %s",mask,COMPONENT_NAME(2-toggle)));
    AND(R(r_temp2),R(r_outword),IMM12(mask),a);

    /* Expand r_temp1 if necessary */
    if(screen_fmt->bits[toggle] < blend_fmt->bits[toggle])
    {
      dsprintf((a,"ADD     r_temp1,r_temp1,r_temp1,LSR #%i    ; Expand dest %s",screen_fmt->bits[toggle],COMPONENT_NAME(toggle)));
      ADD(R(r_temp1),R(r_temp1),OP2R(R(r_temp1)) | LSRI(screen_fmt->bits[toggle]),a);
    }
  
    bits = screen_fmt->top[toggle] + alpha_top - blend_fmt->top[toggle];
    if(bits > 0)
    {
      dsprintf((a,"ADD     r_pixel,r_pixel,r_temp1,LSR #%i    ; Add in dest %s",bits,COMPONENT_NAME(toggle)));
      ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp1)) | LSRI(bits),a);
    }
    else
    {
      dsprintf((a,"ADD     r_pixel,r_pixel,r_temp1,LSL #%i    ; Add in dest %s",-bits,COMPONENT_NAME(toggle)));
      ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp1)) | LSLI(-bits),a);
    }
  
    dsprintf((a,  "MUL     r_temp2,r_alpha,r_temp2            ; dest %s",COMPONENT_NAME(2-toggle)));
    MUL(R(r_temp2),R(r_alpha),R(r_temp2),0,a);
  
    bits = screen_fmt->bits[1];
    mask = ((1<<bits)-1)<<(screen_fmt->top[1]-bits);
    dsprintf((a,  "AND     r_temp1,r_outword,#&%x             ; Extract dest green",mask));
    AND(R(r_temp1),R(r_outword),IMM12(mask),a);
  }
  
  if(screen_fmt->bits[2-toggle] < blend_fmt->bits[2-toggle])
  {
    dsprintf((a,"ADD     r_temp2,r_temp2,r_temp2,LSR #%i    ; Expand dest %s",screen_fmt->bits[2-toggle],COMPONENT_NAME(2-toggle)));
    ADD(R(r_temp2),R(r_temp2),OP2R(R(r_temp2)) | LSRI(screen_fmt->bits[2-toggle]),a);
  }

  /* Mask & shift */
  bits = blend_fmt->bits[2-toggle];
  mask = ((1<<bits)-1)<<(screen_fmt->top[2-toggle]+alpha_top-bits);
  /* Fudge - when expanding to 32bpp in order to perform dithering we
     sometimes need to generate impossible 12bit immediate constants
     (i.e. 0xff at an odd bit offset)
     Deal with this by dropping the bottom bit of the mask, the effect
     should be negligible */
  if((bits == 8) && ((screen_fmt->top[2-toggle]+alpha_top-bits) & 1))
  {
    mask = mask & (mask<<1);
  }
  dsprintf((a,  "AND     r_temp2,r_temp2,#&%x               ; Mask dest %s",mask,COMPONENT_NAME(2-toggle)));
  AND(R(r_temp2),R(r_temp2),IMM12(mask),a);

  MUL(R(r_temp1),R(r_alpha),R(r_temp1),0,"MUL     r_temp1,r_alpha,r_temp1 ; dest green");

  bits = screen_fmt->top[2-toggle] + alpha_top - blend_fmt->top[2-toggle];
  if(bits > 0)
  {
    dsprintf((a,"ADD     r_pixel,r_pixel,r_temp2,LSR #%i    ; Add in dest %s",bits,COMPONENT_NAME(2-toggle)));
    ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp2)) | LSRI(bits),a);
  }
  else
  {
    dsprintf((a,"ADD     r_pixel,r_pixel,r_temp2,LSL #%i    ; Add in dest %s",-bits,COMPONENT_NAME(2-toggle)));
    ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp2)) | LSLI(-bits),a);
  }
  
  if(screen_fmt->bits[1] < blend_fmt->bits[1])
  {
    dsprintf((a,"ADD     r_temp1,r_temp1,r_temp1,LSR #%i    ; Expand dest green",screen_fmt->bits[1]));
    ADD(R(r_temp1),R(r_temp1),OP2R(R(r_temp1)) | LSRI(screen_fmt->bits[1]),a);
  }

  bits = blend_fmt->bits[1];
  mask = ((1<<bits)-1)<<(screen_fmt->top[1]+alpha_top-bits);
  /* Deal with impossible constants */
  if((bits == 8) && ((screen_fmt->top[1]+alpha_top-bits) & 1))
  {
    mask = mask & (mask<<1);
  }
  dsprintf((a,  "AND     r_temp1,r_temp1,#&%x               ; Mask dest green",mask));
  AND(R(r_temp1),R(r_temp1),IMM12(mask),a);

  /* Restore r_alpha if necessary */
  if(ws->regnames.r_alpha.regno == ws->regnames.r_translucency.regno)
  {
    DEFINE_LABEL(blend_nodestalpha,"Skip dest blend calc");
    dsprintf((a,"RSB     r_alpha,r_alpha,#1<<%i             ; Restore r_alpha / r_translucency",alpha_top));
    RSB(R(r_alpha),R(r_alpha),IMM12(1<<alpha_top),a);    
  }

  bits = screen_fmt->top[1] + alpha_top - blend_fmt->top[1];
  if(bits > 0)
  {
    dsprintf((a,"ADDNE   r_pixel,r_pixel,r_temp1,LSR #%i    ; Add in dest green",bits));
    ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp1)) | LSRI(bits) | NE,a);
  }
  else
  {
    dsprintf((a,"ADDNE   r_pixel,r_pixel,r_temp1,LSL #%i    ; Add in dest green",-bits));
    ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp1)) | LSLI(-bits) | NE,a);
  }

  if(!L(blend_nodestalpha)->def)
    DEFINE_LABEL(blend_nodestalpha,"Skip dest blend calc");

  if(blend_pixelformat & PixelFormat_Alpha)
  {
    dsprintf((a,"ORR     r_pixel, r_pixel, #&%x",PIXELFORMAT_ALPHA_MASK(blend_pixelformat)));
    ORR(R(r_pixel),R(r_pixel),blend_fmt->alphaimm12 | (1<<25),a);
  }

  /* And we're done! */

  return blend_pixelformat;
}

static PixelFormat apply_dither(asm_workspace *wp, workspace *ws, PixelFormat pixelformat, BOOL *have_dithered)
{
  if(ws->odither && !*have_dithered)
  {
    if(((pixelformat & PixelFormat_BPPMask) == PixelFormat_12bpp)
      && (ws->out_pixelformat >= PixelFormat_4bpp))
    {
      /* When dithering 12bpp down to 4bpp/8bpp, we need to
         convert to 32bpp to make it look good, and to fix
         bugs with the dither value writing into the wrong
         colour channels */
      PixelFormat ditherformat = (PixelFormat) (PixelFormat_32bpp | (pixelformat & (PixelFormat_RGB | PixelFormat_Alpha)));
      convert_pixel(wp,ws,pixelformat,ditherformat);
      pixelformat = ditherformat;
    }
    add_ordered_dither(wp, ws, pixelformat); /* do ordered dither */
    *have_dithered = TRUE;
  }
  return pixelformat;
}

static PixelFormat pick_colourmap_format(asm_workspace *wp, workspace *ws, PixelFormat in_pixelformat, PixelFormat out_pixelformat)
{
  /* Based around input and output pixel format, pick a sensible ColourTTRFormat
     value which will (ideally) allow us to perform a 1-instruction translation
     to 32bpp_Hi ready for passing to the colour mapping code */
  if((in_pixelformat & PixelFormat_Alpha) && (out_pixelformat & PixelFormat_Alpha))
  {
    /* Alpha needs preserving. Only sensible choice is 32bpp + alpha. */
    return (PixelFormat) (PixelFormat_32bpp + PixelFormat_Alpha);
  }
  else if((wp->CPUFlags & CPUFlag_REV) && ((in_pixelformat & ~PixelFormat_Alpha) == (PixelFormat_32bpp + PixelFormat_RGB)))
  {
    /* If REV is available we can do a 1-instruction translation from &TTRRGGBB to 32bpp_Hi */
    return (PixelFormat) (PixelFormat_32bpp + PixelFormat_RGB);
  }
  else
  {
    /* Just go for 32bpp, with or without alpha, as we'll shift up to discard top byte */
    return (PixelFormat) (PixelFormat_32bpp + (in_pixelformat & PixelFormat_Alpha));
  }
}

static PixelFormat apply_ttr(asm_workspace *wp, workspace *ws, PixelFormat pixelformat, BOOL *have_dithered)
/* Apply the TTR, and perform any dithering if necessary */
{
  BOOL preserve_alpha;
  switch(wp->TTRType & ~TTRType_Optional)
  {
  case TTRType_None:
    break;
  case TTRType_Normal:
    assert(pixelformat == ws->ColourTTRFormat, ERROR_FATAL);
    ins(ws, LDRB(R(r_pixel), R(r_table)) | INDEX(R(r_pixel), 0),  "LDRB    r_pixel,[r_table, r_pixel]      ; byte table lookup");
    pixelformat = ws->out_pixelformat;
    break;
  case TTRType_Wide:
    assert(pixelformat == ws->ColourTTRFormat, ERROR_FATAL);
    ins(ws, LDR(R(r_pixel), R(r_table)) | INDEX(R(r_pixel), 2),   "LDR     r_pixel,[r_table, r_pixel, LSL #2] ; word table lookup");
    pixelformat = ws->out_pixelformat;
    break;
  case TTRType_32K:
    /* Hack - skip if this is JPEG and we're already correct */
    if(wp->is_it_jpeg && (pixelformat <= PixelFormat_8bpp))
    {
      assert(pixelformat == ws->out_pixelformat,ERROR_FATAL);
      break;
    }
    /* If we're applying a 32K table, now is our last chance to perform dithering */
    pixelformat = apply_dither(wp,ws,pixelformat,have_dithered);
    if(pixelformat != ws->ColourTTRFormat)
      convert_pixel(wp,ws,pixelformat,ws->ColourTTRFormat);
    ins(ws, LDRB(R(r_pixel), R(r_table)) | INDEX(R(r_pixel), 0),  "LDRB    r_pixel,[r_table, r_pixel]      ; 32K-style table lookup");
    pixelformat = ws->out_pixelformat;
    break;
  case TTRType_ColourMap:
    if(pixelformat != ws->ColourTTRFormat)
      convert_pixel(wp,ws,pixelformat,ws->ColourTTRFormat);
    assert(R(r_pixel) == 14, ERROR_FATAL);
    /* Call the colour map code.. slightly nasty!
       This would be nicer if r0 == r_pixel, but I'm not sure how much code
       is left which assumes r_pixel == r14 (or that r14 isn't r_temp1/r_temp2)
       */
    comment(ws, "Performing colour mapping");
    ins(ws, PUSH | (1<<12) | (1<<0),                    "STMDB   sp!,{r0,r12}");
    preserve_alpha = ((ws->ColourTTRFormat & PixelFormat_Alpha) && (ws->out_pixelformat & PixelFormat_Alpha));
    if(preserve_alpha)
    {
      /* Preserve alpha. Should be in top byte. */
      assert(ws->ColourTTRFormat == PixelFormat_32bpp + PixelFormat_Alpha, ERROR_FATAL);
      if(ISTRANS)
      {
        /* r_temp2 used to avoid r12 clash with hardcoded r_temp1 */
        assert((R(r_temp2) != 0) && (R(r_temp1) == 12), ERROR_FATAL); /* Check that our hardcoding assumptions are correct */
        AND(R(r_temp2),R(r_pixel),IMM(255)|IMMROR(8),   "AND     r_temp2,r_pixel,#&ff000000 ; Preserve alpha");
      }
      else
      {
        assert((R(r_temp1) != 0) && (R(r_temp1) < 12), ERROR_FATAL);
        AND(R(r_temp1),R(r_pixel),IMM(255)|IMMROR(8),   "AND     r_temp1,r_pixel,#&ff000000 ; Preserve alpha");
      }
    }
    if(R(r_table) == 0)
    {
      /* r_table may sometimes be allocated to R0, which is a bit of a pain.
         Relocate to r12 instead.
         TODO - Avoid this clash when allocating registers. Mainly happens with
         sprtrans, but could conceivably happen with putscaled too.
      */
      MOV(12,OP2R(0),                                   "MOV     r12,r_table ; Protect r_table (r0)");
    }
    /* 1-instruction translation from ColourTTRFormat to 32bpp_Hi */
    switch(ws->ColourTTRFormat)
    {
    case PixelFormat_32bpp:
    case PixelFormat_32bpp + PixelFormat_Alpha:
      MOV(0,OP2R(R(r_pixel))|LSLI(8),                   "MOV     r0,r_pixel,LSL #8 ; Convert to palette entry");
      break;
    case PixelFormat_32bpp + PixelFormat_RGB:
      assert(wp->CPUFlags & CPUFlag_REV, ERROR_FATAL);
      REV(0,R(r_pixel),0,                               "REV     r0,r_pixel ; Convert to palette entry");
      break;
    default:
      assert(ws->ColourTTRFormat == PixelFormat_32bpp_Hi, ERROR_FATAL);
      MOV(0,OP2R(R(r_pixel)),                           "MOV     r0,r_pixel");
      break;
    }
    MOV(R(lr),OP2R(R(pc)),                              "MOV     lr,pc");
    if(R(r_table) == 0)
    {
      ins(ws, LDMIA(12) | (1<<12)|(1<<15),              "LDMIA   r12,{r12,pc} ; Call colour mapping code");
    }
    else
    {
      ins(ws, LDMIA(R(r_table)) | (1<<12)|(1<<15),      "LDMIA   r_table,{r12,pc} ; Call colour mapping code");
    }
    /* 1-instruction translation from 32bpp_Hi to something closer to the output format, or at least something a bit easier to work with */
    if(preserve_alpha)
    {
      if(ISTRANS)
      {
        ORR(R(r_pixel),R(r_temp2),0|LSRI(8),            "ORR     r_pixel,r_temp2,r0,LSR #8");
      }
      else
      {
        ORR(R(r_pixel),R(r_temp1),0|LSRI(8),            "ORR     r_pixel,r_temp1,r0,LSR #8");
      }
      pixelformat = (PixelFormat) (PixelFormat_32bpp+PixelFormat_Alpha);
    }
    else if(((ws->out_pixelformat & ~PixelFormat_Alpha) == (PixelFormat_32bpp + PixelFormat_RGB)) && (wp->CPUFlags & CPUFlag_REV))
    {
      REV(R(r_pixel),0,0,                               "REV     r_pixel,r0");
      pixelformat = (PixelFormat) (PixelFormat_32bpp+PixelFormat_RGB);
    }
    else
    {
      MOV(R(r_pixel),0|LSRI(8),                         "MOV     r_pixel,r0,LSR #8");
      pixelformat = PixelFormat_32bpp;
    }
    ins(ws, POP | (1<<12) | (1<<0),                     "LDMIA   sp!,{r0,r12}");
    /* Apply r_inversetable if we have <=8bpp output */
    if(wp->BPP <= 8)
    {
      pixelformat = apply_dither(wp,ws,pixelformat,have_dithered);
      comment(ws,"Convert to 15bpp and apply inversetable");
      convert_pixel(wp,ws,pixelformat,PixelFormat_15bpp);
      ins(ws, LDRB(R(r_pixel), R(r_inversetable)) | INDEX(R(r_pixel), 0), "LDRB    r_pixel,[r_inversetable,r_pixel]");
      pixelformat = ws->out_pixelformat;
    }
    break;
  case TTRType_Palette:
    assert(pixelformat == ws->ColourTTRFormat, ERROR_FATAL);
    ins(ws, LDR(R(r_pixel), R(r_table))
          | INDEX(R(r_pixel), 3),                     "LDR     r_pixel,[r_table, r_pixel, LSL #3] ; standard palette lookup");
    pixelformat = PixelFormat_32bpp_Hi;
    break;
  }

  return pixelformat;
}

static void translate_pixel(asm_workspace *wp, workspace *ws)
/* Translate r_pixel from being a source pixel, to being a destination pixel.
 *
 * Requirements:
 * ws->in_pixelformat valid
 * ws->in_bpp valid
 * ws->out_pixelformat valid
 * ws->gcol valid
 * ws->odither valid
 * wp->ColourTTR valid
 * ws->ColourTTRFormat valid
 * wp->BPP valid
 * wp->BPC valid
 * wp->Log2bpp valid
 * dither_expansion_init() called
 * r_pixel allocated
 * r_table allocated if necessary
 * r_blendtable allocated if necessary
 * r_outword allocated if necessary
 * r_alpha allocated if necessary
 * r_translucency allocated if necessary
 */
{
#ifdef DEBUG
  char a[128];
#endif  
  PixelFormat pixelformat = ws->in_pixelformat;

  if (PLOTMASK || TRANSMASK)
  {
    if ((ws->gcol == 2) && ((pixelformat & PixelFormat_BPPMask) != PixelFormat_32bpp)) /* AND plot action */
    {
      MOV(R(r_pixel), OP2R(R(r_pixel)) | LSLI(31-(wp->BPC)),  "MOV     r_pixel, r_pixel, LSL 31-out_bpc ;a");
      ORR(R(r_pixel), R(r_pixel), IMM(2) | IMMROR(2),         "ORR     r_pixel,r_pixel,#&80000000       ;a");
      MOV(R(r_pixel), OP2R(R(r_pixel)) | ASRI(31-(wp->BPC)),  "MOV     r_pixel, r_pixel, ASR 31-out_bpc ;a");
    }
    return; /* No more transformation necessary */
  }

  switch_bank(wp, ws, REGFLAG_XLOOP,REGFLAG_PERPIXEL);

  comment(ws, "Perform any transformation necessary");

  /* Work out if we want to apply the ttr before or after (or during) the blend:
     * For BlendImpl_BlendTable:
       If we have an optional TTR for a palletised source, we never want to
       apply it. This is currently taken care of by compute_blendimpl
       So, if we have a table, we want to apply it now
     * For BlendImpl_BlendTables:
       If we have an optional TTR for a palletised source, we apply it during
       the blend (for full alpha pixels). Partially alpha'd pixels use LUTs
       generated from the source palette.
       Other types of TTR are applied once we've extracted and tested the source
       alpha.
     * For BlendImpl_InverseTable:
       We want to operate on true colour values, but as we have an 8bpp dest
       any TTR we have will be designed around that. So completely ignore any
       optional 32K table (handled in compute_blendimpl), and apply all others
       before the blend (as we currently don't have support for reading the
       sprite palette here)
     * For BlendImpl_True:
       We want to operate on true colour values, so always apply the TTR first
       as it'll either be a palette/wide TTR or a colour map
    */

  BOOL ttr_before_blend = TRUE;
  switch(ws->blendimpl)
  {
  case BlendImpl_BlendTables:
    ttr_before_blend = FALSE;
    break;
  }

  /* If we're performing blending using the sprite alpha channel, we must
     extract the alpha value before applying any TTR, as the TTR will destroy
     it. We also take this opportunity to test the pixel alpha against zero
     and skip the rest of this code if possible.
     TODO - Use mask skip branch address where possible.
  */
  if(wp->blending)
  {
    L(translate_noalpha)->def = 0;
    L(translate_noalpha2)->def = 0;
  }
  int alpha_top = 0;
  int alpha_bits = 0;
  if((wp->blending & 2) && !(wp->save_mode & 0x80000000))
  {
    blend_extract_alpha(wp,ws,pixelformat,&alpha_top,&alpha_bits);
    if(wp->BPP <= 8)
    {
      AND(R(r_pixel), R(r_outword), IMM(ws->out_pixmask) | EQ, "ANDEQ   r_pixel, r_outword, #out_pixmask ; just use dest pixel if 0 alpha");
    }
    else if(wp->BPP == 32)
    {
      ins(ws, LDR(R(r_pixel), R(r_outptr)) | OFFSET(0) | EQ,   "LDREQ   r_pixel,[r_outptr]             ; just use dest pixel if 0 alpha");
    }
    else
    {
      assert(wp->BPP == 16, ERROR_FATAL);
      if(wp->CPUFlags & CPUFlag_T2)
      {
        UBFX(R(r_pixel),R(r_outword),0,16,EQ,                  "UBFXEQ  r_pixel,r_outword,#0,#16       ; just use dest pixel if 0 alpha");
      }
      else
      {
        MOV(R(r_pixel), OP2R(R(r_outword)) | LSLI(16) | EQ,    "MOVEQ   r_pixel,r_outword,LSL #16      ; just use dest pixel if 0 alpha");
        MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(16) | EQ,      "MOVEQ   r_pixel,r_pixel,LSR #16");
      }
    }
    branch(ws, B | EQ, L(translate_noalpha),                   "BEQ     translate_noalpha                ; and skip remaining blend code");
  }

  BOOL have_dithered = FALSE;
  if(ttr_before_blend && wp->TTRType)
  {  
    pixelformat = apply_ttr(wp,ws,pixelformat,&have_dithered);
  }  

  /* Blending */
  int alpha_shift = 0;
  switch(ws->blendimpl)
  {
  case BlendImpl_BlendTable:
    /* Single blend table */
    /* JPEG might need translating to out_pixelformat before the blend can take place */
    if((wp->is_it_jpeg) && (pixelformat > PixelFormat_8bpp))
    {
      pixelformat = apply_dither(wp,ws,pixelformat,&have_dithered);
      convert_pixel(wp,ws,pixelformat,ws->out_pixelformat);
      pixelformat = ws->out_pixelformat;
    }
    comment(ws, "Use blend table");
    AND(R(r_temp1), R(r_outword), IMM((1<<wp->BPP)-1) | IMMROR(0),    "AND     r_temp1, r_outword, #(1<<out_bpp)-1");
    if((wp->is_it_jpeg) || (wp->TTRType != TTRType_None))
    {
      /* r_pixel should have been translated by ColourTTR to output bpp */
      assert(pixelformat == ws->out_pixelformat, ERROR_FATAL);
      ORR(R(r_temp1), R(r_pixel), OP2R(R(r_temp1)) | LSLI(wp->BPP),   "ORR     r_temp1, r_pixel, r_temp1, LSL #out_bpp");
    }
    else
    {
      assert(pixelformat == ws->in_pixelformat, ERROR_FATAL);
      ORR(R(r_temp1), R(r_pixel), OP2R(R(r_temp1)) | LSLI(ws->in_bpp),"ORR     r_temp1, r_pixel, r_temp1, LSL #in_bpp");
    }
    ins(ws, LDRB(R(r_pixel), R(r_blendtable)) | INDEX(R(r_temp1), 0), "LDRB    r_pixel, [r_blendtable, r_temp1]");
    pixelformat = ws->out_pixelformat;
    break;
  case BlendImpl_InverseTable:
    /* TODO should really use source palette for this, via makepalette16bpp */
    if(pixelformat == PixelFormat_8bpp)
    {
      ins(ws, LDR(R(r_pixel), R(r_screenpalette)) | INDEX(R(r_pixel), 2),"LDR     r_pixel,[r_screenpalette,r_pixel,LSL #2] ; Convert sprite pixel to 15bpp");
      pixelformat = PixelFormat_15bpp;
    }
    /* Fall through... */
  case BlendImpl_True:
    /* True colour blend */
    comment(ws, "True colour blend");
    assert(pixelformat > PixelFormat_8bpp, ERROR_FATAL);
    pixelformat = blend_rgb(wp,ws,pixelformat,alpha_top,alpha_bits,have_dithered);
    break;
  case BlendImpl_BlendTables:
    /* Screen is <= 4bpp, use lots of blendtables
       If src is true colour, use ColourTTR to convert to screen
       Else use palette index directly */
    comment(ws, "Lots of blend tables");
    /* r_translucency (if used) assumed to be 0-256 alpha */
    assert(wp->blending & 2, ERROR_FATAL);
    /* Calculate the alpha value and branch if 0
       Actual blend happens later on */
    if (SOURCE_ALPHAMASK)
    {
      /* Alpha mask */
      if(ISTRANS)
      {
        /* Transformed sprite alpha mask handling is somewhat sub-optimal */
        LDR_SP(r_alpha,trns_comp_mask_offset)
        LDR_SP(r_temp1,trns_comp_mask_base)
        ins(ws, LDRB(R(r_alpha),R(r_temp1)) | INDEX(R(r_alpha),0), "LDRB    r_alpha,[r_temp1,r_alpha]        ; Fetch alpha mask");
      }
      if (wp->blending & 1)
      {
        if(!ISTRANS)
        {
          AND(R(r_alpha), R(r_maskinword), IMM(255),             "AND     r_alpha, r_maskinword, #255      ; Alpha mask");
        }
        MUL(R(r_alpha), R(r_translucency), R(r_alpha), 0,        "MUL     r_alpha, r_translucency, r_alpha ; Combined mask + SpriteOp translucency");
        MOV(R(r_alpha), OP2R(R(r_alpha)) | LSRI(13) | S,         "MOVS    r_alpha, r_alpha, LSR #13");
      }
      else
      {
        if(ISTRANS)
        {
          AND(R(r_alpha), R(r_alpha), IMM(0xE0) | S,             "ANDS    r_alpha, r_alpha, #&E0           ; Alpha mask");
        }
        else
        {
          AND(R(r_alpha), R(r_maskinword), IMM(0xE0) | S,        "ANDS    r_alpha, r_maskinword, #&E0      ; Alpha mask");
        }
        alpha_shift = 5;
      }
      alpha_bits = 3;  
    }
    else if (alpha_bits)
    {
      /* Alpha channel */
      unsigned int chan_mask = ((1<<alpha_bits)-1)<<(alpha_top-alpha_bits);
      if (wp->blending & 1)
      {
        if (alpha_bits == 1)
        {
          MOV(R(r_alpha), OP2R(R(r_translucency))|LSRI(5)|S,     "MOVS  r_alpha, r_translucency, LSR #5");
        }
        else
        {
          assert(alpha_bits >= 4, ERROR_FATAL);
          if(chan_mask == 0xff)
          {
            MUL(R(r_alpha), R(r_translucency), R(r_alpha), 0,    "MUL     r_alpha, r_translucency, r_alpha ; Combined alpha + SpriteOp translucency");
            MOV(R(r_alpha), OP2R(R(r_alpha)) | LSRI(13) | S,     "MOVS    r_alpha, r_alpha, LSR #13");
          }
          else
          {
            assert(chan_mask == 0xf000, ERROR_FATAL);
            MUL(R(r_alpha), R(r_translucency), R(r_alpha), 0,    "MUL     r_alpha, r_translucency, r_alpha ; Combined alpha + SpriteOp translucency");
            MOV(R(r_alpha), OP2R(R(r_alpha)) | LSRI(21) | S,     "MOVS    r_alpha, r_alpha, LSR #21");
          }  
        }
        alpha_bits = 3;  
      }
      else
      {
        chan_mask &= ~(chan_mask>>3);
        dsprintf((a,"ANDS    r_alpha, r_alpha, #&%x ; Alpha channel",chan_mask));
        AND(R(r_alpha), R(r_alpha), IMM12(chan_mask) | S,a);
        alpha_shift = alpha_top-3;
        alpha_bits = (alpha_bits>3?3:alpha_bits); /* Should be 1 or 3, asserted below */
      }
    }
    else
    {
      /* Ordinary translucent plotting */
      /* This shouldn't happen, should be handled by single blendtable case above */
      assert(0, ERROR_FATAL);
    }
    AND(R(r_pixel), R(r_outword), IMM(ws->out_pixmask) | EQ,   "ANDEQ   r_pixel, r_outword, #out_pixmask ; just use dest pixel if 0 alpha");
    /* TODO can use mask skip branch address? */
    branch(ws, B | EQ, L(translate_noalpha2),                  "BEQ     translate_noalpha                ; and skip remaining blend code");

    /* Apply TTR here, unless it's an optional normal TTR (in which case we
       only apply for full alpha pixels) */
    assert(!ttr_before_blend, ERROR_FATAL);
    if(wp->TTRType != TTRType_Normal+TTRType_Optional)
    {
      pixelformat = apply_ttr(wp,ws,pixelformat,&have_dithered);
      ttr_before_blend = TRUE;
    }

    /* Assume r_alpha 0-8 or 0-1, with 8/1 case already handled with a branch */
    if(alpha_bits == 3)
    {
      assert(alpha_bits == 3,ERROR_FATAL);
      dsprintf((a,"CMP     r_alpha,#%i<<%i",(1<<alpha_bits)-1,alpha_shift));
      CMP(R(r_alpha), IMM12(((1<<alpha_bits)-1)<<alpha_shift),a);
      if (wp->TTRType == TTRType_Normal+TTRType_Optional)
      {
        /* Use the supplied TTR to translate any full alpha pixels */
        ins(ws, LDRB(R(r_pixel), R(r_table)) | INDEX(R(r_pixel), 0) | HS,   "LDRHSB  r_pixel,[r_table, r_pixel]      ; byte table lookup");
      }
      if(alpha_shift > 2)
      {
        dsprintf((a,"LDRLO   r_alpha,[r_blendtable,r_alpha,LSR #%d]",alpha_shift-2));
        ins(ws, LDR(R(r_alpha), R(r_blendtable)) | INDEX_LSR(R(r_alpha), alpha_shift-2) | LO, a);
      }
      else
      {
        dsprintf((a,"LDRLO   r_alpha,[r_blendtable,r_alpha,LSL #%d]",2-alpha_shift));
        ins(ws, LDR(R(r_alpha), R(r_blendtable)) | INDEX(R(r_alpha), 2-alpha_shift) | LO, a);
      }
      AND(R(r_temp1), R(r_outword), IMM((1<<wp->BPP)-1) | IMMROR(0) | LO,   "ANDLO   r_temp1, r_outword, #(1<<out_bpp)-1");
      if(ttr_before_blend)
      {
        /* r_pixel should have been translated by ColourTTR to output bpp */
        assert(pixelformat == ws->out_pixelformat, ERROR_FATAL);
        ORR(R(r_temp1), R(r_pixel), OP2R(R(r_temp1)) | LSLI(wp->BPP) | LO,  "ORRLO   r_temp1, r_pixel, r_temp1, LSL #out_bpp");
      }
      else
      {
        /* TTR will have been applied for full alpha pixels, but won't have been applied for these partial alpha ones */
        assert(pixelformat == ws->in_pixelformat, ERROR_FATAL);
        ttr_before_blend = TRUE;
        ORR(R(r_temp1), R(r_pixel), OP2R(R(r_temp1)) | LSLI(ws->in_bpp) |LO,"ORRLO   r_temp1, r_pixel, r_temp1, LSL #in_bpp");
      }
      ins(ws, LDRB(R(r_pixel), R(r_alpha)) | INDEX(R(r_temp1), 0) | LO,     "LDRLOB    r_pixel, [r_alpha, r_temp1]");
    }
    else
    {
      assert(alpha_bits == 1, ERROR_FATAL);
      if ((wp->ColourTTR != 0) && (ws->ColourTTRFormat <= PixelFormat_8bpp))
      {
        /* Should be impossible, 1bpp alpha only possible with 1bpp alpha channel, which means 16bpp sprite pixels */
        assert(0, ERROR_FATAL);
      }
    }
    pixelformat = ws->out_pixelformat;              /* we've finished */
    break;
  }

  pixelformat = apply_dither(wp,ws,pixelformat,&have_dithered);

  switch(ws->blendimpl)
  {
  case BlendImpl_InverseTable:
    /* Inverse table lookup for 15bpp -> palette
       TODO - Could potentially use ColourTTR here if it was an optional (i.e.
       ordinary) 32K table */
    assert(ws->out_pixelformat == PixelFormat_8bpp, ERROR_FATAL);
    assert(pixelformat >= PixelFormat_12bpp, ERROR_FATAL);
    if(pixelformat != PixelFormat_15bpp)
    {
      convert_pixel(wp,ws,pixelformat,PixelFormat_15bpp);
    }
    ins(ws, LDRB(R(r_pixel), R(r_inversetable)) | INDEX(R(r_pixel), 0),  "LDRB    r_pixel,[r_inversetable, r_pixel]      ; 32K-style inversetable lookup");
    pixelformat = PixelFormat_8bpp;
    break;
  }

  /* Do any extra conversion necessary */
  if(pixelformat != ws->out_pixelformat)
  {
    convert_pixel(wp,ws,pixelformat,ws->out_pixelformat);
    pixelformat = ws->out_pixelformat;
  }

  if(wp->blending)
  {
    DEFINE_LABEL(translate_noalpha,"Skip blend calc");
    DEFINE_LABEL(translate_noalpha2,"Skip blend calc");
  }

  if ((ws->gcol == 2) && ((pixelformat & PixelFormat_BPPMask) != PixelFormat_32bpp)) /* AND plot action which did something stupid for 32bpp (GPS)*/
  {
    MOV(R(r_pixel), OP2R(R(r_pixel)) | LSLI(31-(wp->BPC)),  "MOV     r_pixel, r_pixel, LSL 31-out_bpc");
    ORR(R(r_pixel), R(r_pixel), IMM(2) | IMMROR(2),         "ORR     r_pixel,r_pixel,#&80000000 ");
    MOV(R(r_pixel), OP2R(R(r_pixel)) | ASRI(31-(wp->BPC)),  "MOV     r_pixel, r_pixel, ASR 31-out_bpc");
  }

  comment(ws, "r_pixel is now a destination pixel.");
  assert(have_dithered == (ws->odither != 0), ERROR_FATAL);

  if (DPIXEL_OUTPUT)
    ORR(R(r_pixel), R(r_pixel), OP2R(R(r_pixel)) | LSLI(wp->BPP),   "ORR     r_pixel,r_pixel,r_pixel,LSL #out_bpp ; double pixel output");

  switch_bank(wp, ws, REGFLAG_PERPIXEL,REGFLAG_XLOOP);

  newline();
}

/**************************************************************************
*                                                                         *
*    Advancing the current pixel.                                         *
*                                                                         *
**************************************************************************/

static void odither_inc(asm_workspace *wp, workspace *ws, int xy)
/* Call every output pixel - alternates the ordered dither addition value
 * xy == 0 for x, 1 for y
 *
 * Requirements:
 * ws->odither valid
 * dither_expansion_init() called
 * r_oditheradd allocated if necessary
 */
{
  if (ws->odither)
    EOR(R(r_oditheradd),R(r_oditheradd), IMM(1 << (ws->odither - xy)) | IMMROR(8),
      xy == 0 ? "EOR     r_oditheradd,r_oditheradd,#odither_eorvalue ; alternate dither offset"
              : "EOR     r_oditheradd,r_oditheradd,#odither_eorvalue:SHR:1 ; alternate dither offset");
  UNUSED(wp);
}

/**************************************************************************
*                                                                         *
*    Misc                                                                 *
*                                                                         *
**************************************************************************/

static int get_key_word(asm_workspace *wp, workspace *ws)
/* Compute the low bits of the key word value */
{
  int key_word;

  key_word = ws->in_pixelformat             /* 0..5 */
               + (ws->out_pixelformat << 6) /* 6..11 */
               + (ws->gcol << 12)           /* 12..14 */
               + (ws->masktype << 15)       /* 15..16 */
               + (wp->TTRType << 17);       /* 17..20 */
  if (DPIXEL_OUTPUT) key_word |= 1<<21;
  if (DPIXEL_INPUT) key_word |= 1<<22;
  if (PLOTMASK || TRANSMASK) key_word |= 1<<23;
  if (ISTRANS) key_word |= 1<<24;
  key_word |= (wp->blending << 25);         /* 25..26 */

  /* Bits 27+ are free for putscaled/sprtrans to use as they please */

  return key_word;
}

static void compile_buffer_init(asm_workspace *wp, workspace *ws)
/* We intend to compile some code. Pick a buffer to use, and set up
 * for generating into it. We use a simple round-robin for reusing buffers,
 * rather than attempting to do LRU.
 */
{
  label *p;
  regname *r;
  code_buffer *b = &(ws->buffers[ws->build_buffer]);
  ws->compile_base = &(b->code[0]);
  ws->compile_ptr = ws->compile_base;
  ws->compile_lim = ws->compile_base + BUFSIZE;
  ws->regframeoffset = 0;
  ws->pixel_expansion_mask[0] = ws->pixel_expansion_mask[1] = 0;
  FOR_EACH_LABEL(p) {p->def = 0; p->ref = 0;} /* zap all the labels to be undefined. */
  FOR_EACH_REGISTER_NAME(r) { r->regno = -1; r->flags = 0; r->spindex = -1; }
#ifdef DEBUG
  dprintf(("", "Compile buffer initialised.\n"));
  if(ISTRANS)
  {
    dprintf(("", "%t20; Blitting code for %s\n",
      (TRANSMASK ? "PlotMaskTransformed" : "PlotSpriteTransformed")));
  }
  else
  {
    dprintf(("", "%t20; Blitting code for %s, scale factors %i:%i,%i:%i outoffset %x\n",
      (PLOTMASK ? "PlotMaskScaled" : "PutSpriteScaled"),
      b->xadd - b->xdiv, b->xdiv, b->yadd, b->ydiv, wp->save_outoffset));
  }
  dprintf(("", "%t20; gcol action=%i in-bpp=%i out-bpp=%i in-dpix=%s out-dpix=%s masktype=%i table=%s\n", 
    ws->gcol, (1<<wp->save_inlog2bpp), wp->BPP,
    whether(DPIXEL_INPUT), whether(DPIXEL_OUTPUT),
    ws->masktype,
    whether(wp->ColourTTR != 0)));
  dprintf(("", "%t20; Src format=%x Dest format=%x\n", ws->in_pixelformat, ws->out_pixelformat));
  dprintf(("", "%t20.; Generated by compiler of (%s %s)\n", __DATE__, __TIME__));
  comment(ws, "Get register and workspace definitions, turn on listing");
  dprintf(("", "%t28.GET     w.GenHdr\n"));
  dprintf(("", "%t28.OPT     1\n"));
#endif
  RN(wp, 12, REGFLAG_GLOBAL, "workspace pointer") /* TODO - HACK - Make non-global again somehow */
//  RN(wp, 12, (wp->is_it_jpeg?REGFLAG_GLOBAL:REGFLAG_INPUT), "workspace pointer")
  RN(sp, 13, REGFLAG_GLOBAL, "stack pointer")
  RN(lr, 14, REGFLAG_USED, "link register")
  RN(pc, 15, REGFLAG_GLOBAL, "program counter")
}

static void compile_buffer_done(workspace *ws)
/* Finished compiling code sequence. */
{
#ifdef DEBUG
  label *p;
#endif

  dprintf(("", "%t28.END\n"));
  dprintf(("", "Compile buffer done, %i words generated.\n", ws->compile_ptr - ws->compile_base));
  /* Increment pointer for next buffer to reuse. */
  ws->build_buffer++;
  if (ws->build_buffer >= NBUFFERS) ws->build_buffer = 0;
#ifdef DEBUG
  /* Check no unresolved references to labels */
  FOR_EACH_LABEL(p)
  {
    if(p->ref != 0) dprintf(("", "Unresolved reference to label %s at %x\n",
                             p->name, sizeof(int) * (p->ref - ws->compile_base)));
    assert(p->ref == 0, ERROR_FATAL);
  }
#endif
  /* ws->compile_base can be used as the base of the resulting procedure. */
}

static void init_useful_constants(asm_workspace *wp, workspace *ws)
{
  /* Various useful constants not provided directly by wp. */
  newline();
  comment(ws, "Various useful constants");
  if (DPIXEL_INPUT)
    comment(ws, "Double-pixel input - pixels are not the same as double-pixels");
  else
    comment(ws, "Not double-pixel input - pixels are exactly the same as double-pixels");
  ws->in_bpp         = 1 << wp->save_inlog2bpp;
  ws->in_bpc         = 1 << wp->save_inlog2bpc;
  ws->in_pixmask     = (1 << ws->in_bpp) - 1;
  dprintf(("", "%t20.in_bpp  *       %i %t68); bits per input pixel\n", ws->in_bpp));
  dprintf(("", "%t20.in_bpc  *       %i %t68); bits per input double-pixel ('character')\n", ws->in_bpc));
  dprintf(("", "%t20.in_l2bpp  *     %i %t68); log base 2 of bits per input pixel\n", wp->save_inlog2bpp));
  if (ws->in_bpp <= 8) dprintf(("", "%t20.in_pixmask *    %i %t68); input pixel mask\n", ws->in_pixmask));

  if (SOURCE_MASK)
  {
    if (SOURCE_ALPHAMASK)
    {
      ws->mask_bpp     = 8;
      ws->mask_bpc     = 8;
      ws->mask_pixmask = 255;
    }
    else if (SOURCE_BPPMASK) /* a bit mask */
    {
      ws->mask_bpp     = 1;
      ws->mask_bpc     = 1;
      ws->mask_pixmask = 1;
    }
    else
    {
      ws->mask_bpp     = ws->in_bpp;
      ws->mask_bpc     = ws->in_bpc;
      ws->mask_pixmask = ws->in_pixmask;
    }
    dprintf(("", "%t20.mask_bpp *      %i %t68; bits per mask pixel\n", ws->mask_bpp));
    dprintf(("", "%t20.mask_bpc *      %i %t68; bits per mask double-pixel\n", ws->mask_bpc));
    dprintf(("", "%t20.mask_pixmask *  %i %t68; mask pixel mask\n", ws->mask_pixmask));
  }
  else
    comment(ws, "No input mask");

  if (DPIXEL_OUTPUT)
    comment(ws, "Double-pixel output - pixels are not the same as double-pixels");
  else
    comment(ws, "Not double-pixel output - pixels are exactly the same as double-pixels");
  ws->out_l2ppw      = 5 - wp->Log2bpc;
  ws->out_ppw        = 1 << ws->out_l2ppw;
  ws->out_pixmask    = (1 << wp->BPP) - 1;
  ws->out_dpixmask   = (1 << wp->BPC) - 1;
  dprintf(("", "%t20.out_bpp *       %i %t68; bits per output pixel\n", wp->BPP));
  dprintf(("", "%t20.out_bpc *       %i %t68; bits per output double-pixel\n", wp->BPC));
  dprintf(("", "%t20.out_l2bpp *     %i %t68; log base 2 of bits per output pixel\n", wp->Log2bpp));
  dprintf(("", "%t20.out_l2bpc *     %i %t68; log base 2 of bits per output double-pixel\n", wp->Log2bpc));
  dprintf(("", "%t20.out_ppw *       %i %t68; double-pixels per output word\n", ws->out_ppw));
  dprintf(("", "%t20.out_l2ppw *     %i %t68; log base 2 of double-pixels per output word\n", ws->out_l2ppw));
  if (wp->BPC <= 8)
  {
    dprintf(("", "%t20.out_pixmask *   %i %t68; output pixel mask\n", ws->out_pixmask));
    dprintf(("", "%t20.out_dpixmask *  %i %t68; output double-pixel mask\n", ws->out_dpixmask));
  }
}

/**************************************************************************
*                                                                         *
*    JPEG handling.                                                       *
*                                                                         *
**************************************************************************/

#ifdef ASMjpeg
#include "rojpeg.c"
#include "romemmgr.c"
#include "romerge.c"
#include "rotranscode.c"
#endif

/**************************************************************************
*                                                                         *
*    PutScaled                                                            *
*                                                                         *
**************************************************************************/

#include "putscaled.c"

/**************************************************************************
*                                                                         *
*    SprTrans                                                             *
*                                                                         *
**************************************************************************/

#include "sprtrans.c"
