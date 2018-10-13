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

/* Title: c.resspr
 * Purpose: Common access to sprite resources
 * History: IDJ: 06-Feb-92: prepared for source release
 *
 */


#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "swis.h"
#include "sprite.h"
#include "res.h"
#include "wimp.h"
#include "werr.h"
#include "msgs.h"
#include "VerIntern/messages.h"

#include "resspr.h" /* Ensure consistent interface */

#define SPRITES11 /* Support for new Wimps */

static sprite_area *resspr__area = wimp_spritearea; /*defaults to using the wimp sprite pool*/

/* Having done res_init (argv [0]); the caller should do resspr_init ();
 * before dbox_init (); so that the latter can run over the icon defs and
 * rewrite the sprite pointers to use the sprites we've loaded
 */

#ifdef SPRITES11
static int sprite_rawload(char *file_name);
#endif

static int sprite_load(char *name)
{
    char file_name[40]; /* long enough for <ProgramName$Dir>.SpritesXX */
    res_findname(name, file_name);
    
#ifdef SPRITES11
    return sprite_rawload(file_name);
}

static int sprite_rawload(char *file_name)
{
#endif
    
    sprite_area *area;
    int f, fs;
    int size;

    f = _swi(OS_Find, _IN(0)|_IN(1), 0x47, file_name);
    if (!f) return 0;
    fs = _swi(OS_Args, _IN(0)|_IN(1)|_RETURN(2), 254, f) & 0xff;
    if (fs == 0x2e) {
        area = (sprite_area *)(_swi(OS_FSControl,
                                    _IN(0)|_IN(1)|_RETURN(1), 21, f) - 4);
    } else {
        size = _swi(OS_Args, _IN(0)|_IN(1)|_RETURN(2), 2, f);
        area = malloc(size + 4);
        if (!area) werr(TRUE, msgs_lookup(MSGS_resspr1), file_name);
        area->size = size + 4;
        _swi(OS_GBPB,
             _IN(0)|_IN(1)|_IN(2)|_IN(3), 4, f, &area->number, size);
    }
    _swi(OS_Find, _IN(0)|_IN(1), 0, f);
    resspr__area = area;
    return 1;
}

void resspr_init(void)
{
#ifdef SPRITES11
    char file_name[60]; /* long enough for <ProgramName$Dir>.<Wimp$IconTheme>SpritesXX */
    _kernel_oserror *e;
    int bufferspace = 0;
    
    res_prefixnamewithpath("<Wimp$IconTheme>Sprites", file_name);
    e = _swix(Wimp_Extend, _INR(0,3)|_OUT(3), 13, file_name, file_name, sizeof file_name, &bufferspace);
    if (bufferspace != sizeof file_name) /* Wimp_Extend 13 is supported on this Wimp */
    {
        if (e)
        {
            res_prefixnamewithdir("<Wimp$IconTheme>Sprites", file_name);
            e = _swix(Wimp_Extend, _INR(0,3), 13, file_name, file_name, sizeof file_name);
        }
        if (e)
        {
            res_prefixnamewithpath("Sprites", file_name);
            e = _swix(Wimp_Extend, _INR(0,3), 13, file_name, file_name, sizeof file_name);
        }
        if (e)
        {
            res_prefixnamewithdir("Sprites", file_name);
            e = _swix(Wimp_Extend, _INR(0,3), 13, file_name, file_name, sizeof file_name);
        }
        if (!e)
        {
            sprite_rawload(file_name);
        }
    }
    else /* fall back to old code in case of old Wimp */
    {
#endif
    char name[10];
    char *mode;

    mode = (char *)_swi(Wimp_ReadSysInfo, _IN(0), 2);
    /* Mode 24 is the default mode, ignore it */
    if (strcmp(mode, "24")) {
        strcpy(name, "Sprites");
        strcat(name, mode);
        if (sprite_load(name)) return;
    }
    sprite_load("Sprites");
#ifdef SPRITES11
    }
#endif
}


sprite_area *resspr_area (void)
{
  return resspr__area;
}

/* end of c.resspr */
