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
/************************************************************************/
/* � Acorn Computers Ltd, 2010.                                         */
/*                                                                      */
/* This file forms part of an unsupported source release of RISC_OSLib. */
/*                                                                      */
/* It may be freely used to create executable images for saleable       */
/* products but cannot be sold in source form or as an object library   */
/* without the prior written consent of Acorn Computers Ltd.            */
/*                                                                      */
/* If this file is re-distributed (even if modified) it should retain   */
/* this copyright notice.                                               */
/*                                                                      */
/************************************************************************/

/*
 * Title  : c.jpeg
 * Purpose: rendering of JPEG format images with SpriteExtend
 *
 */

#include <stddef.h>
#include "jpeg.h"

#define JPEG_Info                       0x49980
#define JPEG_FileInfo                   0x49981
#define JPEG_PlotScaled                 0x49982
#define JPEG_PlotFileScaled             0x49983
#define JPEG_PlotTransformed            0x49984
#define JPEG_PlotFileTransformed        0x49985
#define JPEG_PDriverIntercept           0x49986 /* Used by PDriver, not apps */

#pragma -s1


os_error * jpeg_readinfo (const jpeg_id *id, jpeg_info *resultinfo)
{
  os_regset r;
  os_error *result;

  r.r[0] = 3; /* Request dimensions and SOF type */
  if (id->tag == jpeg_id_name)
  {
    /* File based JPEG */
    r.r[1] = (int)id->s.name;
    result = os_swix ( JPEG_FileInfo, &r );
    if (result == NULL)
    {
      resultinfo->encoding = (jpeg_encoding)((r.r[0] >> 3) & 0xF);
    }
    else
    {
      if (result->errnum == 0x712)
      {
        r.r[0] = 1; /* Got reserved-bit-was-set so do lowest common denominator */
        result = os_swix ( JPEG_FileInfo, &r );
        if (result == NULL)
          resultinfo->encoding = jpeg_encoding_BASELINE; /* Guesswork */
      }
    }
  }
  else
  {
    /* In memory JPEG */
    r.r[1] = (int)id->s.image.addr;
    r.r[2] = id->s.image.size;
    result = os_swix ( JPEG_Info, &r );
    if (result == NULL)
    {
      resultinfo->encoding = (jpeg_encoding)((r.r[0] >> 3) & 0xF);
    }
    else
    {
      if (result->errnum == 0x712)
      {
        r.r[0] = 1; /* Got reserved-bit-was-set so do lowest common denominator */
        result = os_swix ( JPEG_Info, &r );
        if (result == NULL)
          resultinfo->encoding = jpeg_encoding_BASELINE; /* Guesswork */
      }
    }
  }
  if (result == NULL) /* Only return result if no error */
  {
    resultinfo->width          = r.r[2];
    resultinfo->height         = r.r[3];
    resultinfo->xdensity       = r.r[4];
    resultinfo->ydensity       = r.r[5];
    resultinfo->extraworkspace = r.r[6];
    resultinfo->colourspace    = (r.r[0] & 1) ? jpeg_colour_GREYSCALE : jpeg_colour_YUV;
  }
  return result;
}

BOOL jpeg_arbitrary_trans_supported (void)
{
  /* This is useful to know but unfortunately the SpriteExtend API only reports its
   * capability as part of JPEG_[File]Info. So give it a minimalist fake JPEG.
   */
  static const char fake[] = { 0xFF, 0xD8 /* SOI */,
                               0xFF, 0xE0 /* APP0 */, 0x00, 0x0E,  /* 14 byte tag */
                                     0,0,0,0,0,0,0, 1, 0,90, 0,90, /* Density representation 1, 90x90 dpi */
                               0xFF, 0xC0 /* SOF0 */, 0x00, 0x08,  /* 8 byte tag */
                                     0,99, 0,99, 3,                /* 99x99 colour space YUV */
                               0xFF, 0xD9 /* EOI */
                             };
  int       flags;
  os_error *result;

  result = os_swix3r ( JPEG_Info, 0, fake, sizeof(fake),
                                  &flags, NULL, NULL );

  return (result == NULL) && ((flags & 2) == 0);
}

os_error * jpeg_put_scaled (const jpeg_id *id, int x, int y,
                            const sprite_factors *factors,
                            jpeg_put_flags flags)
{
  os_regset r;

  r.r[1] = x;
  r.r[2] = y;
  r.r[3] = (factors == NULL) ? 0 : (int)factors;
  if (id->tag == jpeg_id_name)
  {
    r.r[0] = (int)id->s.name;
    r.r[4] = (int)flags;
    return os_swix ( JPEG_PlotFileScaled, &r );
  }
  else
  {
    r.r[0] = (int)id->s.image.addr;
    r.r[4] = id->s.image.size;
    r.r[5] = (int)flags;
    return os_swix ( JPEG_PlotScaled, &r );
  }
}

os_error * jpeg_put_trans (const jpeg_id *id, jpeg_put_flags flags,
                           const sprite_box *box,
                           const sprite_transmat *trans_mat)
{
  os_regset r;

  if (box != NULL)
  {
    r.r[2] = (int)box;
    r.r[1] = 1 | (int)(flags << 1); /* Same basic flags as PlotScaled only shifted */
  }
  else
  {
    r.r[2] = (int)trans_mat;
    r.r[1] = 0 | (int)(flags << 1); /* Same basic flags as PlotScaled only shifted */
  }
  if (id->tag == jpeg_id_name)
  {
    r.r[0] = (int)id->s.name;
    return os_swix ( JPEG_PlotFileTransformed, &r );
  }
  else
  {
    r.r[0] = (int)id->s.image.addr;
    r.r[3] = id->s.image.size;
    return os_swix ( JPEG_PlotTransformed, &r );
  }
}


#pragma -s0

/* end of c.jpeg */
