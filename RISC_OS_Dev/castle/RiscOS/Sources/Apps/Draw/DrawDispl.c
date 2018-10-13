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
/* -> c.DrawDispl
 *
 * Screen painting routines for Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.13
 * History: 0.10 - 12 June 1989 - headers added. Old code weeded
 *                                upgraded to use drawmod, colourtran
 *          0.11 - 14 July 1989 - merged some code
 *          0.12 - 15 Aug  1989 - handle origins differently
 *          0.13 - 05 Sept 1989 - do_object uses offsets (safer than
 *                                addresses)
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <math.h>
#include <swis.h>

#include "os.h"
#include "bbc.h"
#include "colourtran.h"
#include "drawmod.h"
#include "font.h"
#include "msgs.h"
#include "werr.h"
#include "wimp.h"
#include "wimpt.h"
#include "jpeg.h"
#include "dbox.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawAction.h"
#include "DrawDispl.h"
#include "DrawEdit.h"
#include "DrawEnter.h"
#include "DrawGrid.h"
#include "DrawObject.h"
#include "DrawPrint.h"
#include "DrawSelect.h"
#include "DrawTextC.h"

#ifndef USETAGBBOX
draw_bboxtyp *draw_displ_bbox (draw_objptr hdrptr)

{ ftracef1 ("draw_displ_bbox (0x%X)\n", hdrptr);
  if (hdrptr.objhdrp->tag == draw_OBJTAGG)
    hdrptr.bytep += sizeof (draw_taggstr);
  ftracef1 ("answer is 0x%X\n", &hdrptr.objhdrp->bbox);
  return &hdrptr.objhdrp->bbox;
}
#endif

/*(r/c)lpo is last point omitted    */
/*(r/c)fpo is first point omitted   */
/*(r/c)beo is both ends omitted     */
/*(r) is dotted - pattern restarted, */
/*(c) is dotted - pattern continued, */
/*     otherwise solid                */

#if 1
  /* static void lpo_draw (int A, int B)
  { bbc_plot (bbc_SolidExFinal | bbc_DrawAbsFore, A, B); }
  */

  static void fpo_draw (int A, int B)
  { bbc_plot (bbc_SolidExInit  | bbc_DrawAbsFore, A, B); }

  static void beo_draw (int A, int B)
  { bbc_plot (bbc_SolidExBoth  | bbc_DrawAbsFore, A, B); }

  /* static void r_draw (int A, int B)
  { bbc_plot (bbc_DottedBoth    | bbc_DrawAbsFore, A, B); }
  */

  static void rlpo_draw (int A, int B)
  { bbc_plot (bbc_DottedExFinal | bbc_DrawAbsFore, A, B); }

  /* static void cfpo_draw (int A, int B)
  { bbc_plot (bbc_DottedExInit  | bbc_DrawAbsFore, A, B); }
  */

  /* static void cbeo_draw (int A, int B)
  { bbc_plot (bbc_DottedExBoth  | bbc_DrawAbsFore, A, B); }
  */

  static BOOL visible (draw_objptr A, draw_bboxtyp *clip)

  { return draw_box_overlap (draw_displ_bbox (A), clip);
  }
#else
  #define lpo_draw(A, B)  bbc_plot (bbc_SolidExFinal | bbc_DrawAbsFore, (A), (B))
  #define fpo_draw(A, B)  bbc_plot (bbc_SolidExInit  | bbc_DrawAbsFore, (A), (B))
  #define beo_draw(A, B)  bbc_plot (bbc_SolidExBoth  | bbc_DrawAbsFore, (A), (B))

  #define r_draw(A, B)    bbc_plot (bbc_DottedBoth    | bbc_DrawAbsFore, (A), (B))
  #define rlpo_draw(A, B) bbc_plot (bbc_DottedExFinal | bbc_DrawAbsFore, (A), (B))
  #define cfpo_draw(A, B) bbc_plot (bbc_DottedExInit  | bbc_DrawAbsFore, (A), (B))
  #define cbeo_draw(A, B) bbc_plot (bbc_DottedExBoth  | bbc_DrawAbsFore, (A), (B))

  #define visible(A, clip)  ((A).objhdrp->bbox.x0<= (clip)->x1 &&   \
                             (A).objhdrp->bbox.y0<= (clip)->y1 &&   \
                             (A).objhdrp->bbox.x1>= (clip)->x0 &&   \
                             (A).objhdrp->bbox.y1>= (clip)->y0)
#endif

/* ScaleP - for path coordinates ('stroke' takes graphics coords << 8)    */
/* ScaleW - for path stroke width ('stroke' takes graphics coords << 8)   */
/* ScaleT - for text position coords ('font_paint' takes graphics coords) */
/* ScaleS - for sprite position coords ('put_sprite takes graphics coords)*/
/* ScaleB - for bounding box coords ('bbc_draw' takes graphics coords)    */
/* ScaleF - T.B.A                                                         */
/* ScaleM - for printmargin coordinates ('bbc_draw' takes graphics coords)*/
/* ScaleZ - for text size (dBc -> oscoords)                               */

#if 1
  /* static int scaleP (int A, int B)
  { return ((A) + (int) (draw_displ_scalefactor*(double) (B))); } */

  /* static int scaleW (int A)
  { return ((int) (draw_displ_scalefactor*(double) (A))); } */

  static int scaleZ (int A)
  { return (((int) (draw_displ_scalefactor*(double) (A))) >> 8); }

  static int scaleT (int A, int B)
  { return (((A) + (int) (draw_displ_scalefactor*(double) (B))) >> 8); }

  #define scaleS(A,B) scaleT (A,B)
  #define scaleB(A,B) scaleT (A,B)

  static int scaleF (int A)
  { return ((int) (draw_displ_scalefactor*(double) (A)/40)); }

  #define scaleM(A,B) scaleT (A,B)
#else
  #define scaleP(A,B) ((A) + (int) (draw_displ_scalefactor*(double) (B)))
  #define scaleW(A) ((int) (draw_displ_scalefactor*(double) (A)))
  #define scaleZ(A) (((int) (draw_displ_scalefactor*(double) (A))) >> 8)
  #define scaleT(A,B) (((A) + (int) (draw_displ_scalefactor*(double) (B))) >> 8)
  #define scaleS(A,B) (((A) + (int) (draw_displ_scalefactor*(double) (B))) >> 8)
  #define scaleB(A,B) (((A) + (int) (draw_displ_scalefactor*(double) (B))) >> 8)
  #define scaleF(A) ((int) (draw_displ_scalefactor*(double) (A)/40))
  #define scaleM(A,B) (((A) + (int) (draw_displ_scalefactor*(double) (B))) >> 8)
#endif

/* Sets a given wimp colour; includes tint setting for 256-colour modes
   Plotcol is the wimp colour, bgcolour is either the colour of the object
   to plot over (used for construction lines), or -1 for the window bg
   (only used in EOR case, ie action = 3). */

static void displ_gcol (int action, int plotcol, int bgcolour)

{ int displcolour;

  ftracef3 ("displ_gcol: action: %d; plotcol: %d; "
      "bgcolour: %d\n", action, plotcol, bgcolour);
  #if (HOLLOWBLOB)
    if (draw_currentmode.ncolour == 1)
    { plotcol = plotcol == 0? 0: 7;
      bbc_gcol (action, plotcol);
      return;
    }
  #else
    if (draw_currentmode.ncolour == 1)
    { plotcol = plotcol == 0? 0: 7;
      if (bgcolour != -1) bgcolour = bgcolour == 0? 0: 7;
    }
  #endif

  if (action == 3)
    displcolour =
      draw_palette.c
      [ bgcolour == -1?
          Window_WORKBG:
          bgcolour
      ].bytes.gcol ^ draw_palette.c [plotcol].bytes.gcol;
  else
    displcolour = draw_palette.c [plotcol].bytes.gcol;

  switch ((unsigned) draw_currentmode.ncolour)
  { case 63u: case 0xFFFu: case 0xFFFFu: case 0xFFFFFFFFu:
      ftracef4 ("GCOL %d, %d\nTINT %d, %d\n",
          action, displcolour >> 2, 2, displcolour & 0xff);
      bbc_gcol (action, displcolour >> 2);
      bbc_tint (2, displcolour & 0xff);
    break;

    case 1u: case 3u: case 15u: case 255u:
      ftracef2 ("OS_SetColour %d, %d\n", action, displcolour);
      os_swi2 (OS_SetColour, action, displcolour);
    break;
  }

  ftracef0 ("displ_gcol]\n");
}

/* GCol (action,colour) where colour is BBGGRRxx (foreground colour) */
static os_error *draw_displ_settruecol (int action, draw_coltyp colour)

{ int dummy;
  wimp_paletteword pal_colour;

  ftracef2 ("draw_displ_settruecol (action 0x%X, colour 0x%X)\n", action, colour);
  pal_colour.word = colour;

  return colourtran_setGCOL (pal_colour, 1 << 8 /*use ECF if possible*/,
      action, &dummy);
}

#if (0)
  /* Nobody uses this */
  static os_error *displ_returntruecol (int action, draw_coltyp colour,
      int *gcol)
  { wimp_paletteword pal_colour;
    pal_colour.word = colour;

    ftracef0 ("displ_returntruecol\n");
    return colourtran_returnGCOL (pal_colour, gcol);
  }
#endif

#if 0 /*FIX RP-0161 JRC 21 Oct '91 Noone uses this either*/
/* GCol (action,colour) where colour is BBGGRRxx (background colour) */
os_error *draw_displ_settruecolBG (int action, draw_coltyp colour)

{ int dummy;
  wimp_paletteword pal_colour;

  ftracef0 ("draw_displ_settruecolBG\n");
  pal_colour.word = colour;
  #if 1
    return NULL;
  #else
    return colourtran_setGCOL (pal_colour,
        128 | 1 << 8 /*use ECF if possible*/, action, &dummy);
  #endif
}
#endif

#if USE_TRUE_COLOURS
static os_error *draw_displ_settruefontcol (font fonth, draw_coltyp foregrd,
                                           draw_coltyp backgrd)

{ char paint [11];
  os_error *error;
  int i = 0;

  ftracef0 ("draw_displ_settruefontcol\n");
  /*Use genuine true font colours. JRC 17 Jan 1990*/
  paint [i++] = 26;
  paint [i++] = fonth;
  paint [i++] = 19;
  paint [i++] = backgrd >> 8;
  paint [i++] = backgrd >> 16;
  paint [i++] = backgrd >> 24;
  paint [i++] = foregrd >> 8;
  paint [i++] = foregrd >> 16;
  paint [i++] = foregrd >> 24;
  paint [i++] = 14;
  paint [i++] = '\0';

  ftracef3 ("draw_displ_settruefontcol: "
    "calling font_paint to set handle 0x%X colour to 0x%08X, 0x%08X\n",
    fonth, foregrd, backgrd);
  error = font_paint (paint, 0, 0, 0); /*Doesn't matter where.*/
  ftracef1 ("... error returned was 0x%08X\n", error);

  return error;
}
#endif

static os_error *draw_displ_setfontcol (font fonth, draw_coltyp foregrd,
                                           draw_coltyp backgrd)

{ int offset = 14;

  ftracef0 ("draw_displ_setfontcol\n");
  return colourtran_setfontcolours (&fonth, (wimp_paletteword *)&backgrd,
                                           (wimp_paletteword *)&foregrd,
                                           &offset);
}

/* ---------------------------------------------------------------------- */

double draw_displ_scalefactor;

/* ------------------------------------------------------------------- */

/* Fill and/or outline a path */
void draw_displ_unpackpathstyle (draw_objptr hdrptr,
                                drawmod_capjoinspec *jspecp)

{ draw_pathstyle style = hdrptr.pathp->pathstyle;

  ftracef0 ("draw_displ_unpackpathstyle\n");
  jspecp->join           = style.s.join;
  jspecp->leadcap        = style.s.endcap;
  jspecp->trailcap       = style.s.startcap;
  jspecp->reserved8      = 0;
  jspecp->mitrelimit     = 0xA0000; /* Mitre limit=10.0 (postscript default) */
  jspecp->lead_tricap_w  =
  jspecp->trail_tricap_w = style.s.tricapwid << 4;
  jspecp->lead_tricap_h  =
  jspecp->trail_tricap_h = style.s.tricaphei << 4;
}

static void set_transmat (int *matrix, draw_objcoord *org)

{ ftracef0 ("set_transmat\n");
  matrix[0] = matrix[3] = (int) (draw_displ_scalefactor*65536);
  matrix[1] = matrix[2] = 0;
  matrix[4] = org->x;
  matrix[5] = org->y;
}

static os_error *do_objpath (draw_objptr objhdr, draw_objcoord *org)

{ os_error *error;
  drawmod_transmat matrix;
  drawmod_filltype fillstyle;
  draw_coltyp      fillcol = objhdr.pathp->fillcolour;
  draw_coltyp      linecol = objhdr.pathp->pathcolour;

  ftracef0 ("do_objpath\n");
  set_transmat (&matrix[0], org);

  /* Fill the path if not transparent */
  if (fillcol != TRANSPARENT)
  { draw_pathstyle style = objhdr.pathp->pathstyle;

    if ((error = draw_displ_settruecol (0, fillcol)) != NULL)
      return error;

    fillstyle = (drawmod_filltype) (fill_FBint | fill_FNonbint |
                        (style.s.windrule? fill_WEvenodd: fill_WNonzero));
    #if HIGH_RES_LINES
      if ((error = drawmod_fill (draw_obj_pathstart (objhdr), fillstyle, &matrix,
                         (int) (200/MAXZOOMFACTOR))) != NULL)
      return error;
    #else
      if ((error = drawmod_fill (draw_obj_pathstart (objhdr), fillstyle, &matrix,
                         (int) (200/draw_displ_scalefactor))) != NULL)
      return error;
    #endif
  }

  /* Stroke path if not transparent */
  if (linecol != TRANSPARENT)
  { drawmod_line linestyle;

    if ((error = draw_displ_settruecol (0, linecol)) != NULL)
      return error;

    #if HIGH_RES_LINES
      linestyle.flatness   = (int) (200/MAXZOOMFACTOR);
    #else
      linestyle.flatness   = (int) (200/draw_displ_scalefactor);
    #endif
    linestyle.thickness    = objhdr.pathp->pathwidth;
    linestyle.dash_pattern = (drawmod_dashhdr *) draw_obj_dashstart (objhdr);
    draw_displ_unpackpathstyle (objhdr, &linestyle.spec);

    fillstyle = (drawmod_filltype) (fill_FBint | fill_FNonbint | fill_FBext);
    if ((error = drawmod_stroke (draw_obj_pathstart (objhdr), fillstyle, &matrix,
                             &linestyle)) != NULL)
      return error;
  }

  return NULL;
}

/* ------------------------------------------------------------------- */
/* Draw a line of text */

/*If the font can't be found (ie 'font disc not present' or font name came
  from a fontlist object), use the system font. This seems kinder than
  aborting, or poping up an error box. Any other errors are passed back.*/

/*Either system font specified, or fancy font could not be found, so
  render in the system font (ie scaled VDU5 characters)*/
static os_error *do_objtext_system (draw_objptr hdrptr, draw_objcoord *org,
    BOOL skeleton)

{ os_error *error;
  int
    textcol = hdrptr.textp->textcolour,
    xsize = (int) ((draw_displ_scalefactor*hdrptr.textp->fsizex)/
                      draw_currentmode.pixsizex),
    ysize = (int) ((draw_displ_scalefactor*hdrptr.textp->fsizey)/
                      draw_currentmode.pixsizey);
  /* xsize,ysize in pixels. pixsizex,pixsizey in dBase coords per pixel */

  ftracef0 ("do_objtext_system\n");
  skeleton = skeleton;
  if ((error = draw_displ_settruecol (0, textcol)) != NULL)
    return error;

  /* assume char base line is row 7 (of 8) */
  ftracef0 ("do_objtext_system: calling bbc_move\n");
  if ((error = bbc_move (scaleT (org->x, hdrptr.textp->coord.x),
      scaleT (org->y, hdrptr.textp->coord.y + 7*hdrptr.textp->fsizey/8))) !=
      NULL)
    return error;

  ftracef0 ("do_objtext_system: draw_displ_setVDU5charsize\n");
  if ((error = draw_displ_setVDU5charsize (xsize, ysize, xsize, ysize)) !=
      NULL)
    return error;

  ftracef0 ("do_objtext_system: calling bbc_stringprint\n");
  if ((error = bbc_stringprint (hdrptr.textp->text)) != NULL)
    return error;

  return NULL;
}

#if TRACE
  #define TRACE_FONT \
    { font_state state; \
      \
      wimpt_complain (font_current (&state)); \
      ftracef4 \
          ("font_current: handle 0x%X, back 0x%X, fore 0x%X, offset %d\n", \
          state.f, state.back_colour, state.fore_colour, state.offset); \
    }
#else
  #define TRACE_FONT
#endif

static os_error *do_objtext (draw_objptr hdrptr, draw_objcoord *org,
    BOOL skeleton)

{ os_error *error;
  int textcol = hdrptr.textp->textcolour,
      backgrd = hdrptr.textp->background; /*a hint (kludge) to font munger*/
  int blend = ((backgrd == TRANSPARENT) && draw_fonts_blend) ? font_BLENDED : 0;

  ftracef1 ("do_objtext: painting \"%s\"\n", hdrptr.textp->text);
  if (textcol == TRANSPARENT)
    return NULL; /* nothing to plot */

  if (hdrptr.textp->textstyle.fontref != NULL)
  { font fonth;
    int scaled_x = scaleF (hdrptr.textp->fsizex),
      scaled_y = scaleF (hdrptr.textp->fsizey);

    if (scaled_x < 16 || scaled_y < 16)
    { ftracef0 ("text too small - using system font\n");
      return do_objtext_system (hdrptr, org, skeleton);
    }

    ftracef3 ("do_objtext: calling font_find (\"%s\", %d, %d)\n",
        draw_fontcat.name [hdrptr.textp->textstyle.fontref],
        scaled_x, scaled_y);
    if ((error = font_find
        (draw_fontcat.name [hdrptr.textp->textstyle.fontref],
        scaled_x, scaled_y, 0, 0, &fonth)) != NULL)
    { ftracef1 ("do_objtext: *ERROR* \"%s\"\n", error->errmess);

      ftracef0 ("do_objtext: calling do_objtext_system\n");
      return do_objtext_system (hdrptr, org, skeleton);
    }

    ftracef4 ("do_objtext: calling font_setfont: "
        "handle 0x%X; name: %s in (%d, %d) point\n",
        (int) fonth,
        draw_fontcat.name [hdrptr.textp->textstyle.fontref],
        hdrptr.textp->fsizex/640,hdrptr.textp->fsizey/640);
    if ((error = font_setfont (fonth)) != NULL)
    { ftracef1 ("do_objtext: *ERROR* \"%s\"\n", error->errmess);

      ftracef0 ("do_objtext: calling font_lose\n");
      (void) font_lose (fonth);

      ftracef0 ("do_objtext: calling do_objtext_system\n");
      return do_objtext_system (hdrptr, org, skeleton);
    }
    TRACE_FONT

    ftracef0 ("do_objtext: calling "
        "draw_displ_settruefontcol\n");
    #if USE_TRUE_COLOURS
      if ((error = draw_displ_settruefontcol (fonth, textcol, backgrd))
          != NULL)
      { /*Couldn't use true colours - try close approximations*/
        ftracef1 ("do_objtext: *ERROR* \"%s\"\n",
            error->errmess);
        TRACE_FONT

        ftracef0 ("do_objtext: "
            "calling draw_displ_setfontcol\n");
        if ((error = draw_displ_setfontcol (fonth, textcol, backgrd))
            != NULL)
        { ftracef1 ("do_objtext: *ERROR* \"%s\"\n",
              error->errmess);

          ftracef0 ("do_objtext: calling font_lose\n");
          (void) font_lose (fonth);

          ftracef0 ("do_objtext: calling do_objtext_system\n");
          return do_objtext_system (hdrptr, org, skeleton);
        }
      }
    #else
      if ((error = draw_displ_setfontcol (fonth, textcol, backgrd))
          != NULL)
      { ftracef1 ("do_objtext: *ERROR* \"%s\"\n",
            error->errmess);

        ftracef0 ("do_objtext: calling font_lose\n");
        (void) font_lose (fonth);

        ftracef0 ("do_objtext: calling do_objtext_system\n");
        return do_objtext_system (hdrptr, org, skeleton);
      }
    #endif
    TRACE_FONT

    #if TRACE
      ftracef
      ( __FILE__, __LINE__,
        "do_objtext: calling font_paint (\"%s\", "
            "0x%X, %d, %d)\n"
        "... coords are (%d, %d) offset from origin (%d, %d) and scaled\n",
        hdrptr.textp->text,
        font_OSCOORDS | blend,
        scaleT (org->x, hdrptr.textp->coord.x),
        scaleT (org->y, hdrptr.textp->coord.y),
        hdrptr.textp->coord.x, hdrptr.textp->coord.y,
        org->x, org->y
      );
    #endif
    if ((error = font_paint (hdrptr.textp->text,
        font_OSCOORDS | blend,
        scaleT (org->x, hdrptr.textp->coord.x),
        scaleT (org->y, hdrptr.textp->coord.y))) != NULL)
    { ftracef1 ("do_objtext: *ERROR* \"%s\"\n", error->errmess);
      TRACE_FONT

      ftracef1 ("do_objtext: calling font_lose (%d)\n", fonth);
      (void) font_lose (fonth);

      ftracef0 ("do_objtext: calling do_objtext_system\n");
      return do_objtext_system (hdrptr, org, skeleton);
    }
    TRACE_FONT

    ftracef0 ("do_objtext: calling font_lose\n");
    if ((error = font_lose (fonth)) != NULL)
    { ftracef1 ("do_objtext: *ERROR* \"%s\"\n", error->errmess);
      TRACE_FONT
      return error;
    }
  }
  else
  { /*Really system font.*/
    ftracef0 ("do_objtext: calling do_objtext_system\n");

    if ((error = do_objtext_system (hdrptr, org, skeleton)) != NULL)
    { ftracef1 ("do_objtext_system: *ERROR* \"%s\"\n",
          error->errmess);
      TRACE_FONT
      return error;
    }
  }

  TRACE_FONT
  return NULL;
}

/*********************************************
 * Call the SWI to build a translation table *
 *********************************************/

/* Overflow check code used for sprites */
static void overflow_check (int *mag, int *div, int size)

{ double result = (double)*mag*size;

  ftracef0 ("overflow_check\n");
  if (result > INT_MAX)
  { /* Find the largest acceptable scaling */
    double max_mag  = (double)INT_MAX / size;

    /* Reduce the mag and div factors to this */
    *div = (int) (((double)*div / (*mag))*max_mag);
    *mag = (int)max_mag;
  }
}

static os_error *do_objsprite (draw_objptr hdrptr, draw_objcoord *org)

{ os_error *err;
  sprite_id id;
  sprite_info info;
  sprite_factors factors;
  int pixtrans[256];             /* pixel conversion tab                */
  int ne;
  os_regset reg_set;

  ftracef1 ("do_objsprite: \"%.12s\"\n", hdrptr.spritep->sprite.name);

  id.tag    = sprite_id_addr;
  id.s.addr = &hdrptr.spritep->sprite;

  ne = (hdrptr.spritep->sprite.image - sizeof (sprite_header))/
      (2*sizeof (int));

  if (ne != 0)
  { reg_set.r [0] = 0x100 /*source mode*/;
    reg_set.r [1] = (int) &hdrptr.spritep->sprite /*source palette*/;
    reg_set.r [2] = -1 /*destination mode*/;
    reg_set.r [3] = -1 /*destination palette*/;
    reg_set.r [4] = (int) pixtrans /*pixel translation table*/;
    reg_set.r [5] = 1 << 0 /*R1 is a sprite pointer*/ |
        1 << 1 /*use current palette if sprite has none*/ |
        1 << 4 /*return wide entries*/;

    #if TRACE
      ftracef (__FILE__, __LINE__,
          "SWI ColourTrans_GenerateTable, %d, %d, %d, %d, %d, %d\n",
          reg_set.r [0], reg_set.r [1], reg_set.r [2],
          reg_set.r [3], reg_set.r [4], reg_set.r [5]);
    #endif
    if ((err = os_swix (ColourTrans_GenerateTable, &reg_set)) != NULL)
     return err;
  }
  else
  { /*Sprite has no palette*/
    wimp_palettestr palette_str;
    int lb_bpp;

    if ((lb_bpp = bbc_modevar (hdrptr.spritep->sprite.mode, bbc_Log2BPP))
        == -1)
      return NULL;

    if (lb_bpp < 3)
    { ftracef0 ("read WIMP's palette\n");
      if ((err = wimp_readpalette (&palette_str)) != NULL)
        return err;
    }

    /*Fix MED-4786: use the right entries for palettes < 16 entries. J R C
       6th Mar 1995*/
    switch (lb_bpp)
    {  case 0:
          palette_str.c [1] = palette_str.c [7];
       break;

       case 1:
          palette_str.c [1] = palette_str.c [2];
          palette_str.c [2] = palette_str.c [4];
          palette_str.c [3] = palette_str.c [7];
       break;
    }

    reg_set.r [0] = hdrptr.spritep->sprite.mode /*source mode*/;
    reg_set.r [1] = lb_bpp < 3? (int) &palette_str.c [0]:
                       -1 /*source palette*/;
                       /*was NULL. J R C 5th Oct 1993**/
    reg_set.r [2] = -1 /*destination mode*/;
    reg_set.r [3] = -1 /*destination palette*/;
    reg_set.r [4] = (int) pixtrans /*pixel translation table*/;
    reg_set.r [5] = 1 << 4 /*return wide entries*/;

    #if TRACE
      ftracef (__FILE__, __LINE__,
          "SWI ColourTrans_GenerateTable, %d, %d, %d, %d, %d, %d\n",
          reg_set.r [0], reg_set.r [1], reg_set.r [2],
          reg_set.r [3], reg_set.r [4], reg_set.r [5]);
    #endif
    if ((err = os_swix (ColourTrans_GenerateTable, &reg_set)) != NULL)
      return err;
  }

  sprite_readsize (UNUSED_SA, &id, &info);

  factors.xmag = (int) (((double) hdrptr.spritep->bbox.x1 -
                (double) hdrptr.spritep->bbox.x0) *
                       draw_displ_scalefactor);
  factors.xdiv = draw_currentmode.pixsizex*info.width;
  factors.ymag = (int) (((double) hdrptr.spritep->bbox.y1 -
               (double) hdrptr.spritep->bbox.y0)*draw_displ_scalefactor);
  factors.ydiv = draw_currentmode.pixsizey*info.height;

  /*For large sprites, it is possible for the xmag factor to lead to an
     overflow. So we do a floating point multiplication to check if this is
     the case, and if so, reduce the factors*/
  overflow_check (&factors.xmag, &factors.xdiv, info.width);
  overflow_check (&factors.ymag, &factors.ydiv, info.height);

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "pixtrans: {%d, %d, %d, %d, %d, %d, %d, %d, "
        "%d, %d, %d, %d, %d, %d, %d, %d, ...}\n",
        pixtrans [0], pixtrans [1], pixtrans [2], pixtrans [3],
        pixtrans [4], pixtrans [5], pixtrans [6], pixtrans [7],
        pixtrans [8], pixtrans [9], pixtrans [10], pixtrans [11],
        pixtrans [12], pixtrans [13], pixtrans [14], pixtrans [15]);
  #endif

  return sprite_put_scaled
     (UNUSED_SA,           /* this op needs no area */
     &id,                  /* address of sprite  */
     8 | 1 << 5 | 1 << 6,  /* GcolAction=STORE thro mask, wide entries, dithered*/
     scaleS (org->x, hdrptr.spritep->bbox.x0),
     scaleS (org->y, hdrptr.spritep->bbox.y0),
     &factors,
     (sprite_pixtrans *) pixtrans);
}

static os_error *do_objtrfmsprite (draw_objptr hdrptr, draw_objcoord *org)

  /*Fix med-5342: use wide ttab.*/

{ os_error *err;
  sprite_id id;
  int pixtrans [256];            /* pixel conversion tab                */
  sprite_transmat mat;
  int i, ne;
  os_regset reg_set;

  ftracef1 ("do_objtrfmsprite: name: \"%.12s\"\n",
      hdrptr.trfmspritep->sprite.name);

  id.tag    = sprite_id_addr;
  id.s.addr = &hdrptr.trfmspritep->sprite;

  ne = (hdrptr.trfmspritep->sprite.image - sizeof (sprite_header))/
      (2*sizeof (int));

  if (ne != 0)
  { reg_set.r [0] = 0x100 /*source mode*/;
    reg_set.r [1] = (int) &hdrptr.trfmspritep->sprite /*source palette*/;
    reg_set.r [2] = -1 /*destination mode*/;
    reg_set.r [3] = -1 /*destination palette*/;
    reg_set.r [4] = (int) pixtrans /*pixel translation table*/;
    reg_set.r [5] = 1 << 0 /*R1 is a sprite pointer*/ |
        1 << 1 /*use current palette if sprite has none*/ |
        1 << 4 /*return wide entries*/;

    #if TRACE
      ftracef (__FILE__, __LINE__,
          "SWI ColourTrans_GenerateTable, %d, %d, %d, %d, %d, %d\n",
          reg_set.r [0], reg_set.r [1], reg_set.r [2],
          reg_set.r [3], reg_set.r [4], reg_set.r [5]);
    #endif
    if ((err = os_swix (ColourTrans_GenerateTable, &reg_set)) != NULL)
      return err;
  }
  else
  { /*Sprite has no palette*/
    wimp_palettestr palette_str;
    int lb_bpp;

    if ((lb_bpp = bbc_modevar (hdrptr.trfmspritep->sprite.mode, bbc_Log2BPP))
        == -1)
      return NULL;

    if (lb_bpp < 3)
    { ftracef0 ("read WIMP's palette\n");
      if ((err = wimp_readpalette (&palette_str)) != NULL)
        return err;
    }

    /*Fix MED-4786: use the right entries for palettes < 16 entries. J R C
       6th Mar 1995*/
    switch (lb_bpp)
    {  case 0:
          palette_str.c [1] = palette_str.c [7];
       break;

       case 1:
          palette_str.c [1] = palette_str.c [2];
          palette_str.c [2] = palette_str.c [4];
          palette_str.c [3] = palette_str.c [7];
       break;
    }

    reg_set.r [0] = hdrptr.trfmspritep->sprite.mode /*source mode*/;
    reg_set.r [1] = lb_bpp < 3? (int) &palette_str.c [0]: -1 /*source palette*/;
                       /*was NULL. J R C 13th Jun 1995*/
    reg_set.r [2] = -1 /*destination mode*/;
    reg_set.r [3] = -1 /*destination palette*/;
    reg_set.r [4] = (int) pixtrans /*pixel translation table*/;
    reg_set.r [5] = 1 << 4 /*return wide entries*/;

    #if TRACE
      ftracef (__FILE__, __LINE__,
          "SWI ColourTrans_GenerateTable, %d, %d, %d, %d, %d, %d\n",
          reg_set.r [0], reg_set.r [1], reg_set.r [2],
          reg_set.r [3], reg_set.r [4], reg_set.r [5]);
    #endif
    if ((err = os_swix (ColourTrans_GenerateTable, &reg_set)) != NULL)
      return err;
  }

  for (i = 0; i < 6; i++) mat [i] = hdrptr.trfmspritep->trfm [i];

  /*take scale factor into account*/
  for (i = 0; i < 6; i++) mat [i] = (int) (mat [i]*draw_displ_scalefactor);

  mat [4] += org->x; /*take screen position into account*/
  mat [5] += org->y;

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "put sprite trfm ((%d, %d)^T, (%d, %d)^T, (%d, %d)^T)\n",
        mat [0], mat [1], mat [2], mat [3], mat [4], mat [5]);

    ftracef (__FILE__, __LINE__,
        "pixtrans: {%d, %d, %d, %d, %d, %d, %d, %d, "
        "%d, %d, %d, %d, %d, %d, %d, %d, ...}\n",
        pixtrans [0], pixtrans [1], pixtrans [2], pixtrans [3],
        pixtrans [4], pixtrans [5], pixtrans [6], pixtrans [7],
        pixtrans [8], pixtrans [9], pixtrans [10], pixtrans [11],
        pixtrans [12], pixtrans [13], pixtrans [14], pixtrans [15]);
  #endif

  return sprite_put_trans      /*osspriteop_put_sprite_transformed*/
      (UNUSED_SA,              /*this op needs no spArea*/
      &id,                     /*pass address of sprite*/
      8 | 1 << 5 | 1 << 6,     /*GcolAction=STORE thro mask, wide entries, dithered*/
      NULL,                    /*no box - put whole sprite*/
      (sprite_transmat *) mat, /*transformation matrix*/
      (sprite_pixtrans *) pixtrans);
}

#if TRACE
/*Same routine for trfmtext. Assume char base line is row 7 (of 8).*/
static os_error *do_objtrfmtext_system (draw_objptr hdrptr,
    draw_objcoord *org)

{ os_error *error;
  sprite_area *area;
  sprite_ptr ptr;
  sprite_id id;
  int size_of_area, len, i, *trfm;
  sprite_state saved_state;
  drawmod_transmat trans_mat;
  double tm [6];
  ftracef2 ("do_objtrfmtext_system: plotting \"%s\", mode %d\n",
      hdrptr.trfmtextp->text, draw_currentmode.mode);

  ftracef0 ("do_objtrfmtext_system: allocate memory\n");
  len = strlen (hdrptr.trfmtextp->text);
  size_of_area = 10*1024; /*!!!*/
  if ((area = Alloc (size_of_area)) == NULL)
  { ftracef1 ("-> out of memory\n");
    return draw_make_oserror ("DrawNR");
  }

  ftracef0 ("do_objtrfmtext_system: initialise sprite area\n");
  sprite_area_initialise (area, size_of_area);

  ftracef0 ("do_objtrfmtext_system: create sprite\n");
  if ((error = sprite_create_rp (area, "t", (sprite_palflag) 0, 8*len, 8,
      draw_currentmode.mode, &ptr)) != NULL)
  { free (area);
    ftracef1 ("-> \"%s\"\n", error->errmess);
    return error;
  }

  id.tag = sprite_id_addr;
  id.s.addr = ptr;

  ftracef0 ("do_objtrfmtext_system: create mask, redirect\n");
  if
  ((error = sprite_create_mask (area, &id)) != NULL ||
    (error = sprite_outputtosprite (area, &id, NULL, &saved_state)) != NULL
  )
  { free (area);
    ftracef1 ("-> \"%s\"\n", error->errmess);
    return error;
  }

  ftracef0 ("do_objtrfmtext_system: set colour, move, print\n");
  if
  ((error = draw_displ_settruecol (0, hdrptr.trfmtextp->textcolour)) !=
        NULL ||
    (error = bbc_move (0, 8)) != NULL ||
    (error = bbc_stringprint (hdrptr.trfmtextp->text)) != NULL
  )
  { (void) sprite_restorestate (saved_state);
    free (area);
    ftracef1 ("-> \"%s\"\n", error->errmess);
    return error;
  }

  ftracef0 ("do_objtrfmtext_system: switch back to screen, "
      "redirect to mask\n");
  if
  ((error = sprite_restorestate (saved_state)) != NULL ||
    (error = sprite_outputtomask (area, &id, NULL, &saved_state)) != NULL
  )
  { free (area);
    ftracef1 ("-> \"%s\"\n", error->errmess);
    return error;
  }

  ftracef0 ("do_objtrfmtext_system: set colour, move, print "
      "for mask\n");
  if
  ( bbc_modevar (-1, bbc_Log2BPP) == 3?
      ((ftracef0 ("bbc_gcol (0, 0)\n"), error = bbc_gcol (0, 0)) != NULL ||
        (ftracef0 ("bbc_tint (2, 0)\n"), error = bbc_tint (2, 0)) != NULL
      ):
      (ftracef0 ("bbc_gcol (0, 0)\n"), error = bbc_gcol (0, 0)) != NULL ||
    (ftracef0 ("bbc_move (0, 8)\n"), error = bbc_move (0, 8)) != NULL ||
    ( ftracef1 ("bbc_stringprint (\"%s\")\n", hdrptr.trfmtextp->text),
      error = bbc_stringprint (hdrptr.trfmtextp->text)
    ) != NULL
  )
  { (void) sprite_restorestate (saved_state);
    free (area);
    ftracef1 ("-> \"%s\"\n", error->errmess);
    return error;
  }

  ftracef0 ("do_objtrfmtext_system: switch back to screen\n");
  if ((error = sprite_restorestate (saved_state)) != NULL)
  { free (area);
    ftracef1 ("-> \"%s\"\n", error->errmess);
    return error;
  }

  #if TRACE
    /*Look at the sprite we've made*/
    (void) sprite_area_save (area, "ram:$.trfmtext");
  #endif

  /*Now we've made the sprite, plot it.*/
  ftracef0 ("do_objtrfmtext_system: make matrix\n");
  trfm = &hdrptr.trfmtextp->trfm [0];
  #if 0
    trans_mat [0] =
        (int) ((double) hdrptr.trfmtextp->fsizex*trfm [0]*
        draw_displ_scalefactor/ (8.0*draw_currentmode.pixsizex));
    trans_mat [1] =
        (int) ((double) hdrptr.trfmtextp->fsizex*trfm [1]*
        draw_displ_scalefactor/ (8.0*draw_currentmode.pixsizex));
    trans_mat [2] =
        (int) ((double) hdrptr.trfmtextp->fsizey*trfm [2]*
        draw_displ_scalefactor/ (8.0*draw_currentmode.pixsizey));
    trans_mat [3] =
        (int) ((double) hdrptr.trfmtextp->fsizey*trfm [3]*
        draw_displ_scalefactor/ (8.0*draw_currentmode.pixsizey));
    trans_mat [4] = (int) (((double) hdrptr.trfmtextp->coord.x +
        trfm [4])* draw_displ_scalefactor + org->x);
    trans_mat [5] = (int) (((double) hdrptr.trfmtextp->coord.y -
        draw_currentmode.pixsizey/8.0 + trfm [5])*draw_displ_scalefactor +
        org->y);
  #else
    tm [0] = (1.0/4096.0)*hdrptr.trfmtextp->fsizex*trfm [0];
    tm [1] = (1.0/4096.0)*hdrptr.trfmtextp->fsizex*trfm [1];
    tm [2] = (1.0/4096.0)*hdrptr.trfmtextp->fsizey*trfm [2];
    tm [3] = (1.0/4096.0)*hdrptr.trfmtextp->fsizey*trfm [3];
    tm [4] =- (1.0/4096.0)*hdrptr.trfmtextp->fsizey*trfm [2]*draw_currentmode.pixsizey/65536.0 + trfm [4] + hdrptr.trfmtextp->coord.x;
    tm [5] =- (1.0/4096.0)*hdrptr.trfmtextp->fsizey*trfm [3]*draw_currentmode.pixsizey/65536.0 + trfm [5] + hdrptr.trfmtextp->coord.y;
  #endif

  ftracef3 ("matrix (%10.2f %10.2f %10.2f)\n",
      tm [0]/65536.0, tm [2]/65536.0, tm [4]/256.0);
  ftracef3 ("       (%10.2f %10.2f %10.2f)\n",
      tm [1]/65536.0, tm [3]/65536.0, tm [5]/256.0);

  ftracef0 ("do_objtrfmtext_system: apply scale\n");
  for (i = 0; i < 5; i++) tm [i] *= draw_displ_scalefactor;

  ftracef0 ("do_objtrfmtext_system: apply translation\n");
  tm [4] += org->x, tm [5] += org->y;

  ftracef0 ("do_objtrfmtext_system: fix\n");
  for (i = 0; i < 6; i++) trans_mat [i] = (int) tm [i];

  ftracef0 ("do_objtrfmtext_system: put sprite transformed\n");

  ftracef3 ("   matrix (%10d %10d %10d)\n",
      trans_mat [0],
      trans_mat [2],
      trans_mat [4]);
  ftracef3 ("          (%10d %10d %10d)\n",
      trans_mat [1],
      trans_mat [3],
      trans_mat [5]);

  ftracef3 ("        = (%10.2f %10.2f %10.2f)\n",
      trans_mat [0]/65536.0,
      trans_mat [2]/65536.0,
      trans_mat [4]/256.0);
  ftracef3 ("          (%10.2f %10.2f %10.2f)\n",
      trans_mat [1]/65536.0,
      trans_mat [3]/65536.0,
      trans_mat [5]/256.0);

  if ((error = sprite_put_trans (area, &id, 8, NULL,
      (sprite_transmat *) &trans_mat, NULL)) != NULL)
  { free (area);
    ftracef1 ("-> \"%s\"\n", error->errmess);
    return error;
  }

  free (area);
  return NULL;
}
#endif

static os_error *do_objtrfmtext (draw_objptr hdrptr, draw_objcoord *org)

{ int textcol = hdrptr.trfmtextp->textcolour,
      backgrd = hdrptr.trfmtextp->background;
  int blend = ((backgrd == TRANSPARENT) && draw_fonts_blend) ? font_BLENDED : 0;
  os_error *error;
  os_regset reg_set;
  font fonth;
  int scaled_x = scaleF (hdrptr.trfmtextp->fsizex),
    scaled_y = scaleF (hdrptr.trfmtextp->fsizey);

  ftracef1 ("do_objtrfmtext: painting \"%s\"\n", hdrptr.trfmtextp->text);
  if (textcol == TRANSPARENT)
    return NULL; /* nothing to plot */

  if (hdrptr.trfmtextp->textstyle.fontref == NULL) /*shouldn't ever happen*/
    return
      #if TRACE
        do_objtrfmtext_system (hdrptr, org);
      #else
        NULL;
      #endif

  if (scaled_x < 16 || scaled_y < 16)
  { ftracef0 ("trfmtext too small - throwing it on the floor\n");
    return NULL;
  }

  ftracef0 ("do_objtrfmtext: calling font_find\n");
  if ((error = font_find
      (draw_fontcat.name [hdrptr.trfmtextp->textstyle.fontref],
      scaled_x, scaled_y, 0, 0, &fonth)) != NULL)
  { ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n", error->errmess);
    return error;
  }

  ftracef4 ("do_objtrfmtext: calling font_setfont: "
      "handle 0x%X; name: %s in (%d, %d) point\n",
      (int) fonth,
      draw_fontcat.name [hdrptr.trfmtextp->textstyle.fontref],
      hdrptr.trfmtextp->fsizex/640,hdrptr.trfmtextp->fsizey/640);
  if ((error = font_setfont (fonth)) != NULL)
  { ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n",
        error->errmess);

    ftracef0 ("do_objtrfmtext: calling font_lose\n");
    (void) font_lose (fonth);
    return error;
  }
  TRACE_FONT

  ftracef0 ("do_objtrfmtext: calling draw_displ_settruefontcol\n");
  /*Can't use true colours for the moment. JRC 12 Apr 1990*/
  #if USE_TRUE_COLOURS
    if ((error = draw_displ_settruefontcol (fonth, textcol, backgrd))
        != NULL)
    { /*Couldn't use true colours - try close approximations*/
      ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n",
          error->errmess);
      TRACE_FONT

      ftracef0 ("do_objtrfmtext: "
          "calling draw_displ_setfontcol\n");
      if ((error = draw_displ_setfontcol (fonth, textcol, backgrd))
          != NULL)
      { ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n",
            error->errmess);

        ftracef0 ("do_objtrfmtext: calling font_lose\n");
        (void) font_lose (fonth);
        return error;
      }
    }
  #else
    if ((error = draw_displ_setfontcol (fonth, textcol, backgrd))
        != NULL)
    { ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n",
          error->errmess);

      ftracef0 ("do_objtrfmtext: calling font_lose\n");
      (void) font_lose (fonth);
      return error;
    }
  #endif
  TRACE_FONT

  #if TRACE
    ftracef
    ( __FILE__, __LINE__,
      "do_objtrfmtext: calling font_paint (\"%s\", "
          "0x%X, %d, %d)\n"
      "... coords are (%d, %d) offset from origin (%d, %d) and scaled\n",
      hdrptr.trfmtextp->text,
      font_OSCOORDS | blend,
      scaleT (org->x, hdrptr.trfmtextp->coord.x),
      scaleT (org->y, hdrptr.trfmtextp->coord.y),
      hdrptr.trfmtextp->coord.x, hdrptr.trfmtextp->coord.y,
      org->x, org->y
    );
  #endif

  reg_set.r [2] =
      font_OSCOORDS |
      1 << 6 /*use trfm*/ | blend |
      hdrptr.trfmtextp->flags.kerned << 9 |
      hdrptr.trfmtextp->flags.direction << 10;
  reg_set.r [3] = scaleT (org->x, hdrptr.trfmtextp->coord.x);
  reg_set.r [4] = scaleT (org->y, hdrptr.trfmtextp->coord.y);
  reg_set.r [6] = (int) &hdrptr.trfmtextp->trfm;

  if (hdrptr.trfmtextp->flags.underline)
  { os_regset reg_set1;
    char *buf;
    int position, thickness;
    struct
    { struct {short x0, y0, x1, y1;} bbox;
      short x_offset, y_oofset;
      short italic_correction;
      signed char underline_position;
      unsigned char underline_thickness;
      short cap_height, xheight, ascender, descender;
      int reserved;
    }
    *misc_data;

    /*Get the buffer size needed for the underlining info*/
    memset (&reg_set1, 0, sizeof reg_set1);
    reg_set1.r [0] = fonth;
    if ((error = os_swix (Font_ReadFontMetrics, &reg_set1)) != NULL)
    { (void) font_lose (fonth);
      return error;
    }

    /*Make a buffer big enough*/
    if ((misc_data = Alloc (reg_set1.r [4])) == NULL)
    { (void) font_lose (fonth);
      return draw_make_oserror ("DrawNR");
    }

    /*Fill in the buffer*/
    memset (&reg_set1, 0, sizeof reg_set1);
    reg_set1.r [0] = fonth;
    reg_set1.r [4] = (int) misc_data;
    if ((error = os_swix (Font_ReadFontMetrics, &reg_set1)) != NULL)
    { free (misc_data);
      (void) font_lose (fonth);
      return error;
    }

    position = misc_data->underline_position;
    thickness = misc_data->underline_thickness;
    free (misc_data);

    ftracef2 ("do_objtrfmtext: underline info is (%d, %d)\n",
        position, thickness);

    /*Make a string for Font_Paint*/
    if ((buf = Alloc (3 + strlen (hdrptr.trfmtextp->text) + 1))
        == NULL)
    { (void) font_lose (fonth);
      return draw_make_oserror ("DrawNR");
    }

    /*Fill in the string*/
    sprintf (buf, "%c%c%c%s", 25, position != 0? position: -25,
        thickness != 0? thickness: 15, hdrptr.trfmtextp->text);

    /*Paint the underline sequence*/
    ftracef1 ("do_objtrfmtext: painting string \"%s\"\n", buf);
    reg_set.r [1] = (int) buf;
    if ((error = os_swix (Font_Paint, &reg_set)) != NULL)
    { /*On error in paint, try again without the trfm matrix.*/
      ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n", error->errmess);
      TRACE_FONT

      reg_set.r [2] &= ~(1 << 6); /*turn off bit 6*/
      error = os_swix (Font_Paint, &reg_set);
    }

    if (error != NULL)
    { free (buf);
      (void) font_lose (fonth);
      return error;
    }

    free (buf);
  }
  else
  { reg_set.r [1] = (int) hdrptr.trfmtextp->text /*text to print*/;
    if ((error = os_swix (Font_Paint, &reg_set)) != NULL)
    { ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n", error->errmess);
      TRACE_FONT

      reg_set.r [2] &= ~(1 << 6); /*turn off bit 6*/
      error = os_swix (Font_Paint, &reg_set);
      TRACE_FONT
    }

    if (error != NULL)
    { ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n",
          error->errmess);
      TRACE_FONT

      ftracef1 ("do_objtrfmtext: calling font_lose (%d)\n", fonth);
      (void) font_lose (fonth);
      return error;
    }
    TRACE_FONT
  }

  ftracef0 ("do_objtrfmtext: calling font_lose\n");
  if ((error = font_lose (fonth)) != NULL)
  { ftracef1 ("do_objtrfmtext: *ERROR* \"%s\"\n",
        error->errmess);
    TRACE_FONT
    return error;
  }

  TRACE_FONT
  return NULL;
}

static os_error *do_objjpeg (draw_objptr hdrptr, draw_objcoord *org)

{ sprite_transmat mat;
  jpeg_id         jid;

  jid.s.image.addr = &hdrptr.jpegp->image;
  jid.s.image.size = hdrptr.jpegp->len;
  jid.tag = jpeg_id_addr;
  ftracef0 ("do_objjpeg\n");

  mat [0] = (int) (draw_displ_scalefactor*hdrptr.jpegp->trans_mat [0]);
  mat [1] = (int) (draw_displ_scalefactor*hdrptr.jpegp->trans_mat [1]);
  mat [2] = (int) (draw_displ_scalefactor*hdrptr.jpegp->trans_mat [2]);
  mat [3] = (int) (draw_displ_scalefactor*hdrptr.jpegp->trans_mat [3]);
  mat [4] = (int) (draw_displ_scalefactor*hdrptr.jpegp->trans_mat [4]) + org->x;
  mat [5] = (int) (draw_displ_scalefactor*hdrptr.jpegp->trans_mat [5]) + org->y;
  ftracef3 ("matrix 0x(% .8X % .8X % .8X)\n", mat [0], mat [2], mat [4]);
  ftracef3 ("       0x(% .8X % .8X % .8X)\n", mat [1], mat [3], mat [5]);

  return jpeg_put_trans (&jid, jpeg_PUT_DITHER_ENABLE, NULL, &mat);
}

/* ------------------------------------------------------------------- */
/*                                                                     */
/* Draw the object 'hdrptr-> ' whose origin is (orgx,orgy)             */
/*                                                                     */
/*  The object is:                                                     */
/*    a PATH                                                           */
/*    a line of TEXT                                                   */
/*    a GROUPing of objects                                            */
/*                                                                     */
/*    (orgx,orgy) takes into acount window and scroll bar positions.   */
/*    (orgx,orgy) & clip (x0,y0,x1,y1) are in dBase coordinates.        */
/*                                                                     */
/* ------------------------------------------------------------------- */

os_error *draw_displ_do_objects (diagrec *diag, int offset, int end,
    draw_objcoord *org, draw_bboxtyp *clip)

{ os_error *error = 0;
  int size;
  BOOL boxed = FALSE;

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "draw_displ_do_objects: diag: 0x%X; offset: %d; end: %d; "
        "org: & (%d, %d); clip: 0x%X\n", diag, offset, end,
        org->x, org->y, clip);
  #endif

  for (; offset < end; offset += size)
  { draw_objptr hdrptr;
    os_error *e = NULL;

    hdrptr.bytep = diag->paper + offset;
    size         = hdrptr.objhdrp->size;

    switch (hdrptr.objhdrp->tag)
    { case draw_OBJTEXT:
        if (visible (hdrptr, clip)) e = do_objtext (hdrptr, org, FALSE), boxed = TRUE;
      break;

      case draw_OBJPATH:
        if (visible (hdrptr, clip)) e = do_objpath (hdrptr, org), boxed = TRUE;
      break;

      case draw_OBJSPRITE:
        if (visible (hdrptr, clip)) e = do_objsprite (hdrptr, org), boxed = TRUE;
      break;

      case draw_OBJGROUP:
        if (visible (hdrptr, clip))
          /* Render the objects in the group */
          e = draw_displ_do_objects (diag, offset + sizeof (draw_groustr),
                                            offset + size, org, clip), boxed = TRUE;
      break;

      case draw_OBJTAGG:
        { draw_objptr tagptr;

          tagptr.bytep = hdrptr.bytep + sizeof (draw_taggstr);
          if (visible (tagptr, clip))
            /*Render the (one) object within the tagged object*/
            e = draw_displ_do_objects (diag,
                offset + sizeof (draw_taggstr),
                offset + sizeof (draw_taggstr) + tagptr.objhdrp->size, org,
                clip), boxed = TRUE;
        }
      break;

      case draw_OBJTEXTCOL:
        { /*draw_bboxtyp clipBox = *clip;*/

          if (visible (hdrptr, clip))
            e = draw_text_do_objtextcol (hdrptr, org /*, &clipBox*/), boxed = TRUE;
        }
      break;

      case draw_OBJTEXTAREA:
        { /*draw_bboxtyp clipBox = *clip;*/

          if (visible (hdrptr, clip))
            e = draw_text_do_objtextarea (hdrptr, org /*, &clipBox*/), boxed = TRUE;
        }
      break;

      case draw_OBJTRFMTEXT:
        if (visible (hdrptr, clip)) e = do_objtrfmtext (hdrptr, org), boxed = TRUE;
      break;

      case draw_OBJTRFMSPRITE:
        if (visible (hdrptr, clip)) e = do_objtrfmsprite (hdrptr, org), boxed = TRUE;
      break;

      case draw_OBJJPEG:
        if (visible (hdrptr, clip)) e = do_objjpeg (hdrptr, org), boxed = TRUE;
      break;
    }
    /*Don't do this - it leads to unpredictable behaviour if anything goes
      wrong. JRC 14 June 1990*/
    /*if (error) break;*/ /* break from for-loop */

    if (e != NULL)
    { if (boxed)
      { int xsize = (int) (16*draw_displ_scalefactor/draw_currentmode.pixx),
          ysize = (int) (32*draw_displ_scalefactor/draw_currentmode.pixy),
          x0 = scaleT (org->x, hdrptr.spritep->bbox.x0),
          y0 = scaleT (org->y, hdrptr.spritep->bbox.y0),
          x1 = scaleT (org->x, hdrptr.spritep->bbox.x1),
          y1 = scaleT (org->y, hdrptr.spritep->bbox.y1),
          gw [4], width, height, i;

        static int grwinvars [] = {128, 129, 130, 131, -1};

        /*Display the error message in the object, ho ho. JRC 25th Nov 1994*/
        wimp_setcolour (1); /*light grey*/
        bbc_rectanglefill (x0, y0, x1 - x0, y1 - y0);
        wimp_setcolour (7); /*black*/
        draw_displ_setVDU5charsize (xsize, ysize, xsize, ysize);
        wimpt_noerr (os_swix2 (OS_ReadVduVariables, grwinvars, gw));
        gw [0] <<= draw_currentmode.xeigfactor;
        gw [1] <<= draw_currentmode.yeigfactor;
        gw [2] <<= draw_currentmode.xeigfactor;
        gw [3] <<= draw_currentmode.yeigfactor;
        bbc_gwindow (MAX (x0, gw [0]), MAX (y0, gw [1]),
            MIN (x1, gw [2]), MIN (y1, gw [3]));
        width = (x1 - x0)/(16*draw_displ_scalefactor);
        if (width == 0) width = 1;
        height = (strlen (e->errmess) + width - 1)/width;
        for (i = 0; i < height; i++)
        { bbc_move (x0, y1 - (int) (32*(i*draw_displ_scalefactor)));
          printf ("%.*s", width, e->errmess + width*i);
        }
        bbc_gwindow (gw [0], gw [1], gw [2], gw [3]);
      }

      if (error == NULL) error = e;
    }
  }
  return error;
}

/* ------------------------------------------------------------------- */
/* General code used to start an update. Returns more and redrawstr */
static int start_update (wimp_redrawstr *r, viewrec *vuue)

{ int more;

  ftracef0 ("start_update\n");
  r->box.x0 = -0x1FFFFFFF; r->box.y0 = -0x1FFFFFFF;
  r->box.x1 =  0x1FFFFFFF; r->box.y1 =  0x1FFFFFFF;
  wimp_update_wind (r, &more);

  draw_displ_scalefactor = vuue->zoomfactor;
  return more;
}

/* -----------------------------------------------------------------------*/
/*                                                                        */
/* draw_displ_totalredraw  force a redraw of the whole window of each view*/
/* ================  (including title and scroll bars) of the given       */
/*                   diagram. In fact, we don't change the scroll bar, so */
/*                   forget about it.                                     */
/* -----------------------------------------------------------------------*/

void draw_displ_totalredraw (diagrec *diag)

{ viewrec *vuue;

  ftracef0 ("draw_displ_totalredraw\n");
  for (vuue = diag->view; vuue != NULL; vuue = vuue->nextview)
    if (vuue->w != NULL)
    { wimp_redrawstr redraw_str;

      /*Redraw the title area.*/
      draw_displ_redraw_one_title (vuue);

      /*Redraw the work area*/
      redraw_str.w      =  vuue->w;
      redraw_str.box.x0 = -0x1FFFFFFF;
      redraw_str.box.y0 = -0x1FFFFFFF;
      redraw_str.box.x1 =  0x1FFFFFFF;
      redraw_str.box.y1 =  0x1FFFFFFF;
      wimp_force_redraw (&redraw_str);
    }

  /*If this diagram had the input focus, make sure we get it back*/
  if (diag == draw_enter_focus_owner.diag) draw_get_focus ();
}

#if 0
/*Old version deleted because causes windows to be dragged back onto the
  screen:*/
void draw_displ_totalredraw (diagrec *diag)

{ viewrec *vuue; wimp_wstate s;

  ftracef0 ("draw_displ_totalredraw\n");
  for (vuue = diag->view ; vuue != 0 ; vuue = vuue->nextview)
  { s.o.w = vuue->w;
    if (s.o.w != 0)
    { draw_fillwindowtitle (vuue);
      wimp_get_wind_state (s.o.w, &s);   /* Read window state          */
      wimp_close_wind (s.o.w);           /* Close it, then re-open, to */
      wimp_open_wind (&s.o);             /* redraw title & scroll bars */
    }
  }

  /* If this diagram had the input focus, make sure we get it back */
  if (diag == draw_enter_focus_owner.diag)
    draw_get_focus ();
}
#endif
/* -----------------------------------------------------------------------*/
/*                                                                        */
/* draw_displ_redrawtitle  force a redraw of the title of each view of the*/
/* ================  given diagram                                        */
/*                                                                        */
/* -----------------------------------------------------------------------*/

void draw_displ_redraw_one_title (viewrec *vuue)

{ wimp_redrawstr r;
  wimp_wstate    s;

  ftracef0 ("draw_displ_redraw_one_title\n");
  draw_fillwindowtitle (vuue);
  wimp_get_wind_state (vuue->w, &s);

  r.w = vuue->w;
  wimp_getwindowoutline (&r);

  ftracef4 ("Window outline (%d,%d, %d,%d)\n",r.box.x0,r.box.y0,
                                              r.box.x1,r.box.y1);
  ftracef4 (     "Work area     (%d,%d, %d,%d)\n",s.o.box.x0,s.o.box.y0,
                                              s.o.box.x1,s.o.box.y1);

  r.w      = -1;            /* screen */
  r.box.y0 = s.o.box.y1;

  ftracef4 ("Force_redraw of    (%d,%d, %d,%d)\n\n",r.box.x0,r.box.y0,
                                                r.box.x1,r.box.y1);

  wimp_force_redraw (&r);
}

void draw_displ_redrawtitle (diagrec *diag)

{ viewrec *vuue;

  ftracef0 ("draw_displ_redrawtitle\n");
  /* for each view, read work area limits & window outline to deduce the */
  /* title bar limits then force a redraw of this area of the screen     */
  for (vuue = diag->view ; vuue != 0 ; vuue = vuue->nextview)
    draw_displ_redraw_one_title (vuue);
}

/* -----------------------------------------------------------------------*/
/*                                                                        */
/* draw_displ_forceredraw  force a redraw of each view of the given diagra*/
/* ================                                                       */
/*                                                                        */
/* -----------------------------------------------------------------------*/

void draw_displ_forceredraw (diagrec *diag)

{ viewrec *vuue;
  wimp_redrawstr r;

  ftracef0 ("draw_displ_forceredraw\n");
  for (vuue = diag->view ; vuue != 0; vuue = vuue->nextview)
  { r.w = vuue->w;
    if (r.w != 0)
    { r.box.x0 = -0x1FFFFFFF; r.box.y0 = -0x1FFFFFFF;
      r.box.x1 =  0x1FFFFFFF; r.box.y1 =  0x1FFFFFFF;
      wimp_force_redraw (&r);
    }
  }
}

/* -----------------------------------------------------------------------*/
/*                                                                        */
/* draw_displ_redrawarea  force a redraw (in each view) of part of the dBa*/
/* ===============    coordinate space (usually from an objects BBox)     */
/*                                                                        */
/* -----------------------------------------------------------------------*/

void draw_displ_redrawarea (diagrec *diag, draw_bboxtyp *bboxp)

{ viewrec        *vuue;
  wimp_redrawstr r;
  int            grabH4 = grabH + 4;
  int            grabW4 = grabW + 4;
  draw_objcoord  org;

  ftracef0 ("draw_displ_redrawarea\n");
  org.x = org.y = 0;

  for (vuue = diag->view ; vuue != 0; vuue = vuue->nextview)
  { r.w = vuue->w;
    if (r.w != 0)
    { draw_displ_scalefactor = vuue->zoomfactor;

      r.box.x0 = scaleB (org.x, bboxp->x0) - grabW4;
      r.box.y0 = scaleB (org.y, bboxp->y0) - grabH4;
      r.box.x1 = scaleB (org.x, bboxp->x1) + grabW4;
      r.box.y1 = scaleB (org.y, bboxp->y1) + grabH4;

      wimp_force_redraw (&r);
    }
  }
}

/* -----------------------------------------------------------------------*/
/*                                                                        */
/* draw_displ_redrawobject force a redraw of the given object (in each vie*/
/* =================                                                      */
/*                                                                        */
/* -----------------------------------------------------------------------*/

void draw_displ_redrawobject (diagrec *diag, int obj_off)

{ draw_objptr hdrptr;

  ftracef0 ("draw_displ_redrawobject\n");
  hdrptr.bytep = diag->paper + obj_off;

  draw_displ_redrawarea (diag, draw_displ_bbox (hdrptr));
}

/* -----------------------------------------------------------------------*/
static void make_origin_os (draw_objcoord *to, wimp_redrawstr *r)

{ ftracef0 ("make_origin_os\n");
  to->x = draw_os_to_draw (r->box.x0 - r->scx);
  to->y = draw_os_to_draw (r->box.y1 - r->scy);
}

/* -----------------------------------------------------------------------*/

static os_error *update_each_view (diagrec *diag,
    os_error *(*funcp) (diagrec *diag, draw_objcoord *org))

{ viewrec *vuue;
  os_error *error, *final = NULL;

  ftracef0 ("update_each_view\n");
  for (vuue = diag->view; vuue != 0; vuue = vuue->nextview)
  { wimp_redrawstr r;

    if (r.w = vuue->w, r.w != 0)
    { int more = start_update (&r, vuue);
      draw_objcoord org;

      make_origin_os (&org, &r);

      while (more) /*call paint_ (trans/rotat/scale)boxes*/
      { ftracef0 ("update_each_view: calling argument\n");
        if ((error = (*funcp) (diag, &org)) != NULL)
          if (final == NULL) final = error; /*save the first only*/
        wimp_get_rectangle (&r, &more);
      }
    }
  }

  return final;
}

static os_error *update_this_view (viewrec *vuue,
    os_error *(*funcp) (viewrec *vuue, draw_objcoord *org,
    draw_bboxtyp clip))

{ wimp_redrawstr r;
  os_error *error, *final = NULL;

  ftracef0 ("update_this_view\n");
  if (r.w = vuue->w, r.w != 0)
  { int more = start_update (&r, vuue);

    while (more)
    { draw_bboxtyp  clip;
      draw_objcoord org;
      draw_make_clip (&r, &org, &clip);

      if ((error = (*funcp) (vuue, &org, clip)) != NULL)
        if (final == NULL) final = error; /*save the first only*/

      wimp_get_rectangle (&r, &more);
    }
  }

  return final;
}

/* ------------------------------------------------------------------- */
/* Show the printer papersize & usable area */

static void rectangle (int x0, int y0, int x1, int y1)

{ ftracef4 ("rectangle (%d, %d, %d, %d)\n", x0, y0, x1, y1);
  bbc_move (x0, y0);
  bbc_plot (bbc_RectangleFill|bbc_DrawAbsFore, x1, y1);
}

os_error *draw_displ_do_printmargin (diagrec *diag, draw_objcoord *org)

{ draw_bboxtyp page, visi;

  #if TRACE
    paperstate_typ *paperstate = &diag->misc->paperstate;

    ftracef0 ("draw_displ_do_printmargin\n");

    ftracef (__FILE__, __LINE__,
        "paper limits are (((%d, %d), (%d, %d)), ((%d, %d), (%d, %d)))\n",
        paperstate->viewlimit.x0, paperstate->viewlimit.y0,
        paperstate->viewlimit.x1, paperstate->viewlimit.y1,
        paperstate->setlimit.x0, paperstate->setlimit.y0,
        paperstate->setlimit.x1, paperstate->setlimit.y1);
  #endif

  draw_print_get_limits (diag, &page, &visi);

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "before scaling and shifting, "
        "pagelimit (%d, %d, %d, %d) visiblelimit (%d, %d, %d, %d)\n",
        page.x0, page.y0, page.x1, page.y1,
        visi.x0, visi.y0, visi.x1, visi.y1);
  #endif

  draw_box_scale_shift (&page, &page, draw_displ_scalefactor, org);
  draw_box_scale_shift (&visi, &visi, draw_displ_scalefactor, org);

  #if TRACE
    ftracef (__FILE__, __LINE__,
        "after scaling and shifting, "
        "pagelimit (%d, %d, %d, %d) visiblelimit (%d, %d, %d, %d)\n",
        page.x0, page.y0, page.x1, page.y1,
        visi.x0, visi.y0, visi.x1, visi.y1);
  #endif

  /*Don't EOR print margin - attempting to add print margins by xorring
    results in redraw bugs. The print margin must be at the bottom of the
    diagram and might just as well be drawn properly. J R C 1st Feb 1994*/
  wimpt_noerr (wimp_setcolour (draw_colours.printmargin));
      /* was displ_gcol (3, draw_colours.printmargin, -1);*/

  rectangle (page.x0, visi.y0, visi.x1 - draw_currentmode.pixx, page.y0);
  rectangle (visi.x1, page.y0, page.x1, visi.y1 - draw_currentmode.pixy);
  rectangle (page.x1, visi.y1, visi.x0 + draw_currentmode.pixx, page.y1);
  rectangle (visi.x0, page.y1, page.x0, visi.y0 + draw_currentmode.pixy);

  return NULL;
}

/* Show print margins in all views */
os_error *draw_displ_show_printmargins (diagrec *diag)

{ ftracef0 ("draw_displ_show_printmargins\n");
  if (diag->misc->paperstate.options & Paper_Show)
    return update_each_view (diag, draw_displ_do_printmargin);
  else
    return NULL;
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* Rectangle outline                                                      */
/*                                                                        */
/* tests for height or width zero, to prevent double plotting             */
/*                                                                        */

static void displ_box (draw_objcoord *org, draw_bboxtyp *inbox)

{ draw_bboxtyp box;

  ftracef0 ("displ_box\n");
  draw_box_scale_shift (&box, inbox, draw_displ_scalefactor, org);

  bbc_move (box.x0, box.y0);

  if (box.x0 == box.x1)
    bbc_draw (box.x0, box.y1);
  else if (box.y0 == box.y1)
    bbc_draw (box.x1, box.y0);
  else
  { fpo_draw (box.x1, box.y0);
    fpo_draw (box.x1, box.y1);
    fpo_draw (box.x0, box.y1);
    fpo_draw (box.x0, box.y0);
  }
}

static drawmod_line *set_flat (int flat)

{ static drawmod_line flat_line = {0, 0, 0, 0};

  ftracef0 ("set_flat\n");
  flat_line.flatness = flat;
  return &flat_line;
}

/* ---------------------------------------------------------------------- */
/* displ_strokepath_linebyline                                            */
/*                                                                        */
/* Stroke the path to the screen, line by line                            */

static os_error *displ_dolines (drawmod_transmat *matrix,
                          drawmod_pathelemptr pathptr, int flat)

{ ftracef0 ("displ_lines\n");
  return drawmod_stroke (pathptr, fill_Default, matrix, set_flat (flat));
}

/* Types used for line by line work */
typedef struct
{ drawmod_path_movestr   move;
  drawmod_path_linetostr line;
  drawmod_path_termstr   term;
} line_segment;

typedef struct
{ drawmod_path_movestr   move;
  drawmod_path_bezierstr curve;
  drawmod_path_termstr   term;
} curve_segment;

static os_error *displ_strokepath_linebyline (drawmod_pathelemptr pathptr,
    draw_objcoord *org)

{ line_segment        blkL;
  curve_segment       blkC;
  drawmod_pathelemptr blkLptr, blkCptr;
  drawmod_transmat    matrix;
  int                 flat = (int) (200/draw_displ_scalefactor);
  os_error *error;

  ftracef0 ("displ_strokepath_linebyline\n");
  /* Set up path tags and point to paths */
  blkL.move.tag = blkC.move.tag = path_move_2;
  blkL.term.tag = blkC.term.tag = path_term;
  blkLptr.move2 = &blkL.move;
  blkCptr.move2 = &blkC.move;

  set_transmat (&matrix[0], org);

  /* Draw the path line by line:
     on a move, note the position for the next line/curve
     on a line or curve, move to the last position and then add the line/curve
     on a close, do nothing
     on a term, stop
     after a line or curve, note where it ended
  */

  while (pathptr.end->tag != path_term)
  { switch (pathptr.end->tag)
    { case path_closeline:
        pathptr.closeline++;
      break;

      case path_move_2:
        blkC.move = blkL.move = *(pathptr.move2);
        pathptr.move2++;
      break;

      case path_lineto:
        blkL.line = *(pathptr.lineto);
        if ((error = displ_dolines (&matrix, blkLptr, flat)) != NULL)
          return error;
        blkC.move.x = blkL.move.x = pathptr.lineto->x;
        blkC.move.y = blkL.move.y = pathptr.lineto->y;
        pathptr.lineto++;
      break;

      case path_bezier:
        blkC.curve = *(pathptr.bezier);
        if ((error = displ_dolines (&matrix, blkCptr, flat)) != NULL)
          return error;
        blkC.move.x = blkL.move.x = pathptr.bezier->x3;
        blkC.move.y = blkL.move.y = pathptr.bezier->y3;
        pathptr.bezier++;
      break;
    }
  }

  return NULL;
}

/* Stroke the path to the screen */
static draw_dashstr dotty = { {0, 6},
                              {dbc_TwentythInch, dbc_TwentythInch,
                               dbc_TwentythInch, dbc_TwentythInch,
                               dbc_TwentythInch, dbc_TwentythInch} };

static os_error *displ_strokepath (drawmod_pathelemptr pathptr,
    draw_objcoord *org, draw_dashstr *pattern)

{ /* pattern only used in monochrome modes */
  drawmod_transmat matrix;
  drawmod_line     linestyle;

  ftracef0 ("displ_strokepath\n");
  linestyle.flatness  = (int) (200/draw_displ_scalefactor);
  linestyle.thickness = 0;
  linestyle.spec.join =  linestyle.spec.leadcap = linestyle.spec.trailcap =
  linestyle.spec.reserved8  = 0;
  linestyle.spec.mitrelimit = 0;
  linestyle.spec.lead_tricap_w = linestyle.spec.trail_tricap_w = 0;
  linestyle.spec.lead_tricap_h = linestyle.spec.trail_tricap_h = 0;

#if HOLLOWBLOB
  linestyle.dash_pattern = draw_currentmode.ncolour == 1?
                                           (drawmod_dashhdr *) pattern : NULL;
#else
  linestyle.dash_pattern = NULL;
#endif

  set_transmat (&matrix[0], org);
  return drawmod_stroke (pathptr, fill_Default, &matrix, &linestyle);
}

static int blob_count (draw_objptr hdrptr, draw_objcoord *coordp, int bez,
                      int all)

{ int count = 0;

  ftracef0 ("blob_count\n");
  switch (hdrptr.objhdrp->tag)
  { case draw_OBJPATH:
    { drawmod_pathelemptr pathptr, endptr;

      pathptr      = draw_obj_pathstart (hdrptr);
      endptr.bytep = hdrptr.bytep + hdrptr.pathp->size;

      while (pathptr.bytep < endptr.bytep)
      { /*ftracef4 ("blob_count: count: %d, hdrptr: 0x%X; "
            "pathptr: 0x%X; endptr: 0x%X\n", count, hdrptr.bytep,
            pathptr.bytep, endptr.bytep);*/

        switch (pathptr.end->tag)
        { case path_term:
          case path_closeline:
            pathptr.closeline++;
          break;

          case path_move_2:
          case path_lineto:
            count += (all || &pathptr.move2->x < &coordp->x) &&
                      !bez &&
                      pathptr.move2->x == coordp->x &&
                      pathptr.move2->y == coordp->y;
            pathptr.move2++;
          break;

          case path_bezier:
            if (bez)
              count += ((all || (&pathptr.bezier->x1 < &coordp->x)) &&
                        (pathptr.bezier->x1 == coordp->x) &&
                        (pathptr.bezier->y1 == coordp->y)) +
                        ((all || (&pathptr.bezier->x2 < &coordp->x)) &&
                          (pathptr.bezier->x2 == coordp->x) &&
                          (pathptr.bezier->y2 == coordp->y));
            else
              count += ((all || (&pathptr.bezier->x3 < &coordp->x)) &&
                         (pathptr.bezier->x3 == coordp->x) &&
                         (pathptr.bezier->y3 == coordp->y));
            pathptr.bezier++;
          break;
        }
      }
    }
    break;
  }

  ftracef1 ("blob_count: count: %d\n", count);
  return count;
}

/*Blobs a single point, eg for indicating current point */
static void blob_point (int x, int y, int fg, int bg)

{ ftracef0 ("blob_point\n");
  displ_gcol (3, fg, bg);

#if (HOLLOWBLOB)
  if (draw_currentmode.ncolour == 1)
  { int dx = draw_currentmode.pixsizex >> 8;
    int dy = draw_currentmode.pixsizey >> 8;

    bbc_rectanglefill (x-grabW/2+dx, y-grabH/2+dy, grabW-dx-dx, grabH-dy-dy);
  }
  else
#endif
  { ftracef4 ("bbc_rectanglefill (%d, %d, %d, %d)\n",
        x-grabW/2, y-grabH/2, grabW, grabH);
    bbc_rectanglefill (x-grabW/2, y-grabH/2, grabW, grabH);
  }
}

static void paint_point (int x, int y, draw_objcoord *org)

{ ftracef0 ("paint_point\n");
  x = scaleB (org->x, x);
  y = scaleB (org->y, y);

  blob_point (x, y, draw_colours.anchorpt, draw_colours.highlight);
}

static void blob_line (draw_objptr hdrptr, drawmod_path_linetostr *lineptr,
                      int ctl, draw_objcoord *org)

{ int x = scaleB (org->x, lineptr->x);
  int y = scaleB (org->y, lineptr->y);

  ftracef0 ("blob_line\n");
  if (blob_count (hdrptr, (draw_objcoord *) &lineptr->x, 0, ctl) == ctl)
    blob_point (x, y, draw_colours.anchorpt, -1); /* eor in blue */
}

static os_error *paint_line (draw_objcoord *org,
    drawmod_path_linetostr *lineptr,
    draw_dashstr *pattern /* monochrome only */)

{ line_segment        blk;
  drawmod_pathelemptr blkptr;

  ftracef0 ("paint_line\n");
  blkptr.move2 = &blk.move;

  blk.move.tag = path_move_2;
  blk.move.x   = (lineptr-1)->x;
  blk.move.y   = (lineptr-1)->y;
  blk.line     = *lineptr;
  blk.term.tag = path_term;
  return displ_strokepath (blkptr, org, pattern);
}

static void blob_curve_b1 (drawmod_path_bezierstr *curveptr, draw_objcoord *org)

{ int x0 = scaleB (org->x, (curveptr-1)->x3); /*coord from prev move/line */
  int y0 = scaleB (org->y, (curveptr-1)->y3); /*or curve element*/
  int x1 = scaleB (org->x, curveptr->x1);
  int y1 = scaleB (org->y, curveptr->y1);

  ftracef0 ("blob_curve_b1\n");
  displ_gcol (3, draw_colours.skeleton, -1); /* eor in grey */
  bbc_move (x0, y0); bbc_draw (x1, y1);

  blob_point (x1, y1, draw_colours.bezierpt, -1);
}

static void blob_curve_b2 (drawmod_path_bezierstr *curveptr, draw_objcoord *org)

{ int x2 = scaleB (org->x, curveptr->x2);
  int y2 = scaleB (org->y, curveptr->y2);
  int x3 = scaleB (org->x, curveptr->x3);
  int y3 = scaleB (org->y, curveptr->y3);

  ftracef0 ("blob_curve_b2\n");
  displ_gcol (3, draw_colours.skeleton, -1); /* eor in grey */
  bbc_move (x2, y2); bbc_draw (x3, y3);

  blob_point (x2, y2, draw_colours.bezierpt, -1);
}

static void blob_curve_ep (draw_objptr hdrptr, drawmod_path_bezierstr *curveptr,
                          int ctl, draw_objcoord *org)

{ int x3 = scaleB (org->x, curveptr->x3);
  int y3 = scaleB (org->y, curveptr->y3);

  ftracef0 ("blob_curve_ep\n");
  if (blob_count (hdrptr, (draw_objcoord *) &curveptr->x3, 0, ctl) == ctl)
    blob_point (x3, y3, draw_colours.anchorpt, -1);
}

static void blob_curve (draw_objptr hdrptr, drawmod_path_bezierstr *curveptr,
                       int ctl, draw_objcoord *org)

{ ftracef0 ("blob_curve\n");
  blob_curve_b1 (curveptr, org);
  blob_curve_b2 (curveptr, org);
  blob_curve_ep (hdrptr, curveptr, ctl, org);
}

static os_error *paint_curve (draw_objcoord *org,
    drawmod_path_bezierstr *curveptr,
    draw_dashstr *pattern /* only used in monochrome modes */)

{ curve_segment       blk;
  drawmod_pathelemptr blkptr;

  ftracef0 ("paint_curve\n");
  blkptr.move2 = &blk.move;

  blk.move.tag = path_move_2;
  blk.move.x   = (curveptr-1)->x3;
  blk.move.y   = (curveptr-1)->y3;
  blk.curve    = *curveptr;
  blk.term.tag = path_term;

  return displ_strokepath (blkptr, org, pattern);
}

/* ------------------------------------------------------------------------- */
/* Painting line skeletons - some common code first */
static drawmod_pathelemptr paint_segment_blobs
    (draw_objptr hdrptr, drawmod_pathelemptr pathptr,
    draw_objcoord *org, BOOL end_points)

{
  ftracef0 ("paint_segment_blobs\n");
  switch (pathptr.end->tag)
  { case path_term:
    case path_closeline:
      pathptr.closeline++;
    break;

    case path_move_2:
    case path_lineto:
      blob_line (hdrptr, pathptr.lineto, 0, org);
      pathptr.lineto++;
    break;

    case path_bezier:
      if (end_points)
        blob_curve (hdrptr, pathptr.bezier, 0, org);
      else
        blob_curve_ep (hdrptr, pathptr.bezier, 0, org);
      pathptr.bezier++;
    break;
  }
  ftracef1 ("paint_segment_blobs: returning %d\n",
       pathptr.bytep);
  return pathptr;
}

static void paint_line_blobs (draw_objptr hdrptr, drawmod_pathelemptr endptr,
                             draw_objcoord *org, BOOL end_points)

{ drawmod_pathelemptr pathptr = draw_obj_pathstart (hdrptr);

  ftracef0 ("paint_line_blobs\n");

  while (pathptr.bytep < endptr.bytep)
    pathptr = paint_segment_blobs (hdrptr, pathptr, org, end_points);
}

static os_error *paint_skeleton_pathentry (diagrec *diag,
    draw_objptr objhdr, draw_objcoord *org)

{ os_error *error;

  ftracef0 ("paint_skeleton_pathentry\n");

  /* stroke the outline-eor in grey */
  displ_gcol (3, draw_colours.skeleton, -1);
  if ((error = displ_strokepath_linebyline (draw_obj_pathstart (objhdr), org))
      != NULL)
    return error;

/* now highlight the line following the pointer and show bezier control   */
/* points about its joint with the previous line                          */
/*  in state_path_move   do nothing                                       */
/*  in state_path_point1 show single bezier point if a curve              */
/*                                                                        */
/* for better visual effect, this is the only joint whose bezier points   */
/* are shown                                                              */

  { drawmod_pathelemptr pty, ptz;

    pty.bytep = diag->misc->pty_off + diag->paper;
    ptz.bytep = diag->misc->ptz_off + diag->paper;

    /* Highlight the selected line - changes grey into red */
    if (diag->misc->substate >= state_path_point1)
    { displ_gcol (3, draw_colours.skeleton, draw_colours.highlight);

      switch (ptz.end->tag)
      { case path_move_2:
        case path_lineto:
          /* highlight line */
          if ((error = paint_line (org, ptz.lineto, &dotty)) != NULL)
            return error;
        break;

        case path_bezier:
          /* highlight curve */
          if ((error = paint_curve (org, ptz.bezier, &dotty)) != NULL)
            return error;
          blob_curve_b1 (ptz.bezier, org);          /* show control pt */
        break;
      }

      /* Show bezier control points for previous line */
      if (pty.bezier->tag == path_bezier)
        blob_curve_b2 (pty.bezier, org);
    }

    /*blob all joints. for better visual effect don't blob the final
      line/curve endpoint (ptz) unless in state_path_move*/
    { drawmod_pathelemptr endptr;

      if (diag->misc->substate == state_path_move)
        endptr.bytep  = objhdr.bytep + objhdr.pathp->size; /*blob final pt*/
      else
        endptr.bytep  = ptz.bytep;                    /*dont blob final pt*/

      paint_line_blobs (objhdr, endptr, org, FALSE);
    }
  }

  return NULL;
}

static os_error *paint_skeleton_edit (draw_objptr hdrptr,
    draw_objptr subptr, drawmod_pathelemptr currele, draw_objcoord *org)

{ os_error *error;

  ftracef0 ("paint_skeleton_edit\n");
  switch (hdrptr.objhdrp->tag)
  { case draw_OBJPATH:
    { /* Draw the blobs, including end points */
      if (hdrptr.pathp == subptr.pathp)
      { drawmod_pathelemptr endptr;

        endptr.bytep = hdrptr.bytep + hdrptr.pathp->size;
        paint_line_blobs (hdrptr, endptr, org, TRUE);

        /* Highlight the selected line and point. */
        if (currele.bytep)
        { /* eor - grey into red */
          displ_gcol (3, draw_colours.skeleton, draw_colours.highlight);
          switch (currele.end->tag)
          { case path_move_2:                    /* highlight endpoint */
              paint_point (currele.move2->x, currele.move2->y, org);
            break;

            case path_lineto:             /* highlight line & endpoint */
              if ((error = paint_line (org, currele.lineto, &dotty)) !=
                  NULL)
                return error;
              paint_point (currele.lineto->x, currele.lineto->y, org);
            break;

            case path_bezier:           /* highlight curve & endpoint */
              if ((error = paint_curve (org, currele.bezier, &dotty)) !=
                  NULL)
                return error;
              paint_point (currele.bezier->x3, currele.bezier->y3, org);
            break;
          }
        }
      }

      /*stroke outline-eor in grey*/
      displ_gcol (3, draw_colours.skeleton, -1);
      if ((error = displ_strokepath_linebyline (draw_obj_pathstart (hdrptr),
          org)) != NULL)
        return error;
    }
    break;

    case draw_OBJGROUP:
    { int i;
      int start = sizeof (draw_groustr);
      int limit = hdrptr.objhdrp->size;
      draw_objptr objptr;

      /* Paint the skeletons of the objects in the group  */
      for (i = start ; i < limit ; i += objptr.objhdrp->size)
      { objptr.bytep = hdrptr.bytep + i;
        if ((error = paint_skeleton_edit (objptr, subptr, currele, org)) !=
            NULL)
          return error;
      }
    }
    break;
  }
  return NULL;
}

/*--------------------------------------------------------------------------*/
/* Paint whole of a selection using a given function */
typedef os_error *(*paint_fn) ();

static os_error *paint_selection (draw_objcoord *org, paint_fn fn)

{ int i;
  draw_objptr hdrptr;
  os_error *error, *final = NULL;

  ftracef0 ("paint_selection\n");
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    if ((error = fn (hdrptr, org)) != NULL)
      if (final == NULL) final = error; /*save first error*/

  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  return final;
}

/* ------------------------------------------------------------------------- */

static os_error *paint_transbox (draw_objptr hdrptr, draw_objcoord *org)

{ int transx = draw_translate_cb.dx, transy = draw_translate_cb.dy;
  draw_bboxtyp box;

  ftracef1 ("paint_transbox (0x%X)\n", hdrptr);
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  displ_gcol (3, draw_colours.skeleton, -1);   /* eor in grey */
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  memcpy (&box, draw_displ_bbox (hdrptr), sizeof box);
  box.x0 += transx;
  box.y0 += transy;
  box.x1 += transx;
  box.y1 += transy;

  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  displ_box (org, &box);

  return NULL;
}

static os_error *paint_transboxes (diagrec *diag, draw_objcoord *org)

{ os_error *error = NULL;

  ftracef0 ("paint_transboxes\n");
  diag = diag;
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  error = paint_selection (org, paint_transbox);
  ftracef4 ("draw_selection 0x%X, draw_selection->indx %d, "
      "draw_selection->limit %d, draw_selection->array [0] %d\n",
      draw_selection, draw_selection->indx,
      draw_selection->limit, draw_selection->array [0]);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  return error;
}

os_error *draw_displ_eor_transboxes (diagrec *diag)

{ ftracef0 ("draw_displ_eor_transboxes\n");
  return update_each_view (diag, paint_transboxes);
}

/* ------------------------------------------------------------------------- */

static os_error *paint_rotatbox (draw_objptr hdrptr, draw_objcoord *org)

{ draw_bboxtyp *bbox = draw_displ_bbox (hdrptr);
  int box_centx = (bbox->x1 + bbox->x0)/2;
  int box_centy = (bbox->y1 + bbox->y0)/2;
  int orgx = org->x, orgy = org->y;

  double l = (double) bbox->x0 - (double) box_centx;
  double b = (double) bbox->y0 - (double) box_centy;
  double r = (double) bbox->x1 - (double) box_centx;
  double t = (double) bbox->y1 - (double) box_centy;

  double sin_theta = draw_rotate_cb.sinA_B;
  double cos_theta = draw_rotate_cb.cosA_B;

  /* Precompute common elements - they have no intrinsic meaning */
  double lc = l*cos_theta;
  double bsx = b*sin_theta - box_centx;
  double bc = b*cos_theta;
  double lsy = l*sin_theta + box_centy;
  double rc = r*cos_theta;
  double rsy = r*sin_theta + box_centy;
  double tsx = t*sin_theta - box_centx;
  double tc = t*cos_theta;

  ftracef0 ("paint_rotatbox\n");
  displ_gcol (3, draw_colours.skeleton, -1);    /* eor in grey */
  bbc_move (scaleB (orgx, (int) (lc - bsx)),scaleB (orgy, (int) (bc + lsy)));
  bbc_draw (scaleB (orgx, (int) (rc - bsx)),scaleB (orgy, (int) (bc + rsy)));
  bbc_draw (scaleB (orgx, (int) (rc - tsx)),scaleB (orgy, (int) (tc + rsy)));
  bbc_draw (scaleB (orgx, (int) (lc - tsx)),scaleB (orgy, (int) (tc + lsy)));
  bbc_draw (scaleB (orgx, (int) (lc - bsx)),scaleB (orgy, (int) (bc + lsy)));

  return NULL;
}

static os_error *paint_rotatboxes (diagrec *diag, draw_objcoord *org)

{ ftracef0 ("paint_rotatboxes\n");
  diag = diag;
  return paint_selection (org, paint_rotatbox);
}

os_error *draw_displ_eor_rotatboxes (diagrec *diag)

{ ftracef0 ("draw_displ_eor_rotatboxes\n");
  return update_each_view (diag, paint_rotatboxes);
}

/* ------------------------------------------------------------------------- */

static os_error *draw_displ_scalebox (draw_objptr hdrptr, scale_str *scale,
                                draw_bboxtyp *box)

{ double newx1, newy0;
  draw_bboxtyp *bbox = draw_displ_bbox (hdrptr);

  ftracef0 ("draw_displ_scalebox\n");
  box->x0 = bbox->x0;
  box->y1 = bbox->y1;

  if (scale->old_Dx == 0)
    box->x1 = box->x0;
  else
  { newx1 = 0.5 + (double) box->x0 + ((double) bbox->x1 - (double) box->x0)*
                                 ((double)scale->new_Dx/ (double)scale->old_Dx);
    box->x1 = newx1 > INT_MAX? INT_MAX: newx1 < -INT_MAX? -INT_MAX: (int) newx1;
  }

  if (scale->old_Dy == 0)
    box->y0 = box->y1;
  else
  { newy0 = 0.5 + (double) box->y1 + ((double) bbox->y0 - (double) box->y1)*
                                 ((double)scale->new_Dy/ (double)scale->old_Dy);
    box->y0 = newy0 > INT_MAX? INT_MAX: newy0 < -INT_MAX? -INT_MAX: (int) newy0;
  }

  return NULL;
}

static os_error *paint_scalebox (draw_objptr hdrptr, draw_objcoord *org)

{ draw_bboxtyp box;

  ftracef0 ("paint_scalebox\n");
  draw_displ_scalebox (hdrptr, &draw_scale_cb, &box);

  displ_gcol (3, draw_colours.skeleton, -1);    /* eor in grey */
  displ_box (org, &box);

  return NULL;
}

static os_error *paint_scaleboxes (diagrec *diag, draw_objcoord *org)

{ ftracef0 ("pant_scaleboxes\n");
  diag = diag;
  return paint_selection (org, paint_scalebox);
}

os_error *draw_displ_eor_scaleboxes (diagrec *diag)

{ ftracef0 ("draw_displ_eor_scaleboxes\n");
  return update_each_view (diag, paint_scaleboxes);
}

/* ------------------------------------------------------------------------- */

static os_error *paint_capturebox (diagrec *diag, draw_objcoord *org)

{ ftracef0 ("paint_capturebox\n");
  displ_gcol (3, draw_colours.skeleton, -1); /* eor in grey */
  displ_box (org, &draw_capture_cb);
  diag = diag; /*stupid compiler*/
  return NULL;
}

os_error *draw_displ_eor_capturebox (diagrec *diag)

{ ftracef0 ("draw_displ_eor_capturebox\n");
  return update_each_view (diag, paint_capturebox);
}

/* ---------------------------------------------------------------------- */

os_error *draw_displ_paint_skeleton (diagrec *diag, draw_objcoord *org)

{ os_error *error;

  ftracef0 ("paint_skeleton\n");
  switch (diag->misc->substate)
  { case state_path:
    break;

    case state_path_move:
    case state_path_point1:
    case state_path_point2:
    case state_path_point3:
    { int hdroff = *(int*) (diag->paper + diag->misc->stacklimit);
      draw_objptr hdrptr;

      hdrptr.bytep  = diag->paper + hdroff;

      if ((error = paint_skeleton_pathentry (diag, hdrptr, org)) != NULL)
        return error;
    }
    break;

    case state_rect:
    break;

    case state_rect_drag:
    { int hdroff = *(int*) (diag->paper + diag->misc->stacklimit);
      draw_objptr hdrptr;
      path_pseudo_rectangle *rectp;
      drawmod_pathelemptr rectpath;
      draw_bboxtyp        box;

      hdrptr.bytep  = diag->paper + hdroff;
      rectpath = draw_obj_pathstart (hdrptr);
      rectp    = (path_pseudo_rectangle *)rectpath.bytep;

      displ_gcol (3, draw_colours.skeleton, -1);           /* eor in grey */
      box.x0 = rectp->move.x;
      box.y0 = rectp->move.y;
      box.x1 = rectp->line2.x;
      box.y1 = rectp->line2.y;
      displ_box (org, &box);
    }
    break;

    case state_elli:
    break;

    case state_elli_drag:
    { int hdroff = *(int*) (diag->paper + diag->misc->stacklimit);
      draw_objptr hdrptr;

      hdrptr.bytep  = diag->paper + hdroff;

      displ_gcol (3, draw_colours.skeleton, -1);
      if ((error = displ_strokepath (draw_obj_pathstart (hdrptr), org, 0))
          != NULL) /*solid*/
        return error;
    }
    break;

    case state_text_char:
    { int hdroff = *(int*) (diag->paper + diag->misc->stacklimit);
      draw_objptr hdrptr;
      hdrptr.bytep = diag->paper + hdroff;

      do_objtext (hdrptr, org, TRUE);
    }
    break;

    case state_text_caret:
    case state_text:
    break;

    case state_sel_select:
    case state_sel_adjust:
    case state_sel_shift_select:
    case state_sel_shift_adjust:
    case state_zoom:
    case state_printerI:
    case state_printerO: /*JRC*/
      paint_capturebox (diag, org);
    break;

    case state_sel_trans:
      paint_transboxes (diag, org);
    break;

    case state_sel_scale:
      paint_scaleboxes (diag, org);
    break;

    case state_sel_rotate:
      paint_rotatboxes (diag, org);
    break;

    case state_edit:
    case state_edit_drag:
    case state_edit_drag1:
    case state_edit_drag2:
      if (diag->misc->pathedit_cb.obj_off >= 0)
      { draw_objptr hdrptr;
        /*draw_objptr subptr;*/
        drawmod_pathelemptr currele;

        hdrptr.bytep = diag->misc->pathedit_cb.obj_off + diag->paper;
        /*subptr.bytep = diag->misc->pathedit_cb.sub_off + diag->paper;*/

        if (diag->misc->pathedit_cb.cele_off >= 0)
          currele.bytep = diag->misc->pathedit_cb.cele_off + diag->paper;
        else
          currele.bytep = 0;
        if ((error = paint_skeleton_edit (hdrptr, hdrptr, currele, org)) !=
            NULL)
          return error;
      }
    break;
  }

  return NULL;
}

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* paint_bbox      - paint bbox of given object                           */
/* paint_bboxes    - paint bboxes all selected objects                    */
/* draw_eor_bboxes - call wimp_update_window & paint_bboxes for each view */
/*                                                                        */
/*   NB the value of diag passed to draw_eor_bboxes & paint_bboxes will   */
/*      always equal selection->owner, this parameter is passed to allow  */
/*      for a possible update to one selection per diagram.               */
/*                                                                        */

static os_error *paint_bbox (draw_objptr hdrptr, draw_objcoord *org)

{ draw_bboxtyp box;
  #if 0 /*a mistake. J R C 4th Oct 1993*/
    int xreg = 242 /*was 241. J R C 1st Oct 1993*/;
    int yreg = 64;
  #endif
  int          i;

  ftracef0 ("paint_bbox\n");
  draw_box_scale_shift (&box, draw_displ_bbox (hdrptr),
      draw_displ_scalefactor, org);

  /* Set dot-dash style */
  bbc_vdu (23);bbc_vdu (6);
  for (i = 0 ; i < 4 ; i++) bbc_vduw (0xCC);
  #if 0 /*a mistake. J R C 4th Oct 1993*/
    os_byte (163, &xreg, &yreg);
  #endif

  displ_gcol (3, draw_colours.bbox, -1);  /* eor in red */

  bbc_move (box.x0, box.y0);

  rlpo_draw (box.x1, box.y0);
  beo_draw (box.x1+grabW, box.y0);
  beo_draw (box.x1+grabW, box.y0-grabH);
  beo_draw (box.x1, box.y0-grabH);
  beo_draw (box.x1, box.y0);

  rlpo_draw (box.x1, box.y1);
  if (draw_obj_rotatable (hdrptr))
  { beo_draw (box.x1, box.y1+grabH);
    beo_draw (box.x1+grabW, box.y1+grabH);
    beo_draw (box.x1+grabW, box.y1);
    beo_draw (box.x1, box.y1);
  }

  rlpo_draw (box.x0, box.y1);
  rlpo_draw (box.x0, box.y0);

  return NULL;
}

os_error *draw_displ_paint_bboxes (diagrec *diag, draw_objcoord *org)

{ ftracef0 ("draw_displ_paint_bboxes\n");
  if (draw_select_owns (diag))
    return paint_selection (org, paint_bbox);
  else
    return NULL;
}

os_error *draw_displ_eor_bboxes (diagrec *diag)

{ ftracef0 ("draw_displ_eorbboxes\n");
  return update_each_view (diag, draw_displ_paint_bboxes);
}

/*---------------------------- Grids -------------------------------------*/
os_error *draw_displ_paint_grid (viewrec *vuue, draw_objcoord *org,
    draw_bboxtyp clip)

{ ftracef0 ("draw_displ_paint_grid\n");
  displ_gcol (3, vuue->gridcolour, -1);
  draw_grid_paint (vuue, org, clip);
  return NULL;
}

os_error *draw_displ_eor_grid (viewrec *vuue)

{ ftracef0 ("draw_displ_eor_grid\n");
  return update_this_view (vuue, draw_displ_paint_grid);
}

/* ------------------------------------------------------- */

/* Redraw the last 'len' lines of the path                 */
/*                                                         */
/* ptw,ptx,pty,ptz are points in the database              */
/* where ptz is the pointer position                       */
/*                                                         */
/*                                                         */
/* len=1 means paint      pty-ptz if -pty is straight      */
/*                    ptx-pty-ptz if -pty is curved        */
/*                                                         */
/* len=2 means paint      ptx-pty-ptz if -ptx is straight  */
/*                    ptw-ptx-pty-ptz if -ptx is curved    */
/*                                                         */
static os_error *redraw_path_bands (diagrec *diag, int len,
    draw_objcoord *org)

{ int blobjoint = (len == 2);
  drawmod_pathelemptr pt[4];
  int hdroff = *(int*) (diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;
  os_error *error;

  ftracef0 ("redraw_path_bands\n");
  hdrptr.bytep = (diag->paper + hdroff);

  pt[0].bytep = diag->misc->ptz_off + diag->paper;      /* z */
  pt[1].bytep = diag->misc->pty_off + diag->paper;      /* y */
  pt[2].bytep = diag->misc->ptx_off + diag->paper;      /* x */
  pt[3].bytep = diag->misc->ptw_off + diag->paper;      /* w */

  switch (diag->misc->substate)
  { case state_path:
    case state_path_move:
    default:
    return NULL;

    case state_path_point1:
      len = 1;              /* There is only one line */
    break;

    case state_path_point2:
      if (len != 1) { len = 2; break; }           /* plot both lines */
      /* len = 1; */

    case state_path_point3:                       /* look at pty (len=1) */
      if (pt[len].bezier->tag == path_bezier)     /*      or ptx (len=2) */
        len++;
      break;
  }

  if (blobjoint)
    paint_segment_blobs (hdrptr, pt[1], org, FALSE);

  if (pt[0].bezier->tag == path_bezier)
    blob_curve_b1 (pt[0].bezier, org);

  if (pt[1].bezier->tag == path_bezier)
    blob_curve_b2 (pt[1].bezier, org);

  /* Highlight the selected line */
  displ_gcol (3, draw_colours.skeleton, draw_colours.highlight);

  switch (pt[0].end->tag)
  { case path_move_2:
    case path_lineto:
      /* highlight line */
      if ((error = paint_line (org, pt [0].lineto, &dotty)) != NULL)
        return error;
    break;

    case path_bezier:
      /* highlight curve */
      if ((error = paint_curve (org, pt [0].bezier, &dotty)) != NULL)
    return error;
    break;
  }

  displ_gcol (3, draw_colours.skeleton, -1);    /* eor in grey */

  while (len-- > 0)
    switch (pt[len].end->tag)
    { case path_lineto:
        if ((error = paint_line (org, pt [len].lineto, 0)) != NULL)
          return error;
      break;

      case path_bezier:
        if ((error = paint_curve (org, pt [len].bezier, 0)) != NULL)
          return error;
      break;
    }

  return NULL;
}

static os_error *redraw_path_currnext (diagrec *diag, draw_objcoord *org)

{ draw_objptr hdrptr;
  drawmod_pathelemptr firstele,     /* start of subpath (->tag==MoveTo)  */
              currele,              /* current element (Move/Line/Curve) */
              nextele;              /* next (Move/Line/Curve/Close/Term) */
  int wrapok = diag->misc->pathedit_cb.cele_off >
      diag->misc->pathedit_cb.fele_off + sizeof (drawmod_path_movestr);
  int closed = 0;
  os_error *error;

  ftracef0 ("redraw_path_currnext\n");
  hdrptr.bytep   = diag->misc->pathedit_cb.sub_off  + diag->paper;
  firstele.bytep = diag->misc->pathedit_cb.fele_off + diag->paper;
  currele.bytep  = diag->misc->pathedit_cb.cele_off + diag->paper;
  nextele.bytep  = NULL;


/* Selected element may be a MoveTo, LineTo or CurveTo    */
/*                                                        */
/* N.B. if a Line or Curve, this will be red! (or dashed) */
/*      so eor this first to turn the red into grey       */
/*      then eor this plus next line in grey to remove    */
/*  (all to ensure endpoints and the dashed  lines used   */
/*   in monochrome modes clear properly)                  */

  displ_gcol (3, draw_colours.skeleton, draw_colours.highlight);

  switch (currele.end->tag)
  { case path_move_2:
      nextele.move2 = currele.move2 + 1;
      paint_point (currele.move2->x, currele.move2->y, org);
      blob_line (hdrptr, currele.lineto, 1, org);
    break;

    case path_lineto:
      nextele.lineto = currele.lineto + 1;

      closed = (nextele.closeline->tag == path_closeline);

      if ((error = paint_line (org, currele.lineto, &dotty)) != NULL)
        return error;
      displ_gcol (3, draw_colours.skeleton, -1);    /* eor in grey */
      if ((error = paint_line (org, currele.lineto, 0)) != NULL)
        return error;
      paint_point (currele.lineto->x, currele.lineto->y, org);
      blob_line (hdrptr, currele.lineto, 1 + closed/*JRC 5 Oct 1990*/, org);
    break;

    case path_bezier:
      nextele.bezier = currele.bezier + 1;

      closed = (nextele.closeline->tag == path_closeline);

      if ((error = paint_curve (org, currele.bezier, &dotty)) != NULL)
        return error;
      displ_gcol (3, draw_colours.skeleton, -1);    /* eor in grey */
      if ((error = paint_curve (org, currele.bezier, 0)) != NULL)
        return error;

      paint_point (currele.bezier->x3, currele.bezier->y3, org);

      blob_curve (hdrptr, currele.bezier, 1 + closed, org);
    break;
  }

  /*if next element is a close point nextele past the start of this subpath,
    but only if it contains >1 line/curve*/
  if (nextele.closeline->tag == path_closeline)
    if (wrapok)
      nextele.move2 = firstele.move2 + 1;

  displ_gcol (3, draw_colours.skeleton, -1);

  switch (nextele.end->tag)
  { case path_move_2:   /* current subpath                 - not closed */
    case path_term:     /* current subpath is last subpath - not closed */
    case path_closeline:/* current subpath is closed but has 1 line/curve */
    break;

    case path_lineto:
      if ((error = paint_line (org, nextele.lineto, 0)) != NULL)
        return error;
    break;

    case path_bezier:
      if ((error = paint_curve (org, nextele.bezier, 0)) != NULL)
        return error;
      blob_curve_b1 (nextele.bezier, org);
    break;
  }

  return NULL;
}

static os_error *redraw_path_prevcurr (diagrec *diag, draw_objcoord *org)

{ draw_objptr hdrptr;
  drawmod_pathelemptr
    firstele,
    prevele, /* previous (Move/Line/Curve) */
    currele; /* current element (Move/Line/Curve) */
  os_error *error;

  ftracef0 ("redraw_path_prevcurr\n");
  hdrptr.bytep   = diag->misc->pathedit_cb.sub_off  + diag->paper;
  firstele.bytep = diag->misc->pathedit_cb.fele_off + diag->paper;
  prevele.bytep  = diag->misc->pathedit_cb.pele_off + diag->paper;
  currele.bytep  = diag->misc->pathedit_cb.cele_off + diag->paper;

  if (prevele.bytep == firstele.bytep)
  { int last, term;
    (void) draw_edit_findsubpathend (diag, &last, &term);
    prevele.bytep = diag->paper + last;
  }

  /* Selected element may be a MoveTo, LineTo or CurveTo    */
  /*                                                        */
  /* N.B. if a Line or Curve, this will be red! (or dashed) */
  /*      so eor this first to turn the red into grey       */
  /*      then eor this plus next line in grey to remove    */
  /*  (all to ensure endpoints and the dashed  lines used   */
  /*   in monochrome modes clear properly)                  */

  displ_gcol (3, draw_colours.skeleton, draw_colours.highlight);

  switch (currele.end->tag)
  { case path_move_2:
      paint_point (currele.move2->x, currele.move2->y, org);
      blob_line (hdrptr, currele.lineto, 1, org);
    break;

    case path_lineto:
      if ((error = paint_line (org, currele.lineto, &dotty)) != NULL)
        return error;
      displ_gcol (3, draw_colours.skeleton, -1);    /* eor in grey */
      if ((error = paint_line (org, currele.lineto, 0)) != NULL)
        return error;
      paint_point (currele.lineto->x, currele.lineto->y, org);
      blob_line (hdrptr, currele.lineto, 1, org);
    break;

    case path_bezier:
      if ((error = paint_curve (org, currele.bezier, &dotty)) != NULL)
        return error;
      displ_gcol (3, draw_colours.skeleton, -1);    /* eor in grey */
      if ((error = paint_curve (org, currele.bezier, 0)) != NULL)
        return error;

      paint_point (currele.bezier->x3, currele.bezier->y3, org);

      blob_curve_b1 (currele.bezier, org);
      blob_curve_b2 (currele.bezier, org);
      blob_curve_ep (hdrptr, currele.bezier, 1, org);
    break;
  }

  displ_gcol (3, draw_colours.skeleton, -1);

  switch (prevele.end->tag)
  { case path_lineto:
      if ((error = paint_line (org, prevele.lineto, 0)) != NULL)
        return error;
    break;

    case path_bezier:
      if ((error = paint_curve (org, prevele.bezier, 0)) != NULL)
        return error;
      blob_curve_b2 (prevele.bezier, org);
    break;
  }

  return NULL;
}

static os_error *redraw_path_bands1 (diagrec *diag, draw_objcoord *org)

{ ftracef0 ("redraw_path_bands1\n");
  return redraw_path_bands (diag, 1, org);
}

static os_error *redraw_path_bands2 (diagrec *diag, draw_objcoord *org)

{ ftracef0 ("redraw_path_bands2\n");
  return redraw_path_bands (diag, 2, org);
}

/* ------------------------------------------------------------------------- */

os_error *draw_displ_eor_currnext (diagrec *diag)

{ ftracef0 ("draw_displ_eor_currnext\n");
  return update_each_view (diag, redraw_path_currnext);
}

os_error *draw_displ_eor_prevcurr (diagrec *diag)

{ ftracef0 ("draw_displ_eor_prevcurr\n");
  return update_each_view (diag, redraw_path_prevcurr);
}

os_error *draw_displ_eor_cons2 (diagrec *diag) /* show construction lines */

{ ftracef0 ("draw_displ_eor_cons2\n");
  return update_each_view (diag, redraw_path_bands1);
}

os_error *draw_displ_eor_cons3 (diagrec *diag) /* show construction lines */

{ ftracef0 ("draw_displ_eor_cons3\n");
  return update_each_view (diag, redraw_path_bands2);
}

os_error *draw_displ_eor_skeleton (diagrec *diag) /*show construction lines*/

{ os_error *error;

  ftracef0 ("draw_displ_eor_skeleton\n");
  error = update_each_view (diag, draw_displ_paint_skeleton);
  draw_displ_showcaret_if_up (diag);
  return error;
}

/* ---------------------------------------------------------------------- */

void draw_displ_eor_bbox (diagrec *diag, int obj_off)  /*show bounding box*/

{ viewrec        *vuue;
  draw_objptr    hdrptr;

  ftracef0 ("draw_displ_eor_bbox\n");
  hdrptr.bytep = diag->paper + obj_off;

  for (vuue = diag->view ; vuue != 0 ; vuue = vuue->nextview)
  { wimp_redrawstr r;

    if (r.w = vuue->w, r.w != 0)
    { int more = start_update (&r, vuue);
      draw_objcoord org;

      make_origin_os (&org, &r);

      while (more)
      { paint_bbox (hdrptr, &org);
        wimp_get_rectangle (&r, &more);
      }
    }
  }
}

/* ---------------------------------------------------------------------- */

int draw_displ_lineheight (diagrec *diag)

{ os_error *err;
  font fonth;
  int caretheight;
  int hdroff = *(int *) (diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;

  ftracef0 ("draw_displ_lineheight\n");
  hdrptr.bytep = diag->paper + hdroff;

  caretheight = hdrptr.textp->fsizey; /*If using system font OR if font
      manager gives an error */

  /*fsizex & fsizey are in 1/640ths point, current font managers take
    1/16ths point, so scale by 1/40 (ie 16/640)*/
  if (hdrptr.textp->textstyle.fontref)
  { err = font_find (draw_fontcat.name[hdrptr.textp->textstyle.fontref],
                    hdrptr.textp->fsizex/40, hdrptr.textp->fsizey/40,
                    0,0, &fonth);

    if (!err)
    { font_info f;

      if (err = font_readinfo (fonth, &f), !err)
        caretheight = f.maxy - f.miny << 8;
      font_lose (fonth);
    }
  }
  return caretheight;
}

void draw_displ_showcaret (viewrec *vuue)

{ os_error *err;
  font      fonth;
  int       caretXoffset, caretYoffset, caretheight;
  diagrec  *diag = vuue->diag;
  int         hdroff = *(int*) (diag->paper + diag->misc->stacklimit);
  draw_objptr hdrptr;

  ftracef0 ("draw_displ_showcaret\n");
  hdrptr.bytep = (diag->paper + hdroff);

  draw_displ_scalefactor = vuue->zoomfactor;

  caretXoffset = scaleZ ( hdrptr.textp->fsizex*strlen (hdrptr.textp->text));
  caretheight  = scaleZ ( hdrptr.textp->fsizey);
  caretYoffset = -caretheight/8;

  if (hdrptr.textp->textstyle.fontref)
  { err = font_find (draw_fontcat.name[hdrptr.textp->textstyle.fontref],
        scaleF (hdrptr.textp->fsizex), scaleF (hdrptr.textp->fsizey),
        0, 0, &fonth);

    if (!err)
    { font_info f;

      if (err = font_readinfo (fonth, &f), !err)
      { caretheight  = f.maxy - f.miny;     /* os coords */
        caretYoffset = f.miny;              /* os coords */
      }

      if (err = font_setfont (fonth), !err)
      { font_string fs;

        fs.s = hdrptr.textp->text;
        fs.x = 0x1000000;
        fs.y = 1000;

        if (err = font_findcaret (&fs), !err)
          caretXoffset = (fs.x*180/72000);   /* os coords */
      }

      font_lose (fonth);
    }
  }

  draw_set_caret (vuue->w, caretXoffset  + scaleT (0, hdrptr.textp->coord.x),
                          caretYoffset  + scaleT (0, hdrptr.textp->coord.y),
                          0x01000000 | caretheight);
}

/* Show caret if appropriate */
void draw_displ_showcaret_if_up (diagrec *diag)

{ ftracef3
      ("draw_displ_showcaret_if_up: diag 0x%X, owner 0x%X, state %d\n",
      diag, draw_enter_focus_owner.diag, diag->misc->substate);
  if (diag == draw_enter_focus_owner.diag)
    switch (diag->misc->substate)
    { case state_text_char:
      case state_text_caret:
        draw_displ_showcaret (draw_enter_focus_owner.vuue);
      break;
    }
}

static os_error *paint_highlightskeleton (diagrec *diag, draw_objcoord *org)

{ drawmod_pathelemptr currele;              /* selected element ptr */
  os_error *error;

  ftracef0 ("pant_highlightskeleton\n");
  if (diag->misc->pathedit_cb.cele_off >= 0)
  { currele.bytep = diag->misc->pathedit_cb.cele_off + diag->paper;

    displ_gcol (3, draw_colours.skeleton, draw_colours.highlight);

    switch (currele.end->tag)
    { case path_move_2:                          /* highlight endpoint */
        paint_point (currele.move2->x, currele.move2->y, org);
      break;

      case path_lineto:                   /* highlight line & endpoint */
        if ((error = paint_line (org, currele.lineto, &dotty)) != NULL)
          return error;
        paint_point (currele.lineto->x, currele.lineto->y, org);
      break;

      case path_bezier:                 /* highlight curve & endpoint */
        if ((error = paint_curve (org, currele.bezier, &dotty)) != NULL)
          return error;
        paint_point (currele.bezier->x3, currele.bezier->y3, org);
      break;
    }
  }

  return NULL;
}

os_error *draw_displ_eor_highlightskeleton (diagrec *diag)

{ ftracef0 ("draw_displ_eor_highlightskeleton\n");
  return update_each_view (diag, paint_highlightskeleton);
}

/* ---------------------------------------------------------------------- */
static os_error *vduq23 (int code, int x, int y)

{ ftracef0 ("vduq23\n");
  return bbc_vduq (23, 17, 7, code, x, x>>8, y, y>>8, 0, 0);
}

/* Set size & spacing of VDU5 characters, units are pixels */
os_error *draw_displ_setVDU5charsize (int xsize,  int ysize,
                                     int xspace, int yspace)

{ os_error *err;

  ftracef0 ("draw_displ_setVDU5charsize\n");
  draw_currentmode.gcharaltered = 1; /*so we restore before next pollwimp*/

  return
    (err = vduq23 (2, xsize, ysize)) != NULL?
      err:
      vduq23 (4, xspace, yspace);
}
