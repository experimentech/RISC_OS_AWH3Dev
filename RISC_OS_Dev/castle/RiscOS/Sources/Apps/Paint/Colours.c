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
/* > C.Colours
 *
 *  Paint: Arthur 2 sprite editor
 *   Main loop and resource loading
 *
 *  Author: A.P. Thompson
 *
 * Upgraded to RISCOSlib - DAHE - 16 Aug 1989
 *  DAHE, 28 Aug 89 - internationalisation
 *  JAB,  30 Oct 90 - Brings colour window to the front it is already open
 *  JAB,  23 Nov 90 - Doesn't reset options when closing colour window
 */

#include <swis.h>
#include "Global/VduExt.h"

#include "bbc.h"
#include "wimpt.h"

#include "ftrace.h"
#include "m.h"
#include "main.h"
#include "Menus.h"
#include "PSprite.h"
#include "SprWindow.h"
#include "ToolWindow.h"
#include "Colours.h"
#include "PaintLib.h"

/**********************************
 * Number of colours in a sprite  *
 **********************************/

int colours_count (main_sprite *sprite)

{
  int mode = psprite_address(sprite)->mode;
  int ncolour,modeflags;
  ncolour = bbc_modevar(mode, bbc_NColour)+1;
  modeflags = bbc_modevar(mode, bbc_ModeFlags);

  /* Use similar logic to psprite_get_colours() */
  if (modeflags == -1) /* i.e. error */
    ncolour = -1;
  else if (ncolour == 64)
    ncolour = 256;
  else if ((ncolour == 65536) && !(modeflags & ModeFlag_64k))
    ncolour = 32768;
  else if (!ncolour)
    ncolour = 1<<24;

  ftracef2 ("colours_count (\"%.12s\") -> 0x%X\n",
      psprite_address (sprite)->name,
      ncolour);

  return ncolour;
}

/**************************************************
 * Set gcol, doing tint if dest = 256 colour mode *
 **************************************************/

char colours_gcol_ttab [] =
    "\00\01\20\21\02\03\22\23\04\05\24\25\06\07\26\27\10"
    "\11\30\31\12\13\32\33\14\15\34\35\16\17\36\37\40\41"
    "\60\61\42\43\62\63\44\45\64\65\46\47\66\67\50\51\70"
    "\71\52\53\72\73\54\55\74\75\56\57\76\77";

void colours_set_gcol (int col, int action, int back)

{ switch ((unsigned) bbc_modevar (-1, bbc_NColour))
  { case 63u: case 0xFFFFu: case 0xFFFFFFFFu:
      bbc_gcol (action, colours_gcol_ttab [col >> 2] | back << 7);
      bbc_tint (2 | back, col & 3); /* library shifts it for me */
      ftracef3 ("GCOL 0x%X=%d, TINT %d\n",
          colours_gcol_ttab [col >> 2] | back << 7,
          colours_gcol_ttab [col >> 2] | back << 7, col & 3);
    break;

    case 1u: case 3u: case 15u: case 255u:
      os_swi2 (OS_SetColour, action | back << 4, col);
      ftracef2 ("SetColour 0x%X=%d\n", col, col);
    break;
  }
}

/***********************************************************
 * Set the gcol, doing sprite ECF selection if appropriate *
 ***********************************************************/

void colours_set_sprite_gcol (main_colour gcol, main_sprite *sprite, int back)

{ ftracef4 ("colours_set_sprite_gcol (0x%08x %d %d, ..., %d)\n", gcol.colour, gcol.alpha, gcol.ecf, back);

  if (gcol.ecf)
    psprite_set_ecf (sprite, gcol.colour, back);
  else
  {
    int col = colours_pack_alpha(sprite, gcol);
    if (colours_count (sprite) != 256 || psprite_hastruecolpal (sprite))
    { /*Deep sprite - just use OS_SetColour.*/
      ftracef2 ("OS_SetColour (%d, %d)\n",
          toolwindow_current_mode | back << 4, col);
      os_swix2 (OS_SetColour, toolwindow_current_mode | back << 4, col);
    }
    else
      colours_set_gcol (col, toolwindow_current_mode, back);
  }

  ftracef3 ("set gcol 0x%X %d %d\n", gcol.colour, gcol.alpha, gcol.ecf);
}

/**********************************************************************
 *                                                                    *
 *  Window event handler for sprite colour windows.                   *
 *                                                                    *
 **********************************************************************/

void colours_event_handler (wimp_eventstr *e, void *handle)

{ main_sprite *sprite = (main_sprite *) handle;
  int coloursize = sprite->coloursize, x_eig, y_eig, max_eig;

  ftracef0 ("colours_event_handler\n");
  x_eig = bbc_vduvar (bbc_XEigFactor);
  y_eig = bbc_vduvar (bbc_YEigFactor);
  if (x_eig > y_eig) max_eig = x_eig; else max_eig = y_eig;
  coloursize = (coloursize - 1 >> max_eig) + 1 << max_eig;

  switch (e->e)
  { case wimp_EOPEN:
      wimpt_complain (wimp_open_wind (&e->data.o));
    break;

    case wimp_EREDRAW:
    { int nc, lim, nacross, lb_bpp;
      BOOL more, mask;
      wimp_redrawstr rds;
      unsigned char mono_ttab [256];

      static const unsigned int mono_palette [] = {0x00000000, 0xFFFFFF00};

      mask = psprite_hasmask (sprite);
      lim = nc = colours_count (sprite);
      if (mask) lim++;
      for (more = 0; more < 4; more++)
        if (sprite->ECFs [more].sarea != NULL)
          lim++;
      lb_bpp = bbc_modevar (psprite_address (sprite)->mode, bbc_Log2BPP);

      rds.w = e->data.o.w;
      wimpt_noerr (wimp_redraw_wind (&rds, &more));

      nacross = (lim > 21? 16: 4)*coloursize;

      /*Get a mapping from the sprite to black and white.*/
      if (psprite_haspal (sprite))
        os_swi6 (ColourTrans_GenerateTable, sprite->file->spritearea,
            psprite_address (sprite), 0, (int) mono_palette, (int) mono_ttab,
            1 << 0 /*R1 is sprite*/);
      else
        os_swi6 (ColourTrans_GenerateTable, psprite_address (sprite)->mode,
            psprite_std_palettes [sprite->file->use_current_palette? 0: 1]
            [lb_bpp], 0, (int) mono_palette, (int) mono_ttab, 0);

      #ifdef XTRACE
      { int i;

        for (i = 0; i < 1 << (1 << lb_bpp); i++)
          ftracef2 ("mono_ttab [%d]: %d\n", i, mono_ttab [i]);
      }
      #endif

      while (more)
      { int i, colourx = -coloursize, coloury = 0, xpos, ypos;

        /*Is this a wide table?*/
        ftracef2 ("got a %d-entry sprite, table size %d\n",
            nc, sprite->transtab->ttab_size);

        wimp_setcolour (0);
        bbc_clg ();

        /* now convert to on_screen coordinates */
        for (i = 0; i < lim; i++)
        { int ECF = 0;
          colourx += coloursize;
          if (colourx + coloursize > nacross)
            colourx = 0, coloury -= coloursize;

          xpos = colourx + rds.box.x0 - rds.scx;
          ypos = coloury + rds.box.y1 - rds.scy;

          if (main_CLIPS (&rds.g, xpos, ypos - coloursize,
              xpos + coloursize, ypos))
          { int x, y;

            x = xpos + (1 << x_eig)/2;
            y = ypos - coloursize + (1 << y_eig)/2;

            if (i == nc && mask)
              psprite_ecf (0);
            else
            { if (i >= nc)     /* ECF! */
              { int ECFno;

                ECFno = i - nc;
                if (!mask) ECFno++;        /* ECF index + 1 */

                for (ECF = 0; ECFno; ECF++)
                  if (sprite->ECFs [ECF].sarea != NULL) ECFno--;

                psprite_plot_ecf_sprite (sprite, ECF-1, x, y);
                ftracef2 ("Got ECF %d; gcol %d\n", ECF, sprite->gcol);
              }
              else
              { if (sprite->transtab->table != 0)
                  switch (sprite->transtab->ttab_size/nc)
                  { case 1:
                    #ifdef JRC
                      colours_set_gcol (sprite->transtab->table [i], 0, 0);
                    #else
                    { unsigned char *t =
                          (unsigned char *) sprite->transtab->table;
                      os_swi2 (OS_SetColour, 0, t [i]);
                    }
                    #endif
                    break;

                    case 2:
                    { short *t = (short *) sprite->transtab->table;
                      os_swi2 (OS_SetColour, 0, t [i]);
                    }
                    break;

                    case 4:
                    { int *t = (int *) sprite->transtab->table;
                      os_swi2 (OS_SetColour, 0, t [i]);
                    }
                    break;
                  }
              }
            }

            if (!ECF) bbc_rectanglefill (x, y, coloursize - (1 << x_eig),
                coloursize - (1 << y_eig));

            /*If this is the selected colour, border is white, otherwise
              black.*/
            BOOL selected;
            if (ECF)
              selected = sprite->gcol.ecf && (sprite->gcol.colour == ECF-1);
            else if(i == nc)
              selected = !sprite->gcol.ecf && !sprite->gcol.alpha;
            else
              selected = !sprite->gcol.ecf && sprite->gcol.alpha && (sprite->gcol.colour == i);
            wimpt_noerr (wimp_setcolour (selected?
                0: 7));
            bbc_rectangle (x, y, coloursize - (1 << x_eig),
                coloursize - (1 << y_eig));

            /*Fill in the number (full size only).*/
            if
            ( coloursize == colours_SIZE
                #if !TRACE
                  && selected
                #endif
            )
            { unsigned int fg, bg;

              /*Find the RGB colour of this cell in the colours window.*/
              if (psprite_hastruecolpal (sprite))
                bg = (&psprite_address (sprite)->mode + 1) [2*i];
              else
              { if (psprite_haspal (sprite))
                  /*Use the brain-damaged palette.*/
                  bg = (&psprite_address (sprite)->mode + 1) [2*(i & 15)] |
                      (i & 16) << 11 | (i & 96) << 17 | (i & 128) << 24;
                else
                { /*Use the relevant "standard palette."*/
                  if (nc == 256)
                    bg = psprite_std_palettes
                        [sprite->file->use_current_palette? 0: 1]
                        [3] [i & 15] |
                        (i & 16) << 11 | (i & 96) << 17 | (i & 128) << 24;
                  else
                    bg = psprite_std_palettes
                        [sprite->file->use_current_palette? 0: 1]
                        [nc == 2? 0: nc == 4? 1: 2] [i];

                  /*Copy nybbles.*/
                  bg |= bg >> 4;
                }
              }

              if (mono_ttab [i /*was colour 31st Jan 1994*/])
                fg = 0 /*black*/;
              else
                fg = 0xFFFFFF00 /*white*/;

              if (os_swix3 (Wimp_TextOp, 0 /*SetColour*/, fg, bg) == NULL)
              { /*Do this with the WIMP font ...*/
                char s [10];

                if (i < nc)
                  sprintf (s, "%d", i);
                else if (!ECF)
                  s [0] = 'T', s [1] = '\0';
                else
                  sprintf (s, "E%d", ECF);

                os_swi6 (Wimp_TextOp, 2 /*RenderText*/, s,
                    -1, -1,
                    xpos + coloursize/2 -
                    (i < nc? (i < 10? 1: i < 100? 2: 3):
                    !ECF? 1: 2)*(main_FILER_TextWidth - 4)/2,
                    ypos - coloursize + (main_FILER_TextHeight/2));
              }
              else
              { /*WIMP Does not support wimptextop_set_colour.*/
                wimpt_noerr (wimp_setcolour (mono_ttab [i /*was colour 31st
                    Jan 1994*/]? 7: 0));

                bbc_move (xpos + coloursize/2 -
                    (i < nc? (i < 10? 1: i < 100? 2: 3):
                    !ECF? 1: 2)*(main_FILER_TextWidth - 4)/2,
                    ypos - (main_FILER_TextHeight/2));
                /*the main_FILER_TextWidth's have 4 taken off to set value
                  to the original size*/

                if (i < nc)
                  printf ("%d", i);
                else if (!ECF)
                  puts ("T");
                else
                  printf ("E%d", ECF);
              }
            }
          }
        }

        wimpt_noerr (wimp_get_rectangle (&rds, &more));
      }
    }
    break;

    case wimp_EBUT:
      if (e->data.but.m.bbits & (wimp_BRIGHT | wimp_BLEFT))
      { wimp_wstate whereisit;
        wimp_redrawstr rds;
        int x, y, ncols, ncs, perrow;
        main_colour oldgcol,newgcol;
        BOOL mask = psprite_hasmask(sprite);

        wimpt_noerr (wimp_get_wind_state (sprite->colourhandle, &whereisit));
        ncs = colours_count (sprite);
        if (!mask) ncs--;
        ncols = ncs;
        for (x=0; x<4; x++) if (sprite->ECFs[x].sarea != NULL) ncols++;
        perrow = ncols > 20 ? 16 : 4;

        /* convert to work extent coordinates */
        x = e->data.but.m.x-whereisit.o.box.x0+whereisit.o.x;
        y = - (e->data.but.m.y-whereisit.o.box.y1+whereisit.o.y);

        /* and now to colour number */
        x /= coloursize;
        if (x>=perrow) break;
        y /= coloursize;

        newgcol.colour = y*perrow + x;
        newgcol.alpha = 255;
        newgcol.ecf = FALSE;
        oldgcol = e->data.but.m.bbits & wimp_BLEFT ? sprite->gcol : sprite->gcol2;

        if (newgcol.colour > ncols) break;

        if (newgcol.colour > ncs)
        { int ECF, n = newgcol.colour - ncs;

          for (ECF = 0; n; ECF++)
             if (sprite->ECFs [ECF].sarea != NULL)
                n--;

          newgcol.colour = ECF-1;
          newgcol.ecf = TRUE;
        }
        else if((newgcol.colour == ncs) && mask)
        {
          newgcol.colour = 0;
          newgcol.alpha = 0;
        }

        ftracef2 ("Colour %d %d\n", newgcol.colour, newgcol.ecf /*sprite->gcol*/);
        rds.w = sprite->colourhandle;
        rds.box.x0 = x*coloursize /*x*coloursize*/;
        rds.box.y0 = -(y + 1)*coloursize /*rds.box.y1 - coloursize*/;

        rds.box.x1 = (x + 1)*coloursize /*rds.box.x0 + coloursize*/;
        rds.box.y1 =-y*coloursize /*-y*coloursize*/;
        wimpt_noerr (wimp_force_redraw (&rds));  /* of new colour */

        if (oldgcol.ecf)
        { int ECFno, n = 0;

          for (ECFno = 0; ECFno < oldgcol.colour; ECFno++)
            if (sprite->ECFs[ECFno].sarea != NULL) n++;

          oldgcol.colour = n + ncs + 1;
        }
        else if(!oldgcol.alpha)
          oldgcol.colour = ncs;

        rds.w = sprite->colourhandle;
        x = oldgcol.colour%perrow;
        y = oldgcol.colour/perrow;
        rds.box.x0 = x*coloursize /*x*coloursize*/;
        rds.box.y0 =- (y + 1)*coloursize /*rds.box.y1 - coloursize*/;

        rds.box.x1 = (x + 1)*coloursize /*rds.box.x0 + coloursize*/;
        rds.box.y1 =-y*coloursize /*-y*coloursize*/;
        wimpt_noerr (wimp_force_redraw (&rds));  /* of old colour */

        *(e->data.but.m.bbits & wimp_BLEFT ? &sprite->gcol : &sprite->gcol2) = newgcol;
      }
    break;

    case wimp_ECLOSE:
      ftracef0 ("Colour window close\n");
      colours_delete_window (sprite);
      main_current_options.colours.show_colours = FALSE;
    break;

    case wimp_ESEND:
    case wimp_ESENDWANTACK:
      if (e->data.msg.hdr.action == wimp_MHELPREQUEST)
      { ftracef0 ("Help request on colour window\n");
        main_help_message ("PntH6", e);
      }
    break;

    default:
      ftracef1 ("Poll returned event %d\n", e->e);
    break;
  }
  menus_insdel_frig ();
}

/*****************************************************
 *  Delete a sprite colour window                    *
 *****************************************************/

void colours_delete_window (main_sprite *sprite)

{ ftracef0 ("colours_delete_window\n");
  ftracef1 ("deleting colour window %d\n", sprite->colourhandle);

  m_FREE (sprite->colourtitle, 23); /*plug memory leak. J R C 29th Nov 1993*/
  if (sprite->colourdialogue != 0)
  { os_swi2 (ColourPicker_CloseDialogue, 0, sprite->colourdialogue);
    sprite->colourdialogue = 0;
  }
  else
    main_delete_window (sprite->colourhandle);
  sprite->colourhandle = 0;
}

/****************************************************
 *  Force display of sprite colour window           *
 ****************************************************/

static void calculate_colour_extent (main_sprite *sprite,
    wimp_box *box, char *title)

{ int ne, width, height, i, x_eig, y_eig, max_eig, coloursize;

  ftracef0 ("calculate_colour_extent\n");
  ne = colours_count (sprite);
  if (psprite_hasmask (sprite)) ne++;
  for (i = 0; i < 4; i++) if (sprite->ECFs [i].sarea != NULL) ne++;

  width  = ne >= 256? 16: 4;
  height = (ne - 1)/width + 1;
  ftracef2 ("colour window is %d x %d\n", width, height);

  x_eig = bbc_vduvar (bbc_XEigFactor);
  y_eig = bbc_vduvar (bbc_YEigFactor);
  if (x_eig > y_eig) max_eig = x_eig; else max_eig = y_eig;
  coloursize = (sprite->coloursize - 1 >> max_eig) + 1 << max_eig;

  /* make extent something appropriate */
  box->x0 = 0;
  box->y1 = 0;
  box->x1 = coloursize*width;
  box->y0 =-coloursize*height;

  i = (strlen (title) + 5)*(main_FILER_TextWidth - 4);
    /* set main_FILER_TextWidth to original size */
  if (box->x1 < i) box->x1 = i;
}

void colours_set_extent (main_sprite *sprite)

{ ftracef0 ("colours_set_extent\n");
  if (sprite->colourhandle != NULL)
  { wimp_winfo curr;
    wimp_redrawstr newext;

    curr.w = sprite->colourhandle;
    wimpt_noerr (paintlib_get_wind_info (&curr));

    newext.w = sprite->colourhandle;
    calculate_colour_extent (sprite, &newext.box,
                          curr.info.title.indirecttext.buffer);
    wimpt_noerr (wimp_set_extent (&newext));

    wimpt_noerr (wimp_open_wind ((wimp_openstr *) &curr));
    main_force_redraw (sprite->colourhandle);
  }
}

void colours_create_window (main_sprite *sprite)

{ wimp_openstr colours_open_str;
  wimp_wstate colours_w_state, sprite_w_state;
  wimp_redrawstr sprite_redraw_str;
  int colours_height, colours_width, nc;

  ftracef0 ("colours_create_window\n");
  if (sprite->colourhandle == 0)
  { char *sprname = psprite_address (sprite)->name;

    ftracef0 ("New sprite colour window\n");

    /*Get the state of the parent sprite window*/
    wimpt_noerr (wimp_get_wind_state (sprite->windows->window->handle,
        &sprite_w_state));

    /*And its outline*/
    sprite_redraw_str.w = sprite->windows->window->handle;
    wimpt_noerr (wimp_getwindowoutline (&sprite_redraw_str));

    /*Allocate store for the title*/
    if ((sprite->colourtitle = m_ALLOC (23)) == NULL)
    { main_NO_ROOM ("indirect title - sprite colours");
      return;
    }
    sprintf (sprite->colourtitle, msgs_lookup ("PntW7"), sprname);

    if ((nc = colours_count (sprite)) > 256)
    { /*Use a colour picker.*/
      colourpicker_dialogue dialogue;

      dialogue.flags       =
          ((psprite_transparency_type (sprite) != transparency_type_none)?
              colourpicker_DIALOGUE_OFFERS_TRANSPARENT: 0) |
          ((!sprite->gcol.alpha)? colourpicker_DIALOGUE_TRANSPARENT: 0) |
          (colourpicker_DIALOGUE_TYPE_CLICK << colourpicker_DIALOGUE_TYPE_SHIFT);
      ftracef1 ("flags set to 0x%X\n", dialogue.flags);
      dialogue.title       = sprite->colourtitle;
      dialogue.visible.x0  = sprite_redraw_str.box.x1;
      dialogue.visible.y0  = (int)0x80000000;
      dialogue.visible.x1  = 0x7FFFFFFF;
      dialogue.visible.y1  = sprite_w_state.o.box.y1;
      dialogue.xscroll     = 0;
      dialogue.yscroll     = 0;
      dialogue.colour      = (!sprite->gcol.alpha)? 0:
          colours_entry (psprite_address(sprite)->mode, sprite->gcol.colour);
      dialogue.size        = 0;

      if (wimpt_complain (os_swix2r (ColourPicker_OpenDialogue,
          colourpicker_OPEN_TOOLBOX, &dialogue, &sprite->colourdialogue,
          &sprite->colourhandle)) != NULL)
      { m_FREE (sprite->colourtitle, 23);
        sprite->colourtitle = 0;
        return;
      }
    }
    else
    { wimp_wind colours_wind;

      colours_wind = sprwindow_template.t;
      colours_wind.workflags = (wimp_iconflags) (wimp_IBTYPE*wimp_BCLICKAUTO);
      colours_wind.minsize = 0x00010001;      /* allow tinyness */
      colours_wind.titleflags = (wimp_iconflags) (colours_wind.titleflags | wimp_INDIRECT);
      colours_wind.title.indirecttext.bufflen = 23;
      colours_wind.title.indirecttext.buffer = sprite->colourtitle;
      colours_wind.title.indirecttext.validstring = 0;

      calculate_colour_extent (sprite, &colours_wind.ex,
                              colours_wind.title.indirecttext.buffer);
      colours_wind.box.x1 = colours_wind.box.x0 + colours_wind.ex.x1; /*new*/
      colours_wind.box.y0 = colours_wind.box.y1 + colours_wind.ex.y0;
      if (!main_create_window (&colours_wind, &sprite->colourhandle,
                          &colours_event_handler, sprite)) return;

      wimpt_noerr (wimp_get_wind_state (sprite->colourhandle,
          &colours_w_state));
      colours_width  = colours_w_state.o.box.x1 - colours_w_state.o.box.x0;
      colours_height = colours_w_state.o.box.y1 - colours_w_state.o.box.y0;

      colours_open_str.w = sprite->colourhandle;
      /* open colours_wind to right of its parent */
      colours_open_str.box.x0 = sprite_redraw_str.box.x1;
      colours_open_str.box.x1 = sprite_redraw_str.box.x1 + colours_width;
      colours_open_str.box.y0 = sprite_w_state.o.box.y1 - colours_height;
      colours_open_str.box.y1 = sprite_w_state.o.box.y1;
      colours_open_str.behind = -1;
      colours_open_str.x = 0;
      colours_open_str.y = 0;
      wimpt_noerr (wimp_open_wind (&colours_open_str));
    }
  }
  else
  { /* if the window is already open, then bring it to the front */
    wimp_wstate colour_w_state;

    wimpt_noerr (wimp_get_wind_state (sprite->colourhandle,
        &colour_w_state));
    colour_w_state.o.behind = -1;
    wimpt_noerr (wimp_open_wind (&colour_w_state.o));
  }
}

int colours_entry (int mode, int colour)

{ /*Returns the &BBGGRRxx palette entry corresponding to the given colour number.*/
  ftracef0 ("colours_entry\n");

  int ncolour,modeflags;
  ncolour = bbc_modevar(mode, bbc_NColour);
  modeflags = bbc_modevar(mode, bbc_ModeFlags);

  int r,g,b;

  /* Assume RGB colourspace */
  switch (ncolour)
  { case 4095:
      r = (colour & 0xF)*0x11;
      g = ((colour>>4) & 0xF)*0x11;
      b = ((colour>>8) & 0xF)*0x11;
      break;
    case 65535:
      r = 255*(colour & 0x1F)/31;
      if (modeflags & ModeFlag_64k)
      {
        g = 255*((colour & 0x7E0)>>5)/63;
        colour = colour>>11;
      }
      else
      {
        g = 255*((colour & 0x3E0)>>5)/31;
        colour = colour>>10;
      }
      b = 255*(colour & 0x1F)/31;
      break;
    case 1677215:
    case -1:
      r = colour & 0xff;
      g = (colour>>8) & 0xff;
      b = (colour>>16) & 0xff;
      break;

    default:
      ftracef0 ("INVALID SPRITE MODE!!!\n");
      return 0;
    break;
  }

  if(modeflags & ModeFlag_DataFormatSub_RGB)
  {
    return (r<<24) | (g<<16) | (b<<8);
  }
  else
  {
    return (r<<8) | (g<<16) | (b<<24);
  }
}

int colours_pack_alpha(main_sprite *sprite, main_colour gcol)
{
  int mode = psprite_address(sprite)->mode;
  int modeflags = bbc_modevar(mode, bbc_ModeFlags);
  int colour = gcol.colour;
  if ((modeflags != -1) && (modeflags & ModeFlag_DataFormatSub_Alpha))
  {
    int ncolour = bbc_modevar(mode, bbc_NColour);
    if(ncolour == 4095)
      colour |= (gcol.alpha & 0xf0)<<8;
    else if(ncolour == 65535)
      colour |= (gcol.alpha & 0x80)<<8;
    else
      colour |= gcol.alpha<<24;
  }
  return colour;
}

sprite_colour colours_pack_colour(main_sprite *sprite, main_colour gcol)
{
  sprite_colour colour;
  if (colours_count(sprite) != 256 || psprite_hastruecolpal (sprite))
  {
    colour.colour = colours_pack_alpha(sprite,gcol);
    colour.tint = 0;
  }
  else
  {
    colour.colour = colours_gcol_ttab [gcol.colour >> 2];
    colour.tint = (gcol.colour & 3) << 6;
  }
  return colour;  
}

main_colour colours_unpack_colour(main_sprite *sprite, sprite_colour colour)
{
  main_colour gcol;
  gcol.alpha = 255;
  gcol.ecf = FALSE;
  int nc = colours_count(sprite);
  if (nc != 256 || psprite_hastruecolpal (sprite))
  {
    gcol.colour = colour.colour;
    int modeflags = bbc_modevar(psprite_address(sprite)->mode, bbc_ModeFlags);
    if((modeflags != -1) && (modeflags & ModeFlag_DataFormatSub_Alpha))
    {
      if(nc == 4096)
      {
        gcol.alpha = (gcol.colour>>12) * 0x11;
        gcol.colour &= ~0xf000;
      }
      else if(nc == 32768)
      {
        if(!(gcol.colour & 32768))
          gcol.alpha = 0;
        gcol.colour &= ~32768;
      }
      else
      {
        gcol.alpha = gcol.colour >> 24;
        gcol.colour &= ~0xff000000;
      }
    }
  }
  else
  {
    gcol.colour =
        colours_gcol_ttab [colours_gcol_ttab [colours_gcol_ttab
        [colour.colour]]] << 2 | colour.tint >> 6;
  }
  return gcol;
}

sprite_maskstate colours_pack_mask(main_sprite *sprite, main_colour gcol)
{
  switch(psprite_transparency_type(sprite))
  {
  case transparency_type_onoffmask:
    return (gcol.alpha?sprite_masksolid:sprite_masktransparent);
  case transparency_type_alphamask:
    return (sprite_maskstate) gcol.alpha;
  }
  return sprite_masksolid;
}

main_colour colours_unpack_colour2(main_sprite *sprite, sprite_colour colour, sprite_maskstate mask)
{
  main_colour gcol = colours_unpack_colour(sprite,colour);
  switch(psprite_transparency_type(sprite))
  {
  case transparency_type_onoffmask:
    gcol.alpha = (mask==sprite_masksolid?255:0);
    break;
  case transparency_type_alphamask:
    gcol.alpha = mask;
    break;
  }
  return gcol;
}

