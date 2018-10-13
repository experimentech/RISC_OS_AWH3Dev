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
/* � Acorn Computers Ltd, 1992.                                         */
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

/* Title: c.pointer
 * Purpose:   Setting of the pointer shape
 * History: IDJ: 06-Feb-92: prepared for source release
 */


#include <stddef.h>
#include "os.h"
#include "sprite.h"
#include "pointer.h"

#define OS_SpriteOp 0x2E
#define Wimp_SpriteOp 0x400E9

static char pointer__ttab[] = "\0\1\2\3\0\1\2\3\0\1\2\3\0\1\2\3" ;

#pragma -s1

os_error *pointer_set_shape(sprite_area *area, sprite_id *spr,
                            int apx, int apy)
{
 os_error *result ;
 os_regset r ;

 if (area == sprite_mainarea || area == wimp_spritearea)
 {
  r.r[0] = 36;
  r.r[2] = (int) (spr->s.name);
 }
 else
 {
  r.r[1] = (int) area;
  if (spr->tag == sprite_id_addr)
  {
   r.r[0] = 512 + 36;
   r.r[2] = (int) (spr->s.addr);
  }
  else
  {
   r.r[0] = 256 + 36;
   r.r[2] = (int) (spr->s.name);
  }
 }
 r.r[3] = 2 ;     /* shape number */
 r.r[4] = apx ;   /* active point */
 r.r[5] = apy ;
 r.r[6] = 0 ;     /* scale appropriately */
 r.r[7] = (int) pointer__ttab ;
 result = os_swix(area == wimp_spritearea ? Wimp_SpriteOp : OS_SpriteOp, &r) ;
 if (result == NULL)
 {
  int x = 2 ;
  os_byte(106, &x, &x) ;
 }
 return result ;
}

/* restore pointer to shape 1  */
void pointer_reset_shape(void)
{
 int x = 1 ;
 os_byte(106, &x, &x) ;
}

#pragma -s0

/* end */
