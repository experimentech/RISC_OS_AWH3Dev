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
/* c.PutScaled - the bitblit compiler for PutSpriteScaled/PlotMaskScaled */

/**************************************************************************
*                                                                         *
*    Bitblit: Evaluate conditions.                                        *
*                                                                         *
**************************************************************************/

static BOOL simple_x_scale(asm_workspace *wp, workspace *ws)
/* Return true if 1:1 along x */
{
  return (  wp->save_xadd - wp->save_xdiv == wp->save_xdiv
         && wp->save_xdiv <= wp->save_xcount
         && !PLOTMASK
         && ws->gcol == 0
         && !ws->odither /* CAN be done, but the code sequences get awfully big so let's cut it out for now. */
         && !wp->blending /* as above, blending is too big and slow, and needs more registers */
         && (wp->TTRType != TTRType_ColourMap) /* as above, too many pixel format conversions can overflow buffer) */
         ? TRUE : FALSE);
  /* Without the second test we MIGHT have to omit the first pixel, which the 1:1 code doesn't allow for. */
  /* The 2-at-a-time loop doesn't allow for PLOTMASK - not important enough. */
  /* The 2-at-a-time loop doesn't allow for any gcol but 0 - not important enough. */
}

static BOOL x_block_move(asm_workspace *wp, workspace *ws)
/* Returns true if the inner loop is the simple movement of a block of bits */
{
  return (  simple_x_scale(wp, ws)
         && wp->BPC == (1<<wp->save_inlog2bpc)
         && ws->gcol == 0
         && !SOURCE_MASK
         && !SOURCE_TABLE
         && wp->cal_table == 0
         && ws->in_pixelformat == ws->out_pixelformat
         && !wp->blending
         ? TRUE : FALSE);
}

static BOOL simple_y_scale(asm_workspace *wp, workspace *ws)
/* Return true if 1:1 along y */
{
  UNUSED(ws);
  return wp->save_yadd == wp->save_ydiv;
}

static int palette_is_grey(int *palette, int entries)
/* Scan a palette looking how they increment to deduce if it's just greyscale */
{
  int loop;
  int entry;
  int ascending = 1;

  for (loop=0;loop<entries;loop++)
  {
    entry = palette[loop];

    if (((entry ^ (entry>>8)) & 0xffff00) != 0)
      return 0;
    if ((entry & 0xff00)>>8 != loop)
      ascending = 0;
  }
  if (ascending)
   return 2;
  return 1;
}

/**************************************************************************
*                                                                         *
*    Bitblit: Register allocation.                                        *
*                                                                         *
**************************************************************************/

static void ptrs_rn(asm_workspace *wp, workspace *ws)
/* Declare the pointer registers, which must be visible in both the x-loop and the y-loop */
{
  /* r_pixel is always needed, and need not be saved between loops.
   * So, we put it in r14 to remove the need for the register allocator
   * to worry about r14.
   */
  int flags = REGFLAG_TEMPORARY+REGFLAG_XLOOP+REGFLAG_PERPIXEL;
  if(PLOTMASK)
    flags |= REGFLAG_YLOOP; /* For ECF handling */
  RN(r_pixel, 14, flags, "fetched and translated pixel")

  /* In most cases there are not enough registers, and the control of
   * the outer (y) loop requires swapping two 'banks' of registers.
   * inptr, outptr (and maskinptr if it exists) are always registers
   * r0, r1, r2, and they are visible when the y registers are swapped in.
   */
  RN(r_inptr, 0, REGFLAG_XLOOP+REGFLAG_YLOOP+REGFLAG_XLOOPVAR, PLOTMASK ? "ECF pattern pointer" : "input word pointer")
  RN(r_outptr, 1, REGFLAG_XLOOP+REGFLAG_YLOOP+REGFLAG_XLOOPVAR, "word pointer to output")
  if (SOURCE_TRICKYMASK || PLOTMASK) RN(r_maskinptr, -1, REGFLAG_XLOOP+REGFLAG_YLOOP+REGFLAG_XLOOPVAR, "mask input word pointer")

  if (ws->odither) RN(r_oditheradd, -1, REGFLAG_XLOOP+REGFLAG_YLOOP+REGFLAG_PERPIXEL+REGFLAG_XLOOPVAR, "ordered dither offset value")
  /* The initial dither add value needs to be changed for every output line,
   * so it helps to have r_oditheradd visible in the y loop
   */
}

static void xloop_rn(asm_workspace *wp, workspace *ws)
/* Other variables for the x-loop */
{
  int need_temps = 0; /* set to 1 or 2 if temp1 and temp2 are needed */
  if (x_block_move(wp, ws))
  {
    /* X loop is very very simple, and communicates with machine-code block-shift routine. */
    RN(r_inshift, 2, REGFLAG_GLOBAL+REGFLAG_XLOOPVAR, "Number of (most sig) bits of first input word to transfer, in 1..32")
    RN(r_outshift, 3, REGFLAG_GLOBAL+REGFLAG_XLOOPVAR, "Number of (most sig) bits of first output word to fill, in 1..32")
    RN(r_xsize, 4, REGFLAG_GLOBAL+REGFLAG_XLOOPVAR, "Number of bits to transfer per row")
    RN(r_blockroutine, -1, REGFLAG_GLOBAL, "Block transfer routine")
    /* Those registers had better be the same ones as the assembler code is expecting! */
    assert(ws->regnames.r_inptr.regno == 0, ERROR_FATAL);
    assert(ws->regnames.r_outptr.regno == 1, ERROR_FATAL);
    assert(ws->regnames.r_inshift.regno == 2, ERROR_FATAL);
    assert(ws->regnames.r_outshift.regno == 3, ERROR_FATAL);
    assert(ws->regnames.r_xsize.regno == 4, ERROR_FATAL);
  }
  else
  {
    /* Normal case - declare whatever other registers are needed for fetching and translating pixels. */
    if (PLOTMASK)
      RN(r_inword, -1, REGFLAG_XLOOP, "ECF pattern input word")
    else if (!SOURCE_32_BIT) /* if not 32-bit source */
    {
      RN(r_inshift, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "bit shift of current pixel LSL #27")
      RN(r_inword, -1, REGFLAG_XLOOP, "current input word")
    }
    if (SOURCE_MASK)
    {
      RN(r_maskinword, -1, REGFLAG_XLOOP, "current mask word")
      if (SOURCE_TRICKYMASK || PLOTMASK)
        RN(r_maskinshift, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "bit shift of current mask pixel")
      else
        RN(r_masko, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "offset of mask data from sprite data")
    }
    if (  need_temps == 0
       && (ws->gcol != 0)
       && DEST_32_BIT       /* use in save_pixel */
       )
       need_temps = 1;

    if (PLOTMASK)
    {
      RN(r_ecfindex, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "index into ECF pattern")
      RN(r_bgcolour, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "background plotting colour")
    }
    else
    {
      if (SOURCE_TABLE || wp->cal_table) RN(r_table, -1, REGFLAG_PERPIXEL+REGFLAG_CONSTANT, "translation table or palette")

      need_temps = translate_pixel_rn(wp,ws,need_temps);

      if ( need_temps == 0
        && (wp->save_xmag % wp->save_xdiv) == 0
        && (wp->save_xmag / wp->save_xdiv) > 4    /* used in optimised scale up */
         )
       need_temps = 1;
    }

    /* Declare whatever registers needed for saving the new pixel
     * into the current destination pixel.
     */
    if (!DEST_32_BIT)
    {
      RN(r_outword, -1, REGFLAG_XLOOP, "current output word")
      RN(r_outshift, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "bit shift of current pixel in current output word LSL 27")
    }
    else if (wp->blending)
    {
      RN(r_outword, -1, REGFLAG_XLOOP+REGFLAG_PERPIXEL, "screen pixel to blend with") /* TODO REGFLAG_XLOOP unnecessary? */
    }

    if (wp->save_inlog2bpp <= 3 && simple_x_scale(wp, ws))
      /* going to use 2-at-a-time loop - if 16bpp or more, don't need this register. */
      RN(r_in_pixmask, -1, REGFLAG_XLOOP+REGFLAG_CONSTANT, "pixel mask for 2-at-a-time loop")

    /* Declare whatever registers are needed for control of
     * horizontal scaling. For some simple cases no scaling registers
     * are needed.
     */
    RN(r_xsize, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "number of output pixels per row")
    if (!simple_x_scale(wp, ws)) /* not 1:1 scale */
      RN(r_xcount, -1, REGFLAG_XLOOP+REGFLAG_XLOOPVAR, "total for x scale")
      /* Adder and subractor values become constants in the code. */
  }

  blendimpl_rn(wp,ws);

  if (need_temps >= 1) RN(r_temp1, -1, REGFLAG_PERPIXEL+REGFLAG_TEMPORARY+REGFLAG_XLOOP, "temp1 for pixel transformation temporary values")
  if (need_temps >= 2) RN(r_temp2, -1, REGFLAG_PERPIXEL+REGFLAG_TEMPORARY, "temp2 for pixel transformation temporary values")
}

static void yloop_rn(asm_workspace *wp, workspace *ws)
/* Declare whatever registers are needed for control of
 * the vertical loop. These registers are part of a separate 'bank'
 * from those in the central loop.
 */
{
  RN(r_ysize, -1, REGFLAG_YLOOP, "number of output rows");
  if (!simple_y_scale(wp, ws)) /* not 1:1 scale */
    RN(r_ycount, -1, REGFLAG_YLOOP, "total for y scale")

  /* Adder and subractor values become constants in the code. */
  RN(r_inoffset, -1, REGFLAG_YLOOP+REGFLAG_CONSTANT, "byte offset between input rows.")
  if (SOURCE_TRICKYMASK || PLOTMASK) RN(r_maskinoffset, -1, REGFLAG_YLOOP+REGFLAG_CONSTANT, "byte offset between mask rows.")
  if (wp->is_it_jpeg)             RN(r_fetchroutine, -1, REGFLAG_XLOOP+REGFLAG_CONSTANT, "routine for getting row of decompressed JPEG data.")

  /* MAX POSSIBLE REQUIREMENT - 5 registers */
}

/**************************************************************************
*                                                                         *
*    Bitblit: Register initialisation.                                    *
*                                                                         *
**************************************************************************/

static void get_in_shift(asm_workspace *wp, workspace *ws)
/* Used within fetch_pixel_init, to load r_inshift. The complication is
 * that if this is JPEG data then the save_inshift value was not calculated,
 * because SpriteExtend assembler stuff thought this was 32bit data. This
 * only matters if JPEG is being made to produce 8bpp or 16bpp data.
 */
{
  if (wp->is_it_jpeg && wp->save_inlog2bpp != 5)
  {
    LDR_WP_C(r_inshift, in_x, "input x coord (JPEG input data)")
    if (wp->save_inlog2bpp == 4)
    {
      AND(R(r_inshift), R(r_inshift), S | IMM(1),              "ANDS    r_inshift,r_inshift,#1          ; halfword offset (0 or 1)");
      MOV(R(r_inshift), EQ | IMM(2),                           "MOVEQ   r_inshift,#2                    ; halfword offset (1 or 2)");
      MOV(R(r_inshift), OP2R(R(r_inshift)) | LSLI(4),          "MOV     r_inshift,r_inshift,LSL #4      ; 16/32 bit offset");
    }
    else /* wp->save_inlog2bpp == 3 */
    {
      AND(R(r_inshift), R(r_inshift), S | IMM(3),              "ANDS    r_inshift,r_inshift,#3          ; byte offset as 0/1/2/3");
      RSB(R(r_inshift), R(r_inshift), IMM(4),                  "RSB     r_inshift,r_inshift,#4          ; byte offset as 4/3/2/1");
      MOV(R(r_inshift), OP2R(R(r_inshift)) | LSLI(3),          "MOV     r_inshift,r_inshift,LSL #3      ; 8/16/24/32 bit offset");
    }
  }
  else
  {
    LDR_WP_C(r_inshift, save_inshift, "input initial shift")
    RSB(R(r_inshift), R(r_inshift), IMM(32),                 "RSB     r_inshift,r_inshift,#32         ; pixels of first word to transfer, in 1..32");
  }
}

static void fetch_pixel_init(asm_workspace *wp, workspace *ws)
/* Initialise whatever registers are needed for fetching pixels.
 */
{
  /* The input word pointer */
  if (PLOTMASK)
  {
    LDR_WP_C(r_inptr, save_ecflimit, "base of ECF pattern")
  }
  else if (wp->is_it_jpeg)
  {
    LDR_WP_C(r_inptr, in_y, "initial y coordinate (for JPEG data)")
  }
  else /* normal data source for PutSpriteScaled */
  {
    LDR_WP_C(r_inptr, save_inptr, "input word pointer")
  }

  /* all other registers re fetching input data */
  if (x_block_move(wp, ws))
  {
    /* Prepare for machine code core to inner loop */
    get_in_shift(wp, ws);
    LDR_WP(r_blockroutine, ccompiler_bitblockmove)
  }
  else
  {
    /* initialise r_inptr */
    if (PLOTMASK)
    {
      LDR_WP(r_inptr, save_ecfptr)
    }
    else
    {
      /* r_inword and r_inshift */
      if (!SOURCE_32_BIT) /* if not 32-bit source */
      {
        /* r_inword not initialised yet, done in inner loop */
        get_in_shift(wp, ws);
        MOV(R(r_inshift), OP2R(R(r_inshift)) | LSLI(27),     "MOV     r_inshift,r_inshift,LSL #27     ; keep up at top end of register");
      }
    }

    /* mask registers */
    if (SOURCE_MASK)
    {
      if (SOURCE_TRICKYMASK || PLOTMASK)
      {
        LDR_WP(r_maskinshift, save_maskinshift)
        if (SOURCE_TRICKYMASK)
        {
          LDR_WP(r_maskinptr, save_maskinptr)
        }
        else /* PLOTMASK and not BPPMASK */
        {
          LDR_WP_C(r_maskinptr, save_inptr, "mask pointer for PlotMaskScaled")
          LDR_WP(r_pixel, save_masko) /* temp use of r_pixel */
          ADD(R(r_maskinptr), R(r_maskinptr), OP2R(R(r_pixel)),"ADD     r_maskinptr,r_maskinptr,r_pixel ; mask pointer (for PlotMask)");
        }
        RSB(R(r_maskinshift), R(r_maskinshift), IMM(32),   "RSB     r_maskinshift,r_maskinshift,#32 ; pixels still to shift");
        MOV(R(r_maskinshift),
            OP2R(R(r_maskinshift)) | LSLI(27),             "MOV     r_maskinshift,r_maskinshift,LSL #27 ; keep up at top end of register");
      }
      else
        LDR_WP(r_masko, save_masko)
    }

    if (wp->save_inlog2bpp <= 3 && simple_x_scale(wp, ws))
      MOV(R(r_in_pixmask), IMM(ws->in_pixmask),           "MOV     r_in_pixmask,#in_pixmask        ; for use in 2-at-a-time loop");
  }
    
  newline();
}

static void per_pixel_init(asm_workspace *wp, workspace *ws)
/* Initialise whatever registers are needed for translating pixels.
 */
{
  if (!x_block_move(wp, ws))
  {
    /* translation registers */
    if (wp->cal_table) LDR_WP(r_table, cal_table)
    else if (wp->ColourTTR != 0) LDR_WP(r_table, ColourTTR)

    /* temp1 and temp2 need no initialisation. */

    dither_expansion_init(wp,ws);
  }
    
  newline();
}

static void save_pixel_init(asm_workspace *wp, workspace *ws)
/* Initialise whatever registers are needed for saving the new pixel
 * into the current destination pixel.
 */
{
  LDR_WP(r_outptr, save_outptr)

  if (x_block_move(wp, ws))
  {
    /* Very simple inner loop */
    LDR_WP_C(r_pixel, save_xcoord, "get initial output x coord in pixels") /* Measured in pixels */
    AND(R(r_outshift), R(r_pixel), IMM(ws->out_ppw-1),            "AND     r_outshift,r_pixel,#out_ppw-1   ; pix offset of start");
    MOV(R(r_outshift),OP2R(R(r_outshift)) | LSLI(wp->Log2bpc),  "MOV     r_outshift,r_outshift,LSL #out_l2bpc ; bit offset of start, in 0..31");
    RSB(R(r_outshift), R(r_outshift), IMM(32),                    "RSB     r_outshift,r_outshift,#32       ; pixels of space, in 1..32");
  }
  else
  {
    /* Normal cases */
    if (PLOTMASK || !DEST_32_BIT)
      LDR_WP_C(r_pixel, save_xcoord, "output x coord measured in pixels")

    if (PLOTMASK)
    {
      MOV(R(r_ecfindex), OP2R(IMM(0)),                          "MOV     r_ecfindex, #0               ; should always be 0 ?");
    }

    if (!DEST_32_BIT)
    {
      AND(R(r_outshift), R(r_pixel), IMM(ws->out_ppw-1),          "AND     r_outshift,r_pixel,#out_ppw-1 ; pixel offset of start");
      MOV(R(r_outshift),OP2R(R(r_outshift)) | LSLI(wp->Log2bpc),"MOV     r_outshift,r_outshift,LSL #out_l2bpc ; bit offset of start");
      RSB(R(r_outshift), R(r_outshift), IMM(32),                  "RSB     r_outshift,r_outshift,#32       ; pixels still to rotate");
      MOV(R(r_outshift), OP2R(R(r_outshift)) | LSLI(27),          "MOV     r_outshift,r_outshift,LSL #27   ; up at the top");
    }
  }
}

static void xloop_init(asm_workspace *wp, workspace *ws)
/* Initialise whatever registers are needed for control of
 * horizontal scaling. For some simple cases no scaling registers
 * are needed.
 */
{
  LDR_WP(r_xsize, save_xsize)
  if (!simple_x_scale(wp, ws)) /* not 1:1 scale */
  {
#if 0
    if ((ws->odither) && (SOURCE_16_BIT))
    {
      LDR_WP(r_pixel, save_xcount); /* Changed by (GPS) to fix register spill bug*/
    }
    else
#endif
    {
      LDR_WP(r_xcount, save_xcount);
    }
  }
  if (x_block_move(wp, ws))
    MOV(R(r_xsize), OP2R(R(r_xsize)) | LSLI(wp->Log2bpc),       "MOV     r_xsize,r_xsize,LSL #out_l2bpc  ; size in bits");
  if (wp->is_it_jpeg) LDR_WP_C(r_fetchroutine, fetchroutine, "routine to call to get JPEG data line")
}

static void yloop_init(asm_workspace *wp, workspace *ws)
/* Initialise whatever registers are needed for control of
 * the vertical loop. These registers are part of a separate 'bank'
 * from those in the central loop.
 */
{
  LDR_WP(r_ysize, save_ysize)
  if (!simple_y_scale(wp, ws)) /* not 1:1 scale */ LDR_WP(r_ycount, save_ycount)
  if (!PLOTMASK)
  {
    if (wp->is_it_jpeg)
      /* We could save this register, but there's not all that much point - simpler to code like this. */
      MOV(R(r_inoffset),IMM(1),                                   "MOV     r_inoffset,#1                   ; JPEG coord offset on input");
    else
      LDR_WP(r_inoffset, save_inoffset)
  }
  if (SOURCE_TRICKYMASK) LDR_WP(r_maskinoffset, save_maskinoffset)
  else if (PLOTMASK) LDR_WP(r_maskinoffset, save_inoffset)
}

/**************************************************************************
*                                                                         *
*    Bitblit: Pixel loading, translation, saving.                         *
*                                                                         *
**************************************************************************/

static void fetch_pixel_unmasked(asm_workspace *wp, workspace *ws)
/* Assuming no mask, get the next input pixel and put it in r_pixel. This is separated
 * from fetch_pixel for the case of scaling up an ordered dither, where the same input
 * pixel is repeatedly fetched and translated.
 */
{
  if (PLOTMASK)
  {
    comment(ws, "Fetch an ECF pixel");
    if (DEST_32_BIT)
    {
      ins(ws, LDR(R(r_inword), R(r_inptr))
             | INDEX(R(r_ecfindex), 0),                      "LDR     r_inword,[r_inptr,r_ecfindex] 2222");
      ADD(R(r_ecfindex), R(r_ecfindex),
            IMM(4),                                          "ADD     r_ecfindex,r_ecfindex,#4  5t453");
      ins(ws, LDR(R(r_bgcolour), R(r_inptr))
            | INDEX(R(r_ecfindex), 0),                       "LDR     r_bgcolour,[r_inptr,r_ecfindex]   ; load next EOR word of ECF222");
      SUB(R(r_ecfindex), R(r_ecfindex),
            IMM(4),                                          "SUB     r_ecfindex,r_ecfindex,#4 1212");
    }
    else
    {
      if (DEST_16_BIT)
      {
        if (wp->CPUFlags & CPUFlag_T2)
        {
          UBFX(R(r_pixel),R(r_inword),0,16,0,               "UBFX    r_pixel,r_inword,#0,#16         ; fetch 16 bit ECF pattern pixel");
        }
        else
        {
          MOV(R(r_pixel), OP2R(R(r_inword)) | LSLI(16),     "MOV     r_pixel,r_inword,LSL #16        ; fetch 16 bit ECF pattern pixel");
          MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(16),      "MOV     r_pixel,r_pixel,LSR #16");
        }
      }
    }
  }
  else
  {
    comment(ws, "Fetch a source pixel");
    if (SOURCE_32_BIT)
      ins(ws, LDR(R(r_pixel), R(r_inptr)) | OFFSET(0),    "LDR     r_pixel,[r_inptr]");
    else if (SOURCE_16_BIT)
    {
      if (wp->CPUFlags & CPUFlag_T2)
      {
        UBFX(R(r_pixel),R(r_inword),0,16,0,               "UBFX    r_pixel,r_inword,#0,#16         ; fetch 16 bit ECF pixel");
      }
      else
      {
        MOV(R(r_pixel), OP2R(R(r_inword)) | LSLI(16),     "MOV     r_pixel,r_inword,LSL #16        ; fetch 16 bit pixel");
        MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(16),      "MOV     r_pixel,r_pixel,LSR #16");
      }
      /* >>> Maybe we can leave it in the top 16 bits, and get by? Not yet. */
    }
    else
    {
      AND(R(r_pixel), R(r_inword), IMM(ws->in_pixmask), "AND     r_pixel,r_inword,#in_pixmask    ; fetch the pixel");
    }
  }
}

static BOOL fetch_pixel(asm_workspace *wp, workspace *ws, label *l_masked)
/* Check the mask, fetch the current pixel. If the current pixel is
 * transparent then branch out to l_masked. Return TRUE if the branch could be
 * taken, else FALSE.
 */
{
#ifdef DEBUG
  char a[256];
#endif
  if (SOURCE_MASK)
  {
    if (SOURCE_ALPHAMASK)
    {
      TST(R(r_maskinword), IMM(255),                    "TST     r_maskinword,#255");
    }
    else
    {
      TST(R(r_maskinword), IMM(1),                      "TST     r_maskinword,#1");
    }
    dsprintf((a,                                "BEQ     %s", l_masked->name));
    branch(ws, B | EQ, l_masked, a);
  }

  fetch_pixel_unmasked(wp, ws);

  return SOURCE_MASK;
}

static BOOL fetch_pixel2(asm_workspace *wp, workspace *ws, label *l_masked)
/* Check the mask, fetch the pixel after the current one. You are assured
 * that no word of input need be loaded between these two. If the pixel is
 * transparent then branch out to l_masked. Return TRUE if the branch could be
 * taken, else FALSE.
 */
{
#ifdef DEBUG
  char a[256];
#endif
  assert(!PLOTMASK, ERROR_FATAL); /* Doesn't do 2-at-a-time loop */

  if (SOURCE_MASK) /* Test the second pixel of mask */
  {
    if (SOURCE_TRICKYMASK) /* we may have reached the end of mask word if not doing an aligned plot */
    {
      MOV(R(r_maskinword), OP2R(R(r_maskinword))
                       | RORI(ws->mask_bpc),                   "MOV     r_maskinword,r_maskinword,ROR #mask_bpc");
      SUB(R(r_maskinshift),R(r_maskinshift),
                       S | IMM(ws->mask_bpc*2) | IMMROR(6),    "SUBS    r_maskinshift,r_maskinshift,#mask_bpc:SHL:27");
      ins(ws, LDR(R(r_maskinword), R(r_maskinptr))
          | EQ | WRITEBACK | OFFSET(4),                        "LDREQ   r_maskinword,[r_maskinptr,#4]!     ; load more mask pixels (inc2)");
      if (SOURCE_ALPHAMASK)
      {
        TST(R(r_maskinword), IMM(255),                         "TST     r_maskinword,#255");
      }
      else
      {
        TST(R(r_maskinword), IMM(1),                           "TST     r_maskinword,#1");
      }
    }
    else
    {
      TST(R(r_maskinword),
          ws->mask_bpc < 8
            ? IMM(1 << ws->mask_bpc)
            : IMM(1) | IMMROR(32 - ws->mask_bpc),       "TST     r_maskinword,#1:SHL:mask_bpc");
    }
    dsprintf((a,                                "BEQ     %s", l_masked->name));
    branch(ws, B | EQ, l_masked, a);
  }

  comment(ws, "Fetch the source pixel after the current one");
  if (SOURCE_32_BIT)
    ins(ws, LDR(R(r_pixel), R(r_inptr)) | OFFSET(4),  "LDR     r_pixel,[r_inptr,#4]");
  else if (SOURCE_16_BIT)
  {
    MOV(R(r_pixel), OP2R(R(r_inword)) | LSRI(16),     "MOV     r_pixel,r_inword,LSR #16");
    /* >>> Getting it into top 16bits harder in this case! */
  }
  else
    AND(R(r_pixel), R(r_in_pixmask),
        OP2R(R(r_inword)) | LSRI(ws->in_bpc),         "AND     r_pixel,r_in_pixmask,r_inword,LSR #in_bpc"
                                                      " ; fetch the next pixel");
  return SOURCE_MASK;
}

static void save_pixel(asm_workspace *wp, workspace *ws)
/* Save the new pixel into the current destination pixel. */
/* Recall GCOL actions:
 * 0 -> overwrite old pixel
 * 1 -> OR with old pixel
 * 2 -> AND with old pixel
 * 3 -> EOR with old pixel
 * 4 -> invert old pixel
 * 5 -> do nothing
 * 6 -> AND old pixel with NOT of new pixel
 * 7 -> OR old pixel with NOT of new pixel
 */
{
  comment(ws, "Put the pixel in the output stream.");
  if (PLOTMASK)
  {
    if (DEST_32_BIT)
    {
      ins(ws, LDR(R(r_pixel), R(r_outptr)) | OFFSET(0),              "LDR     r_pixel,[r_outptr] ;bkah");
      ORR(R(r_pixel), R(r_inword), OP2R(R(r_pixel)),                 "ORR     r_pixel,r_inword,r_pixel               ; 1OR gcol action");
      EOR(R(r_pixel), R(r_bgcolour), OP2R(R(r_pixel)),               "EOR     r_pixel,r_bgcolour,r_pixel            ; 1EOR gcol action");
      ins(ws, STR(R(r_pixel), R(r_outptr)) | OFFSET(0),              "STR     r_pixel,[r_outptr]                    ;blaq5h");
    }
    else
    {
      if (DEST_16_BIT)
      {
        if (wp->CPUFlags & CPUFlag_T2)
        {
          UBFX(R(r_pixel),R(r_inword),0,16,0,                     "UBFX    r_pixel,r_inword,#0,#16         ; fetch 16 bit ECF pattern pixel");
        }
        else
        {
          MOV(R(r_pixel), OP2R(R(r_inword)) | LSLI(16),           "MOV     r_pixel,r_inword,LSL #16        ; fetch 16 bit ECF pattern pixel44 99");
          MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(16),            "MOV     r_pixel,r_pixel,LSR #16         ; 4444444");
        }
        ORR(R(r_outword), R(r_outword), OP2R(R(r_pixel)),         "ORR     r_outword,r_outword,r_pixel           ; ECF OR mask44 99");
        if (wp->CPUFlags & CPUFlag_T2)
        {
          UBFX(R(r_pixel),R(r_bgcolour),0,16,0,                   "UBFX    r_pixel,r_bgcolour,#0,#16         ; fetch 16 bit ECF pattern pixel");
        }
        else
        {
          MOV(R(r_pixel), OP2R(R(r_bgcolour)) | LSLI(16),         "MOV     r_pixel,r_bgcolour,LSL #16        ; fetch 16 bit ECF pattern pixel 4499");
          MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(16),            "MOV     r_pixel,r_pixel,LSR #16           ;449");
        }
        EOR(R(r_outword), R(r_outword), OP2R(R(r_pixel)),         "EOR     r_outword,r_outword,r_pixel           ; ECF EOR mask 4499");
      }
      else
      {
        AND(R(r_pixel), R(r_inword), IMM(ws->out_pixmask),        "AND     r_pixel,r_inword,#out_pixmask  ; blah blah");
        ORR(R(r_outword), R(r_outword), OP2R(R(r_pixel)),         "ORR     r_outword,r_outword,r_pixel           ; ECF OR mask");
        AND(R(r_pixel), R(r_bgcolour), IMM(ws->out_pixmask),      "AND     r_pixel,r_bgcolour,#out_pixmask    jthjg");
        EOR(R(r_outword), R(r_outword), OP2R(R(r_pixel)),         "EOR     r_outword,r_outword,r_pixel           ; ECF EOR mask");
      }
    }
  }
  else
  {
    if (DEST_32_BIT)
    {
      if (ws->gcol != 0) /* Not just a simple store operation */
      {
        ins(ws, LDR(R(r_temp1), R(r_outptr)) | OFFSET(0),             "LDR     r_temp1,[r_outptr]");
        switch(ws->gcol)
        {
          case 7: MVN(R(r_pixel), OP2R(R(r_pixel)),                     "MVN     r_pixel,r_pixel                       ; OR with neg action");
          case 1: ORR(R(r_temp1), R(r_pixel), OP2R(R(r_temp1)),         "ORR     r_temp1,r_pixel,r_temp1               ; OR gcol action"); break;
          case 6: BIC(R(r_temp1), R(r_temp1), OP2R(R(r_pixel)),         "BIC     r_temp1,r_temp1,r_pixel               ; AND NOT gcol action"); break;
          case 2: AND(R(r_temp1), R(r_pixel), OP2R(R(r_temp1)),         "AND     r_temp1,r_pixel,r_temp1               ; AND gcol action"); break;
          case 3: EOR(R(r_temp1), R(r_pixel), OP2R(R(r_temp1)),         "EOR     r_temp1,r_pixel,r_temp1               ; EOR gcol action"); break;
          case 4: MVN(R(r_temp1), OP2R(R(r_temp1)),                     "MVN     r_temp1,r_temp1                       ; neg gcol action"); break;
          /* case 5: is a NOP */
        }
        ins(ws, STR(R(r_temp1), R(r_outptr)) | OFFSET(0),               "STR     r_temp1,[r_outptr]");
        if (ws->gcol == 7) /* put r_pixel back as we found it */
          MVN(R(r_pixel), OP2R(R(r_pixel)),                             "1MVN     r_pixel,r_pixel                       ; Put r_pixel back");
      }
      else
      {
        ins(ws, STR(R(r_pixel), R(r_outptr)) | OFFSET(0),             "STR     r_pixel,[r_outptr]");
      }
    }
    else
    {
      if (ws->gcol == 7) /* AND with NOT of incoming pixel */
      {
        if (DESTD_16_BIT)
        {
          EOR(R(r_pixel), R(r_pixel), IMM(255),                       "1EOR     r_pixel,r_pixel,#0x00ff               ; act with NOT of input pixel");
          EOR(R(r_pixel), R(r_pixel), IMM(255) | IMMROR(24),          "1EOR     r_pixel,r_pixel,#0xff00");
        }
        else
          EOR(R(r_pixel), R(r_pixel), IMM(ws->out_dpixmask),          "1EOR     r_pixel,r_pixel,#out_dpixmask         ; act with NOT of input pixel");
      }

      switch (ws->gcol)
      {
        case 0:
          if (SOURCE_MASK || wp->blending) /* if no mask, the pixels are clear already */
          {
            if (wp->CPUFlags & CPUFlag_T2)
            {
              BFC(R(r_outword), 0, wp->BPC, 0,                          "BFC     r_outword,#0,#out_bpc"); 
            }
            else if (DESTD_16_BIT)
            {
              BIC(R(r_outword), R(r_outword), IMM(255),                 "BIC     r_outword,r_outword,#0x00ff");
              BIC(R(r_outword), R(r_outword), IMM(255) | IMMROR(24),    "BIC     r_outword,r_outword,#0xff00");
            }
            else
              BIC(R(r_outword), R(r_outword), IMM(ws->out_dpixmask),    "BIC     r_outword,r_outword,#out_dpixmask");
          }
          /* fall through */
        case 7:
        case 1: ORR(R(r_outword), R(r_outword), OP2R(R(r_pixel)),       "ORR     r_outword,r_outword,r_pixel           ; gcol action"); break;
        case 6: BIC(R(r_outword), R(r_outword), OP2R(R(r_pixel)),       "BIC     r_outword,r_outword,r_pixel           ; AND NOT gcol action"); break;
        case 2: AND(R(r_outword), R(r_outword), OP2R(R(r_pixel)),       "AND     r_outword,r_outword,r_pixel           ; AND gcol action"); break;
        case 3: EOR(R(r_outword), R(r_outword), OP2R(R(r_pixel)),       "EOR     r_outword,r_outword,r_pixel           ; EOR gcol action"); break;
        case 4: if (DESTD_16_BIT)
                {
                  EOR(R(r_outword), R(r_outword), IMM(255),             "EOR     r_outword,r_outword,#0x00ff           ; negate existing pixel");
                  EOR(R(r_outword), R(r_outword), IMM(255) | IMMROR(24),"EOR     r_outword,r_outword,#0xff00");
                }
                else
                  EOR(R(r_outword), R(r_outword), IMM(ws->out_dpixmask),"EOR     r_outword,r_outword,#out_dpixmask     ; negate existing pixel");
                break;
        case 5: comment(ws, "no GCOL action"); break;
      }
      if (ws->gcol == 7) /* put r_pixel back as we found it in case scaling > 1:1! */
      {
        if (DESTD_16_BIT)
        {
          EOR(R(r_pixel), R(r_pixel), IMM(255),                       "EOR     r_pixel,r_pixel,#0x00ff               ; put r_pixel back as it was");
          EOR(R(r_pixel), R(r_pixel), IMM(255) | IMMROR(24),          "EOR     r_pixel,r_pixel,#0xff00               ; put r_pixel back as it was");
        }
        else
          EOR(R(r_pixel), R(r_pixel), IMM(ws->out_dpixmask),          "EOR     r_pixel,r_pixel,#out_dpixmask         ;  put r_pixel back as it was");
      }
    }
  }
}

static void save_pixel_opt(asm_workspace *wp, workspace *ws)
/* Save pixel for use by optimised >5 scaling code. */
{
  if (wp->CPUFlags & CPUFlag_T2)
  {
    BFI(R(r_outword), R(r_pixel), 0, wp->BPC, 0,                "BFI     r_outword,r_pixel,#0,#out_bpc     ; gcol action"); 
  }
  else
  {
    if (DESTD_16_BIT)
    {
      BIC(R(r_outword), R(r_outword), IMM(255),                 "BIC     r_outword,r_outword,#0x00ff");
      BIC(R(r_outword), R(r_outword), IMM(255) | IMMROR(24),    "BIC     r_outword,r_outword,#0xff00");
    }
    else
    {
      BIC(R(r_outword), R(r_outword), IMM(ws->out_dpixmask),    "BIC     r_outword,r_outword,#out_dpixmask");
    }
    ORR(R(r_outword), R(r_outword), OP2R(R(r_pixel)),       "ORR     r_outword,r_outword,r_pixel           ; gcol action");
  }
}

static void save_pixel2(asm_workspace *wp, workspace *ws)
/* Save the new pixel into the pixel after the current destination pixel. */
{
  comment(ws, "Put the pixel in the output stream, one after the 'current' pixel.");

  /* Current limitation */
  assert(ws->gcol == 0, ERROR_FATAL);

  if (DEST_32_BIT)
  {
    ins(ws, STR(R(r_pixel), R(r_outptr)) | OFFSET(4),         "STR     r_pixel,[r_outptr,#4]");
  }
  else if (wp->CPUFlags & CPUFlag_T2)
  {
    BFI(R(r_outword), R(r_pixel), wp->BPC, wp->BPC, 0,        "BFI     r_outword,r_pixel,#out_bpc,#out_bpc");
  }
  else
  {
    if (SOURCE_MASK)
    {
      if (wp->BPC == 16) /* DEST_16_BIT but includes double-pixel 256-colour mode 10 too */
      {
        BIC(R(r_outword), R(r_outword), IMM(255) | IMMROR(16),"BIC     r_outword,r_outword,#0x00ff0000");
        BIC(R(r_outword), R(r_outword), IMM(255) | IMMROR(8), "BIC     r_outword,r_outword,#0xff000000");
      }
      else
        BIC(R(r_outword), R(r_outword),
            wp->BPC == 1
              ? IMM(2) /* IMMROR arg must be an even number */
              : IMM(ws->out_dpixmask) | IMMROR(32 - wp->BPC), "BIC     r_outword,r_outword,#out_dpixmask:SHL:out_bpc");
    }
    ORR(R(r_outword),R(r_outword),
        OP2R(R(r_pixel)) | LSLI(wp->BPC),                     "ORR     r_outword,r_outword,r_pixel,LSL #out_bpc");
  }
}

/**************************************************************************
*                                                                         *
*    Bitblit: Advancing the current pixel.                                *
*                                                                         *
**************************************************************************/

static void fetch_pixel_inc(asm_workspace *wp, workspace *ws)
/* Increment the pointer to the source pixel */
{
  comment(ws, "Advance source pointer");

  if (!PLOTMASK) /* The ECF pattern remains aligned to the destination */
  {
    if (SOURCE_32_BIT)
    {
      ADD(R(r_inptr), R(r_inptr), IMM(4),                      "ADD     r_inptr,r_inptr,#4");
    }
    else
    {
      MOV(R(r_inword), OP2R(R(r_inword)) | RORI(ws->in_bpc),   "MOV     r_inword,r_inword,ROR #in_bpc");
      if (SOURCE_OLDMASK)
      {
        MOV(R(r_maskinword), OP2R(R(r_maskinword)) |
                             RORI(ws->in_bpc),                 "MOV     r_maskinword,r_maskinword,ROR #in_bpc");
      }
      SUB(R(r_inshift), R(r_inshift),
          S | IMM(ws->in_bpc*2) | IMMROR(6),                   "SUBS    r_inshift,r_inshift,#in_bpc:SHL:27 ; auto-resets itself to 0");
      ins(ws, LDR(R(r_inword), R(r_inptr))
            | EQ | WRITEBACK | OFFSET(4),                      "LDREQ   r_inword,[r_inptr,#4]!");
    }
  }

  if (SOURCE_MASK)
  {
    if (SOURCE_TRICKYMASK || PLOTMASK)
    {
#ifdef ASMdoublepixel_bodge
      MOV(R(r_maskinword), OP2R(R(r_maskinword))
                         | RORI(ws->mask_bpp),               "MOV     r_maskinword,r_maskinword,ROR #mask_bpp");
      SUB(R(r_maskinshift),R(r_maskinshift),
                         S | IMM(ws->mask_bpp*2) | IMMROR(6),"SUBS    r_maskinshift,r_maskinshift,#mask_bpp:SHL:27 ; auto-resets itself to 0");
#else
      MOV(R(r_maskinword), OP2R(R(r_maskinword))
                         | RORI(ws->mask_bpc),               "MOV     r_maskinword,r_maskinword,ROR #mask_bpc");
      SUB(R(r_maskinshift),R(r_maskinshift),
                         S | IMM(ws->mask_bpc*2) | IMMROR(6),"SUBS    r_maskinshift,r_maskinshift,#mask_bpc:SHL:27 ; auto-resets itself to 0");
#endif
      ins(ws, LDR(R(r_maskinword), R(r_maskinptr))
            | EQ | WRITEBACK | OFFSET(4),                    "LDREQ   r_maskinword,[r_maskinptr,#4]!");
    }
    else
    {
      assert(!SOURCE_32_BIT, ERROR_FATAL);
      ins(ws, LDR(R(r_maskinword),
              R(r_inptr)) | EQ | INDEX(R(r_masko), 0),       "LDREQ   r_maskinword,[r_inptr,r_masko]");
    }
  }
}

static void fetch_pixel_inc2(asm_workspace *wp, workspace *ws)
/* Increment the pointer to the source pixel by two - only used in the 2-at-a-time
 * optimised loop
 */
{
  comment(ws, "Advance source pointer by two pixels");
  if (SOURCE_32_BIT)
  {
    ADD(R(r_inptr), R(r_inptr), IMM(8),                      "ADD     r_inptr,r_inptr,#8                ; past 2 32-bit pixels");
  }
  else if (SOURCED_16_BIT)
  {
    /* Two pixels per word - assured of loading a new word */
    ins(ws, LDR(R(r_inword), R(r_inptr))
          | WRITEBACK | OFFSET(4),                           "LDR     r_inword,[r_inptr,#4]!             ; past 2 16-bit pixels");
  }
  else
  {
    MOV(R(r_inword), OP2R(R(r_inword)) | RORI(ws->in_bpc*2), "MOV     r_inword,r_inword,ROR #in_bpc*2");
    if (SOURCE_OLDMASK)
    {
      MOV(R(r_maskinword), OP2R(R(r_maskinword)) |
                           RORI(ws->in_bpc*2),               "MOV     r_maskinword,r_maskinword,ROR #in_bpc*2 ; two more mask bits");
    }
    SUB(R(r_inshift), R(r_inshift),
        S | IMM(ws->in_bpc) | IMMROR(4),                     "SUBS    r_inshift,r_inshift,#in_bpc:SHL:27+1 ; auto-resets itself to 0");
    ins(ws, LDR(R(r_inword), R(r_inptr))
          | EQ | WRITEBACK | OFFSET(4),                      "LDREQ   r_inword,[r_inptr,#4]!             ; load more input pixels (inc2)");
  }

  if (SOURCE_MASK)
  {
    if (SOURCE_TRICKYMASK)
    {
      MOV(R(r_maskinword), OP2R(R(r_maskinword))
                         | RORI(ws->mask_bpc),               "MOV     r_maskinword,r_maskinword,ROR #mask_bpc");
      SUB(R(r_maskinshift),R(r_maskinshift),
                         S | IMM(ws->mask_bpc*2) | IMMROR(6),"SUBS    r_maskinshift,r_maskinshift,#mask_bpc:SHL:27");
      ins(ws, LDR(R(r_maskinword), R(r_maskinptr))
            | EQ | WRITEBACK | OFFSET(4),                    "LDREQ   r_maskinword,[r_maskinptr,#4]!     ; load more mask pixels (inc2)");
    }
    else
    {
      assert(!SOURCE_32_BIT, ERROR_FATAL);
      ins(ws, LDR(R(r_maskinword), R(r_inptr))
              | EQ | INDEX(R(r_masko), 0),                   "LDREQ   r_maskinword,[r_inptr,r_masko]      ; load more mask pixels (inc2)");
    }
  }
}

#if 1
static void skip_current_output_words(asm_workspace *wp, workspace *ws)
/* Skip over masked out words. r_xcount = output pixels to skip
 *                             r_temp1   = pixels left in current word.
 */
{
  comment(ws, "4Skipping masked words.");
  if (DEST_32_BIT)
  {
    ADD(R(r_outptr), R(r_outptr), R(r_xcount) | LSLI(2),          "ADD     r_outptr,r_outptr,r_xcount,LSL #2        ; skip 4*pixels bytes");
    MOV(R(r_xcount), IMM(0),                                      "MOV     r_xcount,#0");
  }
  else
  {
    SUB(R(r_xcount), R(r_xcount), OP2R(R(r_temp1)),               "SUB     r_xcount, r_xcount, r_temp1");
    MOV(R(r_temp1),  OP2R(R(r_temp1)) | LSLI(wp->Log2bpc),        "MOV     r_temp1, t_temp1, LSL #out_log2bpc");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORR(R(r_temp1)),      "MOV     r_outword,r_outword,ROR r_temp1");
    ins(ws, STR(R(r_outword), R(r_outptr)) | POSTINC(4),          "STR     r_outword,[r_outptr],#4");
    MOV(R(r_outshift), IMM(0),                                    "MOV     r_outshift, #0");

    MOV(R(r_temp1), OP2R(R(r_xcount)) | S |LSRI(ws->out_l2ppw),   "MOVS    r_temp1,r_xcount,LSR #out_log2ppw            ; whole words to skip");
    ADD(R(r_outptr), R(r_outptr), NE | R(r_temp1) | LSLI(2),      "ADDNE   r_outptr,r_outptr,r_temp1,LSL #2             ; skip 4*pixels bytes");

    ins(ws, LDR(R(r_outword), R(r_outptr)) | OFFSET(0),           "LDR     r_outword,[r_outptr]");
    SUB(R(r_xcount), R(r_xcount),
                      OP2R(R(r_temp1)) | LSLI(ws->out_l2ppw),     "SUB     r_xcount, r_xcount, r_temp1 LSL #out_log2ppw ; pixels left to skip");
  }
}

static void skip_some_pixels(asm_workspace *wp, workspace *ws)
/* Adjust outword and outshift back to start */
{
    MOV(R(r_temp1),  OP2R(R(r_xcount)) | LSLI(wp->Log2bpc),       "MOV     r_temp1, r_xcount, LSL #out_log2bpc");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORR(R(r_temp1)),      "MOV     r_outword,r_outword,ROR r_temp1");
    SUB(R(r_outshift), R(r_outshift),
        OP2R(R(r_temp1)) | LSLI(27),                              "SUB     r_outshift,r_outshift,r_temp1,SHL #27");
    MOV(R(r_xcount), IMM(0),                                      "MOV     r_xcount,#0");
    UNUSED(wp);
}
#endif

static void save_pixel_inc(asm_workspace *wp, workspace *ws)
/* Increment the pointer to the destination pixel */
{
  comment(ws, "Advance destination pointer");
  if (DEST_32_BIT)
  {
    ADD(R(r_outptr), R(r_outptr), IMM(4),                    "ADD     r_outptr,r_outptr,#4 323232");
  }
  else
  {
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),    "MOV     r_outword,r_outword,ROR #out_bpc    545454");
    if (PLOTMASK)
    {
      MOV(R(r_inword), OP2R(R(r_inword)) | RORI(wp->BPC),    "MOV     r_inword,r_inword,ROR #out_bpc         ; advance ECF pattern    5");
      MOV(R(r_bgcolour), OP2R(R(r_bgcolour)) | RORI(wp->BPC),    "MOV     r_bgcolour,r_bgcolour,ROR #out_bpc ; advance ECF eeyore pattern    5");
    }
    SUB(R(r_outshift), R(r_outshift),
        S | IMM(wp->BPC*2) | IMMROR(6),                      "SUBS    r_outshift,r_outshift,#out_bpc:SHL:27        5");
    ins(ws, STR(R(r_outword), R(r_outptr)) | EQ | POSTINC(4),"STREQ   r_outword,[r_outptr],#4        4");
    if (ws->gcol == 0 && !SOURCE_MASK && !PLOTMASK && !wp->blending)
      MOV(R(r_outword), EQ | IMM(0),                         "MOVEQ   r_outword,#0                    ; setting pixels and no mask      4");
    else
      ins(ws, LDR(R(r_outword), R(r_outptr)) | EQ | OFFSET(0), "LDREQ   r_outword,[r_outptr]        4");
  }
  odither_inc(wp, ws, 0);
}

static void save_pixel_inc2(asm_workspace *wp, workspace *ws)
/* Increment the pointer to the destination pixel by two. You are assured that
 * a word fetch won't be necessary after the first of these. Only used in the
 * optimised 2-at-a-time inner loop. You are assured that gcol==0.
 */
{
  comment(ws, "Advance destination pointer by two pixels");
  if (DEST_32_BIT)
    ADD(R(r_outptr), R(r_outptr), IMM(8),                    "ADD     r_outptr,r_outptr,#8");
  else if (DESTD_16_BIT)
  {
    /* Two pixels per word - assured of saving a word, assured that gcol==0 and !SOURCE_MASK*/
    ins(ws, STR(R(r_outword), R(r_outptr)) | POSTINC(4),     "STR     r_outword,[r_outptr],#4         ; store two pixels");
    if (!SOURCE_MASK)
      MOV(R(r_outword), IMM(0),                              "MOV     r_outword,#0                    ; setting pixels and no mask");
    else
      ins(ws, LDR(R(r_outword), R(r_outptr)) | OFFSET(0),    "LDR     r_outword,[r_outptr]            ; load dest data (in case of mask)");
  }
  else
  {
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC*2),  "MOV     r_outword,r_outword,ROR #out_bpc*2 ; two more done");
    SUB(R(r_outshift), R(r_outshift),
        S | IMM(wp->BPC) | IMMROR(4),                        "SUBS    r_outshift,r_outshift,#out_bpc:SHL:27+1");
    ins(ws, STR(R(r_outword), R(r_outptr)) | EQ | POSTINC(4),"STREQ   r_outword,[r_outptr],#4         ; store pixels (inc2)");
    if (!SOURCE_MASK)
      MOV(R(r_outword), EQ | IMM(0),                         "MOVEQ   r_outword,#0                    ; setting pixels and no mask (inc2)");
    else
      ins(ws, LDR(R(r_outword), R(r_outptr)) | EQ | OFFSET(0), "LDREQ   r_outword,[r_outptr]            ; get dest data (in case of mask)");
    /* If entirely replacing pixels, no need to fetch the old ones.
     * The last word has to be patched up carefully, see x_loop.
     */
  }
  odither_inc(wp, ws, 0); /* assume this has also been called once after the first pixel has been translated */
}

static void plot_current_output_words(asm_workspace *wp, workspace *ws, int scale)
/* plot multiple words of one pixel. r_xcount = output pixels to skip
 *                                   r_temp1   = pixels left in current word.
 *                                   r_pixel = pixel to output.
 */
{
  int loop;
  comment(ws, "2Optimised plotting of scaled sprite.");
  if (DEST_32_BIT)
  {
#if 1
    ins(ws, STR(R(r_pixel),  R(r_outptr)) | POSTINC(4),      "32STR     r_pixel,[r_outptr],#4");
    SUB(R(r_xcount), R(r_xcount),
        S | IMM(1),                                         "14SUBS    r_xcount,r_xcount,#1");
    if (scale < 21)
    {
      for (loop = 1;loop<scale;loop++)
      {
        ins(ws, STR(R(r_pixel), R(r_outptr)) | NE | POSTINC(4),      "32STRNE   r_pixel,[r_outptr],#4");
        SUB(R(r_xcount), R(r_xcount),
              S | NE | IMM(1),                                    "14SUBNES    r_xcount,r_xcount,#1");
      }
    }
    else
    {
      CMP(R(r_xcount), IMM(10),                                    "CMP     r_xcount, #10");
      branch(ws, B | LE, L(plot_loop1b),                           "BLE     plot_loop1b");
      DEFINE_LABEL(plot_loop1a, "loop for every ten pixels")
      for (loop = 0;loop<10;loop++)
      {
        ins(ws, STR(R(r_pixel), R(r_outptr)) | POSTINC(4),         "32STR   r_pixel,[r_outptr],#4");
      }
      SUB(R(r_xcount), R(r_xcount),
          IMM(10),                                                 "14SUB    r_xcount,r_xcount,#10");
      CMP(R(r_xcount), IMM(10),                                    "CMP     r_xcount, #10");
      branch(ws, B | GT, L(plot_loop1a),                           "BGT     plot_loop1a");
      DEFINE_LABEL(plot_loop1b, "branch here when LH side obscured")
      CMP(R(r_xcount), IMM(0),                                     "CMP     r_xcount, #0");
      for (loop = 0;loop<10;loop++)
      {
        ins(ws, STR(R(r_pixel), R(r_outptr)) | NE | POSTINC(4),      "4STRNE   r_pixel,[r_outptr],#4");
        SUB(R(r_xcount), R(r_xcount),
              S | NE | IMM(1),                                    "16SUBNES    r_xcount,r_xcount,#1");
      }
    }
#else
    for (loop = 0;loop<scale;loop++)
      ins(ws, STR(R(r_pixel), R(r_outptr)) | POSTINC(4),      "32STR   r_outword,[r_outptr],#4");
#endif
  }
  else
  {
    SUB(R(r_xcount), R(r_xcount), OP2R(R(r_temp1)),             "52SUB     r_xcount, r_xcount, r_temp1");

    DEFINE_LABEL(plot_loop1, "1???")
    save_pixel_opt(wp, ws);
    SUB(R(r_outshift), R(r_outshift),
        S | IMM(wp->BPC*2) | IMMROR(6),                         "SUBS    r_outshift,r_outshift,#out_bpc:SHL:27");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");
    branch(ws, B | EQ, L(plot_loop1a),                          "BEQ     plot_loop1a");

    save_pixel_opt(wp, ws);
    SUB(R(r_outshift), R(r_outshift),
        S | IMM(wp->BPC*2) | IMMROR(6),                         "SUBS    r_outshift,r_outshift,#out_bpc:SHL:27");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");
    branch(ws, B | EQ, L(plot_loop1b),                          "BEQ     plot_loop1b");

    save_pixel_opt(wp, ws);
    SUB(R(r_outshift), R(r_outshift),
        S | IMM(wp->BPC*2) | IMMROR(6),                         "SUBS    r_outshift,r_outshift,#out_bpc:SHL:27");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");
    branch(ws, B | EQ, L(plot_loop1c),                          "BEQ     plot_loop1c");

    save_pixel_opt(wp, ws);
    SUB(R(r_outshift), R(r_outshift),
        S | IMM(wp->BPC*2) | IMMROR(6),                         "SUBS    r_outshift,r_outshift,#out_bpc:SHL:27");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");

    branch(ws, B | NE, L(plot_loop1),                           "8BNE     plot_loop1");
    DEFINE_LABEL(plot_loop1a, "plot loop 1a - coz only one forward referance allowed")
    DEFINE_LABEL(plot_loop1b, "plot loop 1b - coz only one forward referance allowed")
    DEFINE_LABEL(plot_loop1c, "plot loop 1c - coz only one forward referance allowed")

    ins(ws, STR(R(r_outword), R(r_outptr)) | POSTINC(4),          "9STR     r_outword,[r_outptr],#4");

    MOV(R(r_temp1), OP2R(R(r_xcount)) | S |LSRI(ws->out_l2ppw),   "0MOVS    r_temp1,r_xcount,LSR #out_log2ppw            ; whole words to skip");

    branch(ws, B | EQ, L(plot_loop3),                             "1BEQ     plot_loop3");

    for (loop = wp->BPC;loop<32;loop*=2)
      ORR(R(r_pixel), R(r_pixel), OP2R(R(r_pixel)) | LSLI(loop),  "2ORR     r_pixel,r_pixel,r_pixel, LSL #somenumber");
    DEFINE_LABEL(plot_loop2, "2???")
    ins(ws, STR(R(r_pixel), R(r_outptr)) | POSTINC(4),            "3STR     r_pixel,[r_outptr],#4");
    SUB(R(r_temp1), R(r_temp1),
        S | IMM(1),                                               "5SUBS    r_temp1,r_temp1,#1");
    SUB(R(r_xcount), R(r_xcount),
        IMM(ws->out_ppw),                                         "4SUB     r_xcount,r_xcount,#out_ppw");
    branch(ws, B | NE, L(plot_loop2),                             "6BNE     plot_loop2");

    MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRI(32-wp->BPC),          "MOV     r_pixel,r_pixel,LSR #32-out_bpc");

    DEFINE_LABEL(plot_loop3, "3???")


    ins(ws, LDR(R(r_outword), R(r_outptr)) | OFFSET(0),           "0LDR     r_outword,[r_outptr]");
  }
}

static void plot_some_pixels(asm_workspace *wp, workspace *ws)
/* Non complete word pixel plot */
{
    DEFINE_LABEL(plot_loop4, "4???")
    save_pixel_opt(wp, ws);
    SUB(R(r_xcount), R(r_xcount),
        S | IMM(1),                                             "SUBS    r_xcount, r_xcount, #1");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");
    SUB(R(r_outshift), R(r_outshift),
        IMM(wp->BPC*2) | IMMROR(6),                             "SUB     r_outshift,r_outshift,#out_bpc:SHL:27");
    branch(ws, B | EQ, L(plot_loop4a),                          "BEQ     plot_loop4a");

    save_pixel_opt(wp, ws);
    SUB(R(r_xcount), R(r_xcount),
        S | IMM(1),                                             "SUBS    r_xcount, r_xcount, #1");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");
    SUB(R(r_outshift), R(r_outshift),
        IMM(wp->BPC*2) | IMMROR(6),                             "SUB     r_outshift,r_outshift,#out_bpc:SHL:27");
    branch(ws, B | EQ, L(plot_loop4b),                          "BEQ     plot_loop4b");

    save_pixel_opt(wp, ws);
    SUB(R(r_xcount), R(r_xcount),
        S | IMM(1),                                             "SUBS    r_xcount, r_xcount, #1");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");
    SUB(R(r_outshift), R(r_outshift),
        IMM(wp->BPC*2) | IMMROR(6),                             "SUB     r_outshift,r_outshift,#out_bpc:SHL:27");
    branch(ws, B | EQ, L(plot_loop4c),                          "BEQ     plot_loop4c");

    save_pixel_opt(wp, ws);
    SUB(R(r_xcount), R(r_xcount),
        S | IMM(1),                                             "SUBS    r_xcount, r_xcount, #1");
    MOV(R(r_outword), OP2R(R(r_outword)) | RORI(wp->BPC),       "MOV     r_outword,r_outword,ROR #out_bpc");
    SUB(R(r_outshift), R(r_outshift),
        IMM(wp->BPC*2) | IMMROR(6),                             "SUB     r_outshift,r_outshift,#out_bpc:SHL:27");

    branch(ws, B | NE, L(plot_loop4),                           "BNE     plot_loop4");
    DEFINE_LABEL(plot_loop4a, "plot loop 4a - coz only one forward referance allowed")
    DEFINE_LABEL(plot_loop4b, "plot loop 4b - coz only one forward referance allowed")
    DEFINE_LABEL(plot_loop4c, "plot loop 4c - coz only one forward referance allowed")
}

/**************************************************************************
*                                                                         *
*    Bitblit: Overall construction of the X loop.                         *
*                                                                         *
**************************************************************************/

static void init_word_registers(asm_workspace *wp, workspace *ws)
/* Initialise inword, outword, maskinword from their respective pointers
 * and shift values.
 */
{
  comment(ws, "Load initial values of word registers");

  /* Set up inword */
  if (!PLOTMASK) /* PLOTMASK case handled below, because helped by setting up r_outword */
  {
    if (!SOURCE_32_BIT)
    {
      ins(ws, LDR(R(r_inword), R(r_inptr)) | OFFSET(0),         "LDR     r_inword,[r_inptr]              ; fetch first input pixels");
      MOV(R(r_pixel), OP2R(R(r_inshift)) | LSRI(27),            "MOV     r_pixel,r_inshift,LSR #27       ; get real shift distance");
      RSB(R(r_pixel), R(r_pixel), IMM(32),                      "RSB     r_pixel,r_pixel,#32             ; temporary use of r_pixel");
      MOV(R(r_inword), OP2R(R(r_inword)) | RORR(R(r_pixel)),    "MOV     r_inword,r_inword,ROR r_pixel   "
                                                              "; current input pixel now in least sig bit[s]");
    }
  }

  if (SOURCE_MASK) /* Set up maskinword */
  {
    if (SOURCE_TRICKYMASK || PLOTMASK)
    {
      ins(ws, LDR(R(r_maskinword), R(r_maskinptr)) | OFFSET(0), "LDR     r_maskinword,[r_maskinptr]        ; fetch first mask word");
      MOV(R(r_pixel), OP2R(R(r_maskinshift)) | LSRI(27),      "MOV     r_pixel,r_maskinshift,LSR #27     ; get real shift distance");
      RSB(R(r_pixel), R(r_pixel), IMM(32),                    "RSB     r_pixel,r_pixel,#32         ; mask shift");
    }
    else
      ins(ws, LDR(R(r_maskinword),
              R(r_inptr)) | INDEX(R(r_masko), 0),             "LDR     r_maskinword,[r_inptr,r_masko]    ; fetch first mask word");
    MOV(R(r_maskinword), OP2R(R(r_maskinword)) | RORR(R(r_pixel)),"MOV     r_maskinword,r_maskinword,ROR r_pixel "
                                                              "; current mask pixel now in least sig bit[s]");
  }

  if (!DEST_32_BIT) /* Set up outword */
  {
    if (ws->gcol == 0 && !SOURCE_MASK && !PLOTMASK && !wp->blending)
    {
      /* Faster in the inner loop, but the unneeded pixels must be cleared out first */
      MOV(R(r_pixel), S | OP2R(R(r_outshift)) | LSRI(27),     "MOVS    r_pixel,r_outshift,LSR #27      ; get real shift distance");
      ins(ws, LDR(R(r_outword), R(r_outptr)) | NE | OFFSET(0),  "LDRNE   r_outword,[r_outptr]            ; load up output word");
      MOV(R(r_outword), NE | OP2R(R(r_outword))
                      | LSLR(R(r_pixel)),                     "MOVNE   r_outword,r_outword,LSL r_pixel "
                                                              "; set untouched pixels to correct places, clear the others");
      MOV(R(r_outword), EQ | IMM(0),                          "MOVEQ   r_outword,#0                    ; if r_pixel=0, make them all clear");
    }
    else
    {
      ins(ws, LDR(R(r_outword), R(r_outptr)) | OFFSET(0),     "LDR     r_outword,[r_outptr]            ; load up output word");
      MOV(R(r_pixel), OP2R(R(r_outshift)) | LSRI(27),         "MOV     r_pixel,r_outshift,LSR #27      ; get real shift distance");
      RSB(R(r_pixel), R(r_pixel), IMM(32),                    "RSB     r_pixel,r_pixel,#32             ; temp use of r_pixel");
      MOV(R(r_outword), OP2R(R(r_outword)) | RORR(R(r_pixel)),"MOV     r_outword,r_outword,ROR r_pixel "
                                                              "; current output pixel now in least sig bit[s]");
      /* Set up inword from ECF pattern - uses r_pixel value */
      if (PLOTMASK)
      {
        ins(ws, LDR(R(r_inword), R(r_inptr))
              | INDEX(R(r_ecfindex), 0),                      "LDR     r_inword,[r_inptr,r_ecfindex]   ; get ECF pattern word");
        MOV(R(r_inword), OP2R(R(r_inword)) | RORR(R(r_pixel)),"MOV     r_inword,r_inword,ROR r_pixel  1 "
                                                              "; current ECF pixel now in least sig bit[s]");
        ADD(R(r_ecfindex), R(r_ecfindex),
              IMM(4),                                           "ADD     r_ecfindex,r_ecfindex,#4        ; to load EOR word 1");
        ins(ws, LDR(R(r_bgcolour), R(r_inptr))
              | INDEX(R(r_ecfindex), 0),                        "LDR     r_bgcolour,[r_inptr,r_ecfindex]   ;fetch next EOR word of ECF1");
        SUB(R(r_ecfindex), R(r_ecfindex),
              IMM(4),                                           "SUB     r_ecfindex,r_ecfindex,#4        ;blah1");
        MOV(R(r_bgcolour), OP2R(R(r_bgcolour)) | RORR(R(r_pixel)),"MOV     r_bgcolour,r_bgcolour,ROR r_pixel  1 ");
      }
    }
  }
}

static void loop_x(asm_workspace *wp, workspace *ws)
/* The variables are set up - perform the inner loop that processes a
 * single line. Fall out of the bottom of the loop when complete.
 */
{
  BOOL mask_possible;

  comment(ws, "The inner loop: iterating along a row of pixels.");
  if (x_block_move(wp, ws))
  {
    comment(ws, "Very simple inner loop - we use an existing block-move primitive");
    if(wp->CPUFlags & CPUFlag_BLX)
    {
      BLX(R(r_blockroutine),                                   "BLX     r_blockroutine                  ; block move");
    }                 
    else
    {
      MOV(R(lr), OP2R(R(pc)),                                  "MOV     lr,pc                           ; remember return address");
      MOV(R(pc), OP2R(R(r_blockroutine)),                      "MOV     pc,r_blockroutine               ; block move");
    }
    /* It would be a little bit more efficient to do state saving here rather than inside the routine,
     * and so only save registers that need to be saved - not a big saving, and only per-line.
     */
  }
  else
  {
    init_word_registers(wp, ws);

    if (simple_x_scale(wp, ws)) /* 1:1 scaling */
    {
      comment(ws, "1:1 scaling along x, so each source pixel is painted once");

#if 0
      align16(wp, ws);
      DEFINE_LABEL(loop_x_repeat, "Loop around for each source/dest pixel")
      mask_possible = fetch_pixel(wp, ws, &ws->labels.l_masked);
      translate_pixel(wp, ws);
      save_pixel(wp, ws);
      if (mask_possible) DEFINE_LABEL(l_masked, "This pixel masked out")
      fetch_pixel_inc(wp, ws);
      save_pixel_inc(wp, ws);
      SUB(R(r_xsize), R(r_xsize), S | IMM(1),                    "SUBS    r_xsize,r_xsize,#1");
      branch(ws, B | NE, L(loop_x_repeat),                       "BNE     loop_x_repeat");
#else

      /* We generate a loop that does two pixels at a time, only advancing pointers, counts, shifts
       * etc. every two pixels. There are two versions of this loop, one where the in and out shifts
       * are 'in phase' (ie initially both even or both odd), one where they are out of phase. There
       * is also some initial stuff to get the outshift to be even if necessary when entering either
       * of these, and some final stuff to patch up the end.
       */
      comment(ws, "Optimised 2-at-a-time loop");
      if (!DEST_32_BIT)
      {
        TST(R(r_outshift), IMM(wp->BPC*2) | IMMROR(6),           "TST     r_outshift,#out_bpc:SHL:27      ; start at odd or even pixel shift?");
        branch(ws, B | EQ, L(x_evenstart),                       "BEQ     x_evenstart                     ; B if even");
        comment(ws, "r_outshift an odd number of pixels - process just one of these");
        mask_possible = fetch_pixel(wp, ws, &ws->labels.x_oddmask);
        translate_pixel(wp, ws);
        save_pixel(wp, ws);
        if (mask_possible) DEFINE_LABEL(x_oddmask, "This pixel masked out")
        fetch_pixel_inc(wp, ws);
        save_pixel_inc(wp, ws);
        SUB(R(r_xsize), R(r_xsize), S | IMM(1),                  "SUBS    r_xsize,r_xsize,#1              ; count towards overall width");
        branch(ws, B | EQ, L(loop_x_exit),                       "BEQ     loop_x_exit                     ; check for just one pixel wide");
        DEFINE_LABEL(x_evenstart, "r_outshift is an even number of pixels")
      }
      if (!SOURCE_32_BIT)
      {
        TST(R(r_inshift), IMM(ws->in_bpc*2) | IMMROR(6),         "TST     r_inshift,#in_bpc:SHL:27        ; input at odd or even pixel shift?");
        branch(ws, B | NE, L(x_misaligned),                      "BNE     x_misaligned                    ; B if odd");
      }
      branch(ws, B, L(x_aligned_enter),                          "B       x_aligned_enter                 ; else, in phase with output - start loop");
      newline();

      align16(wp, ws);
      DEFINE_LABEL(x_aligned_loop, "The 2-at-a-time inner loop, aligned case")
      mask_possible = fetch_pixel(wp, ws, &ws->labels.x_alignmask1);
      translate_pixel(wp, ws);
      save_pixel(wp, ws);
      if (mask_possible) DEFINE_LABEL(x_alignmask1, "First pixel masked out")
      odither_inc(wp, ws, 0);
      mask_possible = fetch_pixel2(wp, ws, &ws->labels.x_alignmask2);
      translate_pixel(wp, ws);
      save_pixel2(wp, ws);
      if (mask_possible) DEFINE_LABEL(x_alignmask2, "Second pixel masked out")
      fetch_pixel_inc2(wp, ws);
      save_pixel_inc2(wp, ws);
      DEFINE_LABEL(x_aligned_enter, "Entering the aligned 2-at-a-time inner loop")
      SUB(R(r_xsize), R(r_xsize), S | IMM(2),                    "SUBS    r_xsize,r_xsize,#2              ; done 2 pixels");
      branch(ws, B | GE, L(x_aligned_loop),                      "BGE     x_aligned_loop                  ; loop until 0 or 1 left");
      if (!SOURCE_32_BIT)
      {
        branch(ws, B, L(x_2atatime_exit),                        "B       x_2atatime_exit                 ; final patchup code");
        newline();

        DEFINE_LABEL(x_misaligned, "The 2-at-a-time inner loop, misaligned case, entry sequence")
        /* A bit delicate - we have to prepare the input stream for an inc2 call,
         * by effectively winding it back by a pixel. We know this won't go back a word,
         * however, because r_inshift is an odd number of pixels.
         */
        comment(ws, "Wind input stream back by a pixel");
        if (SOURCE_32_BIT)
          SUB(R(r_inptr), R(r_inptr), IMM(4),                    "SUB     r_inptr,r_inptr,#4              ; wind back a pixel");
        else
        {
#ifdef ASMdoublepixel_bodge
          MOV(R(r_inword), OP2R(R(r_inword)) | LSLI(ws->in_bpp), "MOV     r_inword,r_inword,LSL #in_bpp   ; wind back a pixel");
          ADD(R(r_inshift), R(r_inshift),
              IMM(ws->in_bpp*2) | IMMROR(6),                     "ADD     r_inshift,r_inshift,#in_bpp:SHL:27");
#else
          MOV(R(r_inword), OP2R(R(r_inword)) | LSLI(ws->in_bpc), "MOV     r_inword,r_inword,LSL #in_bpc   ; wind back a pixel");
          ADD(R(r_inshift), R(r_inshift),
              IMM(ws->in_bpc*2) | IMMROR(6),                     "ADD     r_inshift,r_inshift,#in_bpc:SHL:27");
#endif
        }
        if (SOURCE_MASK)
        {
#ifdef ASMdoublepixel_bodge
          MOV(R(r_maskinword), OP2R(R(r_maskinword))
                             | LSLI(ws->mask_bpp),               "MOV     r_maskinword,r_maskinword,LSL #mask_bpp");
          if (SOURCE_TRICKYMASK)
          {
            ADD(R(r_maskinshift), R(r_maskinshift),
                IMM(ws->mask_bpp*2) | IMMROR(6),                 "ADD     r_maskinshift,r_maskinshift,#mask_bpp:SHL:27");
          }
#else
          MOV(R(r_maskinword), OP2R(R(r_maskinword))
                             | LSLI(ws->mask_bpc),               "MOV     r_maskinword,r_maskinword,LSL #mask_bpc");
          if (SOURCE_TRICKYMASK)
          {
            ADD(R(r_maskinshift), R(r_maskinshift),
                IMM(ws->mask_bpc*2) | IMMROR(6),                 "ADD     r_maskinshift,r_maskinshift,#mask_bpc:SHL:27");
          }
#endif
        }
        branch(ws, B, L(x_misaligned_enter),                     "B       x_misaligned_enter              ; start misaligned loop");
        align16(wp, ws);
        DEFINE_LABEL(x_misaligned_loop, "The 2-at-a-time inner loop, misaligned case")
        mask_possible = fetch_pixel2(wp, ws, &ws->labels.x_misalignmask1);
        translate_pixel(wp, ws);
        save_pixel(wp, ws);
        if (mask_possible) DEFINE_LABEL(x_misalignmask1, "A pixel masked out")
        fetch_pixel_inc2(wp, ws);
        odither_inc(wp, ws, 0);
        mask_possible = fetch_pixel(wp, ws, &ws->labels.x_misalignmask2);
        translate_pixel(wp, ws);
        save_pixel2(wp, ws);
        if (mask_possible) DEFINE_LABEL(x_misalignmask2, "Another pixel masked out")
        save_pixel_inc2(wp, ws);
        DEFINE_LABEL(x_misaligned_enter, "Entering the misaligned 2-at-a-time inner loop")
        SUB(R(r_xsize), R(r_xsize), S | IMM(2),                  "SUBS    r_xsize,r_xsize,#2              ; count towards overall size");
        branch(ws, B | GE, L(x_misaligned_loop),                 "BGE     x_misaligned_loop               ; and loop until done");
        fetch_pixel_inc(wp, ws);
        newline();

        DEFINE_LABEL(x_2atatime_exit, "Final patchup for 2-at-a-time inner loop")
      }
      else
        newline();
      ADD(R(r_xsize), R(r_xsize), S | IMM(2),                    "ADDS    r_xsize,r_xsize,#2              ; up to 0 or 1");
      branch(ws, B | EQ, L(loop_x_exit1),                        "BEQ     loop_x_exit1                    ; No last pixel to be done\n");
      mask_possible = fetch_pixel(wp, ws, &ws->labels.x_lastmask);
      translate_pixel(wp, ws);
      save_pixel(wp, ws);
      if (mask_possible) DEFINE_LABEL(x_lastmask, "Last pixel masked out")
      fetch_pixel_inc(wp, ws);
      save_pixel_inc(wp, ws);

      DEFINE_LABEL(                                     loop_x_exit1, "End of input pixel line (1)")
#endif
    }
    else
    {
      comment(ws, "Control of scaling along x");
      if ((ws->odither || wp->blending) && wp->save_xadd - wp->save_xdiv > wp->save_xdiv)
      {
        /* If dithering/blending and scaling we have to be very careful about where we do fetch_pixel_inc, because when replicating
         * a pixel we must repeatedly fetch_pixel it.
         */
        SUB_A(r_xcount, wp->save_xadd)
        DEFINE_LABEL(                                       loop_x_repeat, "Loop around for each source pixel (ordered dither / blending)")
        ADD_A(r_xcount, wp->save_xadd)  /*(GPS)*/

        mask_possible = fetch_pixel(wp, ws, &ws->labels.l_masked);
        SUBS_A(r_xcount, wp->save_xdiv)  /* Stop dither from printing 1 too many pixels... (GPS) */
        DEFINE_LABEL(                                       loop_put_pixel_repeat, "Repeatedly paint and ordered-dither/blend a source pixel");
        translate_pixel(wp, ws);
        save_pixel(wp, ws);
        save_pixel_inc(wp, ws);
        SUB(R(r_xsize), R(r_xsize), S | IMM(1),                    "SUBS    r_xsize,r_xsize,#1              ; count output ordered dither / blended pixels");
        branch(ws, B | EQ, L(loop_x_exit),                         "BEQ     loop_x_exit                     ; painted enough pixels");
        /* We must not paint the same pixel repeatedly - we must reextract and retranslate it, otherwise
         * the dithering on scaled up pixels will not occur.
         */
        fetch_pixel_unmasked(wp, ws); /* reextract the pixel into r_pixel */
        SUBS_A(r_xcount, wp->save_xdiv)  /* Decrement count (GPS) */
        branch(ws, B | PL, L(loop_put_pixel_repeat),               "BPL     loop_put_pixel_repeat           ; recalculate and repaint");
        fetch_pixel_inc(wp, ws); /* moved by (GPS) */
        branch(ws, B, L(loop_x_repeat),                            "B       loop_x_repeat                   ; next input pixel");
      }
      else
      {
        if ( !PLOTMASK && (wp->save_xmag % wp->save_xdiv) == 0 && ((wp->save_xmag / wp->save_xdiv) > 4) && ws->gcol == 0 && !wp->blending)
                 /* do optimised code */
        {
          register int toskip = wp->save_xmag / wp->save_xdiv;

          dprintf(("", "in optimised scale\nxmag = %d, xdiv = %d, xmag mod xdiv = %d\n", wp->save_xmag, wp->save_xdiv, wp->save_xmag % wp->save_xdiv));
          SUB_A(r_xcount, toskip)
          DEFINE_LABEL(                                       loop_x_repeat, "3Loop around for each source pixel")
          TEQ(R(r_xsize), IMM(0),                                       "3TEQ     r_xsize, #0");
          DEFINE_LABEL(loop_x_exitskip,          "3Kludge to avoid multiple forward references");
          branch(ws, B | EQ, L(loop_x_exit),                      "3BEQ     loop_x_exit");
          ADD_A(r_xcount, toskip)
          mask_possible = fetch_pixel(wp, ws, &ws->labels.l_masked);
          translate_pixel(wp, ws); /* If we're about the discard the pixel this is in fact wasted work - we could reorganise
                                    * this whole loop to improve that situation, but it doesn't really seem worthwhile, the gain
                                    * is not enormous.
                                    */
          fetch_pixel_inc(wp, ws);

          comment(ws, "3calculating number of times to plot pixel 1");
          MOV(R(r_temp1), OP2R(R(r_xsize)),                            "3MOV     r_temp1, r_xsize               ; store r_xsize");
          SUB(R(r_xsize), R(r_xsize), S | OP2R(R(r_xcount)),            "3SUBS    r_xsize, r_xsize, r_xcount  ; count output pixels");
          MOV(R(r_xsize), MI | IMM(0),                                  "3MOVMI   r_xsize, #0                                          ");
          MOV(R(r_xcount), MI | OP2R(R(r_temp1)),                       "3MOVMI   r_xcount, r_temp1                                          ");

          if (!DEST_32_BIT)
          {
            MOV(R(r_temp1), S | OP2R(R(r_outshift)) | LSRI(27),           "3MOVS    r_temp1, r_outshift, LSR #27");
            MOV(R(r_temp1), EQ | IMM(32),                                 "3MOVEQ   r_temp1, #32                    ; 0 in r_outshift => 32 bits left");
            if (!DEST_1_BIT)
              MOV(R(r_temp1), OP2R(R(r_temp1)) | LSRI(wp->Log2bpc),       "3MOV     r_temp1, r_temp1, LSR #out_log2bpc");
            CMP(R(r_xcount), OP2R(R(r_temp1)),                            "3CMP     r_xcount, r_temp1");
            branch(ws, B + LT, L(loop2),                                  "3BLT     loop2                   ; end of this masked input pixel");
          }

          plot_current_output_words(wp, ws, toskip);

          if (DEST_32_BIT)
          {
            branch(ws, B, L(loop_x_repeat),                          "11B     loop_x_repeat                   ; end of this masked input pixel");
          }
          else
          {
            TEQ(R(r_xcount), IMM(0),                                      "1TEQ     r_xcount, #0");
            branch(ws, B + EQ, L(loop_x_repeat),                         "1BEQ     loop_x_repeat                   ; end of this masked input pixel");

            DEFINE_LABEL(loop2, "Last word to plot")
            plot_some_pixels(wp, ws);
            branch(ws, B, L(loop_x_repeat),                              "1B       loop_x_repeat                   ; end of this masked input pixel");
          }

        }
        else
        {
          /* >>> There's not all that much point in this being separate from the odither case - could really
           * abandon this one and use the dithering one all the time, with tiny variants. Not done.
           */
          SUB_A(r_xcount, wp->save_xadd)
          DEFINE_LABEL(                                       loop_x_repeat, "Loop around for each source pixel")
          ADD_A(r_xcount, wp->save_xadd)
          mask_possible = fetch_pixel(wp, ws, &ws->labels.l_masked);
          translate_pixel(wp, ws); /* If we're about the discard the pixel this is in fact wasted work - we could reorganise
                                    * this whole loop to improve that situation, but it doesn't really seem worthwhile, the gain
                                    * is not enormous.
                                    */
          fetch_pixel_inc(wp, ws);
          DEFINE_LABEL(loop_put_pixel_repeat, "Loop around to repeatedly paint a source pixel");
          SUBS_A(r_xcount, wp->save_xdiv)
          branch(ws, B | MI, L(loop_x_repeat),                       "BMI     loop_x_repeat                   ; discard this pixel");
          save_pixel(wp, ws);
          save_pixel_inc(wp, ws);
          SUB(R(r_xsize), R(r_xsize), S | IMM(1),                    "SUBS    r_xsize,r_xsize,#1              ; count for each output pixel");
          branch(ws, B | NE, L(loop_put_pixel_repeat),               "BNE     loop_put_pixel_repeat");
          branch(ws, B, L(loop_x_exit),                              "B       loop_x_exit              ; skip code for masked pixels");/* moved from next if (GPS) */
        }
      }
      if (mask_possible)
      {
        DEFINE_LABEL(l_masked, "This source pixel masked out")
        if (!PLOTMASK && (wp->save_xmag % wp->save_xdiv) == 0 && ((wp->save_xmag / wp->save_xdiv) > 4) && ws->gcol == 0 && !wp->blending)
        {
#if 1
          fetch_pixel_inc(wp, ws);

          comment(ws, "calculating number of times to plot pixel");
          MOV(R(r_temp1), OP2R(R(r_xsize)),                             "@MOV     r_xtemp1, r_xsize               ; store r_xsize");
          SUB(R(r_xsize), R(r_xsize), S | OP2R(R(r_xcount)),             "@SUBS    r_xsize, r_xsize, r_xcount  ; count output pixels");
          MOV(R(r_xsize), MI | IMM(0),                                  "@MOVMI   r_xsize, #0                                          ");
          MOV(R(r_xcount), MI | OP2R(R(r_temp1)),                       "@MOVMI   r_xcount, r_temp1                                          ");

          if (!DEST_32_BIT)
          {
            MOV(R(r_temp1), S | OP2R(R(r_outshift)) | LSRI(27),           "@@MOVS    r_temp1, r_outshift, LSR #27");
            MOV(R(r_temp1), EQ | IMM(32),                              "@@MOVEQ   r_temp1, #32                    ; 0 in r_outshift => 32 bits left");
            if (!DEST_1_BIT)
              MOV(R(r_temp1), OP2R(R(r_temp1)) | LSRI(wp->Log2bpc),       "@@MOV     r_temp1, r_temp1, LSR #log2bpc");
            CMP(R(r_xcount), OP2R(R(r_temp1)),                            "@@CMP     r_xcount, r_temp1");
            branch(ws, B + LT, L(loop1),                                  "@@BLT     loop1                   ; end of this masked input pixel");
          }

          skip_current_output_words(wp, ws);

          if (DEST_32_BIT)
          {
            branch(ws, B, L(loop_x_repeat),                         "1@B     loop_x_repeat                   ; end of this masked input pixel");
          }
          else
          {
            TEQ(R(r_xcount), IMM(0),                                     "1@TEQ     r_xcount, #0");
            branch(ws, B + EQ, L(loop_x_repeat),                        "1@BEQ     loop_x_repeat                   ; end of this masked input pixel");
            DEFINE_LABEL(loop1, "Last word to skip")
            skip_some_pixels(wp, ws);

            branch(ws, B, L(loop_x_repeat),                            "1@@B       loop_x_repeat                   ; end of this masked input pixel");
          }
#else
          int loop;

          fetch_pixel_inc(wp, ws);
          for (loop = 0;loop < (wp->save_xmag / wp->save_xdiv);loop++)
          {
            save_pixel_inc(wp, ws);
            SUB(R(r_xsize), R(r_xsize), S | IMM(1),                    "SUBS    r_xsize,r_xsize,#1              ; count output pixels");
            branch(ws, B | EQ, L(loop_x_exitskip),              "BEQ     loop_x_exitskip");
          }
          branch(ws, B, L(loop_x_repeat),                       "B       loop_x_repeat                   ; end of this masked input pixel");
#endif
        }
        else
        {
          fetch_pixel_inc(wp, ws);
          DEFINE_LABEL(loop_put_masked_repeat, "Loop around to skip over dest pixels");
          SUBS_A(r_xcount, wp->save_xdiv)
          branch(ws, B | MI, L(loop_x_repeat),                       "BMI     loop_x_repeat                   ; end of this masked input pixel");
          save_pixel_inc(wp, ws);
          SUB(R(r_xsize), R(r_xsize), S | IMM(1),                    "SUBS    r_xsize,r_xsize,#1              ; count output pixels");
          branch(ws, B | NE, L(loop_put_masked_repeat),              "BNE     loop_put_masked_repeat");
        }
      }
    }
    DEFINE_LABEL(                                     loop_x_exit, "End of input pixel line")
    newline();

    if (!DEST_32_BIT)
    {
      comment(ws, "End of x loop - ensure any contents of r_outword are written out.");
      MOV(R(r_outshift), S | OP2R(R(r_outshift)) | LSRI(27),     "MOVS    r_outshift,r_outshift,LSR #27   ; get real output shift distance");
      MOV(R(r_outshift), EQ | IMM(32),                           "MOVEQ   r_outshift,#32                  "
                                                                 "; number of useful new bits in r_outword");
      if (ws->gcol == 0 && !SOURCE_MASK)
      {
        /* If setting pixels we must pick up the word we're about to
         * partially overwrite, and combine the new and old pixels.
         */
        comment(ws, "The top 32-r_outshift bits of r_outword are new pixels.");
        MOV(R(r_outword), OP2R(R(r_outword)) | LSRR(R(r_outshift)),"MOV     r_outword,r_outword,LSR r_outshift ; get new pixels in correct place");
        ins(ws, LDR(R(r_pixel), R(r_outptr)) | OFFSET(0),        "LDR     r_pixel,[r_outptr]              ; temporary use of r_pixel");
        RSB(R(r_outshift), R(r_outshift), IMM(32),               "RSB     r_outshift,r_outshift,#32");
        MOV(R(r_pixel), OP2R(R(r_pixel)) | LSRR(R(r_outshift)),  "MOV     r_pixel,r_pixel,LSR r_outshift  ; shift to clear out old pixels");
        ORR(R(r_outword), R(r_outword),
              OP2R(R(r_pixel)) | LSLR(R(r_outshift)),            "ORR     r_outword,r_outword,r_pixel, LSL r_outshift ; combine old and new");
        ins(ws, STR(R(r_outword), R(r_outptr)) | OFFSET(0),      "STR     r_outword,[r_outptr]            ; store updated word");
      }
      else
      {
        MOV(R(r_outword), OP2R(R(r_outword)) | RORR(R(r_outshift)),"MOV     r_outword,r_outword,ROR r_outshift");
        ins(ws, STR(R(r_outword), R(r_outptr)) | OFFSET(0),        "STR     r_outword,[r_outptr]");
      }
    }
  }
}

/**************************************************************************
*                                                                         *
*    Bitblit: Overall construction of the Y loop.                         *
*                                                                         *
**************************************************************************/

static void loop_y(asm_workspace *wp, workspace *ws, j_decompress_ptr cinfo)
/* Overall control of the code and outer loop */
{
#ifdef DEBUG
  char a[256];
  char saveregs[256];
#endif

  init_useful_constants(wp, ws);

  /* Setting up ordered dither, if required */
  if (ws->odither)
  {
    dprintf(("", "in dither_truecolour = %x\n", wp->dither_truecolour));
    comment(ws, "Ordered dither being used");
    /* If not 0 then ws->odither is the number of bits - 1 being truncated from 8-bit source colour values */
    if(wp->Log2bpp > 3)
    {
      /* Use the number of blue bits in the output as our guide */
      ws->odither = 7-pixelformat_info(ws->out_pixelformat)->bits[0];
    }
    else
    {
      /* dithering down to 1/2/4/8 bit. */
      if (wp->Log2bpp == 3) /* 8bpp */
      {
        if (wp->is_it_jpeg && cinfo->jpeg_color_space == JCS_GRAYSCALE)
          ws->odither = 3; /* dither assuming 4 bits of grey represented */
        else
          ws->odither = 4; /* seems to work better for colour than 3, which is what you might expect if
                            * you were assuming 4 bits of colour per gun. In other words, the tint is NOT
                            * effective enough at representing the next two bits of colour output!
                            * If the source is known to be greyscale then 3 is a better value.
                            */
      }
      else
        ws->odither = 6 - wp->Log2bpp; /* 6, 5 or 4 for 2, 4, or 16 colour output (2, 4 or 8 grey level) */
    }
    dprintf(("", "%t20.odither_eorvalue * 1:SHL:(24+%i) %t68; value to EOR into r_oditheradd each pixel", ws->odither));
  }
    dprintf(("", "out dither_truecolour = %x\n", wp->dither_truecolour));

  newline();
  ins(ws, PUSH | 0x5fff,                                    "STMDB   sp!,{r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,lr} ; save entry registers");
  newline();

  comment(ws, "Register declarations");
  ptrs_rn(wp, ws);
  xloop_rn(wp, ws);
  yloop_rn(wp, ws);

  allocate_registers(wp, ws);
  reserve_regstackframe(wp, ws);
  newline();

  comment(ws, "Load up initial values of per-pixel variables");
  begin_init_bank(wp, ws, REGFLAG_PERPIXEL);
  blendimpl_init(wp, ws);
  if((ws->regnames.r_translucency.regno != -1) && (ws->regnames.r_translucency.regno != 12))
  {
    LDR_WP(r_translucency,trns_flags2);
    if(wp->CPUFlags & CPUFlag_T2)
    {
      UBFX(R(r_translucency),R(r_translucency),4,8,0,           "UBFX    r_translucency,r_translucency,#4,#8");
    }
    else
    {
      MOV(R(r_translucency),OP2R(R(r_translucency)) | LSRI(4),  "MOV     r_translucency,r_translucency,LSR #4");
      AND(R(r_translucency),R(r_translucency),IMM(255),         "AND     r_translucency,r_translucency,#255");
    }
    RSB(R(r_translucency),R(r_translucency),IMM(1) | IMMROR(24),"RSB     r_translucency,r_translucency,#256 ; Convert translucency to alpha");
  }
  per_pixel_init(wp, ws);
  end_init_bank(wp, ws, REGFLAG_PERPIXEL);
  newline();

  comment(ws, "Load up initial values of x-loop variables");
  begin_init_bank(wp, ws, REGFLAG_XLOOP);
  fetch_pixel_init(wp, ws);
  save_pixel_init(wp, ws);
  xloop_init(wp, ws);
  end_init_bank(wp, ws, REGFLAG_XLOOP);
  newline();

  comment(ws, "Load up initial values of y-loop variables");
  begin_init_bank(wp, ws, REGFLAG_YLOOP);
  yloop_init(wp, ws);
  end_init_bank(wp, ws, REGFLAG_YLOOP);

  if (!simple_y_scale(wp, ws)) /* If not simple scaling, might not paint the first row */
    branch(ws, B, L(y_loop_enter),                          "B       y_loop_enter                    ; enter the main loop");

  /* Top of the y-loop */
  newline();
  DEFINE_LABEL(y_loop,                        "Loop around for each row")

  switch_bank(wp, ws, REGFLAG_YLOOP,REGFLAG_XLOOP);
  newline();

  /* Preserve some loop regs */
  int save_mask = 0;
  regname *r;
  FOR_EACH_REGISTER_NAME(r)
  {
    if(r->flags & REGFLAG_XLOOPVAR)
    {
      assert((r->regno & 0xff) == r->regno, ERROR_FATAL);
      save_mask |= 1<<r->regno;
    }
  }
#ifdef DEBUG
  ldm_reg_list(ws, saveregs, save_mask, FALSE);
  dsprintf((a, "STMDB   sp!,{%s}",saveregs));
#endif  
  ins(ws, PUSH | save_mask, a);
  ws->regframeoffset += countbits(save_mask)<<2;

  if (wp->is_it_jpeg)
  {
    comment(ws, "r_inptr is the source y coord for JPEG data: convert to data pointer");
    comment(ws, "fetchroutine uses r_inptr(=r0), r12. On output r_inptr=source result pointer");
    if(wp->CPUFlags & CPUFlag_BLX)
    {
      BLX(R(r_fetchroutine),                                  "BLX     r_fetchroutine                  ; get source address");
    }
    else
    {
      MOV(R(lr), OP2R(R(pc)),                                 "MOV     lr,pc                           ; remember return address from fetchroutine");
      MOV(R(pc), OP2R(R(r_fetchroutine)),                     "MOV     pc,r_fetchroutine               ; get source address");
    }
    LDR_WP_C(lr, in_x, "returned value is for base of line - add initial offset")
    if (wp->save_inlog2bpp < 5)
    {
      if (wp->save_inlog2bpp == 3)
        ADD(R(r_inptr),R(r_inptr),OP2R(R(lr)),                "ADD     r_inptr,r_inptr,lr              ; add in_x as byte offset");
      else
        ADD(R(r_inptr),R(r_inptr),OP2R(R(lr)) | LSLI(1),      "ADD     r_inptr,r_inptr,lr,LSL#1        ; add in_x as halfword offset");
      BIC(R(r_inptr),R(r_inptr),IMM(3),                     "BIC     r_inptr,r_inptr,#3              ; r_inptr is a word pointer");
    }
    else
      ADD(R(r_inptr),R(r_inptr),OP2R(R(lr)) | LSLI(2),      "ADD     r_inptr,r_inptr,lr,LSL#2        ; add in_x as word offset");
  }

  /* Generate the inner loop. */
  loop_x(wp, ws);

  /* Restore regs */
  dsprintf((a, "LDMIA   sp!,{%s}",saveregs));
  ins(ws, POP | save_mask, a);
  ws->regframeoffset -= countbits(save_mask)<<2;

  /* Suitable register 'bank' swapping. */
  switch_bank(wp, ws, REGFLAG_XLOOP,REGFLAG_YLOOP);

  if (PLOTMASK)
  {
    comment(ws,                                      "Advance ECF pointer");
    LDR_WP(r_pixel, save_ecflimit);                        /*LDR     r_pixel,save_ecflimit*/
    CMP(R(r_inptr), OP2R(R(r_pixel)),                       "CMP     r_inptr,r_pixel                 ; check for bottom of ECF");
    ADD(R(r_inptr), R(r_inptr), EQ | IMM(64),               "ADDEQ   r_inptr,r_inptr,#64             ; and if reached, reset to top");
    SUB(R(r_inptr), R(r_inptr), IMM(8),                     "SUB     r_inptr,r_inptr,#8              ; points to base of current row of ECF");
  }

  /* Control of scaling in the y direction */
  if (simple_y_scale(wp, ws))
  {
    comment(ws,                                      "1:1 scaling in y direction - each source row appears once");
    if (!PLOTMASK)
    {
      if (wp->is_it_jpeg)
        ADD(R(r_inptr), R(r_inptr), IMM(1),                 "ADD     r_inptr,r_inptr,#1               ; inc y coord of input JPEG data");
      else
        SUB(R(r_inptr), R(r_inptr), OP2R(R(r_inoffset)),    "SUB     r_inptr,r_inptr,r_inoffset");
    }
    SUB_A(r_outptr,wp->save_outoffset)                     /*SUB     r_outptr,r_outptr,#outoffset*/
    odither_inc(wp, ws, 1); /* advance to next coord */
    odither_inc(wp, ws, 0); /* ensure X coord phase alternates on alternate lines */
    if (SOURCE_TRICKYMASK || PLOTMASK)
      SUB(R(r_maskinptr), R(r_maskinptr),
          OP2R(R(r_maskinoffset)),                          "SUB     r_maskinptr,r_maskinptr,r_maskinoffset");
    SUB(R(r_ysize), R(r_ysize), S | IMM(1),                 "SUBS    r_ysize,r_ysize,#1              ; decrement output pixel size");
    branch(ws, B | GT, L(y_loop),                           "BGT     y_loop");
  }
  else
  {
    SUB(R(r_ysize), R(r_ysize), S | IMM(1),                 "SUBS    r_ysize,r_ysize,#1");
    branch(ws, B | LE, L(y_loop_exit),                      "BLE     y_loop_exit");
    SUB_A(r_outptr,wp->save_outoffset)                     /*SUB     r_outptr,r_outptr,#outoffset*/
    odither_inc(wp, ws, 1);
    odither_inc(wp, ws, 0);

    comment(ws,                                      "Control of scaling in y direction");
    DEFINE_LABEL(                                    y_loop_enter,  "Initial entry into the loop")
    SUBS_A(r_ycount, wp->save_ydiv)                        /*SUBS    r_ycount,r_ycount,#ydiv*/
    branch(ws, B | PL, L(y_loop),                           "BPL     y_loop                          ; if count>=0 then B else next source row");
    if (!PLOTMASK)
    {
      if (wp->is_it_jpeg)
        ADD(R(r_inptr), R(r_inptr), IMM(1),                 "ADD     r_inptr,r_inptr,#1              ; inc y coord of source JPEG data");
      else
        SUB(R(r_inptr), R(r_inptr), OP2R(R(r_inoffset)),    "SUB     r_inptr,r_inptr,r_inoffset      ; next source row");
    }
    if (SOURCE_TRICKYMASK || PLOTMASK)
      SUB(R(r_maskinptr), R(r_maskinptr),
          OP2R(R(r_maskinoffset)),                          "SUB     r_maskinptr,r_maskinptr,r_maskinoffset ; advance input mask pointer");
    ADD_A(r_ycount, wp->save_ydiv + wp->save_yadd)         /*ADD     r_ycount,r_ycount,#(ydiv+yadd)*/
    branch(ws, B, L(y_loop_enter),                          "B       y_loop_enter                    ; reenter the main loop");
    DEFINE_LABEL(y_loop_exit,                  "Exit from y loop")
  }
  newline();
  comment(ws, "Discard workspace, restore registers, and exit");

  discard_regstackframe(wp, ws);

  ins(ws, POP | 0x5fff,                                     "LDMIA   sp!,{r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,lr} ; restore, exit");

  MOV(R(pc), OP2R(R(lr)),         "MOV   pc, lr");
}

/**************************************************************************
*                                                                         *
*    Bitblit: The main compiler entry points.                             *
*                                                                         *
**************************************************************************/

static blitter find_or_compile_code(asm_workspace *wp, workspace *ws, j_decompress_ptr cinfo)
/* Based on the workspace variables look through existing compiled buffers for an existing match */
{
  code_buffer *p;
  int key_word;

  key_word = get_key_word(wp,ws);

#ifdef ASMjpeg
  if (wp->is_it_jpeg) key_word |= 1<<27;
  if (wp->is_it_jpeg && cinfo->jpeg_color_space == JCS_GRAYSCALE) key_word |= 1<<28;
#endif
  assert(!wp->cal_table, ERROR_FATAL); /* Never set by assembler! */
#if 0
  if (wp->cal_table)
  {
    key_word |= 1<<27;
    if (ws->cal_table_simple) key_word |= 1<<26;
    if (wp->cal_table->tablecount == 3) key_word |= 1<<27;
  }
#endif
#ifdef ASMjpeg
  if (wp->is_it_jpeg && (wp->dither_truecolour & 1)) key_word |= 1<<29;
  if (wp->is_it_jpeg && (wp->dither_truecolour & 2)) key_word |= 1<<30;
#endif
  if (  !PLOTMASK                        /* if plotting sprite */
     && wp->save_inlog2bpp >= 4          /* from true colour source */
     && (wp->dither_truecolour & 1)      /* and dithering requested */
     && (
         (wp->Log2bpp < wp->save_inlog2bpp) /* and losing resolution */
         || ((wp->Log2bpp == wp->save_inlog2bpp) /* or same resolution */
             && wp->blending                     /* and blending */
             && (wp->Log2bpp < 5)                /* and not 32bpp output */
            )
        )
     && !(wp->is_it_jpeg && (wp->dither_truecolour & 2)) /* And not JPEG error diffused dither */
     )
  {
    ws->odither = 1; /* Flag that ordered dithering is required */
    key_word |= 1<<31; /* And flag this routine as containing dither code */
  }
  dprintf(("", "Searching for compiled code for key_word=%x, scale=%i:%i,%i:%i outoffset=%x.\n",
    key_word, wp->save_xadd - wp->save_xdiv, wp->save_xdiv, wp->save_yadd, wp->save_ydiv, wp->save_outoffset));
  dprintf(("", "simple_x_scale=%s x_block_move=%s jpeg=%s calibration table=0x%x dither_truecolour=%i\n"
       , whether(simple_x_scale(wp, ws))
       , whether(x_block_move(wp, ws))
       , whether(wp->is_it_jpeg)
       , wp->cal_table
       , wp->dither_truecolour));
  FOR_EACH_BUFFER(p)
    if (  p->key_word == key_word
       && p->xadd == wp->save_xadd
       && p->xdiv == wp->save_xdiv
       && p->yadd == wp->save_yadd
       && p->ydiv == wp->save_ydiv
       && p->outoffset == wp->save_outoffset
       )
     {
       dprintf(("", "Found existing compiled code in buffer %x.\n", p));

       return (blitter)p->code;
     }
  p = &ws->buffers[ws->build_buffer];
  p->key_word = -1; /* Not set unless we complete the compilation - see below */
  p->xadd = wp->save_xadd;
  p->xdiv = wp->save_xdiv;
  p->yadd = wp->save_yadd;
  p->ydiv = wp->save_ydiv;
  p->outoffset = wp->save_outoffset;
  dprintf(("", "Compiler initialised for buffer at %x.\n", p));
  compile_buffer_init(wp, ws);

  /* Now we actually do the compile */
  loop_y(wp, ws, cinfo);

  compile_buffer_done(ws);
  p->key_word = key_word;

  /* Just did some dynamic code generation so flush the I cache */
  _swix(OS_SynchroniseCodeAreas, _IN(0) | _IN(1) | _IN(2), 1,
        (int)ws->compile_base, (int)ws->compile_base + ((BUFSIZE - 1 /* Inclusive */) * sizeof(int)));

  return (blitter)ws->compile_base;
}

blitter putscaled_compiler(asm_workspace *wp, workspace *ws, workspace *ws_end, int gcol)
/* Main entrypoint from the assembler */
{
  j_decompress_ptr cinfo = NULL;
  int                 i, j;
  blitter             result;

  /* Check that the assembler has an adequate opinion of our workspace needs. */
  dprintf(("", "wp=%x ws=%x ws_end=%x.\n", wp, ws, ws_end));
  dprintf(("", "Size of assembler workspace: %i.\n", ((char*)ws) - ((char*)wp)));
  dprintf(("", "Size of C workspace: %i. (needed: %i.)\n", ((char*)ws_end) - ((char*)ws), sizeof(workspace)));
  assert(ws_end > ws, ERROR_FATAL);
  assert((((char*)ws_end)-((char*)ws)) >= sizeof(workspace), ERROR_FATAL);
  check_workspace(ws);
#ifdef DEBUG
  dump_asm_workspace(wp);
#endif  

  ws->gcol = gcol & 7;
  if(!(gcol & 8))
  {
    ws->masktype = MaskType_None;
  }
  else if(wp->save_mode & 0x80000000)
  {
    ws->masktype = MaskType_8bpp;
  }
  else if(wp->save_mode & (15<<27))
  {
    ws->masktype = MaskType_1bpp;
  }
  else
  {
    ws->masktype = MaskType_Old;
  }
  ws->odither = FALSE; /* Set more carefully later. */
  dprintf(("", "gcol=%i (& 7 = %i)       %t32. GCOL action - 0 for plot, 1..7 for various others.\n", gcol, gcol & 7));
  dprintf(("", "masktype=%i              %t32. Mask type - 0=none, 1=old, 2=1bpp, 3=8bpp alpha.\n", ws->masktype));

#ifdef ASMjpeg
  if (wp->is_it_jpeg)
  {
    sprite_header *s = wp->save_sprite;
    int  *compress_id_word = (int*)((char*) s + s->image); /* The first word of the sprite data */
    const JOCTET *jpeg_data;
    int   jpeg_data_size, jpeg_ws_size;
    int   opt, err, xmax;
    
    assert(compress_id_word[0] == -1, ERROR_BAD_JPEG);
    dprintf(("", "This JPEG sprite was constructed by PutJPEGScaled\n"));
    jpeg_data = (const JOCTET *)compress_id_word[1];
    jpeg_data_size = compress_id_word[2];
    jpeg_ws_size = compress_id_word[3];
    check_jpeg_workspace(wp, jpeg_ws_size);
    cinfo = wp->jpeg_info_ptr;

    assert(wp->save_inlog2bpp == 5, ERROR_FATAL);          /* 32bpp source */
    assert(!SOURCE_MASK, ERROR_FATAL);                     /* no mask */
    dprintf(("", "JPEG, initial source coords are %i,%i.\n", wp->in_x, wp->in_y));
    if (((wp->save_mode >> 27) == 0) && (wp->TTRType != TTRType_ColourMap))
    {
      /* Old-style mode - make sure no translation table present. */
      wp->ColourTTR = 0;                                   /* >>>> mainly for JPEG on RO3 */
      wp->TTRType = TTRType_None;                          /* >>>> mainly for JPEG on RO3 */
    }

    /* Deduce the decompression options */
    opt = jpeg_decompressor_opts(cinfo, wp);
    
    /* Reverse scaling calculation */ 
    xmax = wp->in_x + 2 + (wp->save_xsize * wp->save_xdiv) / (wp->save_xadd - wp->save_xdiv);
    if (xmax < 0) xmax = s->width; /* set safe xmax if reverse scale calculation overflowed */

    /* Initialise the decompressor */
    err = jpeg_scan_file(cinfo, jpeg_data, jpeg_data_size, wp->in_x, xmax, -1, -1, opt);
    assert(err == 0, ERROR_BAD_JPEG);

    /* Check the decompressor agreed with proposed output options */
    if (cinfo->error_argument & (jopt_OUTBPP_8DITHER | jopt_OUTBPP_8YUV | jopt_OUTBPP_8GREY)) /* we asked for it, and we got it - 8bpp output pixels */
    {
      dprintf(("", "actually doing new shiny 8BPP plotting technique\n"));
      assert(wp->TTRType != TTRType_ColourMap, ERROR_FATAL); /* Colour mapping should have asked for 32bpp output */
      wp->save_inlog2bpp = wp->save_inlog2bpc = 3;
      wp->ColourTTR = 0;
      wp->TTRType = TTRType_None;
    }
    else
    {
      if (cinfo->error_argument & jopt_OUTBPP_16) /* we asked for it, and we got it - 16bpp output pixels */
      {
        wp->save_inlog2bpp = wp->save_inlog2bpc = 4;
      }
    }

    /* If error diffusion isn't supported, clear the flag so that we'll fall back to ordered dither */
    if(!(cinfo->options & jopt_DIFFUSE))
      wp->dither_truecolour &= ~2;
  }
#endif

  ws->out_pixelformat = compute_pixelformat(wp->ncolour,wp->modeflags,wp->Log2bpp);

#ifdef ASMjpeg
  if (wp->is_it_jpeg)
  {
    /* Work out what format we're being given
       This is deduced by following the same logic in jpeg_find_line */
    if(cinfo->options & jopt_DIFFUSE)
    {
      /* Error diffusion means we should have data in either an 8bpp or 32bpp container, and that data will be 8bpp (or lower) palette indices matching the required output format */
      ws->in_pixelformat = ws->out_pixelformat;
    }
    else if(cinfo->options & jopt_OUTBPP_8GREY)
    {
      /* 8bpp greyscale values packed in 8 bits. Should only be possible if destination is 8bpp with 0=black, 255=white. */
      assert(ws->out_pixelformat == PixelFormat_8bpp, ERROR_FATAL);
      ws->in_pixelformat = PixelFormat_8bpp;
    }
    else if(cinfo->options & jopt_GREY)
    {
      /* 24bpp greyscale values packed in 32 bits */
      ws->in_pixelformat = PixelFormat_24bpp_Grey;
    }
    else if(cinfo->options & jopt_OUTBPP_16)
    {
      /* Merged upsampling version should produce exactly what we need */
      ws->in_pixelformat = ws->out_pixelformat;

      /* 16bpp output is only enabled when JPEG is handling the dithering */
      wp->dither_truecolour &= ~3; 
    }
    else if(cinfo->options & jopt_OUTBPP_8YUV)
    {
      /* 8bpp colour in VIDC1 format. This should match the output format (i.e. screen format). */
      ws->in_pixelformat = PixelFormat_8bpp;
    }
    else
    {
      /* 24bpp colour, &BGR */
      ws->in_pixelformat = PixelFormat_32bpp;
    }
  }
  else
#endif
  {
    /* Pull apart the sprite mode word to deduce our pixel format value */
    ws->in_pixelformat = compute_pixelformat(wp->save_inncolour,wp->save_inmodeflags,wp->save_inlog2bpp);
  }

  /* If input data >=32bpp (including JPEG), assume ColourTTR index values are 15bpp
     Else assume ColourTTR index values are same as source pixels, minus alpha
     The table format is validated by preparettr, so these assumptions should be valid */
  if(wp->TTRType != TTRType_None)
  {
    if((wp->TTRType & ~TTRType_Optional) == TTRType_ColourMap)
      ws->ColourTTRFormat = pick_colourmap_format(wp,ws,ws->in_pixelformat,ws->out_pixelformat);
    else if(wp->save_inlog2bpp >= 5)
      ws->ColourTTRFormat = PixelFormat_15bpp;
    else
      ws->ColourTTRFormat = (PixelFormat) (ws->in_pixelformat & ~PixelFormat_Alpha);
  }

  BOOL use_sprite_palette = FALSE;
  ws->blendimpl = compute_blendimpl(wp,ws,&use_sprite_palette);

  blendimpl_gettables(wp,ws,use_sprite_palette);
  dprintf(("", "blendimpl=%i             %t32. Blending implementation - 0=none, 1=blendtable, 2=inversetable, 3=true, 4=blendtables.\n", ws->blendimpl));

#ifdef DEBUG
  /* Additional mask tracing */
  if (PLOTMASK)
  {
    char *p;
    int  *ecf = (int*) wp->save_ecflimit;

    dprintf(("", "Sprite data:\n"));
    p = (char*) wp->save_inptr;
    for (i = 0; i < 16; i++)
    {
      dprintf(("", "%x", p));
      for (j = 0; j < 16; j++) dprintf(("", " %2x", p[j]));
      newline();
      p -= wp->save_inoffset; /* convert from byte offset to int offset */
    }

    dprintf(("", "Mask data:\n"));
    p = (char*) (SOURCE_TRICKYMASK ? wp->save_maskinptr : (int) wp->save_inptr + wp->save_masko);
    for (i = 0; i < 16; i++)
    {
      dprintf(("", "%x", p));
      for (j = 0; j < 16; j++) dprintf(("", " %2x", p[j]));
      newline();
      p -= wp->save_inoffset;
    }

    dprintf(("", "ECF pattern:\n"));
    for (i = 0; i <= 8; i++)
      dprintf(("", "%x: %c %x %x\n", ecf + 2*i, (ecf+2*i == (int*)wp->save_ecfptr ? '>' : ' '), ecf[2*i], ecf[2*i + 1]));
  }
#endif

  if (wp->cal_table)
  {
    calibration_table *t = wp->cal_table;

    ws->cal_table_simple = t->idealblack == 0 && t->idealwhite == 0xffffff00 && t->postprocessSWI == 0;
#ifdef DEBUG
    dprintf(("", "Calibration table at 0x%x: version=%i idealblack=0x%x idealwhite=0x%x postprocessSWI=0x%x tablecount=%i simple=%s.\n"
     , t->version, t->idealblack, t->idealwhite, t->postprocessSWI, t->tablecount, whether(ws->cal_table_simple)));
    for (i = 0; i < 256; i++) dprintf(("", " %i", t->redtable[i])); newline();
    if (t->tablecount == 3) for (i = 0; i < 256; i++) dprintf(("", " %i", t->greentable[i])); newline();
    if (t->tablecount == 3) for (i = 0; i < 256; i++) dprintf(("", " %i", t->bluetable[i])); newline();
#endif
    assert(wp->BPP == 32, ERROR_FATAL);              /* only to 32 bit dest */
    assert(wp->save_inlog2bpp >= 4, ERROR_FATAL);    /* only from 16 or 32 bit source */
    assert(!SOURCE_TABLE, ERROR_FATAL);              /* there isn't room for a calibration table and another table - they share r_table */
    assert(t->version == 0, ERROR_FATAL);            /* check version number of lookup table */
  }

  /* Simplify scale factors - >>> is this useful? Helps spot 1:1 scaling I guess? */
  assert(wp->save_xadd > 0, ERROR_FATAL);
  assert(wp->save_xdiv > 0, ERROR_FATAL);
  assert(wp->save_ydiv > 0, ERROR_FATAL);
  assert(wp->save_ydiv > 0, ERROR_FATAL);
  while ((wp->save_xadd & 1) == 0 &&
         (wp->save_xdiv & 1) == 0 &&
         (wp->save_xcount & 1) == 0 &&
         (wp->save_xmag & 1) == 0)
  {
    wp->save_xadd >>= 1; wp->save_xdiv >>= 1;
    wp->save_xcount >>= 1; wp->save_xmag >>=1;
  }
  while ((wp->save_yadd & 1) == 0 &&
         (wp->save_ydiv & 1) == 0 &&
         (wp->save_ycount & 1) == 0)
  {
    wp->save_yadd >>= 1; wp->save_ydiv >>= 1;
    wp->save_ycount >>= 1;
  }

#ifdef ASMdoublepixel_bodge
  /* Precise handling of double-pixel modes by the surrounding code is still unclear to me!
   * When it enters this code bpc!=bpp can still be the case, but it seems that the actual
   * value of bpc is best ignored, it has all been frigged into the scale factors. Avoid
   * this issue for now, but note that we must set the values back afterwards because they
   * can be reused on the next sprite plot, if the source sprite mode word is the same.
   */
  i = wp->BPC;
  j = wp->save_inlog2bpc;
  wp->BPC = wp->BPP;
  wp->save_inlog2bpc = wp->save_inlog2bpp;
  result = find_or_compile_code(wp, ws, cinfo);
  wp->BPC = i;
  wp->save_inlog2bpc = j;
#else
  result = find_or_compile_code(wp, ws, cinfo);
#endif

  return result;
}
