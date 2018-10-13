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

/**************************************************************************
*                                                                         *
*    Overall construction of the X loop.                                  *
*                                                                         *
**************************************************************************/

static void sprtrans_readpixormask(asm_workspace *wp, workspace *ws)
/* Read pixel or mask from [r_inptr, r_inoffset] into r_pixel */
{
  if(wp->save_inlog2bpp < 3)
  {
    ins(ws, LDRB(R(r_pixel), R(r_inptr)) | INDEX_LSR(R(r_inoffset),3-wp->save_inlog2bpp), "LDRB    r_pixel,[r_inptr,r_inoffset,LSR #3-in_l2bpp]");
    AND(R(r_temp1),R(r_inoffset),IMM(7>>wp->save_inlog2bpp),                              "AND     r_temp1,r_inoffset,#7>>in_l2bpp");
    if(wp->save_inlog2bpp > 0)
    {
      MOV(R(r_temp1),OP2R(R(r_temp1)) | LSLI(wp->save_inlog2bpp),                         "MOV     r_temp1,r_temp1,LSL #in_l2bpp");
    }
    MOV(R(r_pixel),OP2R(R(r_pixel)) | LSRR(R(r_temp1)),                                   "MOV     r_pixel,r_pixel,LSR r_temp1");
    AND(R(r_pixel),R(r_pixel),IMM(ws->in_pixmask),                                        "AND     r_pixel,r_pixel,#in_pixmask");
  }
  else if(wp->save_inlog2bpp == 3)
  {
    ins(ws, LDRB(R(r_pixel), R(r_inptr)) | INDEX(R(r_inoffset),0),                        "LDRB    r_pixel,[r_inptr,r_inoffset]");
  }
  else if(wp->save_inlog2bpp == 4)
  {
    if(wp->CPUFlags & CPUFlag_LDRH)
    {
      MOV(R(r_pixel),OP2R(R(r_inoffset)) | LSLI(1),                                       "MOV     r_pixel,r_inoffset,LSL #1");
      ins(ws, 0x019000B0 | (R(r_pixel)<<12) | (R(r_inptr)<<16) | R(r_pixel),              "LDRH    r_pixel,[r_inptr,r_pixel]");
    }
    else if(wp->CPUFlags & CPUFlag_NoUnaligned)
    {
      ADD(R(r_temp1), R(r_inptr), OP2R(R(r_inoffset)) | LSLI(1),                          "ADD     r_temp1,r_inptr,r_inoffset,LSL #1");
      ins(ws, LDRB(R(r_pixel), R(r_temp1)) | POSTINC(1),                                  "LDRB    r_pixel,[r_temp1],#1");
      ins(ws, LDRB(R(r_temp1), R(r_temp1)),                                               "LDRB    r_temp1,[r_temp1]");
      ORR(R(r_pixel), R(r_pixel), OP2R(R(r_temp1)) | LSLI(8),                             "ORR     r_pixel,r_pixel,r_temp1,LSL #8");
    }
    else
    {
      ins(ws, LDR(R(r_pixel), R(r_inptr)) | INDEX(R(r_inoffset),1),                       "LDR     r_pixel,[r_inptr,r_inoffset,LSL #1]");
      MOV(R(r_pixel),OP2R(R(r_pixel)) | LSLI(16),                                         "MOV     r_pixel,r_pixel,LSL #16");
      MOV(R(r_pixel),OP2R(R(r_pixel)) | LSRI(16),                                         "MOV     r_pixel,r_pixel,LSR #16");
    }
  }
  else
  {
    ins(ws, LDR(R(r_pixel), R(r_inptr)) | INDEX(R(r_inoffset),2),                         "LDR     r_pixel,[r_inptr,r_inoffset,LSL #2]");
  }
}

static void sprtrans_plotaction(asm_workspace *wp, workspace *ws)
/* Combine r_outword and r_outmask to create the final screen word in r_outword */
{
  if(!TRANSMASK)
  {
    comment(ws,"GCOL action handling");
    if(!ws->gcol)
    {
      if(ws->regnames.r_outmask.regno != -1)
      {
        /* Read screen word if mask not all 1's */
        CMN(R(r_outmask),IMM(1),                              "CMN     r_outmask,#1");
        ins(ws, LDR(R(r_inoffset),R(r_outptr)) | NE,          "LDRNE   r_inoffset,[r_outptr]");
        AND(R(r_outword),R(r_outword),OP2R(R(r_outmask)),     "AND     r_outword,r_outword,r_outmask");
        BIC(R(r_inoffset),R(r_inoffset),OP2R(R(r_outmask)),   "BIC     r_inoffset,r_inoffset,r_outmask");
        EOR(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),    "EOR     r_outword,r_inoffset,r_outword");
      }
      else
      {
        /* Mask is always all 1's! */
      }
    }
    else
    {
      /* Always read screen */
      ins(ws, LDR(R(r_inoffset),R(r_outptr)),                 "LDR     r_inoffset,[r_outptr]");
      if(ws->regnames.r_outmask.regno != -1)
      {
        AND(R(r_outword),R(r_outword),OP2R(R(r_outmask)),     "AND     r_outword,r_outword,r_outmask");
      }
      switch(ws->gcol)
      {
      case 1: /* OR */
        ORR(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),    "ORR     r_outword,r_inoffset,r_outword");
        break;
      case 2: /* AND */
        if(ws->regnames.r_outmask.regno != -1)
        {
          EOR(R(r_outword),R(r_outword),OP2R(R(r_outmask)),   "EOR     r_outword,r_outword,r_outmask");
          BIC(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),  "BIC     r_outword,r_inoffset,r_outword");
        }
        else
        {
          AND(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),  "AND     r_outword,r_inoffset,r_outword");
        }
        break;
      case 3: /* EOR */
        EOR(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),    "EOR     r_outword,r_inoffset,r_outword");
        break;
      case 4: /* invert screen */
        if(ws->regnames.r_outmask.regno != -1)
        {
          EOR(R(r_outword),R(r_inoffset),OP2R(R(r_outmask)),  "EOR     r_outword,r_inoffset,r_outmask");
        }
        else
        {
          MVN(R(r_outword),OP2R(R(r_inoffset)),               "MVN     r_outword,r_inoffset");
        }
        break;
      case 5: /* Identity */
        MOV(R(r_outword),OP2R(R(r_inoffset)),                 "MOV     r_outword,r_inoffset");
        break;
      case 6: /* AND with NOT colour */
        BIC(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),    "BIC     r_outword,r_inoffset,r_outword");
        break;
      case 7: /* ORR with NOT colour */
        if(ws->regnames.r_outmask.regno != -1)
        {
          EOR(R(r_outword),R(r_outword),OP2R(R(r_outmask)),   "EOR     r_outword,r_outword,r_outmask");
        }
        else
        {
          MVN(R(r_outword),OP2R(R(r_outword)),                "MVN     r_outword,r_outword");
        }
        ORR(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),    "ORR     r_outword,r_inoffset,r_outword");
        break;
      }
    }
  }
  else
  {
    comment(ws,"Mask plot ECF handling");
    ins(ws, LDR(R(r_inoffset),R(r_outptr)),                   "LDR     r_inoffset,[r_outptr]");
    LDR_SP(r_temp1,trns_comp_ecf_ora)
    LDR_SP(r_outword,trns_comp_ecf_eor)
    if(ws->regnames.r_outmask.regno != -1)
    {
      AND(R(r_temp1),R(r_temp1),OP2R(R(r_outmask)),           "AND     r_temp1,r_temp1,r_outmask");
      AND(R(r_outword),R(r_outword),OP2R(R(r_outmask)),       "AND     r_outword,r_outword,r_outmask");
    }
    ORR(R(r_inoffset),R(r_inoffset),OP2R(R(r_temp1)),         "ORR     r_inoffset,r_inoffset,r_temp1");
    EOR(R(r_outword),R(r_inoffset),OP2R(R(r_outword)),        "EOR     r_outword,r_inoffset,r_outword");
  }
}

static void sprtrans_loop_x(asm_workspace *wp, workspace *ws)
/* Overall control of the code and outer loop */
{
  /* Top of the loop */
  init_useful_constants(wp, ws);

  /* Fixed registers supplied by the assembler wrapper */
  RN(r_xsize_spr_left, 0, REGFLAG_INPUT+REGFLAG_XLOOP,  "top 16: xsize. bottom 16: spr_left");
  RN(r_inptr, 1, REGFLAG_INPUT+REGFLAG_XLOOP+REGFLAG_CONSTANT, "sprite data pointer");
  RN(r_inoffset, 2, REGFLAG_INPUT+REGFLAG_XLOOP,        "offset (in pixels) into sprite");
  RN(r_X, 3, REGFLAG_INPUT+REGFLAG_XLOOP,               "X coord in sprite (16.16 fixed point)");
  RN(r_Y, 4, REGFLAG_INPUT+REGFLAG_XLOOP,               "Y coord in sprite (16.16 fixed point)");
  RN(r_inc_X_x, 5, REGFLAG_INPUT+REGFLAG_XLOOP+REGFLAG_CONSTANT, "sprite X increment");
  RN(r_inc_Y_x, 6, REGFLAG_INPUT+REGFLAG_XLOOP+REGFLAG_CONSTANT, "sprite Y increment");
  RN(r_byte_width, 7, REGFLAG_INPUT+REGFLAG_XLOOP+REGFLAG_CONSTANT, "byte (pixel?) width/stride of sprite rows");
  RN(r_spr_height_right, 8, REGFLAG_INPUT+REGFLAG_XLOOP+REGFLAG_CONSTANT, "top 16: spr_height. bottom 16: spr_right");
  RN(r_outptr, 9, REGFLAG_INPUT+REGFLAG_XLOOP,           "current screen ptr");
  RN(r_out_x, 12, REGFLAG_INPUT+REGFLAG_TEMPORARY,       "screen X coord at start of loop");

  /* Other registers */
  RN(r_temp1, 12, REGFLAG_TEMPORARY+REGFLAG_PERPIXEL+REGFLAG_XLOOP, "temp");
  RN(r_pixel, 14, REGFLAG_TEMPORARY+REGFLAG_PERPIXEL+REGFLAG_XLOOP, "current pixel");
  
  /* Dynamically allocated registers */
  /* HACK - manually allocating these as register allocation order means allocate_registers() will typically fail to find a free reg if it's allowed to allocate these by itself */ 
  if(!DEST_32_BIT)
  {
    RN(r_outword, 10, REGFLAG_XLOOP+REGFLAG_INPUT, "current output word"); /* Not really inputs, but initialised during input stage */
    RN(r_outmask, 11, REGFLAG_XLOOP+REGFLAG_INPUT, "current output mask");
  }
  else if(TRANSMASK)
  {
    RN(r_outword, 10, REGFLAG_XLOOP, "Output word");
  }
  else if(SOURCE_MASK)
  {
    RN(r_outword, 10, REGFLAG_XLOOP, "current output word");
  }
  else if(wp->blending)
  {
    RN(r_outword, 10, REGFLAG_XLOOP+REGFLAG_PERPIXEL, "screen pixel to blend with")
  }

  /* Work out temporary registers needed by pixel translation code */
  if(!TRANSMASK)
  {
    int need_temps;

    need_temps = translate_pixel_rn(wp,ws,0);

    /* Translation table register
       TODO - flag this as being available in stack workspace */
    if(wp->ColourTTR)
    {
      RN(r_table,-1,REGFLAG_PERPIXEL+REGFLAG_CONSTANT,"translation table");
    }
  
    blendimpl_rn(wp,ws);

    if(need_temps > 1)
      RN(r_temp2,-1,REGFLAG_TEMPORARY+REGFLAG_PERPIXEL,"temp");
  }

  allocate_registers(wp, ws);

  comment(ws,"Initialise some loop registers and exit if zero width row");
  ins(ws, PUSH | (1<<14),                     "STMFD   sp!,{r14}");
  CMP(R(r_xsize_spr_left),IMM(1) | IMMROR(16),"CMP     r_xsize_spr_left,#&10000");
  if(!DEST_32_BIT)
  {
    MOV(R(r_outmask),IMM(128) | IMMROR(8),    "MOV     r_outmask,#&80000000");
  }
  ins(ws, POP | (1<<15) | LT,                 "LDMLTFD sp!,{pc}");

  reserve_regstackframe(wp, ws);

  ws->compiled_routine_stacked = 16 + ws->regframesize;

  comment(ws,"Get address of lefthand X of screen row");

  if(wp->Log2bpp < 3)
  {
    ADD(R(r_outptr), R(r_outptr), OP2R(R(r_out_x)) | LSRI(3-wp->Log2bpp), "ADD     r_outptr,r_outptr,r_out_x, LSR #3-out_l2bpp  ; byte pointer of screen pixel");
  }
  else
  {
    ADD(R(r_outptr), R(r_outptr), OP2R(R(r_out_x)) | LSLI(wp->Log2bpp-3), "ADD     r_out_ptr,r_outptr,r_out_x, LSL #out_l2bpp-3 ; byte pointer of screen pixel");
  }
  
  if(!DEST_32_BIT)
  {
    if(wp->Log2bpp > 0)
    {
      MOV(R(r_out_x), OP2R(R(r_out_x)) | LSLI(wp->Log2bpp),            "MOV     r_out_x,r_out_x, LSL #out_l2bpp");
    }
    BIC(R(r_outptr), R(r_outptr), IMM(3),                              "BIC     r_outptr,r_outptr,#3                         ; align pointer");
    AND(R(r_out_x), R(r_out_x), IMM((31>>wp->Log2bpp)<<wp->Log2bpp),   "AND     r_out_x,r_out_x,#(31>>out_l2bpp)<<out_l2bpp  ; bit offset in screen word");
  
    if(wp->blending)
    {
      ins(ws, LDR(R(r_outword),R(r_outptr)),                           "LDR     r_outword,[r_outptr]                         ; initial screen word for blending");
    }  

    comment(ws,"Shift start words (pixel and mask) according to pixel offset");
    MOV(R(r_outmask), OP2R(R(r_outmask)) | LSRR(R(r_out_x)),           "MOV     r_outmask,r_outmask, LSR r_out_x");
    if(wp->blending)
    {
      MOV(R(r_outword), OP2R(R(r_outword)) | LSRR(R(r_out_x)),         "MOV     r_outword,r_outword, LSR r_out_x");
    }
  }

  /* Save out input regs and mark as unavailable */
  switch_bank(wp, ws, REGFLAG_INPUT, 0);

  /* Initialise registers */

  comment(ws, "Load up initial values of per-pixel variables");
  begin_init_bank(wp, ws, REGFLAG_PERPIXEL);
  if(wp->blending || ((wp->TTRType == TTRType_ColourMap) && (wp->BPP <= 8)))
  {
    LDR_SP(wp, trns_asm_workspace); /* R12 needed by blend init code */
  }
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
  if(!TRANSMASK && wp->ColourTTR)
  {
    LDR_SP(r_table,trns_comp_spr_ttr)
  }
  dither_expansion_init(wp,ws);
  end_init_bank(wp, ws, REGFLAG_PERPIXEL);

  /* Load up the X loop regs */
  switch_bank(wp, ws, 0, REGFLAG_XLOOP);

  /* Main loop */
  DEFINE_LABEL(loop_x_enter,          "Main loop start");

  comment(ws,"Get sprite pointers for current pixel");

  MOV(R(r_inoffset),OP2R(R(r_Y)) | ASRI(16) | S,             "MOVS    r_inoffset,r_Y,ASR #16                       ; sprite Y coord");
  MOV(R(r_temp1),OP2R(R(r_spr_height_right)) | LSRI(16),     "MOV     r_temp1,r_spr_height_right,LSR #16           ; get sprite height");
  MOV(R(r_inoffset),IMM(0) | MI,                             "MOVMI   r_inoffset,#0                                ; clamp Y to 0");
  CMP(R(r_temp1),OP2R(R(r_Y)) | ASRI(16),                    "CMP     r_temp1,r_Y,ASR #16                          ; Y beyond sprite height?");
  if(SOURCE_TRICKYMASK)
  {
    LDR_SP(r_pixel,trns_comp_spr_mask_width)
  }
  SUB(R(r_inoffset),R(r_temp1),IMM(1) | LE,                  "SUBLE   r_inoffset,r_temp1,#1                        ; clamp Y to sprite height");
  if(SOURCE_TRICKYMASK)
  {
    MUL(R(r_pixel),R(r_inoffset),R(r_pixel),0,               "MUL     r_pixel,r_inoffset,r_pixel                   ; offset of 1bpp/8bpp mask row");
  }
  CMP(R(r_X),OP2R(R(r_xsize_spr_left)) | LSLI(16),           "CMP     r_X,r_xsize_spr_left,LSL #16                 ; X off left edge of sprite?");
  MOV(R(r_temp1),OP2R(R(r_X)),                               "MOV     r_temp1,r_X                                  ; sprite X coord");
  if(!TRANSMASK || !SOURCE_TRICKYMASK) /* Sprite offset not needed if we're only reading the 1bpp/8bpp mask */
  {
    MUL(R(r_inoffset),R(r_byte_width),R(r_inoffset),0,       "MUL     r_inoffset,r_byte_width,r_inoffset           ; offset of sprite row");
  }
  MOV(R(r_temp1),OP2R(R(r_xsize_spr_left)) | LSLI(16) | LT,  "MOVLT   r_temp1,r_xsize_spr_left,LSL #16             ; clamp X to sprite left edge");
  CMP(R(r_X),OP2R(R(r_spr_height_right)) | LSLI(16),         "CMP     r_X,r_spr_height_right,LSL #16               ; X off right edge of sprite?");
  MOV(R(r_temp1),OP2R(R(r_spr_height_right)) | LSLI(16) | GE,"MOVGE   r_temp1,r_spr_height_right,LSL #16");
  SUB(R(r_temp1),R(r_temp1),IMM(1) | GE,                     "SUBGE   r_temp1,r_temp1,#1                           ; clamp X to sprite right");
  if(SOURCE_TRICKYMASK)
  {
    ADD(R(r_pixel),R(r_pixel),OP2R(R(r_temp1)) | LSRI(16),   "ADD     r_pixel,r_pixel,r_temp1,LSR #16              ; final mask offset");
  }
  if(!TRANSMASK || !SOURCE_TRICKYMASK)
  {
    ADD(R(r_inoffset),R(r_inoffset),OP2R(R(r_temp1)) | LSRI(16),"ADD     r_inoffset,r_inoffset,r_temp1,LSR #16        ; final sprite offset");
  }
  
  if(!TRANSMASK)
  {
    if(SOURCE_TRICKYMASK)
    {
      /* Preserve mask offset */
      STR_SP(r_pixel,trns_comp_mask_offset)
    }
    
    comment(ws,"Load sprite pixel");
    sprtrans_readpixormask(wp,ws);
    comment(ws,"r_pixel is now a source pixel");

    /* Translate */
    translate_pixel(wp,ws);

    if(!DEST_32_BIT)
    {
      comment(ws,"Merge into output word");
      MOV(R(r_outword),OP2R(R(r_outword)) | LSRI(1<<wp->Log2bpp),                 "MOV     r_outword,r_outword,LSR #1<<out_l2bpp");
      MOV(R(r_outmask),OP2R(R(r_outmask)) | LSRI(1<<wp->Log2bpp) | S,             "MOVS    r_outmask,r_outmask,LSR #1<<out_l2bpp");
      ORR(R(r_outword),R(r_outword),OP2R(R(r_pixel)) | LSLI(32-(1<<wp->Log2bpp)), "ORR     r_outword,r_outword,r_pixel,LSL #32-(1<<out_l2bpp)");
    }
    else if(SOURCE_MASK || wp->blending)
    {
      /* Protect r_pixel being overwritten by mask read */
      MOV(R(r_outword),OP2R(R(r_pixel)),                                          "MOV     r_outword,r_pixel");
    }
    else
    {
      /* Make r_outword == r_pixel to simplify GCOL handling */
      RN(r_outword,ws->regnames.r_pixel.regno,REGFLAG_USED,"Output word (== r_pixel)");
    }
  }
  else if(!DEST_32_BIT)
  {
    MOV(R(r_outword),OP2R(R(r_outword)) | LSRI(1<<wp->Log2bpp),                   "MOV     r_outword,r_outword,LSR #1<<out_l2bpp");
    MOV(R(r_outmask),OP2R(R(r_outmask)) | LSRI(1<<wp->Log2bpp) | S,               "MOVS    r_outmask,r_outmask,LSR #1<<out_l2bpp");
  }

  /* If we have a mask, and GCOL action says we should use it, do so */
  if(SOURCE_MASK)
  {
    int mask_l2bpp;
    if(SOURCE_BPPMASK)
    {
      comment(ws,"Read 1bpp mask");
      if(!TRANSMASK)
      {
        /* Recover mask offset stashed earlier */
        LDR_SP(r_pixel,trns_comp_mask_offset)
      }
      LDR_SP(r_temp1,trns_comp_mask_base)
      ins(ws, LDRB(R(r_inoffset),R(r_temp1)) | INDEX_LSR(R(r_pixel),3),            "LDRB    r_inoffset,[r_temp1,r_pixel,LSR #3]");
      AND(R(r_pixel),R(r_pixel),IMM(7),                                            "AND     r_pixel,r_pixel,#7");
      MOV(R(r_pixel),OP2R(R(r_inoffset)) | LSRR(R(r_pixel)),                       "MOV     r_pixel,r_inoffset,LSR r_pixel");
      mask_l2bpp = 0;
    }
    else if(SOURCE_ALPHAMASK)
    {
      comment(ws,"Read 8bpp mask");
      if(!TRANSMASK)
      {
        /* Recover mask offset stashed earlier */
        LDR_SP(r_pixel,trns_comp_mask_offset)
      }
      LDR_SP(r_temp1,trns_comp_mask_base)
      ins(ws, LDRB(R(r_pixel),R(r_temp1)) | INDEX(R(r_pixel),0),                "LDRB    r_pixel,[r_temp1,r_pixel]");
      mask_l2bpp = 3;
    }
    else
    {
      comment(ws,"Read old style mask");
      LDR_SP(r_pixel,trns_comp_spr_masko) /* TODO keep resident if possible (e.g. TRANSMASK) */
      ADD(R(r_inoffset),R(r_inoffset),OP2R(R(r_pixel)),                            "ADD     r_inoffset,r_inoffset,r_pixel");
      sprtrans_readpixormask(wp,ws);
      mask_l2bpp = wp->save_inlog2bpp;
    }

    /* Merge into r_outmask */
    if(!DEST_32_BIT)
    {
      comment(ws,"Merge into output mask");
      if((mask_l2bpp == wp->Log2bpp) && !SOURCE_ALPHAMASK)
      {
        ORR(R(r_outmask),R(r_outmask),OP2R(R(r_pixel)) | LSLI(32-(1<<wp->Log2bpp)), "ORR     r_outmask,r_outmask,r_pixel,LSL #32-(1<<out_l2bpp)");
      }
      else
      {
        /* BPP mask has garbage in upper bits, other masks have been masked correctly */
        if(SOURCE_BPPMASK)
        {
          TST(R(r_pixel),IMM(1),                                                    "TST     r_pixel,#1");
        }
        else
        {
          TEQ(R(r_pixel),IMM(0),                                                    "TEQ     r_pixel,#0");
        }
        if(wp->Log2bpp < 4)
          ORR(R(r_outmask),R(r_outmask),IMM(255 & ~(255 >> wp->BPP)) | IMMROR(8) | NE, "ORRNE   r_outmask,r_outmask,#&FF000000 :AND: :NOT: (&FF000000 >> out_bpp)");
        else if(wp->CPUFlags & CPUFlag_T2)
        {
          MOVT(R(r_outmask),IMM16(0xffff) | NE,                                     "MOVTNE  r_outmask,#&ffff");
        }
        else
        {
          ORR(R(r_outmask),R(r_outmask),IMM(255) | IMMROR(8) | NE,                  "ORRNE   r_outmask,r_outmask,#&FF000000");
          ORR(R(r_outmask),R(r_outmask),IMM(255) | IMMROR(16) | NE,                 "ORRNE   r_outmask,r_outmask,#&00FF0000");
        }
      }
    }
    else
    {
      /* Make r_outmask == r_pixel to simplify plot action handling */
      RN(r_outmask,ws->regnames.r_pixel.regno,REGFLAG_USED,"Output mask (== r_pixel)");
      if(SOURCE_BPPMASK)
      {
        AND(R(r_pixel),R(r_pixel),IMM(1) | S,                                       "ANDS    r_pixel,r_pixel,#1");
      }
      else
      {
        TEQ(R(r_pixel),IMM(0),                                                      "TEQ     r_pixel,#0");
      }
      MVN(R(r_pixel),IMM(0) | NE,                                                   "MVNNE   r_pixel,#0");
    }
  }
  else if(!DEST_32_BIT)
  {
    /* No mask, just set the relevant bits in r_outmask */
    if(wp->Log2bpp < 4)
      ORR(R(r_outmask),R(r_outmask),IMM(255 & ~(255 >> wp->BPP)) | IMMROR(8),       "ORR     r_outmask,r_outmask,#&FF000000 :AND: :NOT: (&FF000000 >> out_bpp)");
    else if(wp->CPUFlags & CPUFlag_T2)
    {
      MOVT(R(r_outmask), IMM16(0xffff), "MOVT    r_outmask,#&ffff");
    }
    else
    {
      ORR(R(r_outmask),R(r_outmask),IMM(255) | IMMROR(8),                         "ORR     r_outmask,r_outmask,#&FF000000");
      ORR(R(r_outmask),R(r_outmask),IMM(255) | IMMROR(16),                        "ORR     r_outmask,r_outmask,#&00FF0000");
    }
  }

  /* Skip plot action if not at end of word */
  if(!DEST_32_BIT)
  {
    branch(ws, B | CC, L(loop_x_exit), "BCC     loop_x_exit");
  }

  sprtrans_plotaction(wp,ws);

  comment(ws,"Store screen pixel");          
  ins(ws, STR(R(r_outword),R(r_outptr)) | POSTINC(4),         "STR     r_outword,[r_outptr],#4");
  if(!DEST_32_BIT)
  {
    if(wp->blending)
    {
      /* Load word of screen pixels for blending, but only if more pixels remain (avoids potential read off end of screen memory) */
      CMP(R(r_xsize_spr_left),IMM(2) | IMMROR(16),            "CMP     r_xsize_spr_left,#&20000");
    }
    MOV(R(r_outmask),IMM(128) | IMMROR(8),                    "MOV     r_outmask,#&80000000");
    if(wp->blending)
    {
      ins(ws, LDR(R(r_outword),R(r_outptr)) | GE,             "LDRGE   r_outword,[r_outptr] ; Load next screen word for blending");
    }  
  }

  DEFINE_LABEL(loop_x_exit,"Main loop end");
  comment(ws,"Move to next pixel");
  SUB(R(r_xsize_spr_left),R(r_xsize_spr_left),IMM(1) | IMMROR(16),  "SUB     r_xsize_spr_left,r_xsize_spr_left,#&10000");
  ADD(R(r_X),R(r_X),OP2R(R(r_inc_X_x)),                             "ADD     r_X,r_X,r_inc_X_x");
  CMP(R(r_xsize_spr_left),IMM(1) | IMMROR(16),                      "CMP     r_xsize_spr_left,#&10000");
  ADD(R(r_Y),R(r_Y),OP2R(R(r_inc_Y_x)),                             "ADD     r_Y,r_Y,r_inc_Y_y");
  branch(ws, B | GE, L(loop_x_enter),                               "BGE     loop_x_enter");

  comment(ws,"Finished row");
  if(!DEST_32_BIT)
  {
    CMP(R(r_outmask),IMM(128)|IMMROR(8),                            "CMP     r_outmask,#&80000000");
    discard_regstackframe(wp, ws);
    ins(ws, POP | (1<<15) | EQ,                                     "LDMEQFD sp!,{pc}");
    /* Loop until we have a full word of data */
    DEFINE_LABEL(x_misaligned,"Misaligned end word loop");
    MOV(R(r_outmask),OP2R(R(r_outmask)) | LSRI(1<<wp->Log2bpp) | S, "MOVS    r_outmask,r_outmask,LSR #1<<out_l2bpp ; (2)");
    MOV(R(r_outword),OP2R(R(r_outword)) | LSRI(1<<wp->Log2bpp),     "MOV     r_outword,r_outword,LSR #1<<out_l2bpp ; (2)");
    branch(ws, B | CC, L(x_misaligned),                             "BCC     x_misaligned");
    /* Perform plot action */
    sprtrans_plotaction(wp,ws);
    comment(ws,"Store last word");
    ins(ws, STR(R(r_outword),R(r_outptr)),                          "STR     r_outword,[r_outptr]");
  }
  else
  {
    discard_regstackframe(wp, ws);
  }
  ins(ws, POP | (1<<15),                                            "LDM     sp!,{pc}");
}

/**************************************************************************
*                                                                         *
*    The main compiler entry points.                                      *
*                                                                         *
**************************************************************************/

static blitter sprtrans_find_or_compile_code(asm_workspace *wp, workspace *ws)
{
  code_buffer *p;
  int key_word;

  key_word = get_key_word(wp,ws);

  dprintf(("", "Searching for compiled code for key_word=%x\n", key_word));
  FOR_EACH_BUFFER(p)
    if (  p->key_word == key_word
       )
     {
       dprintf(("", "Found existing compiled code in buffer %x.\n", p));

       return (blitter)p->code;
     }
  p = &ws->buffers[ws->build_buffer];
  p->key_word = -1; /* Not set unless we complete the compilation - see below */
  dprintf(("", "Compiler initialised for buffer at %x.\n", p));
  compile_buffer_init(wp, ws);

  /* Now we actually do the compile */
  sprtrans_loop_x(wp, ws);

  compile_buffer_done(ws);
  p->key_word = key_word;

  /* Just did some dynamic code generation so flush the I cache */
  _swix(OS_SynchroniseCodeAreas, _IN(0) | _IN(1) | _IN(2), 1,
        (int)ws->compile_base, (int)ws->compile_base + ((BUFSIZE - 1 /* Inclusive */) * sizeof(int)));

  return (blitter)ws->compile_base;
}

blitter sprtrans_compiler(asm_workspace *wp, workspace *ws, workspace *ws_end, int gcol)
/* Main entrypoint from the assembler */
{
  blitter             result;
  int                 i,j;

  dprintf(("", "wp=%x ws=%x ws_end=%x.\n", wp, ws, ws_end));
  dprintf(("", "Size of assembler workspace: %i.\n", ((char*)ws) - ((char*)wp)));
  dprintf(("", "Size of C workspace: %i.\n", ((char*)ws_end) - ((char*)ws)));
  assert(ws_end > ws, ERROR_FATAL);
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
  ws->odither = FALSE;  
  dprintf(("", "gcol=%i (& 7 = %i)       %t32. GCOL action - 0 for plot, 1..7 for various others.\n", gcol, gcol & 7));
  dprintf(("", "masktype=%i              %t32. Mask type - 0=none, 1=old, 2=1bpp, 3=8bpp alpha.\n", ws->masktype));

  /* JPEG not supported yet */
  assert(!wp->is_it_jpeg, ERROR_FATAL);

  ws->out_pixelformat = compute_pixelformat(wp->ncolour,wp->modeflags,wp->Log2bpp);
  
  ws->in_pixelformat = compute_pixelformat(wp->save_inncolour,wp->save_inmodeflags,wp->save_inlog2bpp);

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

  /* Calibration tables not supported */
  assert(!wp->cal_table, ERROR_FATAL);

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
  result = sprtrans_find_or_compile_code(wp, ws);
  wp->BPC = i;
  wp->save_inlog2bpc = j;

  return result;
}
