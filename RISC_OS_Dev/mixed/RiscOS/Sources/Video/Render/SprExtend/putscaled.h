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
/* h.PutScaled
   More interface between core code and SpriteExtend innards.
   started: 12 Sep 93 WRS
*/

#ifndef putscaled_h_
#define putscaled_h_

/**************************************************************************
*                                                                         *
*    Pertinent structures.                                                *
*                                                                         *
**************************************************************************/

/* A sprite header, copied from RISC_OSLib */
typedef struct
{
 int next;
 char name[12];
 int width;
 int height;
 int lbit;
 int rbit;
 int image;
 int mask;
 int mode;
} sprite_header;

/* Printer calibration table - definition internal to ColourTrans,
 * colour printer drivers.
 */
typedef struct
{
  int version;            /* table version number - must be 0 */
  int idealblack;         /* if not 0, need to do colour skewing */
  int idealwhite;         /* if not &FFFFFF00, need to do colour skewing */
  int postprocessSWI;     /* if not 0, need to call ColourTrans */
  /* If idealblack==0, idealwhite==&ffffff00, postprocessSWI==0 then we can do the
   * colour calibration by doing thee lookups. Otherwise, you have to call ColourTrans for
   * each pixel.
   */
  int tablecount;         /* number of tables (1 or 3) */
  char redtable[256];     /* if tablecount==1 this is blue and green tables too */
  char greentable[256];   /* translate 24-bit colour values by doing a lookup for each colour */
  char bluetable[256];
} calibration_table;

/**************************************************************************
*                                                                         *
*    Assembler Workspace declarations.                                    *
*                                                                         *
**************************************************************************/

/* These correspond to the assembler workspace. Changes to either must
 * be synchronised.
 */
typedef struct
{
  #define WP_FIRST_FIELD save_outoffset
  int    save_outoffset;  /* #       4       ; reloaded from R12 */
  int    save_inoffset;   /* #       4 */
  int *  save_inptr;      /* #       4 */
  int *  save_outptr;     /* #       4 */
  int    save_ydiv;       /* #       4 */
  int    save_yadd;       /* #       4 */
  int    save_ysize;      /* #       4 */
  int    save_ycount;     /* #       4 */


  int    save_inshift;    /* #       4 */
  int    save_xsize;      /* #       4 */
  int    save_xcount;     /* #       4 */
  int    save_ecfptr;     /* #       4 */
  int    save_ecflimit;   /* #       4 */
  int    save_xdiv;       /* #       4 */
  int    save_xadd;       /* #       4 */

  int    save_masko;      /* #       4 */
  int    save_xcoord;     /* #       4 */
  int    save_ycoord;     /* #       4 */
  int    save_inputxsize; /* #       4 */
  int    save_inputysize; /* #       4 */
  int    save_xmag;       /* #       4 */
  int    save_ymag;       /* #       4 */

  int    save_inlog2bpp;  /* #       4 ; <- updated by readspritevars, SWIJPEG_PlotScaled */
  int    save_inlog2bpc;  /* #       4 ; <- updated by readspritevars, SWIJPEG_PlotScaled */
  int    save_inbpp;      /* #       4 ; <- updated by readspritevars, SWIJPEG_PlotScaled */
  int    save_inmodeflags; /* #      4 ; <- updated by readspritevars, SWIJPEG_PlotScaled */
  int    save_inncolour;  /* #       4 ; <- updated by readspritevars, SWIJPEG_PlotScaled */
  int    save_mode;       /* #       4 ; input sprite mode word, only used by putscaled_compiler */
  int    save_spr_type;   /* #       4 ; top 5 bits of sprite mode word, a bit useless if RISC OS 5 sprite mode word */

  int    save_maskinshift; /* #      4 */
  int    save_maskinptr;  /* #       4 */
  int    save_maskinoffset; /* #     4 */

  int    inmode;          /* #       4 ; <- updated by readspritevars, SWIPJEG_PlotScaled */
  int    inlog2px;        /* #       4 ; <- updated by readspritevars, SWIPJEG_PlotScaled */
  int    inlog2py;        /* #       4 ; <- updated by readspritevars, SWIPJEG_PlotScaled */
  int    ColourTTR;       /* #       4 */
  int    TTRType;         /* #       4 ; Type of ColourTTR */
#define TTRType_None      0
#define TTRType_Normal    1 // byte lookup table for converting <=8bpp to <=8bpp
#define TTRType_Wide      2 // wide lookup table for converting <=8bpp to >=16bpp, repacked to be one word per entry
#define TTRType_32K       3 // 32K-style table for converting >=16bpp to <=8bpp
#define TTRType_ColourMap 4 // Colour mapping descriptor for >=16bpp source
#define TTRType_Palette   5 // Using the sprite palette
#define TTRType_Optional  8 // Extra flag: translation is optional, can use palette if we wish 

  int    changedbox;      /* #       4 */

  int    spritecode;      /* #       4 ; SpriteOp reason code we were called with */

  int    trns_flags2;     /* #       4      ; Added when merged with 0.62 (GPS)*/

  int    log2px;          /* #       4 ; <- updated by readvduvars */
  int    log2py;          /* #       4 ; <- updated by readvduvars */
  int    Log2bpp;         /* #       4 ; <- updated by readvduvars */
  int    Log2bpc;         /* #       4 ; <- updated by readvduvars */
  int    orgx;            /* #       4 ; <- updated by readvduvars */
  int    orgy;            /* #       4 ; <- updated by readvduvars */
  int    gwx0;            /* #       4 ; <- updated by readvduvars, tweaked elsewhere for double pixel modes */
  int    gwy0;            /* #       4 ; <- updated by readvduvars */
  int    gwx1;            /* #       4 ; <- updated by readvduvars, tweaked elsewhere for double pixel modes */
  int    gwy1;            /* #       4 ; <- updated by readvduvars */
  int    linelength;      /* #       4 ; <- updated by readvduvars */
  int    screenstart;     /* #       4 ; <- updated by readvduvars */
  int    ywindlimit;      /* #       4 ; <- updated by readvduvars */
  int    modeflags;       /* #       4 ; <- updated by readvduvars */
  int    ncolour;         /* #       4 ; <- updated by readvduvars */
  int    BPC;             /* #       4 ; <- updated by readvduvars */
  int    BPP;             /* #       4 ; <- updated by readvduvars */

  int    ccompiler_bitblockmove; /* # 4     ; routine for C to call back into assembler. */
  calibration_table * cal_table; /* # 4     ; printer calibration table */

#ifdef ASMjpeg
  BOOL   is_it_jpeg;      /* #       4 */
  BOOL   ctrans_recent;   /* #       4 */
  int    in_x;            /* #       4       ; initial x coord in input sprite */
  int    in_y;            /* #       4       ; initial y coord in input sprite */
  int    fetchroutine;    /* #       4       ; routine for compiled code to call to get line of JPEG data. */
  j_decompress_ptr jpeg_info_ptr; /* #       4       ; pointer to JPEG workspace */
  int    area_numbers[3]; /* #       4*3     ; dynamic area numbers*/
#endif
  sprite_header * save_sprite;     /* #       4       ; the actual source sprite */

  int    save_PdriverIntercept; /* #  4       ; Flags used to determine if the pdriver is*/


  BOOL   dither_truecolour; /* #   4       ; do we dither true colour images when reducing BPP? */
  int    blending;          /* #   4       ; b0: translucency blending, b1: alpha mask/channel blending */
  int    ecfyoffset_ptr;    /* #   4       ; pointer to Kernel's ECF offset & shift values, required for dithering */
  int    ecfshift_ptr;      /* #   4 */

  int    CPUFlags;          /* #   4       ; Flags about which instructions we can use */
#define CPUFlag_LDRH  1     // LDRH/STRH available
#define CPUFlag_BLX   2     // BLX available
#define CPUFlag_T2    4     // ARMv6 Thumb2 instructions available: MOVW,MOVT,UBFX,BFC,BFI,etc.
#define CPUFlag_REV   8     // REV available
#define CPUFlag_NoUnaligned 16 // Unaligned load/store not allowed

  int    blendtables[6];  /* #       4*6     ; Blending tables */
  int    screenpalette;   /* #       4       ; Screen palette fetched via InverseTable, if required */
  int    inversetable;    /* #       4       ; Inverse screen palette fetched via InverseTable, if necessary */


  int    newtranstable[256];   /*   #       256 *4                  ; buffer for pixel translation table */
} asm_workspace;

/* Stack workspace (for sprtrans) */
typedef struct
{
  int trns_spr_xcoords[4];           /* #       16      ;       Four x coordinates */
  int trns_spr_ycoords[4];           /* #       16      ;       Four y coordinates */
  int trns_comp_spr_left;            /* #       4       ;       Sprite left hand edge (bottom 16 bits) */
  int trns_comp_spr_start;           /* #       4       ;       Sprite start (accounting for internal coord block top) */
  int trns_comp_spr_byte_width;      /* #       4       ;       Sprite byte width << (3-sprite bpp) i.e. row pitch in pixels */
  int trns_comp_spr_height;          /* #       4       ;       Sprite height (top 16 bits) and right hand edge (bottom 16) */
  int trns_comp_spr_ttr;             /* #       4       ;       Translation table (if required) */
  int trns_comp_spr_masko;           /* #       4       ;       Sprite mask offset from image << (3-sprite bpp) */
  int trns_comp_ecf_ora;             /* #       4       ;       ECF OR word */
  int trns_comp_ecf_eor;             /* #       4       ;       ECF EOR word */
  int trns_codebuffer;               /* #       4       ;       Pointer to codebuffer */
  int trns_spr_X_x0_y;               /* #       4       ;       Sprite X,Y at top coordinate of area */
  int trns_spr_Y_x0_y;               /* #       4       ;            in 16.16 fixed point */
  int trns_spr_inc_X_x;              /* #       4       ;       Sprite increments */
  int trns_spr_inc_Y_x;              /* #       4       ;          ( change induced by single */
  int trns_spr_inc_Y_y;              /* #       4       ;            increments in screen x,y on */
  int trns_spr_inc_X_y;              /* #       4       ;            sprite X,Y ) */
  int trns_spr_lineptr;              /* #       4       ;       Line to output onto */
  int trns_spr_edgeblock[6*4];       /* #       6*4*4   ;       Edge blocks, in format as below */
  int trns_spr_edgeblock_end[6];     /* #       4*6     ;        -1, to denote end of edge block */
  int trns_ecf_ptr;                  /* #       4       ;       Ecf pointer */
  int trns_masking_word;             /* #       4       ;       Masking word for > eight bit per pixel */
  int trns_comp_mask_offset;         /* #       4       ;       used to point at 1bpp mask data */
  int trns_comp_spr_mask_width;      /* #       4       ;       1bpp mask equivalent of spr_width */
  int trns_comp_mask_base;           /* #       4       ;       1bpp mask adjustment to mask data */
  int trns_asm_workspace;            /* #       4       ;       assembler R12 */
} stack_ws;

/**************************************************************************
*                                                                         *
*    Exported C functions (called by the assembler part of SpriteExtend)  *
*                                                                         *
**************************************************************************/

typedef void (*blitter)(asm_workspace *wp);

#endif
