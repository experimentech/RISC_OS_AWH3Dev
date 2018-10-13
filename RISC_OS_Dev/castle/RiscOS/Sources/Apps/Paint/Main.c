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
/* > c.Main
 *
 *  Paint: RISC OS sprite editor
 *   Main loop and resource loading
 *
 *  Author: A.P. Thompson
 *  Others:
 *     DAHE David Elworthy
 *     JRC  Jonathan Coxhead
 *     JSR  Jonathan Roach
 *     JAB  James Bye
 *     ECN  Edward Nevill
 *     CDP  Christopher Partington (Cambridge Systems Design)
 *     TMD  Tim Dobson
 *     OSS  Owen Smith
 *
 *  DAHE, 28 Aug  89 - internationalisation
 *        06 Sept 89 - make heap non compacting
 *        13 Sept 89 - get round static data init. problem for module
                         version
 *  JSR,  25 Oct  89 - Add save desk
 *  JAB,  02 Oct  90 - Changed 'Create Sprite Method'
 *  JAB,  17 Oct  90 - Auto-Opens create when new sprite filer window is
                         opened
 *  JAB,  30 Oct  90 - Added call to 'help.h' for interactive menu help
 *  JAB,  23 Jan  91 - Added 'Snapshot' to replace 'get screen area'
 *  JAB,  22 Mar  91 - Fixed templates
 *  JAB,  22 Mar  91 - Fixed timer corruption bug in snapshot
 *  JAB,  30 Apr  91 - Added function to check the modes before loading
 *  ECN,  13 Jan  92 - Set fixed stack size
 *  CDP,  20 Feb  92
 *     Added FIX7631: fixes G-RO-7631 (incorrect error message and empty window
 *     when loaded file does not exist).
 *     Added FIX0780: fixes RP-0780 (incorrect selection of sprite in 2-column
 *     full-info display mode).
 *     Added FIXSIGNAL: ensures that signal causes the error text to be printed
 *     rather than just "(%s)".
*   TMD,  17 Mar  92 - Made print_file call menus_do_print, not queue_print.
 *  OSS,  23 Mar  92 - RP-0716 - split into two directories in ResourceFS
 *                     so the application name can change on a RAM loaded
 *                     localisation.
 *  TMD,  25 Mar  92 - Change main_set_printer_data to only update
 *                     menus_print_where if the printer's bottom left origin
 *                     has actually changed.
 *  JRC  6th Feb 1995  Import JPEG's into sprites with full palette.
 */

#include <assert.h>
#include <ctype.h>
#include <kernel.h>
#include <limits.h>
#include <locale.h>
#include <signal.h>
#include <setjmp.h>
#include <stdarg.h>
#include <swis.h>
#include "Global/CMOS.h"
#include "Global/FileTypes.h"
#include "Global/OsBytes.h"
#include "Global/VduExt.h"

#include "pointer.h"
#include "akbd.h"
#include "alarm.h"
#include "baricon.h"
#include "bbc.h"
#include "colourtran.h"
#include "dboxquery.h"
#include "heap.h"
#include "help.h"
#include "flex.h"
#include "msgs.h"
#include "msgtrans.h"
#include "res.h"
#include "resspr.h"
#include "template.h"
#include "visdelay.h"
#include "werr.h"
#include "wimp.h"
#include "wimpt.h"
#include "xferrecv.h"
#include "jpeg.h"
#include "xfersend.h"

#define FILENAMEMAX 255

#include "ftrace.h"
#include "m.h"

#include "main.h"
#include "Menus.h"
#include "MenuD.h"
#include "PSprite.h"
#include "SprWindow.h"
#include "ToolWindow.h"
#include "Tools.h"
#include "Colours.h"
#include "AltRename.h"
#include "PaintLib.h"

#define FREEZE_STACK 0
#define CATCH_SIGNALS 1

#define EMPTY(s) ((s) [0] == '\0')
#define CLEAR(s) ((s) [0] =  '\0')

#define SIG_LIMIT 11 /*largest signal number + 1*/

#if FREEZE_STACK
  int __root_stack_size = 64*1024; /*64K*/
  extern _kernel_ExtendProc flex_dont_budge;
#endif

#define ICON_SPACE_SIZE 1200 /* For icons in the template */
#define DISPLAY_MARGIN 0
#define SPACE_FOR_HELP_TEXT (main_FILER_TextHeight+DISPLAY_MARGIN)

typedef
  struct
  { BOOL     active;          /*snapshot being taken*/
    BOOL     first;           /*used by the alarm callback*/
    BOOL     delay;           /*whether there is a delay*/
    int      user_sec;        /*seconds field in dbox*/
    int      snap_now;        /*time to snap*/
    BOOL     whole_screen;    /*grab whole screen?*/
    wimp_box box;             /*area to snap if not*/
    BOOL     want_timer;      /*display timer dbox?*/
    dbox     timer;           /*handle if so*/
  }
  snapshotstr;

main_window *main_windows;

main_options main_current_options;

const wimp_box main_big_extent =
    {-0x1FFFFFFF, -0x1FFFFFFF, 0x1FFFFFFF, 0x1FFFFFFF};

/**************************************************************************
 *                                                                        *
 *  Static variables.                                                     *
 *                                                                        *
 **************************************************************************/

static main_template file_template;

static menu main_menu;

static main_file fudgefile =
      {NULL, NULL, NULL, NULL, 0, 0, 1, 0, NULL /* &fudgewindow */};

static main_window fudgewindow = { NULL, 0, main_window_is_file,
                              NULL /* (main_info_block *) &fudgefile */ };

static char *ramfetch_buffer = NULL;

static char Paint_Dir [FILENAME_MAX + 1];
            
static void init_statics (void)

{ /* Required to generate relocatable code */
  fudgefile.window = &fudgewindow;
  fudgewindow.data = (main_info_block *)&fudgefile;
  main_windows    = &fudgewindow;
}

static
  main_options
    initial_options =
    { {/*full info?*/ FALSE, /*use desktop colours?*/ TRUE},
      {/*show colours?*/ TRUE, /*small colours?*/ FALSE},
      {/*show tools?*/ TRUE},
      {/*zoom*/ 1, 1},
      {/*grid?*/ TRUE, /*colour*/ 7},
      {/*extended*/ TRUE /*always on in versions from Black onwards*/}
    };

static
  snapshotstr
    sshot =
    { /*active?*/ FALSE,
      /*first?*/ FALSE,
      /*delay?*/ FALSE,
      /*user_sec*/ 10,
      /*snap_now*/ 0,
      /*whole_screen?*/ FALSE,
      /*box*/ {0, 0, 0, 0},
      /*want_timer?*/ TRUE,
      /*timer*/ NULL
    };

#define MAX_OPTIONS 80

#if CATCH_SIGNALS
  static jmp_buf Buf;
  static void Signal_Handler (int signal) {longjmp (Buf, signal);}
  static void (*Saved_Handlers [SIG_LIMIT]) (int);
#endif

/*******************************************************************
 * Now the code                                                    *
 *******************************************************************/

static void main_clear_background (wimp_redrawstr *rds)

{ sprite_area *base;
  sprite_area *rombase;
  sprite_pixtrans transtab[16];
  sprite_info sinfo;
  sprite_id sid;
  int dummy;
  BOOL use_sprite;
  BOOL scaled = FALSE;
  BOOL use_transtab = FALSE;
  char name[NAME_LIMIT + 1];

  /* Test tiling disabled in CMOS */
  os_byte (OsByte_ReadCMOS, (dummy = DesktopFeaturesCMOS, &dummy), &use_sprite);
  use_sprite = (use_sprite & desktopwindowtile) == 0;

  if (use_sprite)
  { /* Find tile sprite for mode */
    os_swix2r (Wimp_BaseOfSprites, 0, 0, &rombase, &base);
    sprintf (name, "tile_1-%d", 1<<bbc_vduvar (bbc_Log2BPP));
    sid.s.name = name;
    sid.tag = sprite_id_name;
    if (sprite_readsize (base, &sid, &sinfo) != NULL)
    { if (sprite_readsize (rombase, &sid, &sinfo) != NULL)
        use_sprite = 0;
      base = rombase;
    }
    int mode_log2bpp = bbc_vduvar (bbc_Log2BPP);
    int sprite_log2bpp = bbc_modevar (sinfo.mode, bbc_Log2BPP);
    if ((mode_log2bpp != sprite_log2bpp)
     || ((bbc_vduvar (bbc_ModeFlags) ^ bbc_modevar (sinfo.mode, bbc_ModeFlags)) & (ModeFlag_FullPalette | ModeFlag_64k | ModeFlag_DataFormat_Mask))
     || (bbc_vduvar (bbc_NColour) != bbc_modevar (sinfo.mode, bbc_NColour)))
    { scaled = TRUE;
      /* Wimp translation tables only possible for <=8bpp screen and <4bpp sprite. We should probably be asking ColourTrans for a table instead. */
      if ((mode_log2bpp < 4) && (sprite_log2bpp < 3))
      {
        use_transtab = TRUE;
        if (wimp_readpixtrans (base, &sid, NULL, transtab) != NULL)
          use_sprite = 0;
      }
    }
  }
  
  if (use_sprite)
  { int left, top;

    /* Adjust for eigen factors */
    sinfo.width <<= bbc_vduvar (bbc_XEigFactor);
    sinfo.height <<= bbc_vduvar (bbc_YEigFactor);

    left = WORKAREA_TO_SCREEN_X(rds, 0);
    left = left + (((left - rds->g.x0)/sinfo.width) * sinfo.width);
    top = WORKAREA_TO_SCREEN_Y(rds, 0);
    top = top - (((top - rds->g.y1)/sinfo.height) * sinfo.height);

    /*werr(0, "%d %d %d %d %d", left, top, width, height, rds->g.y0);*/

    for (; top>rds->g.y0; top -= sinfo.height)
    { int x;
      for (x = left; x < rds->g.x1; x += sinfo.width)
      { if (scaled)
          use_sprite = (sprite_put_scaled (base, &sid, 0, x, top - sinfo.height, NULL, (use_transtab?transtab:NULL)) == NULL);
        else
          use_sprite = (sprite_put_given (base, &sid, 0, x, top - sinfo.height) == NULL); 
        if (!use_sprite) break;
      }
    }
  }

  if (!use_sprite)
  { wimp_paletteword palette_grey;

    palette_grey.word = (int)0xdfdfdf00; /* background_colour */
    wimpt_noerr (colourtran_setGCOL (palette_grey, 1 << 7, 0, &dummy));
    bbc_clg ();
  }
}

os_error *main_read_pixel (sprite_area *area, sprite_id *id,
    int x, int y, sprite_colour *colour)

{ os_error *error = NULL;
  os_regset reg_set;
  int pal_size;
  sprite_header *header;

  /*This routine is used instead of sprite_readpixel, which is badly
    broken under Medusa. J R C 24th Feb 1994*/

  reg_set.r [0] = 37 /*create/remove palette*/;

  if (id->tag == sprite_id_addr)
  { reg_set.r [0] |= 512;
    reg_set.r [2] = (int) id->s.addr;
  }
  else
  { if (area != NULL) reg_set.r [0] |= 256;
    reg_set.r [2] = (int) id->s.name;
  }

  reg_set.r [1] = (int) area;

  reg_set.r [3] = -1 /*read palette size*/;

  if ((error = os_swix (OS_SpriteOp, &reg_set)) != NULL)
    goto finish;

  pal_size = reg_set.r [3];
  ftracef1 ("palette size is %d\n", pal_size);

  if (pal_size == 256)
  { /*Must do this "by hand."*/
    if ((error = sprite_select_rp (area, id, (sprite_ptr *) &header)) !=
        NULL)
      goto finish;

    ftracef4 ("width %d, height %d, image %d, lbit %d\n",
        header->width, header->height, header->image, header->lbit);

    colour->colour =
        ((char *) (((int *) ((char *) header + header->image) +
        (header->width + 1)*(header->height - y)))) [header->lbit/8 + x];
    colour->tint = 0;

    ftracef4 ("read_pixel from (%d, %d) -> (%d, %d)\n",
        x, y, colour->colour, colour->tint);
  }
  else
    /*All other cases o k.*/
    if ((error = sprite_readpixel (area, id, x, y, colour)) == NULL)
      goto finish;

finish:
  if (error != NULL) ftracef1 ("got error %s\n", error->errmess);
  return error;
}

static int mouseX;
static int mouseY;

static int mouseB (void)

{ os_regset r;

  ftracef0 ("mouseB\n");
  os_swix (OS_Mouse, &r);
  mouseX=r.r[0];
  mouseY=r.r[1];
  return r.r[2];
}

static sprite_header *main_make_newjpeg (sprite_area *area, int size, jpeg_info *info)

{ sprite_header *header;
  int log2bpp = bbc_modevar (-1, bbc_Log2BPP);

  area->size    = size + sizeof (sprite_area);
  area->number  = 1;
  area->sproff  = 16;
  area->freeoff = size + sizeof (sprite_area);

  header = (sprite_header *)((char *)area + sizeof (sprite_area));
  header->next = size;
  strcpy (header->name, "!newjpeg");
  header->width  = ((info->width << log2bpp) - 1)/32;
  header->height = info->height - 1;
  header->lbit   = 0;
  header->rbit   = (info->width << log2bpp) - 32 * header->width - 1;
  header->image  =
  header->mask   = sizeof (sprite_header) +
                   (log2bpp <= 3 ? 8 << (1 << log2bpp) : 0);
  header->mode   = log2bpp + 1 << 27 | 180/wimpt_dy () << 14 |
                   180/wimpt_dx () << 1 | 1;

  return header;
}

static os_error *main_plot_fromjpeg (sprite_area *area, sprite_header *header, jpeg_id *jid)

{ os_error *error;
  int       s1, s2, s3;

  /* Switch to sprite, plot the JPEG */
  error = os_swix4r (OS_SpriteOp, 0x23C, area, header, 0,
                                  NULL, &s1, &s2, &s3);
  if (error != NULL) return error;

  error = jpeg_put_scaled (jid, 0, 0, NULL,
                           jpeg_PUT_DITHER_ENABLE | jpeg_PUT_ERROR_DIFFUSED_DITHER);

  /* Unconditionally switch back */
  os_swix4 (OS_SpriteOp, 0x23C, s1, s2, s3);

  return error;
}

static void main_icon_bboxes (main_window *window, main_sprite *sprite, wimp_box *iniconbbox,
                              wimp_box *spritebbox, wimp_box *namebbox)

{ /* Return the bounding boxes for this sprite */
  psprite_info sinfo;
    
  psprite_read_full_info (sprite, &sinfo);

  if (namebbox != NULL)
  { int width;
    os_swix3r (Wimp_TextOp, 1, sinfo.name, 0, &width, NULL, NULL);
    width += 16;
  
    if (window->data->file.fullinfo)
    { namebbox->x0 = iniconbbox->x0 + 6*main_FILER_TextWidth;
      namebbox->x1 = namebbox->x0 + width;
      namebbox->y0 = iniconbbox->y0 + main_FILER_TextHeight;
      namebbox->y1 = namebbox->y0 + main_FILER_TextHeight;
    }
    else
    { namebbox->x0 = (iniconbbox->x0 + iniconbbox->x1 - width)/2;
      namebbox->x1 = namebbox->x0 + width;
      namebbox->y0 = iniconbbox->y0;
      namebbox->y1 = namebbox->y0 + main_FILER_TextHeight;
    }
  }

  if (spritebbox != NULL)
  { int swidth, sheight;
    swidth = sinfo.width * sprite->iconsize.scale_xmul/sprite->iconsize.scale_xdiv;
    swidth = swidth * sprite->mode.scale_xmul;
    sheight = sinfo.height * sprite->iconsize.scale_ymul/sprite->iconsize.scale_ydiv;
    sheight = sheight * sprite->mode.scale_ymul;

    if (window->data->file.fullinfo)
    { spritebbox->x0 = iniconbbox->x0 + main_FILER_Border/2;
      spritebbox->x1 = spritebbox->x0 + swidth;
      spritebbox->y0 = iniconbbox->y0 + main_FILER_Border/2;
      spritebbox->y1 = spritebbox->y0 + sheight;
    }
    else
    { spritebbox->x0 = (iniconbbox->x0 + iniconbbox->x1-swidth)/2;
      spritebbox->x1 = spritebbox->x0 + swidth;
      spritebbox->y0 = iniconbbox->y1 - (main_FILER_Border + main_FILER_YSize + sheight)/2;
      spritebbox->y1 = spritebbox->y0 + sheight;
    }
  }
}

void main_iprintf (int flags, int x, int y, char *format, ...)

{ char s [500];
  va_list list;
  wimp_icon icon;
  int width;

  ftracef0 ("main_iprintf\n");

  va_start (list, format);
  vsprintf (s, format, list);
  va_end (list);

  if (flags & wimp_IFONT)
    width = 16*strlen (s);
  else
  { os_swix3r (Wimp_TextOp, 1, s, 0, &width, NULL, NULL);
    width/=2;
    width+=8;
  }

  if (flags & wimp_IHCENTRE)
  { icon.box.x0 = x - width;
    icon.box.x1 = x + width;
  }
  else if (flags & wimp_IRJUST)
  { icon.box.x0 = x - 2*width;
    icon.box.x1 = x;
  }
  else
  { icon.box.x0 = x;
    icon.box.x1 = x + 2*width; /*be on the safe side*/
  }

  icon.box.y0 = y - main_FILER_TextHeight;
  icon.box.y1 = y;

  icon.flags = (wimp_iconflags) (flags | wimp_ITEXT | wimp_INDIRECT | 7 << 24);
  icon.data.indirecttext.buffer = s;
  icon.data.indirecttext.validstring = (char *) -1;

  wimpt_noerr (wimp_ploticon (&icon));
}

static int escape (void)

{ return bbc_inkey (-113) || bbc_inkey (-45);
}

/******************************************
 * Snapshot functions - external for      *
 *                      'menu.c' access   *
 ******************************************/

static BOOL get_snapshot_box (wimp_box *box)

{ int x0 = 0, y0 = 0, x1 = 0, y1 = 0;

  ftracef0 ("get_snapshot_box\n");
  if (!sshot.whole_screen)
  { sprite_id id;

    id.s.name = "grabptr";
    id.tag    = sprite_id_name;
    pointer_set_shape (resspr_area (), &id, 0, 0);

    ftracef0 ("wait for button down\n");
    while (!(mouseB () & 4))
      if (escape ())
      { pointer_reset_shape ();
        return FALSE;
      }

    x1 = x0 = mouseX;
    y1 = y0 = mouseY;

    os_swi2 (OS_SetColour, 3, -1);
  #if 0
    /*replaces the following, avoiding need to check full-palette bit*/
    bbc_gcol (3, 127);
    bbc_tint (2 /*was 4?? JRC 27 Aug 1991*/, 3);
  #endif

    bbc_rectangle (x0, y0, x1 - x0, y1 - y0);
    ftracef0 ("wait for button up\n");
    while (mouseB () & 4)
    { if (mouseX != x1 || mouseY != y1)
      { bbc_rectangle (x0, y0, x1 - x0, y1 - y0);
        if (escape ())
        { pointer_reset_shape ();
          return FALSE;
        }
        x1 = mouseX;
        y1 = mouseY;
        bbc_rectangle (x0, y0, x1 - x0, y1 - y0);
      }
    }
    bbc_rectangle (x0, y0, x1 - x0, y1 - y0);
    pointer_reset_shape ();
  }
  else
  { ftracef0 ("User wants whole screen\n");

    x0 = 0;
    y0 = 0;
    x1 = bbc_vduvar (bbc_XWindLimit) << bbc_vduvar (bbc_XEigFactor);
    y1 = bbc_vduvar (bbc_YWindLimit) << bbc_vduvar (bbc_YEigFactor);
  }

  box->x0 = x0, box ->y0 = y0, box->x1 = x1, box->y1 = y1;

  return TRUE;
}

/* smile for the camera */
static void snapshot_happysnapper (int x0, int y0, int x1, int y1)

{ main_sprite tempsprite;
  int width, height, dx, xt, size;
  main_file tsfb;
  sprite_id sid;
  os_error *error = NULL;
  BOOL found_translation = FALSE;

  ftracef4 ("snapshot_happysnapper: x0 %d, y0 %d; x1 %d, y1 %d\n",
      x0, y0, x1, y1);
  tsfb.spritearea = NULL;
  dx   = wimpt_dx ();
  if (x1 < x0) {int t = x1; x1 = x0; x0 = t;}
  xt = x0 & ~ ((32 >> bbc_modevar (-1, bbc_Log2BPC))*dx - 1);
                              /* round down to word boundary */
  ftracef5 ("snapshot_happysnapper: x0 %d (xt %d), y0 %d;"
    " x1 %d, y1 %d\n", x0, xt, y0, x1, y1);
  width = (x1 - xt)/dx + 2;
  if (y1 < y0) {int t = y1; y1 = y0; y0 = t;}
  height = (y1 - y0)/wimpt_dy () + 2;

  size = psprite_size (width, height, wimpt_mode (), /*mask?*/ 0, /*palette?*/ 2) +
      sizeof (sprite_area) + 256;
  ftracef3 ("snapshot_happysnapper: need %d (%dx%d) bytes\n",
     size, width, height);
  if (flex_alloc ((flex_ptr) &tsfb.spritearea, size) == 0)
  { error = main_error ("PntEG");
    goto finish;
  }

  sprite_area_initialise (tsfb.spritearea, size);

  ftracef1 ("capturing sprite as \"%s\"\n", msgs_lookup ("PntF8"));
  /*First try with a palette, then without. J R C 6th Dec 1993*/
  if ((error = sprite_get_given_rp (tsfb.spritearea, msgs_lookup ("PntF8"),
      sprite_haspalette, xt /*JRC*/, y0, x1, y1, &sid.s.addr)) != NULL &&
      (error = sprite_get_given_rp (tsfb.spritearea, msgs_lookup ("PntF8"),
      sprite_nopalette, xt, y0, x1, y1, &sid.s.addr)) != NULL)
    goto finish;
  ftracef0 ("capturing sprite done\n");
  sid.tag = sprite_id_addr;

  /* fake main_sprite  */
  tempsprite.file            = &tsfb;
  tempsprite.offset          = (int) sid.s.addr - (int) tsfb.spritearea;
  tempsprite.spriteno        = 0;
  tempsprite.mode.scale_xmul =
  tempsprite.mode.scale_xdiv = 1 << bbc_modevar (-1, bbc_XEigFactor);
  tempsprite.mode.scale_ymul =
  tempsprite.mode.scale_ydiv = 1 << bbc_modevar (-1, bbc_YEigFactor);
                                 /* might be needed for printing!*/
  ftracef1 ("snapshot_happysnapper: offset: %d\n", tempsprite.offset);
  menus_hack_palette (&tempsprite);
  /* Create a translation table. If you don't do this, you get
     fatal overwriting on saving the screen area to the printer
  */
  ftracef0 ("calling psprite_ttab_for_sprite ()\n");
  if ((tempsprite.transtab = psprite_ttab_for_sprite (&tempsprite,
      -1, (int *) -1)) == NULL)
  { error = main_error ("PntEG");
    goto finish;
  }
  found_translation = TRUE;

  /*JRC 24th Nov 1993*/
  sprwindow_remove_wastage (&tempsprite);

  menus_save_sprite (&tempsprite); /* save via xfersend */

  sid.tag = sprite_id_addr;
  sid.s.addr = psprite_address (&tempsprite);
  sprite_delete (tsfb.spritearea, &sid);

finish:
  /*Check there is a translation table first. JRC 31st Jan 1995*/
  if (found_translation)
  { /* Discard the translation table */
    psprite_drop_translation (&tempsprite.transtab);
  }
  if (tsfb.spritearea != NULL) flex_free ((flex_ptr) &tsfb.spritearea);
  pointer_reset_shape ();

  wimpt_complain (error);
}

static void Timer_Cb (dbox d, void *h)

{ /*Callback for timer events - the only one is Cancel.*/
  ftracef0 ("Timer_Cb\n");
  h = h;

  switch (dbox_get (d))
  { case d_SnapshotTimer_Cancel:
      ftracef0 ("cancel hit\n");

      /*Cancel the snapshot.*/
      sshot.active = FALSE;

      alarm_removeall ((void *) sshot.snap_now);

      /*Kill the timer.*/
      dbox_dispose (&sshot.timer);
      sshot.timer = NULL;
    break;
  }
}

static void Snapshot_Cb (int due, void *h)

{ /*Callback for the second timer, ending in a call to take the snapshot.*/
  int time_now, time_left, secs_left;

  ftracef0 ("Snapshot_Cb\n");
  due = due, h = h; /*for Norcroft*/
  time_now = alarm_timenow ();

  if (sshot.first)
  { if (!get_snapshot_box (&sshot.box))
    { sshot.active = FALSE;
      return; /*do nothing - escape pressed*/
    }
    time_now = alarm_timenow (); /*might be much later now ...*/

    if (sshot.delay)
    { sshot.snap_now = time_now + 100*sshot.user_sec;

      if (sshot.want_timer)
      { if ((sshot.timer = dbox_new ("snpshottime")) != NULL)
        { dbox_showstatic (sshot.timer);
          dbox_eventhandler (sshot.timer, &Timer_Cb, NULL);
        }
      }
      else
        sshot.timer = NULL;
    }
    else
    { sshot.snap_now = time_now;
      sshot.timer = NULL;
    }

    sshot.first = FALSE;
  }

  time_left = alarm_timedifference (time_now, sshot.snap_now);
  ftracef1 ("Snapshot_Cb called with %dcs left to go\n", time_left);
  secs_left = time_left > 0? (time_left + 99)/100 /*round up!*/: 0;

  if (sshot.timer != NULL)
  { /*Update the dbox.*/
    dbox_setnumeric (sshot.timer, d_SnapshotTimer_SecsLeft, secs_left);

    if (secs_left <= 1)
    { /*Kill it.*/
      dbox_dispose (&sshot.timer);
      sshot.timer = NULL;
    }
  }

  if (secs_left == 0)
  { /*Smile for the camera.*/
    ftracef0 ("ACTUALLY GRABBING NOW\n");
    snapshot_happysnapper (sshot.box.x0, sshot.box.y0, sshot.box.x1,
        sshot.box.y1);
    sshot.active = FALSE;
  }
  else
    /*Queue the next call to this routine.*/
    alarm_set (sshot.snap_now - 100*(secs_left - 1), &Snapshot_Cb,
        (void *) sshot.snap_now);
}
/*------------------------------------------------------------------------*/
static BOOL snapshot_raw_event_handler (dbox d, void *event, void *h)

{ BOOL handled = FALSE;

  ftracef0 ("snapshot_raw_event_handler\n");
  h = h; /*for Norcroft*/

  if (help_dboxrawevents (d, event, (void *) "PntHE"))
    return TRUE;

  /*We handle the E S G here, since I don't trust the WIMP: it gets Adjust
    clicks wrong (ending up with nothing selected).*/
  switch (((wimp_eventstr *) event)->e)
  { case wimp_EBUT:
      switch (((wimp_eventstr *) event)->data.but.m.i)
      { case d_Snapshot_NoDelay:
          dbox_setnumeric (d, d_Snapshot_UserDef, !dbox_getnumeric (d,
              d_Snapshot_NoDelay));
          handled = TRUE;
        break;

        case d_Snapshot_UserDef:
          dbox_setnumeric (d, d_Snapshot_NoDelay, !dbox_getnumeric (d,
              d_Snapshot_UserDef));
          handled = TRUE;
        break;
      }
    break;

    /*Fix MED-3201: removed this! J R C 8th Jun 1994*/
    /*case wimp_EKEY:
      handled = TRUE;
    break;*/
  }

  /*Make sure the User defined seconds field is faded if necessary.*/
  if (!dbox_getnumeric (d, d_Snapshot_UserDef))
    dbox_fadefield (d, d_Snapshot_UserSec);
  else
    dbox_unfadefield (d, d_Snapshot_UserSec);

  return handled;
}

/*show snapshot window*/
void main_snapshot_show (void)

{ BOOL open;
  dbox d;

  ftracef0 ("main_shapshot_show\n");
  if (sshot.active)
  { werr (FALSE, msgs_lookup ("PntHF"));
    return;
  }

  ftracef0 ("showing snapshot\n");

  if ((d = dbox_new ("snapshot")) == 0)
    return;

  /*Set all fields to default values.*/
  dbox_setnumeric (d, d_Snapshot_NoDelay,  !sshot.delay);
  dbox_setnumeric (d, d_Snapshot_UserDef,   sshot.delay);
  dbox_setnumeric (d, d_Snapshot_UserSec,   sshot.user_sec);
  dbox_setnumeric (d, d_Snapshot_WholeScr,  sshot.whole_screen);
  dbox_setnumeric (d, d_Snapshot_ShowTimer, sshot.want_timer);

  /*Make sure the User defined seconds field is faded if necessary.*/
  if (!sshot.delay)
    dbox_fadefield (d, d_Snapshot_UserSec);
  else
    dbox_unfadefield (d, d_Snapshot_UserSec);

  /*Supply raw event handler for help messages etc.*/
  dbox_raw_eventhandler (d, &snapshot_raw_event_handler, NULL);

  ftracef4 ("created dbox: delay %d, user_sec %d, "
      "whole_screen %d, want_timer %d\n", sshot.delay, sshot.user_sec,
      sshot.whole_screen, sshot.want_timer);

  dbox_show (d);
  open = TRUE;

  while (open)
  { wimp_i i = dbox_fillin (d);

    ftracef1 ("event on icon %d\n", i);

    switch (i)
    { case d_Snapshot_Go:
        ftracef0 ("Get current values from template\n");
        sshot.active        = TRUE;
        sshot.first         = TRUE;
        sshot.delay         = dbox_getnumeric (d, d_Snapshot_UserDef);
        sshot.user_sec      = dbox_getnumeric (d, d_Snapshot_UserSec);
        sshot.whole_screen  = dbox_getnumeric (d, d_Snapshot_WholeScr);
        sshot.want_timer    = dbox_getnumeric (d, d_Snapshot_ShowTimer);

        ftracef4 ("read dbox: delay %d, snap_now %s, "
            "whole_screen %s, want_timer %s\n", sshot.delay,
            WHETHER (sshot.snap_now), WHETHER (sshot.whole_screen),
            WHETHER (sshot.want_timer));

        /*Set an immediate alarm to do all this.*/
        alarm_set (alarm_timenow (), &Snapshot_Cb, NULL);

        dbox_hide (d);
        open = FALSE;
      break;

      case dbox_CLOSE:
        open = FALSE;
      break;
    }
  }

  dbox_dispose (&d);
}

/* Claim idle events */
/* From RISCOSlib on (rather than cwimp, when we claim idle events, we must
   change the wimp's event mask
 */
void main_claim_idle (wimp_w window)

{ ftracef0 ("main_claim_idle\n");
  event_setmask ((wimp_emask) (window == -1? event_getmask () | wimp_EMNULL:
      event_getmask () & ~wimp_EMNULL));
  win_claim_idle_events (window);
}

os_error *main_error (char *token)

{ static os_error Error;

  ftracef0 ("main_error\n");

  Error.errnum = 1;
  sprintf (Error.errmess, "%.*s", sizeof Error.errmess - 1,
      msgs_lookup (token));

  return &Error;
}

static int ramfetch_buffer_extender (char **buffer, int *size)

{ int currsize = flex_size ((flex_ptr) &ramfetch_buffer);

  ftracef1 ("ramfetch_buffer_extender: extend ram buffer from %d\n",
      currsize);
  *buffer = (char *) ramfetch_buffer + currsize;
  *size = 256;
  return flex_extend ((flex_ptr) &ramfetch_buffer, currsize + 256);
}

static BOOL ramtransfer_file (wimp_msgdatasave *ms)

{ int size, import = -1, file_type, sprite_size,
      ram_size, log2_bpp = bbc_modevar (-1, bbc_Log2BPP);
  sprite_area *area;
  sprite_header *header;

  ftracef0 ("ramtransfer_file\n");
  /*only interested in sprites*/
      /*and jpeg's. J R C 27th Jun 1994*/
  if (!((file_type = xferrecv_checkimport (&size)) == FileType_Sprite ||
      file_type == FileType_JPEG))
  { werr (FALSE, msgs_lookup ("PntEB"), ms->leaf);
    return FALSE;
  }

  /*Don't allocate a buffer of size nought - it's wrong! 6 Aug 1991*/
  if (size <= 0) size = 256;

  ftracef1 ("flexalloc RAM buffer size %d\n", size);
  if (!flex_alloc ((flex_ptr) &ramfetch_buffer, size))
  { main_NO_ROOM ("RAM buffer");
    return FALSE;
  }

  /*Initialise the area (harmless for JPEG's). If no bytes arrive, it's
    empty. If 4 or 8 bytes arrive, we're dead.*/
  ((int *) ramfetch_buffer) [0] = 0;
  ((int *) ramfetch_buffer) [1] = 16;
  ((int *) ramfetch_buffer) [2] = 16;

  import = xferrecv_doimport (ramfetch_buffer, size,
      &ramfetch_buffer_extender);
  ftracef1 ("doimport returned %d\n", import);

  if (import == -1)
  { flex_free ((flex_ptr) &ramfetch_buffer);
    return FALSE;
  }

  if (file_type == FileType_JPEG)
  { jpeg_id   jid;
    jpeg_info jinfo;
    
    /*For JPEG's, we find it convenient to read the file data into
      |ramfetch_buffer| (since that is how ramfetch_buffer_extender() is set
      up), then read the consequent sprite size, malloc that much space,
      paint the sprite and copy it back into |ramfetch_buffer|.*/
    ram_size = flex_size ((flex_ptr) &ramfetch_buffer);

#ifdef XTRACE
    { char cmd [128];
      sprintf (cmd, "%%Save $.JPEG %X +%X", ramfetch_buffer, ram_size);
      os_cli (cmd);
    }
#endif

    jid.s.image.addr = ramfetch_buffer;
    jid.s.image.size = ram_size;
    jid.tag = jpeg_id_addr;
    if (wimpt_complain (jpeg_readinfo (&jid, &jinfo)) != NULL)
    { flex_free ((flex_ptr) &ramfetch_buffer);
      return FALSE;
    }

    sprite_size = psprite_size (jinfo.width, jinfo.height, wimpt_mode (),
                                FALSE /*mask?*/, 2 /*full palette*/);
  
    if ((area = m_ALLOC (sprite_size + sizeof (sprite_area))) == NULL)
    { flex_free ((flex_ptr) &ramfetch_buffer);
      return FALSE;
    }

    /*Create an empty sprite called '!newjpeg' in area*/
    header = main_make_newjpeg(area, sprite_size, &jinfo);

    /*Set the name with a sprite op to get the case right.*/
    if (wimpt_complain (os_swix4 (OS_SpriteOp, 0x1A | 512,
                                  area, header, ms->leaf)) != NULL)
      return -1;
    ftracef5 ("SPRITE %.12s: mode 0x%X, width %d words, height %d pixels, rbit %d\n",
              header->name, header->mode, 1 + header->width, 1 + header->height,
              header->rbit);

    if (log2_bpp <= 3)
      /*Set the sprite's palette to be the same as the screen one. JRC 6th Feb
          1995.*/
      if (wimpt_complain (os_swix5 (ColourTrans_ReadPalette, -1, -1, 
                                    header + 1, 8 << (1 << log2_bpp), 1 << 1)) != NULL)
      { m_FREE (area, sprite_size + sizeof (sprite_area));
        flex_free ((flex_ptr) &ramfetch_buffer);
        return FALSE;
      }

    jid.s.image.addr = ramfetch_buffer; /*Might have shifted*/
    if (wimpt_complain (main_plot_fromjpeg (area, header, &jid)) != NULL)
    { m_FREE (area, sprite_size + sizeof (sprite_area));
      flex_free ((flex_ptr) &ramfetch_buffer);
      return FALSE;
    }

    if (!flex_extend ((flex_ptr) &ramfetch_buffer, sprite_size + sizeof (sprite_area)))
    { m_FREE (area, sprite_size + sizeof (sprite_area));
      flex_free ((flex_ptr) &ramfetch_buffer);
      return FALSE;
    }

    /*Make it look like a sprite file by trimming off 4 bytes*/
    memcpy (ramfetch_buffer, &area->number,
                             sprite_size + sizeof (sprite_area) - sizeof (area->size));
#ifdef XTRACE
    { char cmd [128];
      sprintf (cmd, "%%Save $.Sprite %X +%X", &area->size,
                    sprite_size + sizeof (sprite_area) - sizeof (area->size));
      os_cli (cmd);
    }
#endif

    m_FREE (area, sprite_size + sizeof (sprite_area));
  }

  return TRUE;
}

/***********************************
 * Force complete redraw of window *
 ***********************************/

void main_force_redraw (wimp_w handle)

{ wimp_redrawstr rds;

  ftracef0 ("main_force_redraw\n");
  rds.w   = handle;
  rds.box = main_big_extent;
  ftracef0 ("do wimp_force_redraw\n");
  wimpt_noerr (wimp_force_redraw (&rds));
  ftracef0 ("done\n");
}

/************************************+**
 *                                     *
 *  Set the extent of a file window.   *
 *                                     *
 ***************************************/

void main_set_extent (main_window *window)

{ int nsprites, width, height, x, y, no_across, no_down;
  wimp_winfo curr;
  wimp_redrawstr newext;
  char *name = window->data->file.filename;
  BOOL changed = FALSE;

  ftracef0 ("main_set_extent\n");
  if (window->data->file.fullinfo)
    x = main_FILER_FullInfoWidth, y = main_FILER_FullInfoHeight;
  else
    x = main_FILER_TotalWidth, y = main_FILER_TotalHeight;

  curr.w = window->handle;
  wimpt_noerr (paintlib_get_wind_info (&curr));

  nsprites = window->data->file.spritearea->number;
  ftracef1 ("main_set_extent: %d sprites across\n", nsprites);

  /*title width*/
  width = main_FILER_TextWidth*((name == NULL? 12: strlen (name)) + 10);
  if (width < x*nsprites) width = x*nsprites;
  ftracef1 ("main_set_extent: x extent is %d\n", width);

  no_across = (curr.info.box.x1 - curr.info.box.x0)/x;
  if (no_across < 1) no_across = 1;
  ftracef1 ("main_set_extent: room for %d sprites\n", no_across);

  if (no_across == window->data->file.lastwidth)
  { ftracef0 ("main_set_extent: same number - nothing to do\n");
    return;
  }

  no_down = (nsprites + no_across - 1)/no_across;
  if (no_down < 1) no_down = 1;
  ftracef1 ("main_set_extent: %d sprites down\n", no_down);

  height = y*no_down;

  newext.box.x0 = 0;
  newext.box.y0 =-height;
  newext.box.x1 = width;
  newext.box.y1 = SPACE_FOR_HELP_TEXT;

  if (curr.info.box.x1 - curr.info.box.x0 != width)
  { ftracef0 ("Resetting displayed width\n");
    changed = TRUE;
    curr.info.box.x1 = curr.info.box.x0 + width;
  }

  if (curr.info.box.y1 - curr.info.box.y0 != height + SPACE_FOR_HELP_TEXT)
  { ftracef0 ("Resetting displayed height\n");
    changed = TRUE;
    curr.info.box.y0 = curr.info.box.y1 - (height + SPACE_FOR_HELP_TEXT);
  }

  if (changed)
  { wimp_redrawstr rds;

    newext.w = window->handle;
    wimpt_noerr (wimp_set_extent (&newext));

    curr.w = window->handle;
    wimpt_noerr (paintlib_get_wind_info (&curr));

    ftracef0 ("Really resetting\n");
    wimpt_noerr (wimp_open_wind ((wimp_openstr *) &curr));
    rds.w   = window->handle;
    rds.box = curr.info.ex;

    wimp_force_redraw (&rds);

    window->data->file.lastwidth = no_across; /*avoid ghastly flicker. J R C
        18th Oct 1993*/
  }
}

/**************************
 *                        *
 *  Window killer         *
 *                        *
 **************************/

void main_delete_window (wimp_w h)

{ ftracef0 ("main_delete_window\n");
  win_register_event_handler (h, (win_event_handler) 0, NULL);
  event_attachmenu (h, (menu) 0, NULL, NULL);
  wimp_delete_wind (h);
}

void main_window_delete (main_window *thiswindow)

{ main_window *window = (main_window *) &main_windows;

  altrename_delete ();

  ftracef2 ("main_window_delete: killing %s window: %d\n",
      thiswindow->tag == main_window_is_file? "file": "sprite",
      thiswindow->handle);

  while (window->link != thiswindow && window->link != NULL)
    window = window->link;

  if (window->link != NULL)
  { window->link = thiswindow->link;
    main_delete_window (thiswindow->handle);
    m_FREE (thiswindow->data,
        thiswindow->tag == main_window_is_file? sizeof (main_file):
        sizeof (main_sprite_window));
    m_FREE (thiswindow, sizeof (main_window));
    win_activedec ();
  }
}

/**************************
 *  File window killer    *
 **************************/

static void delete_file_window (main_window *window)

{ main_sprite *sprite;
  main_file *file = &window->data->file;
  int loop = 0, count = 0;

  ftracef0 ("delete_file_window\n");

  for (sprite = file->sprites; sprite != NULL; sprite = sprite->link)
    count++;
  if (count)
  { main_sprite *todelete[count];

    /* First copy all their pointers into an array */
    for (sprite = file->sprites; sprite != NULL; sprite = sprite->link)
    { todelete[loop] = sprite;
      loop++;
    }

    /* Delete all the pointers in the array backwards (flex faster) */
    for (loop=count-1;loop>=0;loop--)
      psprite_delete (window, todelete[loop]);

    ftracef0 ("deleted all sprite blocks\n");
  }

  flex_free ((flex_ptr) &file->spritearea);
  if (file->filename != NULL) flex_free ((flex_ptr) &file->filename);

  m_FREE (file->title, 256);

  main_window_delete (window);
}


/***************************************************************************
 *                                                                         *
 *  Set the (file) window title to the given string.                       *
 *                                                                         *
 ***************************************************************************/

void main_set_title (main_window *window, char *name)

{ wimp_redrawstr r;
  wimp_wstate currinfo;

  ftracef1 ("main_set_title: Resetting window title to '%s'\n", name);
  strcpy (window->data->file.title, name);

  if (window->data->file.filename == NULL)
  { ftracef0 ("allocate filename flex\n");
    flex_alloc ((flex_ptr) &window->data->file.filename, strlen (name) + 1);
  }
  else
  { ftracef0 ("extend filename flex\n");
    flex_extend ((flex_ptr) &window->data->file.filename, strlen (name) +1);
  }

  strcpy (window->data->file.filename, name);
  wimpt_noerr (wimp_get_wind_state (window->handle, &currinfo));
  r.w = window->handle;
  wimp_getwindowoutline (&r);

  r.w = -1;
  r.box.y0 = currinfo.o.box.y1;
  wimp_force_redraw (&r);
}

void main_set_modified (main_file *file)

{ ftracef0 ("main_set_modified\n");
  if (!file->modified)
  { wimp_redrawstr r;
    wimp_wstate currinfo;

    if (strlen (file->title) < 256 - 2) strcat (file->title, " *");
    wimpt_noerr (wimp_get_wind_state (file->window->handle,&currinfo));
    r.w = file->window->handle;
    wimp_getwindowoutline (&r);

    r.w = -1;
    r.box.y0 = currinfo.o.box.y1;
    wimp_force_redraw (&r);
  }

  file->modified = 1;
}

static int startx;
static int starty;
static int nextx;
static int nexty;

void main_allocate_position (wimp_box *box)

{ ftracef0 ("main_allocate_position\n");
  box->x1 += nextx - box->x0;
  box->x0  = nextx;
  box->y0 += nexty - box->y1;
  box->y1  = nexty;
  nexty   -= 48;
}

void main_check_position (main_window *w)

{ int zap = 0;
  wimp_wstate currinfo;
  wimpt_noerr (wimp_get_wind_state (w->handle,&currinfo));

  ftracef0 ("main_check_position\n");
  if (currinfo.o.box.y1 != nexty + 48)
  { currinfo.o.box.y0 += nexty+48-currinfo.o.box.y1;
    currinfo.o.box.y1  = nexty+48;
    zap = 1;
  }

  if (currinfo.o.box.y0 < 140)
  { nexty = starty;
    currinfo.o.box.y0 += nexty-currinfo.o.box.y1;
    currinfo.o.box.y1  = nexty;
    nexty -= 48;
    zap = 1;
  }

  if (zap)
  { wimpt_noerr (wimp_close_wind (w->handle));
    wimpt_noerr (wimp_open_wind (&currinfo.o));
  }
}

/***************************************************************************
 *                                                                         *
 *  Load the given spritefile into the given window, returning error       *
 *   indicator.  Merge with current area if merge flag set                 *
 * return > 0: worked fine                                                 *
 *          0: file type was recognised                                    *
 *         -1: failed but data still intact                                *
 *        <-1: really failed; window wiped out                             *
 *                                                                         *
 ***************************************************************************/

static int Load_File (main_window *window, char *filename, int merge,
    int safe)

{ int rc = 1, i = 0, offset, ramcopy = filename == (char *) -1,
    temp_file = !(safe || xferrecv_file_is_safe ()), file_type = FileType_Sprite,
    sprite_size,
    log2_bpp = bbc_modevar (-1, bbc_Log2BPP);
  os_filestr filestr;
  main_sprite *sprite, **sprptr;
  sprite_header *header;
  main_file *file = &window->data->file;
  wimp_winfo curr;
  jpeg_id jid;
  jpeg_info jinfo;

  if (window->selection.flags & MW_SELSAVING) return 0;

  ftracef0 ("Load_File\n");

  altrename_delete ();

  ftracef4 ("Asked to %s %s %s into window 0x%X\n",
      merge? "merge": "load",
      ramcopy? "RAM": "file",
      ramcopy? "buffer": filename,
      window->handle);

  /*Get the total size |filestr.start| of the sprite(s) to be loaded.*/
  if (!ramcopy)
  { filestr.name   = filename;
    filestr.action = 5;
    os_file (&filestr);

    if (filestr.action != 1)
    { filestr.loadaddr = filestr.action;
      filestr.name     = filename;
      filestr.action   = 19;
      wimpt_complain (os_file (&filestr));
      return 0;      /* failed */
    }

    file_type = (filestr.loadaddr & 0xFFF00) >> 8;
    if (!(file_type == FileType_Sprite || file_type == FileType_JPEG))
    { werr (FALSE, msgs_lookup ("PntEB"), filename);
      return 0;      /* failed */
    }
  }
  else
    filestr.start = flex_size ((flex_ptr) &ramfetch_buffer);

  /*Set the file name.*/
  if (!(merge || ramcopy || temp_file))
  { if (window->data->file.filename == NULL)
    { if (!(flex_alloc ((flex_ptr) &file->filename, strlen (filename) + 1)))
      { main_NO_ROOM ("file title");
        return -1;
      }
    }
    else
    { if (!flex_extend ((flex_ptr) &file->filename, strlen (filename) + 1))
      { main_NO_ROOM ("extended file title");
        return -1;
      }
    }
  }

  /*If ramcopy or merge, read the stuff to be loaded into ramfetch_buffer
    (already there if ramcopy). Otherwise (filecopy and not merge), just make
    sure that file->spritearea is big enough to load the file into.*/
  if (!ramcopy)
  { /*Copying from a file.*/
    if (file_type == FileType_Sprite)
      sprite_size = filestr.start - 12;
    else
    { jid.s.name = filename;
      jid.tag = jpeg_id_name;
      if (wimpt_complain (jpeg_readinfo (&jid, &jinfo)))
        return 0;
      ftracef2 ("JPEG info: %d x %d\n", jinfo.width, jinfo.height);

      sprite_size = psprite_size (jinfo.width, jinfo.height, wimpt_mode (),
                                  FALSE /*mask?*/, 2 /*full palette*/);
    }

    if (merge)
    { /*filecopy && merge*/
      ftracef0 ("allocate ram buffer for file\n");
      if (!flex_alloc ((flex_ptr) &ramfetch_buffer, sprite_size + sizeof (sprite_area)))
      { werr (FALSE, msgs_lookup ("PntEG"));
        return -1;
      }

      ftracef0 ("load file into ram buffer\n");
      if (file_type == FileType_Sprite)
      { ftracef1 ("writing size (%d) at front of buffer\n", sprite_size + sizeof (sprite_area));
        *(int *) ramfetch_buffer = sprite_size + sizeof (sprite_area);
            /* convert into sprite area */

        if (wimpt_complain (sprite_area_load
            ((sprite_area *) ramfetch_buffer, filename)))
        { flex_free ((flex_ptr) &ramfetch_buffer);
          return -1;
        }
      }
      else
      { char *cc;

        /*Create an empty sprite called '!newjpeg' in ramfetch_buffer*/
        header = main_make_newjpeg((sprite_area *)ramfetch_buffer, sprite_size, &jinfo);

        /*Set the name with a sprite op to get the case right.*/
        if (wimpt_complain (os_swix4 (OS_SpriteOp, 0x1A | 512,
                            file->spritearea, header,
                            (cc = strrchr (filename, '.')) != NULL ||
                            (cc = strrchr (filename, ':')) != NULL ? cc + 1 : "jpeg")) != NULL)
          return -1;
        ftracef5 ("SPRITE %.12s: mode 0x%X, width %d words, height %d pixels, rbit %d\n",
                  header->name, header->mode, 1 + header->width, 1 + header->height,
                  header->rbit);

        if (log2_bpp <= 3)
          /*Set the sprite's palette to be the same as the screen one. JRC 6th
              Feb 1995.*/
          if (wimpt_complain (os_swix5 (ColourTrans_ReadPalette, -1, -1,
                                        header + 1, 8 << (1 << log2_bpp), 1 << 1)) != NULL)
            return -1;

          if (wimpt_complain (main_plot_fromjpeg ((sprite_area *)ramfetch_buffer, header, &jid)) != NULL)
            return -1;

        rc = 1;
      }
    }
    else
    { /*filecopy && !merge*/
      if (!menus_ensure_size (&file->spritearea, sprite_size + sizeof (sprite_area)))
      { werr (FALSE, msgs_lookup ("PntEG"));
        return -1;
      }

      ftracef0 ("initialise sprite area\n");
      sprite_area_initialise (file->spritearea, sprite_size + sizeof (sprite_area));
    }
  }
  else /*ramcopy - file contents already converted to sprite*/
  { sprite_size = flex_size ((flex_ptr) &ramfetch_buffer) - 12;

    if (!flex_midextend ((flex_ptr) &ramfetch_buffer, 0, 4))
    { main_NO_ROOM ("4 bytes for ram buffer");
      flex_free ((flex_ptr) &ramfetch_buffer);
      return -1;
    }

    ftracef1 ("writing size (%d) at front of buffer\n", sprite_size + sizeof (sprite_area));
    *(int *) ramfetch_buffer = sprite_size + sizeof (sprite_area);
        /* convert into sprite area */

    ftracef0 ("verify area ...\n"); /*J R C 18th Nov 1994*/
    if (wimpt_complain (os_swix2 (OS_SpriteOp, 512 | 17, ramfetch_buffer)))
    { ftracef0 ("area invalid\n");
      return NULL;
    }
    ftracef0 ("area valid\n");
  }

  if (ramcopy || merge)
  { ftracef0 ("copy all the ram sprites across\n");
    rc = psprite_merge_area (window, file, (sprite_area **) &ramfetch_buffer)? 1:
          -1;
    flex_free ((flex_ptr) &ramfetch_buffer);
  }
  else
  { ftracef0 ("full file load\n");

  #if TRACE
    if (file->sprites != NULL)
      werr (TRUE, "file not empty");
  #endif

    ftracef2 ("Load_File: loading \"%s\" into area 0x%X\n",
        filename, file->spritearea);
    if (file_type == FileType_Sprite)
    { if (wimpt_complain (sprite_area_load (file->spritearea, filename)))
        return NULL;

      ftracef0 ("verify area ...\n"); /*J R C 7th Nov 1994*/
      if (wimpt_complain (os_swix2 (OS_SpriteOp, 512 | 17, file->spritearea)))
      { ftracef0 ("area invalid\n");
        return NULL;
      }
      ftracef0 ("area valid\n");
    }
    else
    { char *cc;

      /*Create an empty sprite called '!newjpeg' in file->spritearea*/
      header = main_make_newjpeg(file->spritearea, sprite_size, &jinfo);

      /*Set the name with a sprite op to get the case right.*/
      if (wimpt_complain (os_swix4 (OS_SpriteOp, 0x1A | 512,
                          file->spritearea, header,
                          (cc = strrchr (filename, '.')) != NULL ||
                          (cc = strrchr (filename, ':')) != NULL ? cc + 1 : "jpeg")) != NULL)
        return -1;
      ftracef5 ("SPRITE %.12s: mode 0x%X, width %d words, height %d pixels, rbit %d\n",
                header->name, header->mode, 1 + header->width, 1 + header->height,
                header->rbit);

      if (log2_bpp <= 3)
        /*Set the sprite's palette to be the same as the screen one. JRC 6th
          Feb 1995.*/
        if (wimpt_complain (os_swix5 (ColourTrans_ReadPalette, -1, -1,
                                      header + 1, 8 << (1 << log2_bpp), 1 << 1)) != NULL)
          rc = -1;

      if (wimpt_complain (main_plot_fromjpeg (file->spritearea, header, &jid)) != NULL)
        rc = -1;
    }

    if (!temp_file) strcpy (file->filename, filename);

    sprptr = &file->sprites;
    for (offset = psprite_first (&file->spritearea); offset != 0;
        offset = psprite_next (&file->spritearea, offset))
    { ftracef2 ("area 0x%X sproff 0x%X\n", file->spritearea, offset);

      if ((*sprptr = psprite_new (offset, i++, file)) == NULL)
      { delete_file_window (window);
        return -2;    /* really couldn't cope */
      }

      sprptr = &(*sprptr)->link; /* keep at end of list */
    }
  }

  if (merge) main_set_modified (file);
  psprite_set_plot_info (file);
  psprite_set_colour_info (file);
  psprite_set_brush_translations (file);

  /* now shrink box if not enough sprites to fill it */
  curr.w = window->handle;
  wimpt_noerr (paintlib_get_wind_info (&curr));
  if (curr.info.box.x1-curr.info.box.x0 >
      file->spritearea->number*main_FILER_TotalWidth)
  { curr.info.box.x1 = curr.info.box.x0 +
        file->spritearea->number*main_FILER_TotalWidth;
    wimpt_noerr (wimp_open_wind ((wimp_openstr *) &curr));
  }

  if ((!merge || window->data->file.filename == NULL) &&
      !(ramcopy || temp_file))
  { /* Clear modified flag and redraw title */
    file->modified = 0;
    main_set_title (window, filename);
  }
  else
    /* force summary window to be updated */
    file->lastwidth = 0; /*was
        main_force_redraw (window->handle); J R C 18th Oct 1993*/

  main_set_extent (window);

  for (sprite = file->sprites; sprite != NULL; sprite = sprite->link)
  { main_sprite_window *sprw;

    for (sprw = sprite->windows; sprw != NULL; sprw = sprw->link)
      sprwindow_set_work_extent (sprw->window, TRUE);

    if (sprite->colourdialogue == 0)
      colours_set_extent (sprite); /*was main_force_redraw
                                 (sprite->colourhandle); JRC 4th Dec '89*/
  }

  ftracef0 ("Loaded file\n");
  return rc;
}

static void main_draw_icon (main_window *window, main_sprite *sprite, int x0, int y0, wimp_redrawstr *rds)

{ sprite_info infoblock;
  int sx, sy;
  psprite_info sinfo;

  psprite_read_full_info (sprite, &sinfo);

  if (psprite_read_size (sprite, &infoblock))
    sinfo.width = -1, sinfo.height = -1;
  else
  { infoblock.width  *= sprite->iconsize.scale_xmul;
    infoblock.height *= sprite->iconsize.scale_ymul;
    infoblock.width  /= sprite->iconsize.scale_xdiv;
    infoblock.height /= sprite->iconsize.scale_ydiv;
  }

  if (window->data->file.fullinfo)
  {
    char sizebuf [20];

    main_iprintf ((sprite->flags & MSF_SELECTED?(wimp_ISELECTED | wimp_IFILLED):0),
        x0 + 6*main_FILER_TextWidth,
        y0 + 2*main_FILER_TextHeight,
        "%s", &sinfo.name);

    /*Check for silly numbers here. JRC 14 June 1990*/
    main_iprintf
    ( 0,
      x0 + 20*main_FILER_TextWidth,
      y0 + 2*main_FILER_TextHeight,
      msgs_lookup
      ( sinfo.width == -1 || sinfo.height == -1?
        "PntW22":
        "PntW21"
      ),
      sinfo.width,
      sinfo.height
    );

    if ((unsigned) sinfo.mode < 256)
      main_iprintf (0,
          x0 + 33*main_FILER_TextWidth,
          y0 + 2*main_FILER_TextHeight,
          msgs_lookup ("PntW23"),
          sinfo.mode);
    else
    {
      char *ncol = psprite_get_colours(sinfo.mode);
      main_iprintf (0,
          x0 + 33*main_FILER_TextWidth,
          y0 + 2*main_FILER_TextHeight,
          msgs_lookup ("PntW24"), ncol);
    }

    (void) os_swix3 (OS_ConvertFixedFileSize, sinfo.size, sizebuf,
        sizeof sizebuf);

    main_iprintf (wimp_IRJUST,
        x0 + 55*main_FILER_TextWidth,
        y0 + 2*main_FILER_TextHeight,
        "%s", sizebuf);

    static char *masktypes[] =
    {
      "PntW6", // transparency_type_none
      "PntW5", // transparency_type_onoffmask
      "PntWD", // transparency_type_alphamask
      "PntWE", // transparency_type_alphachannel
    };
    main_iprintf (0, x0 + 20*main_FILER_TextWidth,
        y0 + main_FILER_TextHeight,
        "%s, %s", msgs_lookup (sinfo.palette?
        sinfo.truepalette? "PntW3a": "PntW3": "PntW4"),
        msgs_lookup (masktypes[psprite_transparency_type(sprite)]));

    sx = x0 + main_FILER_Border/2;
    sy = y0 + main_FILER_Border/2;
  }
  else
  { main_iprintf (wimp_IHCENTRE |
        (sprite->flags & MSF_SELECTED?(wimp_ISELECTED | wimp_IFILLED):0),
        x0 + main_FILER_TotalWidth/2, y0 + main_FILER_TextHeight,
        "%.12s", sinfo.name);

    sx = x0 + (main_FILER_Border + main_FILER_XSize -
       infoblock.width)/2;
    sy = y0 + main_FILER_TotalHeight - (main_FILER_Border + main_FILER_YSize +
       infoblock.height)/2;
  }

  if (!(sinfo.width == -1 || sinfo.height == -1))
    wimpt_noerr (psprite_plot_scaled (sx + rds->box.x0 - rds->scx,
        sy + rds->box.y1 - rds->scy, sprite,
        &sprite->iconsize, (sprite->flags & MSF_SELECTED?3:0)));
}

/* bbox in work area coords */
static void main_update_icon (main_window *window, main_sprite *sprite, wimp_box *bbox)

{ wimp_redrawstr ds;
  int more;
  os_error *e;

  ds.w = window->handle;
  ds.box = *bbox;

  /* just redraw area containing higlighted parts in fullinfo to reduce flicker */
  if (window->data->file.fullinfo) ds.box.x1 = ds.box.x0+20*main_FILER_TextWidth;
  for (e = wimp_update_wind(&ds,&more); !e && more; e = wimp_get_rectangle(&ds, &more))
  { main_clear_background (&ds);
    main_draw_icon(window, sprite, bbox->x0, bbox->y0, &ds);
  }
}

/********************************************************
 *  selections                                          *
 ********************************************************/
typedef enum 
{ SI_SELECT,
  SI_CLEAR,
  SI_TOGGLE
} select_icon_how;

static void main_select_icon(main_window *window, main_sprite *sprite, wimp_box *iconbbox, select_icon_how how)

{ switch (how)
  { case SI_CLEAR: /* clear */
       if (sprite->flags & MSF_SELECTED)
       { sprite->flags &= ~MSF_SELECTED;
         window->selection.count--;
         main_update_icon (window, sprite, iconbbox);
       }
       break;
    case SI_SELECT: /* set */
       if (!(sprite->flags & MSF_SELECTED))
       { sprite->flags |= MSF_SELECTED;
         window->selection.count++;
         main_update_icon (window, sprite, iconbbox);
       }
       break;
    case SI_TOGGLE: /* toggle */
       if (sprite->flags & MSF_SELECTED)
       { sprite->flags &= ~MSF_SELECTED;
         window->selection.count--;
         main_update_icon (window, sprite, iconbbox);
       }   
       else
       { sprite->flags |= MSF_SELECTED;
         window->selection.count++;
         main_update_icon (window, sprite, iconbbox);
       }
  }
  window->selection.transsprite = NULL; /* All selections cancel the transitory one */
}

#define MIN_TARGET_SIZE 64
static void ensure_min_target_size(wimp_box *bbox, int fullinfo)

{ if (bbox->x1-bbox->x0 < MIN_TARGET_SIZE)
  { if (!fullinfo) bbox->x0=(bbox->x0+bbox->x1-MIN_TARGET_SIZE)/2;
    bbox->x1=bbox->x0+MIN_TARGET_SIZE;
  }
  if (bbox->y1-bbox->y0 < MIN_TARGET_SIZE)
  { if (!fullinfo) bbox->y0=(bbox->y0+bbox->y1-MIN_TARGET_SIZE)/2;
    bbox->y1=bbox->y0+MIN_TARGET_SIZE;
  }
}

/* clip area in work area coords */
static void main_clear_selection (main_window *window, wimp_box *clip, select_icon_how how)

{ static wimp_box defclip = {0, -0x7f000000, 0x7f000000, 0};
  wimp_box bbox;
  main_sprite *sprite;
  int width, height;
  wimp_wstate ws;
  int column, spritesperrow;
  int left, top;

  if (!window || (window->selection.count==0 && how == SI_CLEAR)) return;

  if (!clip) clip = &defclip;

  if (window->data->file.fullinfo)
  { width = main_FILER_FullInfoWidth;
    height = main_FILER_FullInfoHeight;
  }
  else
  { width = main_FILER_TotalWidth;
    height = main_FILER_TotalHeight;
  }

  wimpt_noerr (wimp_get_wind_state (window->handle, &ws));
  spritesperrow = (ws.o.box.x1 - ws.o.box.x0) / width;
  if (spritesperrow == 0)
    spritesperrow = 1;

  column = 0;
  left = 0;
  top = 0;
  for (sprite = window->data->file.sprites; sprite != NULL; sprite = sprite->link)
  { if (main_CLIPS(clip, left, top-height, left+width, top))
    { int is_over_graphic = 1;
      bbox.x0 = left;
      bbox.x1 = left + width;
      bbox.y0 = top - height;
      bbox.y1 = top;

      if (bbox.x0<clip->x0 || bbox.x1>clip->x1 || bbox.y0<clip->y0 || bbox.y1>clip->y1)
      { wimp_box spritebbox;
        wimp_box namebbox;
        main_icon_bboxes(window, sprite, &bbox, &spritebbox, &namebbox);
        
        ensure_min_target_size(&spritebbox, window->data->file.fullinfo);

        is_over_graphic = 0;
        if (main_CLIPS(&spritebbox, clip->x0, clip->y0, clip->x1, clip->y1) ||
            main_CLIPS(&namebbox, clip->x0, clip->y0, clip->x1, clip->y1))
          is_over_graphic = 1;
      }

      if (is_over_graphic)
        main_select_icon(window, sprite, &bbox, how);
    }

    column++;
    left += width;
    if (column == spritesperrow)
    { column = 0;
      left = 0;
      top -= height;
    }
  }
}

void main_select_all (main_window *window)

{ main_clear_selection (window, 0, SI_SELECT);
}

void main_clear_all (main_window *window)

{ main_clear_selection (window, 0, SI_CLEAR);
}

static BOOL main_select_area (wimp_eventstr *event, void *handle)

{ wimp_wstate ws;
  wimp_box clip;
  main_window *window = (main_window *)handle;

  if (event->e != wimp_EUSERDRAG) return FALSE;
  win_remove_unknown_event_processor (main_select_area, handle);
  os_swix1 (Wimp_AutoScroll, 0);
  wimp_get_wind_state (window->handle, &ws);

  clip.x0 = SCREEN_TO_WORKAREA_X(&ws, MIN(event->data.dragbox.x0, event->data.dragbox.x1));
  clip.x1 = SCREEN_TO_WORKAREA_X(&ws, MAX(event->data.dragbox.x0, event->data.dragbox.x1));
  clip.y0 = SCREEN_TO_WORKAREA_Y(&ws, MIN(event->data.dragbox.y0, event->data.dragbox.y1));
  clip.y1 = SCREEN_TO_WORKAREA_Y(&ws, MAX(event->data.dragbox.y0, event->data.dragbox.y1));
  /* Lassoo of several sprites */
  main_clear_selection (window, &clip, (window->selection.flags & MW_SELDRAGRIGHT) ? SI_TOGGLE : SI_SELECT);

  return TRUE;
}

int main_selection_file_size (main_window *window)

{ main_sprite *sprite;
  int size = 0;

  if (!window || window->selection.count==0) return 0;
  for (sprite = window->data->file.sprites; sprite != NULL; sprite = sprite->link)
  { if (sprite->flags & MSF_SELECTED)
    { sprite_header *spriteaddr = psprite_address (sprite);
      size += spriteaddr->next;
    }
  }
  return size + sizeof (sprite_area) - sizeof (int);/* file size not area size */
}

static void main_save_finished (int at, void *arg)

{ main_window *window = (main_window *)arg;
  at=at;
  xfersend_clear_unknowns ();
  if (window->selection.flags & MW_SELSAVEBYDRAG)
    main_clear_selection (window, 0, SI_CLEAR); /* Deselect those just saved */
  window->selection.flags &= ~(MW_SELSAVING | MW_SELSAVEBYDRAG);
}

BOOL main_save_selection (char *filename, void *arg)

{ main_window *window = (main_window *)arg;
  main_sprite *sprite;
  int          file;
  os_error    *err;
  struct
  { int num_of_sprites;
    int offset_to_first;
    int offset_to_free;
  } header;

  if (window->selection.count==0 || !filename) return FALSE;

  header.num_of_sprites = window->selection.count;
  header.offset_to_first = sizeof (sprite_area);
  header.offset_to_free = main_selection_file_size (window) + 4;
  if (header.offset_to_free <= sizeof (sprite_area)) return FALSE;

  visdelay_begin ();
  if (wimpt_complain (os_swix2r (OS_Find, 0x83, filename, &file, NULL)) != NULL)
    return FALSE;

  err = os_swix4 (OS_GBPB, 2, file, &header, sizeof (header));
  if (err == NULL)
  { for (sprite = window->data->file.sprites; sprite != NULL; sprite = sprite->link)
    { if (sprite->flags & MSF_SELECTED)
      { sprite_header *header = psprite_address (sprite);
        err = os_swix4 (OS_GBPB, 2, file, header, header->next);
        if (err != NULL) break;
      }
    }
  }
  os_swix2 (OS_Find, 0x00, file);

  if (err != NULL)
  { wimpt_complain (err);
    remove (filename);
    return FALSE;
  }
  
  wimpt_complain (os_swix3 (OS_File, 18, filename, FileType_Sprite)); /* set file type*/
  visdelay_end ();

  alarm_set (alarm_timenow ()+1, main_save_finished, window);
  window->selection.flags |= MW_SELSAVING;  

  return TRUE;
}

/********************************************************
 *  Pick a sprite in a file window, pointed at by mouse *
 ********************************************************/

static main_sprite *main_pick_sprite_bbox (main_window *window,
    wimp_mousestr *mouse, int *is_over_graphic, wimp_box *bbox)

{ wimp_wstate whereisit;
  int spritesperrow, spritenumber;
  main_sprite *sprite;
  int x, y, width, height, mx, my;
  wimp_box dummy;

  if (!bbox) bbox=&dummy;

  ftracef2 ("main_pick sprite: (%d, %d)\n", mouse->x, mouse->y);
  wimpt_noerr (wimp_get_wind_state (window->handle, &whereisit));

  if (window->data->file.fullinfo)
  { width = main_FILER_FullInfoWidth;
    height = main_FILER_FullInfoHeight;
  }
  else
  { width = main_FILER_TotalWidth;
    height = main_FILER_TotalHeight;
  }

  spritesperrow = (whereisit.o.box.x1 - whereisit.o.box.x0) / width;
  if (spritesperrow == 0)
    spritesperrow = 1;

  /* convert to work extent coordinates */
  x =   mouse->x-whereisit.o.box.x0 + whereisit.o.x;
  y = -(mouse->y-whereisit.o.box.y1 + whereisit.o.y);

  mx=x;
  my=-y;

  if (y < 0)
    return NULL;       /* in box area */

  /* and now to sprite number */
  x /= width;
  if (x >= spritesperrow)
    return NULL;

  y /= height;
  spritenumber = y * spritesperrow + x;

  ftracef3 ("Sprite %d x %d, %d\n", x, y, spritenumber);

  bbox->x0 = x*width;
  bbox->x1 = bbox->x0+width-1;
  bbox->y1 = -y*height;
  bbox->y0 = bbox->y1-height;

  for (sprite=window->data->file.sprites;
       spritenumber>0 && sprite != NULL;
       spritenumber--, sprite = sprite->link);

  if (sprite && is_over_graphic)
  { wimp_box spritebbox;
    wimp_box namebbox;

    main_icon_bboxes(window, sprite, bbox, &spritebbox, &namebbox);
    
    ensure_min_target_size(&spritebbox, window->data->file.fullinfo);
 
    *is_over_graphic=0;
    if (main_CLIPS(&spritebbox, mx, my, mx, my))
      *is_over_graphic=1;
    else if (main_CLIPS(&namebbox, mx, my, mx, my))
      *is_over_graphic=2;
  }

  return sprite;
}

/* returns work area of all bounding boxes */
/* bboxes may be 0 if not required */
BOOL main_get_all_sprite_bboxes (main_window *window, main_sprite *sprite,
                                 wimp_box *bbox, wimp_box *spritebbox,
                                 wimp_box *namebbox)

{ wimp_wstate ws;
  int spritesperrow, spritenumber;
  main_sprite *sp;
  int x, y, width, height;
  wimp_box dummy;

  if (!bbox) bbox = &dummy;

  if (!window || !sprite) return FALSE;

  for (spritenumber = 0, sp = window->data->file.sprites;
       sp != sprite; spritenumber++, sp = sp->link)
    if (!sp) return FALSE;

  wimpt_noerr (wimp_get_wind_state (window->handle, &ws));

  if (window->data->file.fullinfo)
  { width = main_FILER_FullInfoWidth;
    height = main_FILER_FullInfoHeight;
  }
  else
  { width = main_FILER_TotalWidth;
    height = main_FILER_TotalHeight;
  }

  spritesperrow = (ws.o.box.x1 - ws.o.box.x0) / width;
  if (spritesperrow == 0)
    spritesperrow = 1;

  x = spritenumber % spritesperrow;
  y = spritenumber / spritesperrow;

  bbox->x0 = x * width;
  bbox->x1 = bbox->x0 + width-1;
  bbox->y1 = -y * height;
  bbox->y0 = bbox->y1 - height;

  main_icon_bboxes(window, sprite, bbox, spritebbox, namebbox);

  return TRUE;
}

static main_sprite *main_pick_sprite (main_window *window, wimp_mousestr *mouse)

{ int is_in_graphic;

  main_sprite *sprite = main_pick_sprite_bbox (window, mouse, &is_in_graphic, 0);
  return (sprite && is_in_graphic) ? sprite : 0;
}

main_sprite *main_pick_menu_button_sprite (main_window *window)

{
  int is_in_graphic;
  wimp_mousestr mouse;
  main_sprite *sprite;
  wimp_box bbox;

  wimpt_noerr (wimp_get_point_info (&mouse));
  sprite = main_pick_sprite_bbox(window, &mouse, &is_in_graphic, &bbox);
  if (window->selection.count==0)
  { if (!sprite || !is_in_graphic) return NULL;
    main_select_icon (window, sprite, &bbox, SI_SELECT);
    window->selection.transbox = bbox;
    window->selection.transsprite = sprite; /* Retain for later deselection */
    return sprite;
  }
  
  if (window->selection.count==1)
  { main_sprite *sp;
    for (sp = window->data->file.sprites; sp != NULL; sp = sp->link)
    { if (sp->flags & MSF_SELECTED)
      { if ((window->selection.transsprite == NULL) || /* One permanently selected (by left/right click) */
            (sprite == sp) /* Is the same one as already selected */)
          return sp;
        if ((sprite == NULL) || /* There is a transitory selection, but the user missed the target */
            !is_in_graphic) /* by miles */
        {
          main_select_icon (window, window->selection.transsprite, &window->selection.transbox, SI_CLEAR);
          return NULL;
        }
        if (sp == window->selection.transsprite)
        { /* Otherwise transfer temporary selection */
          main_select_icon (window, window->selection.transsprite, &window->selection.transbox, SI_CLEAR);
          main_select_icon (window, sprite, &bbox, SI_SELECT);
          window->selection.transbox = bbox;
          window->selection.transsprite = sprite;
          return sprite;
        }
      }
    }
  }

  return NULL;
}

/***************************************************************************
 *                                                                         *
 *  Window event handler for sprite file windows.                          *
 *                                                                         *
 ***************************************************************************/

static void spritefile_event_handler (wimp_eventstr *e, void *handle)

{ main_window *window = (main_window *) handle;

  if (altrename_claim_event (e, window)) return;

  ftracef0 ("spritefile_event_handler\n");
  /*if (!help_process (e))*/ {switch (e->e)
  { case wimp_EOPEN:
      if (wimpt_complain (wimp_open_wind (&e->data.o))) return;
      main_set_extent (window);
    break;

    case wimp_ESCROLL: /* use wimp_escroll to make mousewheel work (Colin Granville) */
      if (e->data.scroll.x || e->data.scroll.y)
      {
         switch (e->data.scroll.x)
         {
           case -2: e->data.scroll.o.x-=(e->data.scroll.o.box.x1-e->data.scroll.o.box.x0); break;
           case -1: e->data.scroll.o.x-=64; break;
           case 1:  e->data.scroll.o.x+=64; break;
           case 2:  e->data.scroll.o.x+=(e->data.scroll.o.box.x1-e->data.scroll.o.box.x0); break;
         }
         switch (e->data.scroll.y)
         {
           case -2: e->data.scroll.o.y-=(e->data.scroll.o.box.y1-e->data.scroll.o.box.y0); break;
           case -1: e->data.scroll.o.y-=64; break;
           case 1:  e->data.scroll.o.y+=64; break;
           case 2:  e->data.scroll.o.y+=(e->data.scroll.o.box.y1-e->data.scroll.o.box.y0); break;
         }
         if (wimpt_complain (wimp_open_wind (&e->data.scroll.o))) return;
      }
      break;

    case wimp_EREDRAW:
    { int more, spritesperline, x, y;
      wimp_redrawstr rds;
      main_file *file = &window->data->file;
      #if TRACE
        int no_rect = 0;
      #endif

      rds.w = e->data.o.w;
      wimpt_noerr (wimp_redraw_wind (&rds, &more));
      ftracef4 ("visible area ((%d, %d), (%d, %d))\n",
          rds.box.x0, rds.box.y0, rds.box.x1, rds.box.y1);

      if (file->fullinfo)
        x = main_FILER_FullInfoWidth, y = main_FILER_FullInfoHeight;
      else
        x = main_FILER_TotalWidth, y = main_FILER_TotalHeight;
      ftracef1 ("width of sprite info %d\n", x);

      spritesperline = (rds.box.x1 - rds.box.x0)/x;
      if (spritesperline == 0) spritesperline = 1;
      ftracef1 ("spritesperline %d\n", spritesperline);

      #if 0
      file->lastwidth = spritesperline;
      if (file->lastwidth > file->spritearea->number)
        file->lastwidth = file->spritearea->number;
      /*Avoid flicker. J R C 18th Oct 1993*/
      #endif

      while (more)
      { main_sprite *currsprite = file->sprites;
        int spritex = -1, spritey = 0;
        int x0, y0, x1, y1;

        main_clear_background (&rds);

#if SPACE_FOR_HELP_TEXT != 0
        x0 = rds.box.x0 - rds.scx;
        x1 = rds.box.x1 - rds.scx;
        y0 = rds.box.y1 - rds.scy;
        y1 = y0 + SPACE_FOR_HELP_TEXT;

        if (main_CLIPS (&rds.g, x0, y0, x1, y1))
        { wimp_setcolour (3);
          bbc_rectanglefill (MAX (x0, rds.g.x0), MAX (y0, rds.g.y0),
              MIN (x1, rds.g.x1) - MAX (x0, rds.g.x0), SPACE_FOR_HELP_TEXT);

          main_iprintf (wimp_IFILLED |
              3 << 28 /*background colour 3*/,
              0, main_FILER_TextHeight+DISPLAY_MARGIN/2,
              msgs_lookup ("PntW1"));
        }
#endif

        for (; currsprite != NULL; currsprite = currsprite->link)
        { if (++spritex == spritesperline) spritex = 0, spritey++;
          ftracef2 ("x %d, y %d\n", spritex, spritey);

          x0 = x*spritex;
          x1 = x0 + x;

          y1 =-y*spritey;
          y0 = y1 - y;

          /* now do clipping */
          if (main_CLIPS (&rds.g, x0 + rds.box.x0 - rds.scx,
              y0 + rds.box.y1 - rds.scy,
              x1 + rds.box.x0 - rds.scx,
              y1 + rds.box.y1 - rds.scy))
              main_draw_icon (window, currsprite, x0, y0, &rds);
        }

        #if TRACE
          no_rect++;
        #endif
        wimpt_noerr (wimp_get_rectangle (&rds, &more));
      }
      ftracef1 ("%d rectangles redrawn\n", no_rect);
    }
    break;

    case wimp_EBUT:

      if (bbc_inkey (-3) || bbc_inkey (-4))
      { /* alt pressed */
        if (e->data.but.m.bbits & (wimp_BCLICKLEFT | wimp_BCLICKRIGHT))
        { int is_over_graphic;
          main_sprite *sprite = main_pick_sprite_bbox (window, &e->data.but.m, &is_over_graphic, 0);
          if (sprite && is_over_graphic==2 && (e->data.but.m.bbits & wimp_BCLICKLEFT))
          {
             /* alt click over name */
             altrename_start (window, sprite);
             break;
          }
        }
        break;
      }

      if (e->data.but.m.bbits & wimp_BLEFT)
      { main_sprite *sprite = main_pick_sprite (window, &e->data.but.m);

        if (sprite != NULL)
        { /*Check sprite has a valid mode. JRC 14 June 1990*/
          psprite_info info;
          psprite_read_full_info (sprite, &info);
          if (info.width == -1 || info.height == -1)
          { werr (FALSE, msgs_lookup ("PntEJ"));
            break;
          }

          sprwindow_new (sprite);
          /* Double click clears the whole selection */
          main_clear_selection (window, 0, SI_CLEAR);
          if (main_current_options.tools.show_tools)
            toolwindow_display (FALSE);
        }
        else /* double clicking on no sprite causes a create */
        { ftracef0 ("Double click on null sprite, opening create\n");
          psprite_create_show (window, FALSE, "");
        }
      }
      else if (e->data.but.m.bbits & (wimp_BCLICKLEFT | wimp_BCLICKRIGHT))
      { wimp_redrawstr rds;
        int is_over_graphic;

        main_sprite *sprite = main_pick_sprite_bbox (window, &e->data.but.m, &is_over_graphic, &rds.box);

        if (e->data.but.m.bbits & wimp_BCLICKLEFT)
        {
          if (sprite && is_over_graphic && (sprite->flags & MSF_SELECTED)) break;
          
          if (sprite == NULL || !is_over_graphic)
          { /* Left click in no man's land clears the selection */
            main_clear_selection (window, 0, SI_CLEAR);
            break;
          }

          if (window->selection.count==0)
          { /* First (left) click on a sprite */
            main_select_icon (window, sprite, &rds.box, SI_SELECT);
            break;
          }

          if (!(sprite->flags & MSF_SELECTED))
          { /* Left click on a sprite that is not currently selected clears the old
             * selection and makes this one sprite the only member of the new selection */
            main_clear_selection (window, 0, SI_CLEAR);
            main_select_icon (window, sprite, &rds.box, SI_SELECT);
            break;
          }
        }
        else
        { /* else right click toggles the selected sprite only */
          if (sprite && is_over_graphic)
          { /* Force clear any transitory selection, so menu click then adjust results in
             * a net selection */
            if (window->selection.transsprite != NULL)
              main_select_icon (window, window->selection.transsprite, &window->selection.transbox, SI_CLEAR);
            main_select_icon (window, sprite, &rds.box, SI_TOGGLE);
          }
        }
      }
      else if (e->data.but.m.bbits & (wimp_BDRAGLEFT | wimp_BDRAGRIGHT))
      { wimp_redrawstr rds;
        int is_over_graphic;

        main_sprite *sprite = main_pick_sprite_bbox (window, &e->data.but.m, &is_over_graphic, &rds.box);

        if (sprite && is_over_graphic)
        { wimp_icreate create;
          wimp_icon icon;
          wimp_wstate ws;
          static const char iconfile[] = "file_ff9";
          static const char iconfiles[] = "package";
          wimp_i iconhandle;
          int width, height;

          /* Read where the window where the click was is */
          wimpt_noerr (wimp_get_wind_state (e->data.but.m.w, &ws));

          /* Bounding box is filer thumbnail size */
          if (window->data->file.fullinfo)
          { width = main_FILER_XSize/2;
            height = main_FILER_YSize/2;
          }
          else
          { width = main_FILER_XSize;
            height = main_FILER_YSize;
          }

          /* Convert mouse to window offset coordinates */
          icon.box.x0 = e->data.but.m.x - (ws.o.box.x0 - ws.o.x) - (width/2);
          icon.box.y0 = e->data.but.m.y - (ws.o.box.y1 - ws.o.y) - (height/2);
          icon.box.x1 = icon.box.x0 + width;
          icon.box.y1 = icon.box.y0 + height;

          /* Create an icon and add it to the window */
          icon.flags = wimp_ISPRITE | wimp_INDIRECT;
          icon.data.indirectsprite.name = window->selection.count > 1 ? (char *)iconfiles :
                                                                        (char *)iconfile;
          icon.data.indirectsprite.spritearea = (sprite_area *)1;
          icon.data.indirectsprite.nameisname = strlen(icon.data.indirectsprite.name);
          create.w = e->data.but.m.w;
          create.i = icon;
          wimpt_noerr (wimp_create_icon (&create, &iconhandle));

          /* Pretend the event came from that icon which allows it to be
             picked up by DragASprite */
          e->data.but.m.i = iconhandle;

          /* Start the xfersend */
          xfersend (FileType_Sprite, msgs_lookup ("PntG6"),
                    main_selection_file_size(window),
                    main_save_selection, 0, 0, e, window);

          /* Denote this as a drag save rather than menu save */
          window->selection.flags |= MW_SELSAVEBYDRAG;
          
          /* Finished with the icon */
          wimpt_noerr (wimp_delete_icon(create.w, iconhandle));
        }
        else
        { wimp_dragstr drag;
          wimp_wstate ws;
          struct 
          {
            int   window_handle;
            struct {int left, bottom, right, top;} pause_zone;
            int   pause_duration;
            int   handler;
            void *handle;
          } scroll;

          wimp_get_wind_state (window->handle, &ws);

          drag.window=window->handle;
          drag.type=wimp_USER_RUBBER;
          drag.box.x0=drag.box.x1=e->data.but.m.x;
          drag.box.y0=drag.box.y1=e->data.but.m.y;
          drag.parent=ws.o.box;
          drag.parent.y1=0x7f000000;
          drag.parent.y0=-0x7f000000;
          os_swix4 (Wimp_DragBox, 0, &drag, *(int *)"TASK", 3);
          
          scroll.window_handle=window->handle;
          scroll.pause_zone.left=0;
          scroll.pause_zone.bottom=0;
          scroll.pause_zone.right=0;
          scroll.pause_zone.top=0;
          scroll.pause_duration=0;
          scroll.handler=1;
          scroll.handle=0;
          os_swix2 (Wimp_AutoScroll, 2, &scroll);
          window->selection.flags &= ~MW_SELDRAGRIGHT;
          if (e->data.but.m.bbits & wimp_BDRAGRIGHT)
            window->selection.flags |= MW_SELDRAGRIGHT;
          win_add_unknown_event_processor (main_select_area, window);
        }
      }
      break;

    case wimp_ECLOSE:
    { main_file *file   = &window->data->file;
      dboxquery_close_REPLY        action = dboxquery_close_SAVE;
      /* Deal with ADJUST clicks on the close box */
      int shifted = akbd_pollsh ();
      wimp_mousestr m;
      wimp_get_point_info (&m);    /* cache button state at time of close */

      ftracef0 ("Window close event\n");

      /* close create box if it is open */
      psprite_close_createbox (window->handle);

      /* Deal with modified files before opening any other windows */
      if (!((m.bbits & wimp_BRIGHT) != 0 && shifted) && file->modified)
      { char mess[256];
        sprintf (mess,
            msgs_lookup (file->filename == NULL ? "PntF2" : "PntF3"),
            file->filename);
        action = dboxquery_close (mess);
        if (action == dboxquery_close_SAVE)
          if (!menus_save_file (window, 1)) action = dboxquery_close_CANCEL;
      }

      if ((m.bbits & wimp_BRIGHT) != 0)
      { if (file->filename != NULL)
        { /* Need to strip off the leafname. */
          int i = strlen (file->filename) - 1;

          while (i > 0 && file->filename[i] != '.') i--;
          if (i > 0)
          { char a[FILENAMEMAX + 1];

            file->filename[i] = 0;
            sprintf (a, "filer_opendir %s", file->filename);
            wimpt_complain (os_cli (a));
            file->filename[i] = '.';
          }
        }
        if (shifted) break;     /* don't close if SHIFT down */
      }

      if (action != dboxquery_close_CANCEL)
      { delete_file_window (window);
        toolwindow_close ();
      }
    }
    break;

    case wimp_ESEND:
    case wimp_ESENDWANTACK:
      switch (e->data.msg.hdr.action)
      { case wimp_MDATASAVE:
          if (ramtransfer_file (&e->data.msg.data.datasave))
          { visdelay_begin ();
            Load_File (window, (char *) -1, 1, 0);
            visdelay_end ();
          }
        break;

        case wimp_MDATALOAD:
        { char *name;
          int type;

          type = xferrecv_checkinsert (&name);    /* sets up reply */
          if (type == FileType_Sprite || type == FileType_JPEG)
          { int ok;
            ftracef1 ("Loading file \"%s\"\n", name);
            visdelay_begin ();
            ok = Load_File (window, name, 1, 0);
            visdelay_end ();
            if (ok > 0) xferrecv_insertfileok ();
            ftracef0 ("file merged\n");
          }
        }
        break;

        case wimp_MHELPREQUEST:
          ftracef0 ("Help request on sprite file window\n");
          main_help_message (window->data->file.spritearea->number == 0?
              "PntH3": "PntH4", e);
        break;

        default:
          ftracef1 ("Got file message %d\n", e->data.msg.hdr.action);
        break;
      }
    break;

    default:
      ftracef1 ("File window event %d\n", e->e);
    break;
   }
  }
  menus_insdel_frig ();
}

/***************************************************************************
 *                                                                         *
 *  Single template loader.                                                *
 *                                                                         *
 ***************************************************************************/

static void load_template (wimp_template *wt, char *name, wimp_wind *buf)

{ char namebuff [FILENAMEMAX + 1]; /*have to copy it because Neil will piss off the end
                                     of the given string */

  ftracef0 ("load_template\n");
  strcpy (namebuff, name);
  ftracef2 ("Load template '%s': %p\n", name, buf);

  wt->buf = buf;
  wt->font = 0;
  wt->name = namebuff;
  wt->index = 0;

#if 0
  wimpt_noerr (wimp_load_template (wt));
#else
  ftracef1 ("work_free before: 0x%X\n", wt->work_free);
  os_swi (Wimp_LoadTemplate, (os_regset *) wt);
  ftracef1 ("work_free after: 0x%X\n", wt->work_free);
#endif

  if (!wt->index)
    werr (TRUE, msgs_lookup ("PntEE"));
}


/***************************************************************************
 *                                                                         *
 *  Resource loading. Load icon sprites, templates, etc.                   *
 *                                                                         *
 ***************************************************************************/

static void load_resources (void)

{ wimp_template wt;

  ftracef0 ("load_resources\n");
  wimpt_noerr (wimp_open_template ("Paint:Templates"));

  if ((wt.work_free = m_ALLOC (ICON_SPACE_SIZE)) == NULL)
    werr (TRUE, msgs_lookup ("PntEG"));
  wt.work_end  = wt.work_free + ICON_SPACE_SIZE;

  /* now load all our templates */
  load_template (&wt, "Sprite",     &sprwindow_template.t);
  wt.work_free += 128;
  load_template (&wt, "toolwind",   &tools_tool_template.t);
  wt.work_free += 128;
  load_template (&wt, "SpriteFile", &file_template.t);

  /*Use radioon, radiooff, opton, optoff from WIMP pool. JRC*/
  template_syshandle ("create")->spritearea = (void *) 1;
  template_syshandle ("Printing")->spritearea = (void *) 1;

  wimpt_noerr (wimp_close_template ());

  tools_tool_template.t.spritearea = resspr_area ();
  ftracef1 ("spritearea = %p\n", tools_tool_template.t.spritearea);

  /* dbox_verify ("progInfo");
  dbox_verify ("fileInfo");
  dbox_verify ("spriteInfo");
  dbox_verify ("create");
  dbox_verify ("number");
  dbox_verify ("xfer_send");
  dbox_verify ("magnifier");
  dbox_verify ("spritesize");
  dbox_verify ("query");
  dbox_verify ("selectECF"); */
}

/*************************************
 *                                   *
 *   No room error                   *
 *                                   *
 *************************************/

#if TRACE
  void main_no_room (char *a)
#else
  void main_no_room (void)
#endif

{ ftracef1 ("main_no_room: %s\n", a);
  werr (FALSE, msgs_lookup ("PntEG"));
}

/***************************************************************************
 *                                                                         *
 *  Create a new spritefile window                                         *
 *                                                                         *
 ***************************************************************************/

BOOL main_create_window (wimp_wind *win, wimp_w *h, win_event_handler handler,
    void *handle)

{ ftracef0 ("main_create_window: calling wimp_create_wind\n");
  if (wimpt_complain (wimp_create_wind (win, h)))
  { ftracef0 ("main_create_window: returning FALSE\n");
    *h = 0;
    return FALSE;
  }
  else
  { ftracef0 ("main_create_window: calling win_register_event_handler\n");
    win_register_event_handler (*h, handler, handle);
    return TRUE;
  }
}

/* Create a new window. The flag indicates if it to be opened */
static main_window *New_Window (BOOL open)

{ main_window *window;
  main_file *file;
  wimp_wind wind;
  wimp_openstr open_str;
  wimp_w w;

  ftracef1 ("New_Window: open %s\n", WHETHER (open));

  if ((window = m_ALLOC (sizeof (main_window))) == NULL)
  { main_NO_ROOM ("new file window block");
    return NULL;
  }
  ftracef1 ("New file window, descriptor at %p\n", window);

  if ((file = m_ALLOC (sizeof (main_file))) == NULL)
  { m_FREE (window, sizeof (main_window));
    main_NO_ROOM ("main_file");
    return NULL;
  }

  wind         = file_template.t;
  wind.scx     = wind.scy = 0;
  wind.minsize = 0x00010001;
  wind.ex      = main_big_extent;
  #if SPACE_FOR_HELP_TEXT != 0
    wind.ex.y1 = SPACE_FOR_HELP_TEXT;
    wind.scy = SPACE_FOR_HELP_TEXT;
  #endif

  wind.titleflags = (wimp_iconflags) (wind.titleflags | wimp_INDIRECT);
  wind.title.indirecttext.bufflen = 256;
  wind.title.indirecttext.validstring = 0;

  if ((wind.title.indirecttext.buffer = m_ALLOC (256)) == NULL)
  { m_FREE (window, sizeof (main_window));
    m_FREE (file, sizeof (main_file));
    main_NO_ROOM ("indirect title - file name");
    return NULL;
  }

  flex_alloc ((flex_ptr) &file->spritearea, 100);
  if (file->spritearea == 0)
  { m_FREE (window, sizeof (main_window));
    m_FREE (file, sizeof (main_file));
    m_FREE (wind.title.indirecttext.buffer, 256);
    main_NO_ROOM ("minimum spritearea");
    return NULL;
  }

  sprite_area_initialise (file->spritearea, 100);
  file->sprites = NULL;

  file->title = wind.title.indirecttext.buffer;
  strcpy (file->title, msgs_lookup ("PntF4"));
  file->fullinfo  =
      main_current_options.display.full_info; /*JRC 1 Dec '89*/
  file->modified  = 0;
  file->lastwidth = 0; /*was 0xFF. J R C 18th Oct 1993*/
  file->use_current_palette =
      main_current_options.display.use_desktop_colours; /*JRC*/

  ftracef0 ("New_Window: calling main_allocate_position\n");
  main_allocate_position (&wind.box);
  ftracef0 ("New_Window: calling main_create_wind\n");
  if (!main_create_window (&wind, &w, &spritefile_event_handler,
      window))
  { ftracef0 ("New_Window: freeing window\n");
    m_FREE (window, sizeof (main_window));
    ftracef0 ("New_Window: freeing &file->spritearea\n");
    flex_free ((flex_ptr) &file->spritearea);
    ftracef0 ("New_Window: freeing file\n");
    m_FREE (file, sizeof (main_file));
    ftracef0 ("New_Window: freeing wind.title.indirecttext.buffer\n");
    m_FREE (wind.title.indirecttext.buffer, 256);
    return NULL;
  }

  ftracef0 ("New_Window: calling event_attachmenumaker\n");
  event_attachmenumaker (w, &menus_file_maker,
      &menus_file_handler, window);

  open_str.w      = w;
  open_str.box    = wind.box;
  open_str.behind = -1;
  open_str.x      = open_str.y = 0;
  #if SPACE_FOR_HELP_TEXT != 0
    open_str.y = SPACE_FOR_HELP_TEXT;
  #endif

  ftracef0 ("New_Window: calling wimp_open_wind\n");
  if (open && wimpt_complain (wimp_open_wind (&open_str)))
  { ftracef0 ("New_Window: calling delete_file_window\n");
    delete_file_window (window);
    return NULL;
  }
  ftracef0 ("New_Window: calling win_active_inc\n");
  win_activeinc ();
  
  window->selection.count       = 0;
  window->selection.flags       = 0;
  window->selection.transsprite = NULL;
  window->link   = main_windows;
  main_windows   = window;
  window->handle = w;
  window->tag    = main_window_is_file;
  window->data   = (main_info_block *) file;
  file->filename = NULL;      /* indicates window is "untitled" */
  file->window   = window;

  ftracef2 ("New_Window: created main_file at "
      "0x%X, spritearea at 0x%X (flexing)\n", file, file->spritearea);

  return window;
}

/*********************************************
 * Handle clicks on the bucket of blood icon *
 *********************************************/

static void main_iconclick (wimp_i iconno)

{ main_window *wind;

  ftracef0 ("main_iconclick\n");

  iconno = iconno;
  ftracef1 ("main_iconclick %d\n", iconno);
  if ((wind = New_Window (FALSE)) != NULL)
  { main_set_extent (wind);
    main_check_position (wind);

    /*open create box offset to filer window*/
    psprite_create_show (wind, TRUE, msgs_lookup ("PntF7"));
  }
}

/***************************************************************************
 *                                                                         *
 *  Background message receiver: allow drops onto icon.                    *
 *                                                                         *
 ***************************************************************************/

static char *write_options (void)

{ /*Translate main_current_options to string (in static space).*/
  static char buffer [MAX_OPTIONS + 1];
  int len;
  main_options *opt  = &main_current_options;
  main_options *opt0 = &initial_options;
    /*name equivalence to save typing.*/

  ftracef0 ("write_options\n");
  buffer [0] = '\0';

  if (memcmp (&opt->display, &opt0->display, sizeof opt->display) != 0)
  { char D [32];

    sprintf (D, "D%c%c ", opt->display.full_info? 'F': 'D',
      opt->display.use_desktop_colours? 'W': 'B');
    strcat (buffer, D);
  }

  if (memcmp (&opt->colours, &opt0->colours, sizeof opt->colours) != 0)
  { char C [32];

    sprintf (C, "C%c%s ", opt->colours.show_colours? '+': '-',
      opt->colours.small_colours? "S": "");
    strcat (buffer, C);
  }

  if (memcmp (&opt->tools, &opt0->tools, sizeof opt->tools) != 0)
  { char T [32];

    sprintf (T, "T%c ", opt->tools.show_tools? '+': '-');
    strcat (buffer, T);
  }

  if (memcmp (&opt->zoom, &opt0->zoom, sizeof opt->zoom) != 0)
  { char Z [32];

    sprintf (Z, "Z%d:%d ", opt->zoom.mul, opt->zoom.div);
    strcat (buffer, Z);
  }

  if (memcmp (&opt->grid, &opt0->grid, sizeof opt->grid) != 0)
  { char G [32];

    sprintf (G, "G%d ", opt->grid.colour);
    if (opt->grid.show) strcat (buffer, G);
      /*Stupid fix because G<n> => grid on*/
  }

  if (memcmp (&opt->extended, &opt0->extended, sizeof opt->extended) != 0)
    if (opt->extended.on) strcat (buffer, "X ");

  if ((len = strlen (buffer)) > 0)
    /*Overwrite the last space with '\0' for neatness*/
    buffer [--len] = '\0';

  return buffer;
}

static void New_File (char *name)

{ main_window *w = New_Window (TRUE);

  ftracef0 ("New_File\n");
  if (w)
  { int ok = 0 /*for Norcroft*/;

    if (name != (char *) -1)
    { char *crap;

      ok = xferrecv_checkinsert (&crap);
      ftracef1 ("checkinsert gave type %d\n", ok);
    }

    visdelay_begin ();
    ok = Load_File (w, name, 0, 0);
    visdelay_end ();

    if (name != (char *) -1)
       /* must acknowledge message or we'll get an error */
       xferrecv_insertfileok ();

    if (ok > 0)
    { main_check_position (w);
      if (w->data->file.spritearea->number == 1 &&
            /*Don't attempt sprites with illegal modes. JRC 21st Nov 1994*/
            bbc_modevar
            (  ((sprite_header *) (w->data->file.spritearea + 1))->mode,
               bbc_Log2BPP
            ) != -1)
        sprwindow_new (w->data->file.sprites);
    }
    else
      delete_file_window (w);
  }
}

void main_help_message (char *tag, wimp_eventstr *e)

{ ftracef0 ("main_help_message\n");
  if (e->data.msg.data.helprequest.m.i >= -1)
  { e->data.msg.hdr.your_ref = e->data.msg.hdr.my_ref;
    e->data.msg.hdr.action = wimp_MHELPREPLY;
    e->data.msg.hdr.size = 256; /* be generous! */

    strcpy (e->data.msg.data.helpreply.text, msgs_lookup (tag));

    wimpt_noerr (wimp_sendmessage (wimp_ESEND, &e->data.msg,
        e->data.msg.hdr.task));
  }
}

static void print_file (char *name)

{ main_window *w = New_Window (TRUE);

  ftracef0 ("print_file\n");
  if (w)
  { int ok;

    ftracef1 ("Print sprite file '%s'\n", name);
    visdelay_begin ();
    ok = Load_File (w, name, 0, 0);
    visdelay_end ();
    if (ok > 0)
    { main_sprite *sprite = w->data->file.sprites;
      if (sprite != NULL) menus_do_print (sprite); /*Don't queue it*/
    }

    if (ok >= -1) delete_file_window (w);
  }
}

void main_set_printer_data (void)

{ print_pagesizestr ps;

  /*Now only updates menus_print_where if the bottom left origin has changed*/
  ftracef0 ("set printer_data\n");
  if (!print_pagesize (&ps))
  { if ((menus_print_last_where.dx != ps.bbox.x0) ||
        (menus_print_last_where.dy != ps.bbox.y0))
    { menus_print_last_where.dx = ps.bbox.x0;
      menus_print_last_where.dy = ps.bbox.y0;
      menus_print_where = menus_print_last_where;
      ftracef2 ("new print position %d %d\n",
          menus_print_where.dx, menus_print_where.dy);
    }
  }
}

static void set_icon (wimp_w w, wimp_i i, char *buffer, int size)

{ wimp_icon       wi;
  wimp_redrawstr   r;

  ftracef0 ("set_icon\n");
  /*A-RO-???? JRC 25 Sep 1991*/
  if (wimpt_complain (wimp_get_icon_info (w, i, &wi)) != NULL)
    return;
  memcpy (wi.data.indirecttext.buffer, buffer, size);
  r.w   = w;
  r.box = wi.box;
  wimpt_complain (wimp_force_redraw (&r));
}


static void Background_Events (wimp_eventstr *e, void *handle)

{ ftracef0 ("Background_Events\n");
  handle = handle; /* avoid not used warning */

  #if TRACE
    ftracef1 ("Got Icon bar event %d\n", e->e);
    if (e->e == 17 || e->e == 18)
      ftracef1 ("Got Wimp Message %d\n", e->data.msg.hdr.action);
  #endif

  switch (e->e)
  { case wimp_ESEND:
    case wimp_ESENDWANTACK:
      switch (e->data.msg.hdr.action)
      { case wimp_MPREQUIT:
        { int count = menus_files_modified ();

          if (count != 0)
          { /* First, acknowledge the message. */
            wimp_t taskmgr = e->data.msg.hdr.task;
            int original_size = e->data.msg.hdr.size,
              original_words0 = e->data.msg.data.words [0];

            e->data.msg.hdr.your_ref = e->data.msg.hdr.my_ref;
            wimpt_noerr (wimp_sendmessage (wimp_EACK,
                                 &e->data.msg,
                                 e->data.msg.hdr.task));
            /* And then tell the user. */
            if (menus_quit_okayed (count))
            { main_window *w;
              /* start up the closedown sequence again. */
              /* We assume that the sender is the Task Manager, and that
                  sh-ctl-12 is the closedown key sequence. */
              wimp_eventdata ee;

              /* now tidy up so that we don't object the next time the
                  message comes round */
              for (w = (main_window *) &main_windows;
                  w->link->link != NULL;)
                if (w->link->tag == main_window_is_file)
                { delete_file_window (w->link);
                  w = (main_window *) &main_windows;
                      /* start again from the top */
                }
                else
                  w = w->link;

              if (original_size > sizeof (wimp_msghdr) &&
                  (original_words0 & 1 /*Killed from task manager?*/))
              { /*Acknowledged the prequit, the user doesn't want its data -
                  die!*/
                m_SUMMARY ();
                exit (0);
              }
              else
              { /*Acknowledged the prequit, the user doesn't want its data,
                  this was a desktop closedown - S-C-F12*/
                wimpt_noerr (wimp_get_caret_pos (&ee.key.c));
                ee.key.chcode = akbd_Sh + akbd_Ctl + akbd_Fn12;
                wimpt_noerr (wimp_sendmessage (wimp_EKEY,
                    (wimp_msgstr *) &ee, taskmgr));
              }
            }
          }
        }
        break;

        case wimp_MDATASAVE:
          if (ramtransfer_file (&e->data.msg.data.datasave))
            New_File ((char *) -1);
        break;

        case wimp_MDATAOPEN:
          if (e->data.msg.data.dataopen.type != FileType_Sprite) break;
        /*Fall through*/

        case wimp_MDATALOAD:
          ftracef1 ("wimp_DATALOAD %s\n", e->data.msg.data.dataload.name);
          New_File ((char *) &e->data.msg.data.dataload.name);
        break;

        case wimp_MPrintTypeOdd:
        { char *name;

          ftracef0 ("Printer broadcast\n");
          /*FIX G-RO-7139 17 Oct '91 We must print the file now, not
            just queue it (was print_file (name);).*/
          if (xferrecv_checkprint (&name) == FileType_Sprite)
          { main_window *w;

            ftracef1 ("printing file \"%s\"\n", name);
            if ((w = New_Window (TRUE)) != NULL)
            { int ok;

              visdelay_begin ();
              ok = Load_File (w, name, 0, 0);
              visdelay_end ();
              if (ok > 0)
              { main_sprite *sprite = w->data->file.sprites;

                if (sprite != NULL)
                  menus_do_print (sprite);
                      /*was menus_print_sprite (sprite, 0)*/
              }

              if (ok >= -1) delete_file_window (w);
            }

            xferrecv_printfileok (-1);
          }
        }
        break;

        case wimp_MSetPrinter:
          main_set_printer_data ();
        break;

        case wimp_PALETTECHANGE:
          os_swix0 (ColourTrans_InvalidateCache);
        /*Fall through*/
        case wimp_MMODECHANGE:
        { main_window *window;
          os_error *error = NULL;

          ftracef1 ("Message %d\n", e->data.msg.hdr.action);
          wimpt_checkmode ();

          if ((error = psprite_set_default_translations ()) != NULL)
            goto changed;

          for (window = main_windows; window != NULL; window = window->link)
            if (window->tag == main_window_is_file)
            { if ((error = psprite_set_plot_info (&window->data->file)) !=
                  NULL)
                goto changed;

              if ((error = psprite_set_colour_info (&window->data->file)) !=
                  NULL)
                goto changed;
            }

          for (window = main_windows; window != NULL; window = window->link)
            if (window->tag == main_window_is_sprite)
            { main_sprite *sprite = window->data->sprite.sprite;

              if (sprite->colourhandle != 0 && sprite->colourdialogue == 0)
                main_force_redraw (sprite->colourhandle);
            }

          for (window = main_windows; window != NULL; window = window->link)
            if (window->handle != 0)
              main_force_redraw (window->handle);

          if (toolwindow_current_tool == &tools_brushpaint)
          { if ((error = psprite_free_brush_blocks ()) != NULL)
              goto changed;
            if ((error = psprite_set_brush_colour_translations ()) != NULL)
              goto changed;
          }
          else if (toolwindow_current_tool == &tools_textpaint)
          { ftracef0 ("changing mode for toolbox\n");
            tools_get_default_text_size ();
            if (toolwindow_handle != 0) /*A-RO-???? JRC 25 Sep 1991*/
            { set_icon (toolwindow_handle, tools_icons [3],
                  tools_text_xsize, 5);
              set_icon (toolwindow_handle, tools_icons [5],
                  tools_text_ysize, 5);
              set_icon (toolwindow_handle, tools_icons [7],
                  tools_text_xspace, 5);
            }
          }

        changed:
          wimpt_noerr (error);
            /*Die noisily if anything went wrong on a mode change. This is
              the best we can do - we can't continue with no translation
              tables, and this at least saves the user's files before
              dying.*/
        }
        break;

        case wimp_MHELPREQUEST:
        { main_window *window;

          ftracef0 ("Help request on icon\n");
          /*Look to see if this is a request to an adopted colour picker
            window, if it's not just give generic 'This is paint' help */
          for (window = main_windows; window != NULL; window = window->link)
            if (window->tag == main_window_is_sprite)
            { if (window->data->sprite.sprite->colourhandle == e->data.msg.data.helprequest.m.w)
              { os_swix2 (ColourPicker_HelpReply, 0, &e->data);
                break;
              }
            }
          if (window == NULL)
          { e->data.msg.data.helprequest.m.i = 0;
            main_help_message ("PntH5", e);
          }
        }
        break;

        case wimp_SAVEDESK:
          if (strlen (Paint_Dir) > 0) /*save if we know where we started*/
          { os_gbpbstr gbpb_str;
            char lines [19 + MAX_OPTIONS + 3 + FILENAME_MAX + 2];

            sprintf (lines, "Set Paint$Options \"%s\"\n/%s\n",
                write_options (), Paint_Dir);

            gbpb_str.action = 2; /* write at current position */
            gbpb_str.file_handle = e->data.msg.data.savedesk.filehandle;
            gbpb_str.data_addr = (void *) lines;
            gbpb_str.number = strlen (lines);

            if (wimpt_complain (os_gbpb (&gbpb_str)) != NULL)
            { e->data.msg.hdr.your_ref = e->data.msg.hdr.my_ref;
              e->data.msg.hdr.size = 20;
              wimpt_noerr (wimp_sendmessage (wimp_EACK, &e->data.msg,
                  e->data.msg.hdr.task));
            }
          }
        break;

        case message_COLOUR_PICKER_CLOSE_DIALOGUE_REQUEST:
        { colourpicker_d d = (colourpicker_d) e->data.msg.data.words [0];
          main_window *w;

          ftracef0 ("message_COLOUR_PICKER_CLOSE_DIALOGUE_REQUEST\n");
          /*Update the sprite info block to reflect the fact that there are
            no colours*/
          for (w = main_windows; w != NULL; w = w->link)
            if (w->tag == main_window_is_sprite)
            { main_sprite *sprite = w->data->sprite.sprite;

              if (sprite->colourdialogue == d)
              { ftracef1 ("Found given picker %s\n", sprite->colourtitle);
                sprite->colourdialogue = 0;
                sprite->colourhandle = 0;
                m_FREE (sprite->colourtitle, 23);
              }
            }

          os_swi2 (ColourPicker_CloseDialogue, 0, d);
          main_current_options.colours.show_colours = FALSE;
        }
        break;

        case message_COLOUR_PICKER_COLOUR_CHANGED:
        { colourpicker_d d = (colourpicker_d) e->data.msg.data.words [0];
          main_window *w;

          ftracef0 ("message_COLOUR_PICKER_COLOUR_CHANGED\n");
          /*Update the sprite info block with the new colour*/
          for (w = main_windows; w != NULL; w = w->link)
            if (w->tag == main_window_is_sprite)
            { main_sprite *sprite = w->data->sprite.sprite;

              if (sprite->colourdialogue == d)
              { ftracef1 ("Found given picker %s\n", sprite->colourtitle);
                if ((e->data.msg.data.words [1] &
                    colourpicker_COLOUR_TRANSPARENT) != 0)
                  sprite->gcol.alpha = 0;
                else
                {
                  sprite_colour col;
                  os_swi3r (ColourTrans_ReturnColourNumberForMode,
                      e->data.msg.data.words [2],
                      psprite_address (sprite)->mode, 0,
                      &col.colour, NULL, NULL);
                  sprite->gcol = colours_unpack_colour(sprite, col);
                  ftracef2 ("rgb is 0x%X => colour number 0x%X\n",
                      e->data.msg.data.words [2], sprite->gcol.colour);
                }
              }
            }
        }
        break;

        default:
          ftracef1 ("Got icon message 0x%X\n", e->data.msg.hdr.action);
        break;
      }
    break;
  }
}

static void read_options (void)

{ /*Sets main_current_options. Called only once, at startup. JRC*/
  char buffer [MAX_OPTIONS + 1], *token, *options;
  main_options *opt = &main_current_options;
    /*name equivalence to save typing.*/

  ftracef0 ("read_options\n");
  if ((options = getenv ("Paint$Options")) != NULL)
    sprintf (buffer, "%.*s", MAX_OPTIONS, options);
  else
    buffer [0] = '\0';
  ftracef1 ("paint options are '%s'\n", buffer);

  /* Set defaults */
  *opt = initial_options;
  ftracef0 ("read_options: set defaults\n");

  /* Get tokens separated by spaces */
  for (token = strtok (buffer, " "); token != NULL;
      token = strtok (NULL, " "))
  { switch (toupper (token [0]))
    { case 'D': /* D(D|F)?(W|B)? */
        { char *cc;

          for (cc = &token [1]; *cc != NULL; cc++)
            switch (toupper (*cc))
            { case 'D': opt->display.full_info = FALSE; break;
              case 'F': opt->display.full_info = TRUE; break;
              case 'W': opt->display.use_desktop_colours = TRUE; break;
              case 'B': opt->display.use_desktop_colours = FALSE; break;
            }
        }
      break;

      case 'G': /* G(+|-)?<n>? */
      { char *cc, *rest;

        for (cc = &token [1]; *cc != '\0';)
          if (isdigit (*cc))
          { opt->grid.colour = (int) strtol (cc, &rest, 10);
            if (rest == cc) break;
            cc = rest;
          }
          else
          { if (*cc == '+')
              opt->grid.show = TRUE;
            else if (*cc == '-')
              opt->grid.show = FALSE;
            cc++;
      }   }
      break;

      case 'Z': /* Z<a>:<b> */
        { int mul, div;
          char  *rest;

          mul = (int) strtol (token + 1, &rest, 10);
          if (rest != token && toupper (*rest) != ':') break;
          div = (int) strtol (rest + 1, &rest, 10);
          if (rest == token) break;

          if (mul < 1) mul = 1;
          if (div < 1) div = 1;
          opt->zoom.mul = mul;
          opt->zoom.div = div;
        }
      break;

      case 'T': /* T(+|-)? */
        if (token [1] == '+')
          opt->tools.show_tools = TRUE;
        else if (token [1] == '-')
          opt->tools.show_tools = FALSE;
      break;

      case 'C': /* C(+|-)?(S|L)? */
      { char *cc;

        for (cc = &token [1]; *cc != '\0'; cc++)
          switch (toupper (*cc))
          { case '+': opt->colours.show_colours = TRUE; break;
            case '-': opt->colours.show_colours = FALSE; break;
            case 'S': opt->colours.small_colours = TRUE; break;
            case 'L': opt->colours.small_colours = FALSE; break;
      }   }
      break;

      case 'X': /* X? */
        opt->extended.on = TRUE;
      break;
    }
  }
}

static menu main_iconmenumaker (void *handle)

{ ftracef0 ("main_iconmenumaker\n");
  handle = handle;
  help_register_handler (&help_simplehandler, (void *) "ICONB");
  menu_setflags (main_menu, i_GetScreen, FALSE, sshot.active);
  return main_menu;
}

/***************************************************************************
 *                                                                         *
 *  Main program. Trivial setup, then a trivial loop!                      *
 *                                                                         *
 ***************************************************************************/

static BOOL Matches (char *a, char *b)

{ ftracef0 ("Matches\n");
  while (*a || *b)
  if (tolower (*a++) != tolower (*b++)) return 0;

  return 1;
}

static BOOL Help_Process (wimp_eventstr *event, void *h)

{ ftracef0 ("Help_Process\n");
  h = h;
  return help_process (event);
}

/* Fixed stack size !!!
 * 5k is the max required for zoom
 * 6*256 is needed for buffer_sprite_palette
 * .5k is a bodge safety factor.
 * Extra 20K needed for tracing
 */
#if TRACE
  int __root_stack_size = 20*1024+5*1024+6*256+512+512+512;
#else
  int __root_stack_size = 5*1024+6*256+512+512+512;
#endif

#if 0
extern int disable_stack_extension;
#endif

int main (int argc, char *argv[])

{ int offset;
  main_sprite **sprptr;
  int i = 0;
  #if CATCH_SIGNALS
    int s, sig;
  #endif

  static wimp_msgaction Messages [] =
    { wimp_MDATASAVE,
      wimp_MDATASAVEOK,
      wimp_MDATALOAD,
      wimp_MDATALOADOK,
      wimp_MDATAOPEN,
      wimp_MRAMFETCH,
      wimp_MRAMTRANSMIT,
      wimp_MPREQUIT,
      wimp_PALETTECHANGE,
      wimp_SAVEDESK,
      wimp_MDATASAVED,
      wimp_MMENUWARN,
      wimp_MMODECHANGE,
      wimp_MHELPREQUEST,
      wimp_MHELPREPLY,
      wimp_MPrintFile,
      wimp_MWillPrint,
      wimp_MPrintTypeOdd,
      wimp_MPrintTypeKnown,
      wimp_MSetPrinter,
      wimp_MPrintError,
      wimp_MPrintSave,
      (wimp_msgaction) message_COLOUR_PICKER_CLOSE_DIALOGUE_REQUEST,
      (wimp_msgaction) message_COLOUR_PICKER_COLOUR_CHANGED,
      wimp_MCLOSEDOWN
    };

  #if 0
    extern void __heap_checking_on_all_allocates (BOOL),
        __heap_checking_on_all_deallocates (BOOL);
  #endif

  #if 0
  disable_stack_extension = 1;
  #endif

  /*  Now call new function to set up default signal handlers,
   *  before we've even tried to open message files etc.
   */

  wimpt_install_signal_handlers ();

  setlocale (LC_ALL, "");

  #if 0
    __heap_checking_on_all_allocates   (TRUE);
    __heap_checking_on_all_deallocates (TRUE);
  #endif

  ftrace_on ();
  ftracef0 ("main\n");

  res_init ("Paint");

  /* OSS Read Messages file by explicit pathname. */
  msgs_readfile ("Paint:Messages");

  wimpt_wimpversion (300);
  wimpt_messages (Messages);
  wimpt_init (msgs_lookup ("Pnt00"));

  flex_init ();
  heap_init (FALSE /* non-compacting */);

  /* OSS Read Templates file by explicit pathname. */
  template_readfile ("Paint:Templates");

  visdelay_init ();
  dbox_init ();

  /* OSS Read Sprites file by explicit name. */
  resspr_readfile ("Paint:Sprites");

  dboxquery_close (0);
  dboxquery_quit (0); /* Reserves space */
  alarm_init ();

  init_statics ();

  baricon (msgs_lookup ("BarIcon"), /* OSS Look sprite name up in Messages */
        1 /*was (int) resspr_area (). JRC 14 June 1990*/,
    main_iconclick);

  #if 1
  { main_menu = menu_new (msgs_lookup ("Pnt00"), msgs_lookup ("PntMI"));

    if (!event_attachmenumaker (win_ICONBAR, &main_iconmenumaker,
        &menus_icon_proc, NULL))
      werr (TRUE, msgs_lookup ("PntEH"));
  }
  #else
   if (!event_attachmenu (win_ICONBAR,
     menu_new (msgs_lookup ("Pnt00"), msgs_lookup ("PntMI")),
         menus_icon_proc, 0))
   werr (TRUE, msgs_lookup ("PntEH"));
  #endif

  load_resources ();

  nextx = startx = file_template.t.box.x0;
  nexty = starty = file_template.t.box.y1;

  /* set up a dummy window event handler to get icon messages */
  win_register_event_handler (win_ICONBARLOAD, Background_Events, 0);
  win_claim_unknown_events (win_ICONBARLOAD);

  /*Add an unknown event handler for menu help messages.*/
  win_add_unknown_event_processor (&Help_Process, NULL);

  /* Read Paint$Dir for desksaving */
  os_read_var_val ("Paint$Dir", Paint_Dir, FILENAME_MAX);
  read_options ();
  ftracef1 ("Options are \"%s\"\n", write_options ());

  menus_init ();

  toolwindow_init ();

  psprite_set_default_translations ();
      /* sprite handler initialisation */

  sprptr = &fudgefile.sprites;
  fudgefile.spritearea = resspr_area ();
  ftracef1 ("sprite area 0x%X\n", fudgefile.spritearea);
  for (offset = psprite_first (&fudgefile.spritearea); offset != 0;
      offset = psprite_next (&fudgefile.spritearea, offset))
  { if ((*sprptr = psprite_new (offset, i++, &fudgefile)) == NULL)
      werr (TRUE, msgs_lookup ("PntEI"));

    sprptr = &(*sprptr)->link; /*keep at end of list*/
  }
  ftracef0 ("psprite_set_plot_info (&fudgefile);\n");
  psprite_set_plot_info (&fudgefile);
  ftracef0 ("psprite_set_colour_info (&fudgefile);\n");
  psprite_set_colour_info (&fudgefile);

  ftracef0 ("main_set_printer_data ();\n");
  main_set_printer_data ();

  #if CATCH_SIGNALS
    /*Catch all signals we can.*/
    for (s = 1; s < SIG_LIMIT; s++)
      if (s != SIGINT && (Saved_Handlers [s] = signal (s, SIG_IGN)) !=
          SIG_IGN && signal (s, &Signal_Handler) == SIG_ERR)
        werr (FALSE, _kernel_last_oserror ()->errmess);

    if ((sig = setjmp (Buf)) != 0)
    { /*Save everything we can ...*/
      char preserve [FILENAMEMAX + 1];
      char *scrap_dir;
      char *paint;
      int f = 0;
      BOOL reported = FALSE;
      os_filestr file_str;
      os_regset regs;
      main_window *w;
      _kernel_oserror error;

      /*Remember the error first.*/
      _kernel_oserror *last_error = _kernel_last_oserror();
      if (last_error != NULL)
        memcpy (&error, last_error, sizeof(_kernel_oserror));
      else
      {
        error.errnum = 0;
        sprintf(error.errmess,"Caught signal %d",sig); /* Should probably be sent through messagetrans, but this case shouldn't happen anyway */
      }

      ftracef2 ("CAUGHT SIGNAL %d!\nError was \"%s\"\n", sig, error.errmess);
      
      scrap_dir = getenv ("WIMP$ScrapDir");
      paint = msgs_lookup ("Pnt00");

      /*Set all handlers back to their previous setting.*/
      for (s = 1; s < SIG_LIMIT; s++)
        if (s != SIGINT && (!(Saved_Handlers [s] == SIG_ERR ||
            Saved_Handlers [s] == SIG_IGN) &&
            signal (s, Saved_Handlers [s]) == SIG_ERR))
          werr (FALSE, _kernel_last_oserror ()->errmess);

      if (scrap_dir != NULL)
        for (w = main_windows; w != NULL; w = w->link)
          if (w->tag == main_window_is_file && w->data->file.modified)
          { if (!reported)
            { struct {int errno; char errmess [sizeof "PntX"];} PntX =
                  {0, "PntX"};

              regs.r[0] = (int)&PntX;
              regs.r[1] = (int)msgs_main_control_block ();
              regs.r[2] = NULL;
              regs.r[3] = 0;
              regs.r[4] = (int)error.errmess;
              regs.r[5] = (int)"<WIMP$ScrapDir>";
              regs.r[6] = (int)paint;
              regs.r[7] = 0;
              os_swix (MessageTrans_ErrorLookup, &regs);
              regs.r[1] = 3 /*OK and Cancel boxes*/;
              regs.r[2] = (int)paint;
              os_swix (Wimp_ReportError, &regs);
              reported = TRUE;

              if (regs.r[1] == 2) break; /*cancel*/

              /*Make the directory, if necessary.*/
              sprintf (preserve, "%s.%s", scrap_dir, paint);

              file_str.action = 8 /*create directory*/;
              file_str.name   = preserve /*name*/;
              file_str.start  = 0 /*default number of entries*/;
              ftracef1 ("making directory \"%s\"\n", preserve);
              if (wimpt_complain (os_file (&file_str)) != NULL)
                return 1;
            }

            sprintf (preserve, "%s.%s.%d", scrap_dir, paint, f++);
            ftracef2 ("Attempting to save \"%s\" in \"%s\"\n",
                w->data->file.filename != NULL? w->data->file.filename:
                "<untitled>", preserve);
            (void) sprite_area_save (w->data->file.spritearea, preserve);
              /*Carry on with the next even if this one failed.*/
          }

      /*Report the error if we haven't yet.*/
      if (!reported)
        wimpt_complain ((os_error *) &error);

      return 1;
    }
  #endif

  while (--argc)
  { ftracef1 ("process arg '%s'\n", * (argv + 1));
    if (Matches (*++argv, "-print"))
    { if (--argc)
        print_file (*++argv);
      else
        argc=1; /* ignore bad parameters */
    }
    else /* must be a filename */
    { main_window *w = New_Window (TRUE);

      if (w)
      { int ok /*for Norcroft*/;

        ftracef1 ("load into new window %d\n", w->handle);
        visdelay_begin ();
        ok = Load_File (w, *argv, 0, 1);
        visdelay_end ();

        if (ok > 0)
        { main_check_position (w);
          if (w->data->file.spritearea->number == 1)
            sprwindow_new (w->data->file.sprites);
        }
        else
          delete_file_window (w);
            /* might have been asked to run with a non-sprite file */
      }
    }
  }

  ftracef0 ("Start main loop.....\n");
  for (;;) /* ever */
   event_process ();
}
