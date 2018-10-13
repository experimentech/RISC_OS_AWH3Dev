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
/*-> c.DrawFileIO
 *
 * File input/output for Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.14
 * History: 0.10 - 12 June 1989 - header added. Old code weeded.
 *                                upgraded to drawmod, visdelay
 *                 16 June 1989 - upgraded to msgs
 *          0.11 - 20 June 1989 - add load_named_file
 *                                draw_file_loadfile will set focus
 *          0.12 -  4 Aug  1989 - undo added
 *          0.13 - 11 Aug  1989 - common up save code
 *          0.14 - 22 Aug  1989 - undoing on save
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <swis.h>
#include "Global/FileTypes.h"

#include "os.h"
#include "bbc.h"
#include "flex.h"
#include "wimp.h"
#include "wimpt.h"
#include "werr.h"
#include "msgs.h"
#include "visdelay.h"
#include "xferrecv.h"
#include "xfersend.h"
#include "menu.h"
#include "drawmod.h"
#include "jpeg.h"
#include "dbox.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawAction.h"
#include "DrawCheck.h"
#include "DrawDispl.h"
#include "DrawDXF.h"
#include "DrawEnter.h"
#include "DrawFileIO.h"
#include "DrawMenu.h"
#include "DrawObject.h"
#include "DrawPrint.h"
#include "DrawSelect.h"
#include "DrawTextC.h"
#include "DrawUndo.h"

static struct
{ diagrec *diag;
  int filelen;
  fileIO_method method;
  int *maxbuf;
} owner_xfersend;

static struct
{ diagrec *diag;
  fileIO_method method;
  int filelen;
} owner_xferrecv;

static void claim_xfersend (diagrec *diag, fileIO_method method, int *maxbuf)
{ ftracef0 ("draw_file: claim_xfersend\n");
  owner_xfersend.diag   = diag;
  owner_xfersend.method = method;
  owner_xfersend.maxbuf = maxbuf;
}

static void claim_xferrecv (diagrec *diag, fileIO_method method)
{ ftracef0 ("draw_file: claim_xferrecv\n");
  owner_xferrecv.diag   = diag;
  owner_xferrecv.method = method;
}

/*-------------------------------------------------------------------------*/

static char *Load_Base;

static BOOL Extend_Buffer (char **buffer, int *size)

  /*New function called when the data is arriving other than in a diagram.
    J R C 25th Feb 1994*/

{ int extendby = 1024;

  ftracef2 ("draw_file: Extend_Buffer: *buffer 0x%X, "
      "*size is %d\n", *buffer, *size);

  ftracef3 ("draw_file: Extend_Buffer: flex_midextend (0x%X, %d, %d)\n",
      *buffer, *size, extendby);
  if (!FLEX_MIDEXTEND ((flex_ptr) &Load_Base, *size, extendby))
  { /*No room to extend*/
    Error (0, "FileN1");
    return FALSE;
  }

  /*Inc filelen by amount just transferred*/
  owner_xferrecv.filelen += *size;

  *buffer += *size;
  *size = extendby; /*and give it the new buffer size*/

  ftracef2 ("leaving Extend_Buffer, *buffer 0x%X, *size %d\n",
      *buffer, *size);

  return TRUE;
}

int draw_file_matches (char *a, char *b)
{ ftracef0 ("draw_file_matches\n");
  while (*a || *b)
    if (tolower (*a++) != tolower (*b++)) return 0;

  return 1;
}

static BOOL draw_file_write_bytes (int filehandle, char **bufp, int offset,
    int size)

{ ftracef4
  ( "draw_file: draw_file_write_bytes: filehandle: %d; bufp: 0x%X; "
        "offset: %d; size: %d\n",
    filehandle, bufp, offset, size
  );
  if (size <= 0) return TRUE;

  if (owner_xfersend.method == via_FILE)
  { os_gbpbstr gbpb;

    gbpb.action      = 2;                       /*write bytes to file*/
    gbpb.file_handle = filehandle;
    gbpb.data_addr   = (void*) (*bufp + offset);
    gbpb.number      = size;

    if (wimpt_complain (os_gbpb (&gbpb))) return FALSE;
  }
  else
  { int send;

    while (size > 0)
    { if (size > *owner_xfersend.maxbuf)
      { send = *owner_xfersend.maxbuf;
        size -= *owner_xfersend.maxbuf;
      }
      else
      { send = size; size = 0; }

      #if TRACE
      { int i;

        ftracef1 ("draw_file_write_bytes: writing %d bytes\n", send);
        ftracef (NULL, 0, "draw_file_write_bytes: bytes are ...\n");
        for (i = 0; i < send; i++)
          ftracef (NULL, 0, "\\x%.2X", (*bufp + offset) [i]);
        ftracef (NULL, 0, "\n");
      }
      #endif
      if (!xfersend_sendbuf (*bufp + offset, send))
      { ftracef0 ("... failed\n");
        return FALSE;
      }

      ftracef0 ("... written OK\n");
      offset += send;
    }
  }

  return TRUE;
}

static void refont_object (draw_objptr hdrptr, int *changelist)

{ ftracef0 ("draw_file: refont_object\n");

  switch (hdrptr.objhdrp->tag)
  { case draw_OBJTEXT:
      hdrptr.textp->textstyle.fontref =
          changelist [hdrptr.textp->textstyle.fontref];
    break;

    case draw_OBJGROUP:
    { int i;
      int start = sizeof (draw_groustr);
      int limit = hdrptr.objhdrp->size;
      draw_objptr objptr;

      for (i = start; i < limit; i+=objptr.objhdrp->size)
      { objptr.bytep = hdrptr.bytep + i;
        refont_object (objptr, changelist);
      }
    }
    break;

    case draw_OBJTRFMTEXT:
      hdrptr.trfmtextp->textstyle.fontref =
        changelist [hdrptr.trfmtextp->textstyle.fontref];
    break;
  }
}

static BOOL tieupfontrefs (diagrec *diag)
{ draw_diagstr *misc = diag->misc;
  int changelist [256] /*newref = changelist[oldref]*/,
    i, from = misc->ghoststart, to = misc->ghostlimit, list_off;
  draw_objptr hdrptr, liststart, listele, listend;
    /*Pointers to scan fontlist N.B. absolute addresses - assume heap
      won't shift*/

  ftracef0 ("draw_file: tieupfontrefs\n");
  hdrptr.bytep = NULL;
  liststart.bytep = NULL;
  listele.bytep = NULL;
  listend.bytep = NULL;

  ftracef3 ("draw_file: tieupfontrefs: (diag=%d, from=%d, to=%d)\n",
      diag, from, to);

  for (i = from; i < to; i += hdrptr.objhdrp->size)
  { hdrptr.bytep = diag->paper + i;

    if (hdrptr.objhdrp->tag == draw_OBJFONTLIST)
    { liststart.fontlistp = hdrptr.fontlistp;
      list_off            = i;
      listele.bytep       = &hdrptr.fontlistp->fontref;
      listend.bytep       = hdrptr.bytep + hdrptr.fontlistp->size;

      break;
    }
  }

  if (liststart.bytep == 0) return TRUE;  /*no new font list*/

  /*Next line assumes font list is first item*/
  /*misc->ghoststart += hdrptr.fontlistp->size; SO DON'T DO IT! JRC 21st Nov
        1994*/

  ftracef0 ("draw_file: tieupfontrefs: found the fontlist\n");

  /*Map all fonts to system font in case of errors*/
  for (i = 0; i <= 255; i++)
    changelist[i] = 0;

  while (listele.bytep < listend.bytep)
  { int oldref = *listele.bytep++; /*extract font ref & point at font name*/

    if (oldref == 0)
    { ftracef0 ("draw_file: tieupfontrefs: fontref is zero, assume this "
          "is null padding at end of blk\n");
      break;
    }

    /*search fontcat as we probably know this font name*/
    ftracef2 ("draw_file: tieupfontrefs: file font ref=%d name='%s'\n",
        oldref, listele.bytep);
    changelist [oldref] = draw_menu_addfonttypeentry (listele.bytep);

    listele.bytep += strlen (listele.bytep) + 1;
  }

  /*Now scan the file and change the font refs*/
  for (i = from; i < to; i += hdrptr.objhdrp->size)
  { hdrptr.bytep = diag->paper + i;
    refont_object (hdrptr, changelist);
  }

  return TRUE;
}

/*Save the options in a file instead. Two routines for reading and writing
   the options from a diagram*/

static BOOL read_options (diagrec *diag, BOOL cleanpaper)

  /*Reads all the options objects in a given diagram's ghost area, sets
    options for it from the first and deletes all of them.*/

{  BOOL first = TRUE;
   int i, size;

   ftracef1 ("draw_file: read_options: diag: 0x%.8X\n", (int) diag);
   for (i = diag->misc->ghoststart; i < diag->misc->ghostlimit; i+= size)
   {  draw_objptr hdrptr;

      hdrptr.bytep = diag->paper + i;
      size = hdrptr.objhdrp->size;

      ftracef2 ("draw_file: read_options: tag: %d; size: %d\n",
            hdrptr.objhdrp->tag, hdrptr.objhdrp->size);
      if (hdrptr.objhdrp->tag == draw_OPTIONS)
      {  if (first && cleanpaper)
         {  /*Set the options of this diagram from the options object.*/
            draw_options *opt = &hdrptr.optionsp->options; /*save typing*/
            int cm = opt->grid.o [4];
            BOOL toolbox;
            int curved, closed;
            draw_state state;

            ftracef0 ("draw_file: read_options: setting options\n");
            diag->misc->paperstate.size    = opt->paper.size;
            diag->misc->paperstate.options = opt->paper.o;

            diag->view->gridunit [cm].space [0] =
            diag->view->gridunit [cm].space [1] =
            diag->view->grid.space [0] =
            diag->view->grid.space [1]     = opt->grid.space;
            diag->view->gridunit [cm].divide [0] =
            diag->view->gridunit [cm].divide [1] =
            diag->view->grid.divide [0] =
            diag->view->grid.divide [1]    = opt->grid.divide;
            diag->view->flags.show         = opt->grid.o [2];
            diag->view->flags.lock         = opt->grid.o [3];
            diag->view->flags.xinch        =!cm;
            diag->view->flags.xcm          = cm;
            diag->view->flags.yinch        =!cm;
            diag->view->flags.ycm          = cm;
            diag->view->flags.rect         =!opt->grid.o [0];
            diag->view->flags.iso          = opt->grid.o [0];
            diag->view->flags.autoadj      = opt->grid.o [1];
#if 0
            diag->view->zoom.mul           = opt->zoom.mul;
            diag->view->zoom.div           = opt->zoom.div;
#endif
            diag->view->flags.zoomlock     = opt->zoom.lock;

            /*Remember what we want for the diagram toolbox, but don't set
               the new state yet. The diagram is already on screen with the
               (possibly wrong) setting)*/
            toolbox                        = opt->toolbox;

            state =
               opt->mode.rect?   state_rect:
               opt->mode.elli?   state_elli:
               opt->mode.text?   state_text:
               opt->mode.select? state_sel:
                                 state_path;
            curved = opt->mode.curve || opt->mode.ccurve;
            closed = opt->mode.cline || opt->mode.ccurve;

            /*Throw away options.undo_size*/

            {  /*Get the screen image up to date*/
               zoomchangestr new_zoom;

               new_zoom.diag     = diag;
               new_zoom.view     = diag->view;
               new_zoom.zoom.mul = opt->zoom.mul;
               new_zoom.zoom.div = opt->zoom.div;
               ftracef3 ("draw_file: read_options: view is at zoom %.2f; "
                   "wanted at %d: %d\n",
                   diag->view->zoomfactor,
                   new_zoom.zoom.mul, new_zoom.zoom.div);

               /*Set paper size - don't redraw yet*/
               draw_action_set_papersize (diag, diag->misc->paperstate.size,
                  diag->misc->paperstate.options);

               /*Set zoom factor and redraw*/
               draw_action_zoom ((void *) &new_zoom);

               ftracef2 ("if the window has already been opened with the "
                   "wrong setting of the toolbox, correct it. (Yuck!). "
                   "Options says %c, diagrams claims to be %c\n",
                   toolbox? 't': 'f', diag->view->flags.showpane? 't': 'f');
               if (toolbox != diag->view->flags.showpane)
                  draw_menu_toolbox_toggle (diag->view);

               ftracef0 ("ditto for state\n"); /*JRC 28 Jan 1991*/
               draw_action_changestate (diag, state, curved, closed, FALSE);
            }

            first = FALSE;
         }

         /*Delete the object anyway - updates ghostlimit*/
         ftracef0 ("draw_file: read_options: deleting object\n");
         draw_obj_losespace (diag, i, size);
         size = 0; /*next object is where the old one was*/
      }
      else if (hdrptr.objhdrp->tag == draw_OBJFONTLIST)
      { /*Delete the object - updates ghostlimit*/
        ftracef0 ("draw_file: read_options: deleting object\n");
        draw_obj_losespace (diag, i, size);
        size = 0; /*next object is where the old one was*/
      }
   }

   return !first; /*i e, TRUE if we read any options*/
}

static BOOL write_options (int file_handle, diagrec *diag, int *bytecount)
   /*Creates an options object and writes it to the file handle specified*/

{  draw_optionsstr options, *optionsp = &options /*to take &&options*/;
   draw_options *opt = &options.options; /*save typing*/
   int cm = diag->view->flags.xcm;

   ftracef0 ("draw_file: write_options\n");
   if (bytecount != NULL) {
     *bytecount += sizeof options;
     return TRUE;
   }

   options.tag        = draw_OPTIONS;
   options.size       = sizeof options;
   memset (&options.bbox, 0, sizeof (draw_bboxtyp));

   opt->paper.size    = diag->misc->paperstate.size;
   opt->paper.o       = diag->misc->paperstate.options;

   opt->grid.space    = diag->view->gridunit [cm].space [0];
   opt->grid.divide   = diag->view->gridunit [cm].divide [0];

   opt->grid.o [0]    = diag->view->flags.iso;
   opt->grid.o [1]    = diag->view->flags.autoadj;
   opt->grid.o [2]    = diag->view->flags.show;
   opt->grid.o [3]    = diag->view->flags.lock;
   opt->grid.o [4]    = cm;

   opt->zoom.mul      = diag->view->zoom.mul;
   opt->zoom.div      = diag->view->zoom.div;
   opt->zoom.lock     = diag->view->flags.zoomlock;

   opt->toolbox       = diag->view->flags.showpane;

   memset (&opt->mode, 0, sizeof opt->mode);
   switch (diag->misc->mainstate)
   {  case state_rect:
         opt->mode.rect = TRUE;
      break;

      case state_elli:
         opt->mode.elli = TRUE;
      break;

      case state_text:
         opt->mode.text = TRUE;
      break;

      case state_sel:
         opt->mode.select = TRUE;
      break;

      case state_path:
         if (diag->misc->options.curved)
            if (diag->misc->options.closed)
               opt->mode.ccurve = TRUE;
            else
               opt->mode.curve = TRUE;
         else
            if (diag->misc->options.closed)
               opt->mode.cline = TRUE;
            else
               opt->mode.line = TRUE;
      break;

      default:
         opt->mode.line = TRUE;
      break;
   }

   opt->undo_size = draw_current_options.undo_size; /*not used*/

   if (!draw_file_write_bytes (file_handle, (char **) &optionsp, 0,
         sizeof options))
      return FALSE;

   return TRUE;
}

/*----------------------------------------------------------------------*/

static BOOL fetch_drawfile (diagrec *diag, char *name, int filelen)

{ ftracef0 ("draw_file: fetch_drawfile\n");
  /*filelen is correct for xfer via_FILE, but a guess for xfer via_RAM*/

  if (wimpt_complain (draw_obj_checkspace (diag, filelen))) return FALSE;

  if (!draw_file_get (name, &diag->paper, diag->misc->ghoststart,
      &filelen, NULL))
    return FALSE;

#if (VALIDATEFILES)
  if (!draw_check_Draw_file (diag, diag->misc->ghoststart,
      diag->misc->ghoststart + filelen))
    return FALSE;
#endif

  diag->misc->ghostlimit = diag->misc->ghoststart + filelen;
  return TRUE;
}

/*-----------------------------------------------------------------------*/

/*Fetch a 'Sprite' file*/

/*The file is loaded slightly above ghoststart, a file header then a
sprite header are laid in front of the first sprite, the remainder
of the file being discarded*/

/*-----------------------------------------------------------------------*/

static BOOL fetch_spritefile (diagrec *diag, char *name, int filelen,
                             draw_objcoord *pt)

{ /*filelen is correct for xfer via_FILE, but a guess for xfer via_RAM*/
  union { sprite_area *areap; char *bytep; } sp_area;
  union { sprite_header *spritep; char *bytep; } spr_start, spr_end;
  draw_objptr hdrptr;
  int gap = sizeof (draw_fileheader) + sizeof (draw_spristrhdr);

  ftracef0 ("draw_file: fetch_spritefile\n");
  filelen += 4;  /*effectively 4 bigger as the file does not
                 include the sprite area size field*/

  if (wimpt_complain (draw_obj_checkspace (diag, gap+filelen)))
    return FALSE;

  sp_area.bytep = diag->paper + diag->misc->ghoststart + gap;

  /*Load the file, leaving a gap (plenty) big enough to insert a file header
    and the sprite header.*/

  if (!draw_file_get (name, &diag->paper,
      (char *) &sp_area.areap->number - diag->paper, &filelen, NULL))
    return FALSE;

  if (sp_area.areap->number <= 0)
  { Error (0, "FileS1");
    return FALSE;
  }

  spr_start.bytep = sp_area.bytep + sp_area.areap->sproff;  /*first sprite*/
  spr_end.bytep = spr_start.bytep + spr_start.spritep->next; /*last byte+1*/

  /*Its probably safer (ie no heap movement) to overlay the fileheader and
    sprite header by steam, rather by fudging ghost (start/limit) then
    calling 'draw_obj_fileheader','draw_obj_start (draw_OBJSPRITE)'*/

  hdrptr.bytep = spr_start.bytep - sizeof (draw_spristrhdr);

  hdrptr.spritep->tag  = draw_OBJSPRITE;
  hdrptr.spritep->size = spr_end.bytep - hdrptr.bytep;

  { int XEigFactor, YEigFactor, pixsizex, pixsizey;
    sprite_id id;
    sprite_info info;

    XEigFactor = bbc_modevar (hdrptr.spritep->sprite.mode, bbc_XEigFactor);
    YEigFactor = bbc_modevar (hdrptr.spritep->sprite.mode, bbc_YEigFactor);
    if (XEigFactor == -1 || YEigFactor == -1)
      return FALSE;

    pixsizex = 0x100 << XEigFactor, pixsizey = 0x100 << YEigFactor;

    id.tag    = sprite_id_addr;
    id.s.addr = &hdrptr.spritep->sprite;

    (void) sprite_readsize
        (UNUSED_SA, /*this op needs no spArea*/
        &id,        /*pass address of sprite*/
        &info       /*result block*/);

    /*Generate sprite box, on mouse position*/
    hdrptr.spritep->bbox.x0 = pt->x;
    hdrptr.spritep->bbox.y0 = pt->y;
    hdrptr.spritep->bbox.x1 = pt->x + pixsizex * info.width;
    hdrptr.spritep->bbox.y1 = pt->y + pixsizey * info.height;

    ftracef4 ("sprite BBox is (%d,%d,%d,%d) \n", hdrptr.spritep->bbox.x0,
                                           hdrptr.spritep->bbox.y0,
                                           hdrptr.spritep->bbox.x1,
                                           hdrptr.spritep->bbox.y1);
  }

  hdrptr.filehdrp -= 1;
  *hdrptr.filehdrp = draw_blank_header;

  diag->misc->ghoststart = hdrptr.bytep  - diag->paper;
  diag->misc->ghostlimit = spr_end.bytep - diag->paper;

  return TRUE;
}

/*-----------------------------------------------------------------------*/

   /*Fetch a JPEG image*/

/*The file is loaded slightly above ghoststart, a file header then a
   JPEG header are laid in front of the file.*/

static BOOL fetch_jpeg (diagrec *diag, char *name, int filelen,
    draw_objcoord *pt)

{ /*filelen is correct for xfer via_FILE, but a guess for xfer via_RAM*/
  draw_objptr  hdrptr;
  jpeg_id      jid;
  jpeg_info    jinfo;
  
  ftracef0 ("draw_file: fetch_jpeg\n");
  if (wimpt_complain (draw_obj_checkspace (diag, sizeof (draw_fileheader) +
      sizeof (draw_jpegstrhdr) + filelen + 3 & ~3)))
    return FALSE;

  /*Load the file, leaving a gap big enough to insert the jpeg header and
    file header.*/
  if (!draw_file_get (name, &diag->paper, diag->misc->ghoststart +
      sizeof (draw_fileheader) + sizeof (draw_jpegstrhdr), &filelen, NULL))
    return FALSE;

  hdrptr.bytep = (char *) diag->paper + diag->misc->ghoststart + sizeof (draw_fileheader);
  hdrptr.jpegp->tag  = draw_OBJJPEG;
  hdrptr.jpegp->size = sizeof (draw_jpegstrhdr) + filelen + 3 & ~3;
  hdrptr.jpegp->len  = filelen;

  /*Get width, height in OSU.*/
  jid.tag = jpeg_id_addr;
  jid.s.image.addr = &hdrptr.jpegp->image;
  jid.s.image.size = hdrptr.jpegp->len;
  if (wimpt_complain (jpeg_readinfo (&jid, &jinfo)))
    return FALSE;

  hdrptr.jpegp->width = jinfo.width;
  hdrptr.jpegp->height = jinfo.height;
  hdrptr.jpegp->xdpi = jinfo.xdensity;
  hdrptr.jpegp->ydpi = jinfo.ydensity;
  ftracef2 ("JPEG scaling (%d, %d) %s\n", hdrptr.jpegp->xdpi, hdrptr.jpegp->ydpi);

  /*Convert width, height to draw units.*/
  hdrptr.jpegp->width  *= 256*180/hdrptr.jpegp->xdpi;
  hdrptr.jpegp->height *= 256*180/hdrptr.jpegp->ydpi;

  /*Matrix is initially a unit.*/
  hdrptr.jpegp->trans_mat [0] = 1 << 16;
  hdrptr.jpegp->trans_mat [1] = 0;
  hdrptr.jpegp->trans_mat [2] = 0;
  hdrptr.jpegp->trans_mat [3] = 1 << 16;
  hdrptr.jpegp->trans_mat [4] = pt->x;
  hdrptr.jpegp->trans_mat [5] = pt->y;

  *--hdrptr.filehdrp = draw_blank_header;
  diag->misc->ghoststart = hdrptr.bytep - diag->paper;
  diag->misc->ghostlimit = diag->misc->ghoststart +
      sizeof (draw_fileheader) + sizeof (draw_jpegstrhdr) + filelen + 3 & ~3;

  return TRUE;
}

/*---------------------- Text area handling ------------------------------*/

static BOOL fetch_textArea_file (diagrec *diag, char *fileName, int length,
    draw_objcoord *mouse)

{ int columns;

  ftracef0 ("draw_file: fetch_textArea_file\n");
  /*Create a file header so loading will work*/
  if (wimpt_complain (draw_obj_checkspace (diag, sizeof (draw_fileheader))))
    return FALSE;
  draw_obj_fileheader (diag);

  /*Allocate initial memory for load*/
  ftracef1 ("draw_file: fetch_textArea_file: flex_alloc (, %d)\n", length);
  if (!FLEX_ALLOC ((flex_ptr) &Load_Base, length))
  { Error (0, "TextM1");
    return FALSE;
  }
  ftracef2 ("flex buffer at 0x%X, size %d\n", Load_Base, length);

  if (!draw_file_get (fileName, &Load_Base, 0, &length, &Extend_Buffer))
  { /*Free temporary memory*/
    FLEX_FREE ((flex_ptr) &Load_Base);
    return FALSE;
  }
  ftracef2 ("flex buffer at 0x%X, size %d\n", Load_Base, length);

  ftracef2 ("File as initially loaded:\n[%.*s]", length, Load_Base);

  ftracef0 ("Prepend standard header if none is present\n");
  if (Load_Base [0] != '\\')
  { int i, len = strlen (draw_text_header), n_bs = 0;

    /*How many '\\' in the text area?*/
    for (i = 0; i < length; i++)
      if (Load_Base [i] == '\\')
        n_bs++;

    /*Make that much extra space.*/
    ftracef1 ("draw_file: fetch_textArea_file: flex_extend (, %d)\n",
        length + n_bs);
    if (!FLEX_EXTEND ((flex_ptr) &Load_Base, length + n_bs))
    { Error (0, "TextM1");
      /*Free temporary memory*/
      FLEX_FREE ((flex_ptr) &Load_Base);
      return FALSE;
    }
    length += n_bs;

    /*And add another '\\' after each '\\' already present.*/
    for (i = length - 1; i > 0 && n_bs > 0; i--)
      if (Load_Base [i - n_bs] == '\\')
      { Load_Base [i] = '\\';
        Load_Base [i - 1] = '\\';
        i--, n_bs--;
      }
      else
        Load_Base [i] = Load_Base [i - n_bs];

    ftracef2 ("After multiplying '\\':\n[%.*s]", length, Load_Base);

    ftracef1 ("draw_file: fetch_textArea_file: flex_midextend (,, %d)\n",
        len);
    if (!FLEX_MIDEXTEND ((flex_ptr) &Load_Base, 0, len))
    { Error (0, "TextM1");
      /*Free temporary memory*/
      FLEX_FREE ((flex_ptr) &Load_Base);
      return FALSE;
    }
    length += len;

    /*Copy new header, avoiding adding the null*/
    memcpy (Load_Base, draw_text_header, len);
    ftracef2 ("With header:\n[%.*s]", length, Load_Base);
  }

  /*Verify the text*/
  if (!draw_text_verifyTextArea (Load_Base, length, &columns, NULL))
  { /*Free temporary memory*/
    FLEX_FREE ((flex_ptr) &Load_Base);
    return FALSE;
  }

  /*Create the new area and columns*/
  if (!draw_text_create (diag, &Load_Base, length, columns, mouse))
  { /*Free temporary memory*/
    FLEX_FREE ((flex_ptr) &Load_Base);
    return FALSE;
  }

  FLEX_FREE ((flex_ptr) &Load_Base);
  return TRUE;
}

/*----------------------------------------------------------------------
Misc file save routines*/


/*create file, stamped with time/date & filetype*/

static BOOL draw_file_create_file (char *name, int filetype, int bytecount)
{ ftracef0 ("draw_file: draw_file_create_file\n");
  if (owner_xfersend.method == via_FILE)
  { os_filestr file;
    int oldattribs = -1;

    file.action = 17; /* Read cat info */
    file.name = name;
    (void) os_file(&file);
    /* if something is already there,remember its attributes */
    if (file.action != 0) oldattribs = file.end;

    file.action   /*r0*/ = 0xB;           /*create stamped file*/
    file.loadaddr /*r2*/ = filetype;
  /*file.execaddr   r3*/
    file.start    /*r4*/ = 0;
    file.end      /*r5*/ = bytecount;

    if (wimpt_complain (os_file (&file))) return FALSE;

    if (oldattribs != -1) {
      file.action = 4; /* Write attribs */
      file.end = oldattribs;
      (void) os_file(&file);
    };

  }

  return TRUE;
}

/*open file for update (will only be written to ? ? ? ) grrr!*/
static BOOL draw_file_openup_file (char *name, int *filehandlep)
{ ftracef0 ("draw_file: draw_file_openup\n");
  if (owner_xfersend.method == via_FILE)
  { os_regset  blk;

    blk.r[0] = 0xCF; /*OpenUp, Ignore file$path, give err if a dir.!*/
    blk.r[1] = (int)name;

    if (wimpt_complain (os_find (&blk))) return FALSE;
    if (blk.r[0] == 0) { Error (FALSE, "FileO1"); return FALSE; }
                           /*Incase the fileswitch bug returns a 0 handle*/
    *filehandlep = blk.r[0];
  }

  return TRUE;
}

/*Close file and turn off the visual delay*/
static BOOL draw_file_close_file (int filehandle)

{ ftracef0 ("draw_file: draw_file_close_file\n");
  if (owner_xfersend.method == via_FILE)
  { os_regset  blk;

    blk.r[0] = 0; blk.r[1] = filehandle;
    if (wimpt_complain (os_find (&blk))) return FALSE;
  }

  visdelay_end ();
  return TRUE;
}

static BOOL write_fontlist (int filehand, char *fontusedp, int *bytecount)
{ int objsize = 0;
  int padby;
  /*The following: fonthdr,i (fontref),fournulls are passed to write_bytes,
    this takes char** (ie a pointer to a flex_anchor) so it can output
    data in any size chunks even if the source flex block shifts in the
    process. fonthdrp,ip,fournullsp allow us to do this with
    'write_bytes (...., &fonthdrp, ......);'*/
  draw_fontliststrhdr fonthdr;            /*header for a fontlist*/
  char *fonthdrp = (char*)&fonthdr;       /*pointer to it*/
  int i;                                  /*loop counter & fontref*/
  char *ip = (char*)&i;                   /*pointer to it*/
  int fournulls = 0;                      /*a useful source of four nulls*/
  char *fournullsp = (char*)&fournulls;   /*pointer to it*/

  ftracef0 ("draw_file: write_fontlist\n");
  for (i = 1; i <= 255; i++)
    if (fontusedp[i])
      objsize += sizeof (draw_fontref) + strlen (draw_fontcat.name[i]) + 1;

  if (objsize == 0) return TRUE;      /*No fonts used - no fontlist needed*/

  padby = (4 - objsize) & 3;           /*0..3 bytes padding at EOobject*/
  objsize += sizeof (draw_fontliststrhdr) + padby;

  if (bytecount != NULL) {
    *bytecount += objsize;
    return TRUE;
  } else {
    fonthdr.tag  = draw_OBJFONTLIST;     /*build, then output a fontlist hdr*/
    fonthdr.size = objsize;

    if (!draw_file_write_bytes (filehand, &fonthdrp, 0,
                               sizeof (draw_fontliststrhdr)))
      return FALSE;

    for (i = 1; i <= 255; i++)/*output each fontref + fontname & terminator*/
      if (fontusedp[i])
      { if (!draw_file_write_bytes (filehand, &ip, 0, sizeof (draw_fontref))
            || !draw_file_write_bytes (filehand, &draw_fontcat.name[i], 0,
                                      strlen (draw_fontcat.name[i])+1))
          return FALSE;
        ftracef1 ("%s,", (int)draw_fontcat.name[i]);
      }

    return draw_file_write_bytes (filehand, &fournullsp, 0, padby);
  }
}

void draw_file_fontuse_object (draw_objptr hdrptr, char *fontusetab)

{ ftracef0 ("draw_file_fontuse_object\n");

  switch (hdrptr.objhdrp->tag)
  { case draw_OBJTEXT:
      fontusetab [hdrptr.textp->textstyle.fontref] = 1;
    break;

    case draw_OBJGROUP:
    { draw_objptr objptr;

      for (objptr.bytep = hdrptr.bytep + sizeof (draw_groustr);
          objptr.bytep < hdrptr.bytep + hdrptr.objhdrp->size;
          objptr.bytep += objptr.objhdrp->size)
        draw_file_fontuse_object (objptr, fontusetab);
    }
    break;

    case draw_OBJTEXTAREA:
    { draw_objptr column;

      /*Find the text of the text area.*/
      for (column.textcolp = &hdrptr.textareastrp->column;
          column.textcolp->tag == draw_OBJTEXTCOL;
          column.bytep += sizeof (draw_textcolhdr))
        ;

      /*Update fontusetab*/
      draw_text_verifyTextArea (column.bytep + sizeof (draw_textareastrend),
          strlen (column.bytep + sizeof (draw_textareastrend)), NULL,
          fontusetab);
    }
    break;

    case draw_OBJTRFMTEXT:
      fontusetab [hdrptr.trfmtextp->textstyle.fontref] = 1;
    break;
  }
}

/*-----------------------------------------------------------------------*/

/*Common save code, shared by individual save operations*/

/*-----------------------------------------------------------------------*/

/*Create and open file, and turn on hourglass*/
static BOOL open_save (char *filename, int filetype, int bytecount, int *filehandle /*out*/)
{ ftracef0 ("draw_file: open_save\n");
  /*create file, stamped with time/date & filetype*/
  if (!draw_file_create_file (filename, filetype, bytecount)) return FALSE;

  /*open file for update*/
  if (!draw_file_openup_file (filename, filehandle)) return FALSE;

  /*from here on, we have an open file, it needs closing whether an
  error occurs or not*/
  visdelay_begin ();
  return TRUE;
}

/*Create and open file, and output file header with given bbox and
    fontlist
Closes file on an error after opening*/
static BOOL start_file_save (draw_bboxtyp *hdrbox,
  char *fonttable, diagrec *diag, int filehandle, BOOL saveoptions, int *bytecount)

{
  draw_fileheader header = draw_blank_header;
  char *hdrp = (char*)&header;          /*so we can get '&&header'!*/

  ftracef0 ("draw_file: start_file_save\n");

  if (bytecount != NULL)
    *bytecount += sizeof (draw_fileheader);
  else
  {
    /*Make and write the file header*/
    header.bbox = *hdrbox;
    if (!draw_file_write_bytes (filehandle, &hdrp, 0, sizeof (draw_fileheader)))
    { /*Error: close file*/
      draw_file_close_file (filehandle);
      return FALSE;
    }
  }

  /*output fontlist (if any)*/
  if (!write_fontlist (filehandle, fonttable, bytecount))
  { /*Error: close file*/
    draw_file_close_file (filehandle);
    return FALSE;
  }

  /*output options structure JRC 5 Oct 1990*/
  if (saveoptions)
    if (!write_options (filehandle, diag, bytecount))
    { /*Error: close file*/
      draw_file_close_file (filehandle);
      return FALSE;
    }

  return TRUE;
}

/*-----------------------------------------------------------------------*/

/*save all objects in a diagram as an Draw file*/

/*draw_file_file_saveall - to a file
draw_file_ram_saveall  - via ram
draw_file_printall     - to the printer application so print it ourselv*/

/*Saving will clear the modified flag, so we save an undo record for it*/

/*-----------------------------------------------------------------------*/


static BOOL save_all_data (draw_bboxtyp *hdrbox,
  char *fonttable, diagrec *diag, int filehandle, int *bytecount)
{
  if (!start_file_save (hdrbox, fonttable, diag, filehandle, TRUE, bytecount))
    return FALSE;

  if (bytecount != NULL)
    *bytecount += diag->misc->solidlimit - diag->misc->solidstart;
  else
    /*output all objects*/
    return draw_file_write_bytes (filehandle, &diag->paper,
      diag->misc->solidstart, diag->misc->solidlimit - diag->misc->solidstart);

  return TRUE;
}

static BOOL saveall (diagrec *diag, char *filename, fileIO_method method,
                    int *maxbuf)
{ draw_bboxtyp hdrbox;
  char         fontusetab[256];
  int          filehandle;
  int  i, bytecount;
  BOOL ok;
  BOOL direct = (method == via_DIRECTCLICK);

  ftracef0 ("draw_file: saveall\n");
  if (direct) method = via_FILE;

  claim_xfersend (diag, method, maxbuf);

  ftracef3 ("save diag %d as %s '%s'\n", diag,
      method == via_RAM? "RAM": method == via_FILE? "file":
      method == via_COMMANDLINE? "command line":
      method == via_DIRECTCLICK? "direct click": "", filename);

  /*Form file bbox*/
  draw_obj_bound_all (diag, &hdrbox);

  /*find fonts used in each selected object*/
  { draw_objptr hdrptr, limit;

    for (i = 0; i <= 255; fontusetab[i++] = 0);      /*clear fontusetab*/

    hdrptr.bytep = diag->paper + diag->misc->solidstart;
    limit.bytep  = diag->paper + diag->misc->solidlimit;

    for (; hdrptr.bytep < limit.bytep; hdrptr.bytep += hdrptr.objhdrp->size)
      draw_file_fontuse_object (hdrptr, &fontusetab[0]);
  }

  /* First pass to get file size. */
  bytecount = 0;
  (void) save_all_data (&hdrbox, fontusetab, diag, 0, &bytecount);

  ftracef1("saveall: file size = %d bytes\n",bytecount);

  /*Create and open the file*/
  if (!open_save (filename, FileType_Draw, bytecount, &filehandle))
    return FALSE;

  /* Do the actual save. */
  ok = save_all_data (&hdrbox, fontusetab, diag, filehandle, NULL);

  /*close file, even if an error has already occured!*/
  if (!draw_file_close_file (filehandle)) ok = FALSE;
  if (!ok) return FALSE;

  /*If no error in transfer AND recipient will not modify the data (i e, we
    saved to the filer) update our filename and our modified flag*/

  /*Note:
    IF    diag->modified || !diag->datestamped
    THEN  diag->datestamped := TRUE;
          diag->timestamp   := NOW
    FI;
    diag->modified = FALSE;
    Set file datestamp to diag->timestamp;
  */
  if (direct || xfersend_file_is_safe ())
  { os_filestr file_str;

    if (diag->misc->options.modified || !diag->misc->options.datestamped)
    { char timestamp [5];

      diag->misc->options.datestamped = TRUE;
      timestamp [0] = 3;
      (void) os_word (14, timestamp);
      diag->misc->address.load = 0xFFFu << 20 | FileType_Draw << 8 |
          timestamp [4];
      memcpy (&diag->misc->address.exec, timestamp, 4);
    }

    diag->misc->options.modified = FALSE;

    file_str.name     = filename;
    file_str.loadaddr = diag->misc->address.load;
    file_str.execaddr = diag->misc->address.exec;

    file_str.action   = 2 /*write load address*/;
    (void) os_file (&file_str);

    file_str.action   = 3 /*write exec address*/;
    (void) os_file (&file_str);

    /*Put undo information*/
    #if 0
      draw_undo_put_start_mod (diag,
          diag->misc->filename [0] != '\0'? (int) diag->misc->filename:
          NULL/*JRC*/);
    #else
      draw_undo_separate_major_edits (diag);
    #endif

    strcpy (diag->misc->filename, filename);

    /*draw_displ_totalredraw (diag);
       title/scroll bars & window contents - waste of time and energy*/

    /*Try this:*/
    draw_displ_redrawtitle (diag);
  }

  return TRUE;    /*TRUE/FALSE for saved/failed*/
}

BOOL draw_file_file_saveall (char *filename, void *handle)
{ ftracef0 ("draw_file_file_saveall\n");
  return (saveall ((diagrec*)handle, filename, via_FILE, 0));
}

BOOL draw_file_file_savedirect (char *filename, diagrec *diag)
{ ftracef0 ("draw_file_savedirect\n");
  return (saveall (diag, filename, via_DIRECTCLICK, 0));
}

BOOL draw_file_ram_saveall (void *handle, int *maxbuf)
{ ftracef0 ("draw_file_ram_saveall\n");
  return (saveall ((diagrec*)handle, "Wimp$Scrap", via_RAM, maxbuf));
}

BOOL draw_file_printall (char *filename, void *handle)
{ os_error *err;
  filename = filename;
                                            /*restore system font size*/
  ftracef0 ("draw_file_printall\n");

  err = draw_print_printall ((diagrec*)handle);

  if (draw_currentmode.gcharaltered)
  { draw_displ_setVDU5charsize
                (draw_currentmode.gcharsizex, draw_currentmode.gcharsizey,
                 draw_currentmode.gcharspacex, draw_currentmode.gcharspacey);
    draw_currentmode.gcharaltered = 0;
  }

  /*Report any errors*/
  return wimpt_complain (err)? xfersend_printFailed: xfersend_printPrinted;
}

/*-------------------------------------------------------------------------*/

/*save all selected objects as an Draw file*/

/*draw_file_file_saveselection - to a file
draw_file_ram_saveselection  - via RAM*/

/*-------------------------------------------------------------------------*/
static BOOL save_selected_data (draw_bboxtyp *hdrbox,
  char *fonttable, diagrec *diag, int filehandle, int *bytecount)
{ BOOL ok = TRUE;
  int i;
  draw_objptr hdrptr;

  if (!start_file_save (hdrbox, fonttable, diag, filehandle, FALSE, bytecount))
    return FALSE;

  /*do each selected object*/
  for (i = 0; ok && (hdrptr = draw_select_find (i), hdrptr.bytep != NULL); i++)
  {
    if (bytecount != NULL)
      *bytecount += hdrptr.objhdrp->size;
    else
      ok = draw_file_write_bytes (filehandle,
                               &draw_selection->owner->paper,
                               draw_selection->array[i],
                               hdrptr.objhdrp->size);
  }
  return ok;
}

static BOOL saveselection (diagrec *diag, char *filename, fileIO_method method,
                          int *maxbuf)
{ draw_bboxtyp hdrbox;
  int  filehandle;
  char fontusetab[256];                    /*slot 0..255 are valid fontrefs*/
  int  i, bytecount;
  BOOL ok;
  draw_objptr hdrptr;

  ftracef0 ("draw_file: saveselection\n");
  /*Deselect all text columns -- they cannot be saved individually*/
  if (draw_select_deselect_type (diag, draw_OBJTEXTCOL))
    return TRUE;                              /*Nothing to save*/

  claim_xfersend (diag, method, maxbuf);

  draw_obj_bound_selection (&hdrbox);

  /*find fonts used in each selected object*/
  (void) memset (fontusetab, 0, 256);       /*clear fontusetab*/
  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    draw_file_fontuse_object (hdrptr, &fontusetab[0]);

  /* First pass to determine file size. */
  bytecount = 0;
  (void) save_selected_data (&hdrbox, fontusetab, diag, 0, &bytecount);

  ftracef1("save_selection: file size = %d bytes\n",bytecount);

  /*Create and open the file*/
  if (!open_save (filename, FileType_Draw, bytecount, &filehandle))
    return FALSE;

  /* Save the data. */
  ok = save_selected_data (&hdrbox, fontusetab, diag, filehandle, NULL);

  /*Close file, even if an error has already occured!*/
  ok &= draw_file_close_file (filehandle);

  return (ok);
}

BOOL draw_file_file_saveselection (char *filename, void *handle)
{ ftracef2 ("draw_file_file_saveselection: filename: %s; handle: 0x%X\n", filename, handle);
  return saveselection ((diagrec*) handle, filename, via_FILE, 0);
}

BOOL draw_file_ram_saveselection (void *handle, int *maxbuf)
{ ftracef2 ("draw_file_ram_saveselection: handle: 0x%X; *maxbuf: %d\n", handle, *maxbuf);
  return saveselection ((diagrec*) handle, "Wimp$Scrap", via_RAM, maxbuf);
}

/*-------------------------------------------------------------------------*/

/*export any 'top-level' selected sprites*/

/*draw_file_file_exportsprites - to a file
draw_file_ram_exportsprites  - via RAM*/

/*-------------------------------------------------------------------------*/

static BOOL save_sprite_data (char **headerp, int filehandle, int *bytecount)
{ draw_objptr hdrptr;
  int i;
  BOOL ok = TRUE;

  if (bytecount != NULL)
    *bytecount += sizeof (sprite_area) - 4;
  else
    if (!draw_file_write_bytes (filehandle, headerp, 4, sizeof (sprite_area)-4))
      return FALSE;

  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    if (hdrptr.objhdrp->tag == draw_OBJSPRITE)
    { if (bytecount != NULL)
        *bytecount += hdrptr.spritep->sprite.next;
      else
        if (!((ok = draw_file_write_bytes (filehandle,
          &draw_selection->owner->paper,
          draw_selection->array [i] + sizeof (draw_spristrhdr),
          hdrptr.spritep->sprite.next)) != FALSE))
        break;
    }
    else if (hdrptr.objhdrp->tag == draw_OBJTRFMSPRITE)
    { if (bytecount != NULL)
        *bytecount += hdrptr.trfmspritep->sprite.next;
      else
        if (!((ok = draw_file_write_bytes (filehandle,
          &draw_selection->owner->paper,
          draw_selection->array [i] + sizeof (draw_trfmspristrhdr),
          hdrptr.trfmspritep->sprite.next)) != FALSE))
        break;
    }

  return ok;
}

static BOOL exportsprites (diagrec *diag, char *filename, fileIO_method method,
                          int *maxbuf)
{
  sprite_area header;
  char *headerp = (char*)&header;       /*so we can do '&&header'!*/
  int filehandle;
  int i, bytecount;
  BOOL ok;
  draw_objptr hdrptr;

  ftracef0 ("draw_file: exportsprites\n");
  claim_xfersend (diag, method, maxbuf);

  /*Build a sprite area header, holding a count of the sprites
  and offset past last sprite saved*/
  header.number  = 0;
  header.sproff  =                      /*1st sprite occurs after header*/
  header.freeoff = sizeof (sprite_area); /*accumulate offset past last sprite*/

  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    if (hdrptr.objhdrp->tag == draw_OBJSPRITE)
    { header.number++;
      header.freeoff += hdrptr.spritep->sprite.next;
    }
    else if (hdrptr.objhdrp->tag == draw_OBJTRFMSPRITE)
    { header.number++;
      header.freeoff += hdrptr.trfmspritep->sprite.next;
    }

  if (header.number <= 0) { Error (FALSE, "FileS2"); return (0); }

  /* First pass to determine file size. */
  bytecount = 0;
  (void) save_sprite_data (&headerp, 0, &bytecount);

  ftracef1("exportsprites: file size = %d\n",bytecount);

  /*Create and open the file*/
  if (!open_save (filename, FileType_Sprite, bytecount, &filehandle)) return FALSE;

  /* Save the data. */
  ok = save_sprite_data (&headerp, filehandle, NULL);

  /*Close file, even if an error has already occured!*/
  if (!draw_file_close_file (filehandle)) ok = FALSE;

  return ok;
}

BOOL draw_file_file_exportsprites (char *filename, void *handle)
{ ftracef0 ("draw_file_file_exportsprites\n");
  return (exportsprites ((diagrec*)handle, filename, via_FILE, 0));
}

BOOL draw_file_ram_exportsprites (void *handle, int *maxbuf)
{ ftracef0 ("draw_file_ram_exportsprites\n");
  return (exportsprites ((diagrec*)handle, "Wimp$Scrap", via_RAM, maxbuf));
}

/*Load a named file, creating a new diagram if the diag given is NULL.
   Set the input focus to the new or specified view.
*/
void draw_file_load_named_file (char *filename, diagrec *diag, viewrec *vuue)
{ draw_objcoord org;

  ftracef0 ("draw_file_load_named_file\n");
  org.x = org.y = 0;
  draw_file_loadfile (diag, vuue, filename, 0, 0, via_COMMANDLINE, &org);
}

/*-------------------------------------------------------------------------*/

/*Only stamped files allowed,
type 'Draw' is
loaded   if paper is empty, ie title set to filename, unmodified
inserted if paper non-empty, title unchanged marked as modified
type 'D' is
inserted (only), title unchanged marked as modified
type 'Sprite'
type 'Text'
inserted (only)*/

/*if method is
via_FILE: name is valid,
filetype assumed invalid to allow func key & cmmd line load
filesize is invalid
via_RAM:  name is invalid
filetype is valid
filesize is a guess*/


/*Set paper size parameters - relies on correspondence with values built
   into c.draw*/
static int paperX[] =
  {dbc_A4short  /*A5*/, dbc_A4long    /*A4*/, dbc_A4short*2 /*A3*/,
   dbc_A4long*2 /*A2*/, dbc_A4short*4 /*A1*/, dbc_A4long*4  /*A0*/, -1};
static int paperY[] =
  {dbc_A4long/2  /*A5*/, dbc_A4short  /*A4*/, dbc_A4long    /*A3*/,
   dbc_A4short*2 /*A2*/, dbc_A4long*2 /*A1*/, dbc_A4short*4 /*A0*/, -1};

static void draw_setPaperSize (diagrec *diag, int maxx, int maxy)
{ int    l, p, choice;
  double dx, dy, fit;
  papersize_typ    size;
  paperoptions_typ options = (paperoptions_typ) (diag->misc->paperstate.options &
      ~Paper_Landscape);

  ftracef0 ("draw_file: draw_setPaperSize\n");
  /*Find nearest size assuming landscape mode*/
  for (l = 0; paperX [l] != -1 && (paperX [l] < maxx || paperY [l] < maxy);
      l++);
  if (paperX[l] == -1) l -= 1;

  /*Find nearest size assuming portrait mode*/
  for (p = 0; paperX [p] != -1 && (paperY [p] < maxx || paperX [p] < maxy);
      p++);
  if (paperX[p] == -1) p -= 1;

  /*See which gave best fit*/
  dx  = (double) maxx - (double) paperX[l];
  dy  = (double) maxy - (double) paperY[l];
  fit = dx*dx + dy*dy;
  dx  = (double) maxx - (double) paperY[p];
  dy  = (double) maxy - (double) paperX[p];

  if (dx*dx + dy*dy < fit)
    choice = p;
  else
  { options = (paperoptions_typ) (options | Paper_Landscape);
    choice = l;
  }

  size = choice == 0? Paper_A5:
         choice == 1? Paper_A4:
         choice == 2? Paper_A3:
         choice == 3? Paper_A2:
         choice == 4? Paper_A1:
                      Paper_A0;

  /*Set paper size by simulating a resize action*/
  draw_action_resize (diag, size, options);
}

/*Error exit code for file loading
Reports an error if message is non null
Deletes diagram if dispose is TRUE
Returns NULL so it can be used for tail exit from draw_file_loadfile*/
static diagrec *load_error (diagrec *diag, char *message, BOOL dispose)
{ ftracef0 ("draw_file: load_error\n");
  /*Kill off any partially completed objects (especially the fileheader)*/
  draw_obj_flush (diag);

  if (message) Error (0, message);

  if (dispose) draw_dispose_diag (diag);

  visdelay_end ();

  /*Kill off whole of undo*/
  /*draw_undo_prevent_undo (diag); All lies - this has already been
      dealloated in draw_dispose_diag()*/
  return NULL;
}

/*name    is ->"" if via_RAM and
->"<filename>" if via_FILE or via_COMMANDLINE"
If vuue is non-NULL, the input focus is claimed for it
If it is null, the input focus is claimed for the first view of the diag
If diag is NULL, a new diagram is opened first. In this case, the operation
   is not undoable; also the diagram is disposed of on an error.
   Returns the diagram, or NULL on error.
*/
diagrec *draw_file_loadfile (diagrec *diag, viewrec *vuue, char *name,
    int filetype, int filesize, fileIO_method method, draw_objcoord *mouse)

{ draw_bboxtyp hdrbox;
  BOOL cleanpaper, commandLine = method == via_COMMANDLINE, newdiag = FALSE,
      ok;
  draw_objptr hdrptr;
  int atoff, size, loadaddr = 0, execaddr = 0;

  ftracef0 ("draw_file_loadfile\n");

  if (commandLine) method = via_FILE;
  if (method == via_FILE)
  { os_filestr  blk;
    diagrec    *rec;

    blk.action   = 5;             /*Read catalogue info*/
    blk.name     = name;          /*for name*/

    if (wimpt_complain (os_file (&blk)) != NULL)
      return NULL;

    if (blk.action != 1) /*save two messages by using OS_File 19*/
    { blk.loadaddr = blk.action;
      blk.action = 19;
      #if TRACE
        wimpt_noerr (os_file (&blk));
      #else
        wimpt_complain (os_file (&blk));
      #endif
      return NULL;
    }

    ftracef1 ("draw_file_loadfile found file, size %d bytes\n",blk.start);
    loadaddr = blk.loadaddr, execaddr = blk.execaddr;

    if ((loadaddr & 0xFFF00000) != 0xFFF00000)
    { Error (0, "FileF2");
      return NULL;
    }

    filetype = (loadaddr & 0x000FFF00) >> 8;
    filesize = blk.start;

    /*See if this is an attempt to load a new file that's already open,
      with the same date stamp, that's not modified, called the
      same thing*/
    for (rec = draw_startdiagchain; rec != NULL; rec = rec->nextdiag)
    { if ((diag == NULL) &&
          (rec->misc->options.datestamped && (rec->misc->address.load == loadaddr) &&
                                             (rec->misc->address.exec == execaddr)) &&
          !rec->misc->options.modified &&
          (strcmp (rec->misc->filename, name) == 0))
      { wimp_wstate state;

        /*Pop to top and gain the caret*/
        wimp_get_wind_state (rec->view->w, &state);
        state.o.behind = -1;
        draw_open_wind (&state.o, rec->view);
        draw_enter_claim_focus (rec, rec->view);
        return rec;
      }
    }
  }
  else
  { /*Filesize is a guess, but we can't allow transfer of zero bytes
      into zero-sized buffer. 6 Aug 1991*/
    if (filesize <= 0) filesize = 1024;
  }

  /*Create new diagram if diag is NULL*/
  if (diag == NULL)
  { if (wimpt_complain (draw_opennewdiag (&diag, FALSE)) != NULL)
      return NULL;
    newdiag = TRUE;
  }
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  ftracef3 ("at start, solidlimit %d, ghoststart %d, ghostlimit %d\n",
      diag->misc->solidlimit, diag->misc->ghoststart, diag->misc->ghostlimit);

  cleanpaper = diag->misc->solidstart == diag->misc->solidlimit;
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  draw_action_abandon (diag);
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  claim_xferrecv (diag, method);

  /*Once the file is loaded, use load_error to dispose of any partially
    loaded/processed file*/

  visdelay_begin ();

  /*If the load is undoable, start undoing now so we get old modified flag*/
  if (!newdiag)
    #if 0
      draw_undo_put_start_mod (diag,
          diag->misc->filename [0] != '\0'? (int) diag->misc->filename:
          NULL/*JRC*/);
    #else
      draw_undo_separate_major_edits (diag);
    #endif

  switch (filetype)
  { case FileType_Draw:                      /*Draw file*/
      ftracef0 ("draw_file_loadfile: fetch_drawfile\n");
      ftracef2 ("draw_selection->owner 0x%X, "
          "draw_selection->owner->paper 0x%X\n",
          draw_selection->owner, draw_selection->owner->paper);
      ok = fetch_drawfile (diag, name, filesize);
      ftracef2 ("draw_selection->owner 0x%X, "
          "draw_selection->owner->paper 0x%X\n",
          draw_selection->owner, draw_selection->owner->paper);
    break;

    #if ALLOW_DFILES
      case filetype_DFILE:                              /*'D' file*/
        cleanpaper = 0;  /*force insert*/
        ok = fetch_Dfile (diag, name, filesize);
      break;
    #endif

    case FileType_Sprite:
      cleanpaper = 0;  /*force insert*/
      ok = fetch_spritefile (diag, name, filesize, mouse);
    break;

    case FileType_Text:
      cleanpaper = 0;
      ok = fetch_textArea_file (diag, name, filesize, mouse);
    break;

    case FileType_DataExchangeFormat:
      ok = draw_dxf_fetch_dxfFile (diag, name, filesize, mouse,
          method == via_RAM);
      /*FIX G-RO-9219 29 Oct '91. Do this here, after the fetch.*/
      /*if (ok) ok = draw_dxf_setOptions ();*/
    break;

    case FileType_JPEG:
      cleanpaper = 0;  /*force insert*/
      ok = fetch_jpeg (diag, name, filesize, mouse);
    break;

    default:                               /*crap*/
      return load_error (diag, "FileF2", newdiag);
  }

  if (!ok) return load_error (diag, NULL, newdiag);

  /*check file header*/
  ftracef0 ("draw_file_loadfile: checking file header\n");
  hdrptr.bytep = diag->paper + diag->misc->ghoststart;
  hdrbox = hdrptr.filehdrp->bbox;

  if (memcmp (hdrptr.filehdrp->title, draw_blank_header.title, 4) != 0)
    return load_error (diag, "FileD2", newdiag);

  if (hdrptr.filehdrp->majorstamp != draw_blank_header.majorstamp)
    return load_error (diag, "FileI1", newdiag);

  /*skip header, point ghoststart at first object - fontlist (maybe)*/
  diag->misc->ghoststart += sizeof (draw_fileheader);

  ftracef0 ("draw_file_loadfile: tieupfontrefs\n");
  if (!tieupfontrefs (diag))
    return load_error (diag, NULL, newdiag);

  /*Rebound all the objects. For DXF files, also set the file bbox*/
  ftracef0 ("draw_file_loadfile: draw_obj_bound_objects\n");
  draw_obj_bound_objects (diag, diag->misc->ghoststart,
      diag->misc->ghostlimit, filetype == FileType_DataExchangeFormat ||
      filetype == FileType_Draw? &hdrbox: NULL);

  /*Strip the ghost area of options objects, setting options from the first
    found if paper is clean. If no options are set, try to deduce the size
    and orientation. JRC 29 Jan '91*/
  /*Also take this opportunity to remove font table objects (now not deleted
     in tieupfontrefs()). JRC 21st Nov 1994*/
  /*Fix MED-xxxx do this mungeing in the ghost area before appending it to
    the diagram proper. This means that undo gets only the data that's going
    into the diagram, and prevents undo subsequently corrupting the
    diagram. JRC 25th Nov 1994*/
  if (!read_options (diag, cleanpaper))
    if (cleanpaper) draw_setPaperSize (diag, hdrbox.x1, hdrbox.y1);

  /*If this is an addition to an existing file, move the insertion so that
    it is at the pointer position. JRC 5 Oct 1990*/
  atoff = diag->misc->solidlimit;
  size  = diag->misc->ghostlimit - diag->misc->ghoststart;
  if (!cleanpaper && filetype == FileType_Draw)
  { trans_str trans;

    trans.dx = mouse->x - hdrbox.x0;
    trans.dy = mouse->y - hdrbox.y0;
    ftracef2 ("draw_file_loadfile: draw_shift_Draw_file: "
        "atoff: %d; size: %d\n", atoff, size);
    draw_shift_Draw_file (diag, diag->misc->ghoststart,
        diag->misc->ghostlimit, &trans);
  }

  /*Make the insertion a part of the diagram proper*/
  ftracef0 ("draw_file_loadfile: draw_obj_appendghost\n");
  ftracef3 ("before appendghost, solidlimit %d, ghoststart %d, ghostlimit %d\n",
      diag->misc->solidlimit, diag->misc->ghoststart, diag->misc->ghostlimit);
  draw_obj_appendghost (diag);
  ftracef3 ("after appendghost, solidlimit %d, ghoststart %d, ghostlimit %d\n",
      diag->misc->solidlimit, diag->misc->ghoststart, diag->misc->ghostlimit);

  /*If the load is undoable, note that an insert was made*/
  if (!newdiag && size != 0)
  { ftracef0 ("draw_file_loadfile: draw_undo_put\n");
    draw_undo_put (diag, draw_undo__insert, atoff, size);
  }

  /*If diagram was empty and the source was good (ie from a file), take the
    filename & clear the modified flag. NB if filetype <> DrawFile, clean
    paper was forced FALSE*/
  if (filetype == FileType_Draw && cleanpaper && method == via_FILE &&
      (xferrecv_file_is_safe () || commandLine))
  { strcpy (diag->misc->filename, name);
    diag->misc->options.modified = 0;

    diag->misc->options.datestamped = TRUE;
    diag->misc->address.load = loadaddr;
    diag->misc->address.exec = execaddr;
  }
  else
  { diag->misc->options.modified = 1;
    diag->misc->options.datestamped = FALSE;
  }

  ftracef0 ("draw_file_loadfile: draw_displ_total_redraw\n");
  draw_displ_totalredraw (diag);  /*title/scroll bars & window contents*/

  ftracef0 ("draw_file_loadfile: visdelay_end\n");
  visdelay_end ();
  ftracef0 ("draw_file_loadfile: draw_enter_claim_focus\n");
  draw_enter_claim_focus (diag, vuue? vuue: diag->view);

  /*Go into select mode only now (if required). JRC 19 Dec '89*/
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);
  if (newdiag && diag->misc->mainstate == state_sel)
  { diag->misc->mainstate = (draw_state) -1; /*a random previous state to
                                     fool draw_action_changestate with*/
    ftracef0 ("draw_file_loadfile: draw_action_changestate\n");
    draw_action_changestate (diag, state_sel, '?', '?', FALSE);
  }
  ftracef2 ("draw_selection->owner 0x%X, "
      "draw_selection->owner->paper 0x%X\n",
      draw_selection->owner, draw_selection->owner->paper);

  return diag;  /*exit OK*/
}

/*-----------------------------------------------------------------------

Fetch a 'Draw' format file

-----------------------------------------------------------------------*/

static BOOL Extend_Diag (char **buffer, int *size)

{ int extendby = 1024;

  ftracef2 ("draw_file: Extend_Diag: owner_xferrecv.diag->paper %d, "
      "*size is %d\n", owner_xferrecv.diag->paper, *size);

  /*we can't call draw_obj_checkspace, it will not extend our block, because
   ghostlimit hasn't moved so borrow its midextend code and do it ourselves*/

  ftracef1 ("draw_file: Extend_Diag: flex_midextend (,, %d)\n",
      extendby);
  if (!FLEX_MIDEXTEND ((flex_ptr) &owner_xferrecv.diag->paper,
      owner_xferrecv.diag->misc->stacklimit, extendby))
  { /*No room to extend*/
    Error (0, "FileN1");
    return FALSE;
  }

  owner_xferrecv.diag->misc->stacklimit  += extendby;
  owner_xferrecv.diag->misc->bufferlimit += extendby;

  /*Inc filelen by amount just transferred*/
  owner_xferrecv.filelen += *size;

  *buffer += *size;
  *size = extendby; /*and give it the new buffer size*/

  ftracef2 ("leaving Extend_Diag, owner_xferrecv.diag->paper %d, "
      "*size %d\n", owner_xferrecv.diag->paper, *size);

  return TRUE;
}


/*Load a file (or receive ram transfered data) into a flex block
   buffp is a pointer to a pointer to the block (typicaly &diag->paper)
   offset is the position in the block to load to
   filelenp allows the filelength to be returned to the caller
   Returns TRUE if data loaded OK, else reports error and returns FALSE*/

BOOL draw_file_get (char *name, char **buffp, int offset, int *filelenp,
    xferrecv_buffer_processor extender)

{ ftracef0 ("draw_file_get\n");

  if (owner_xferrecv.method == via_FILE)
  { os_filestr blk;

    blk.action   = 255;           /*Load file into buffer*/
    blk.name     = name;
    blk.loadaddr = (int) (*buffp + offset);
    blk.execaddr = 0;

    if (wimpt_complain (os_file (&blk)))
      return FALSE;
  }
  else
  { int final;

    owner_xferrecv.filelen = 0;   /*updated by loadram_extend, if called*/

    ftracef2 ("loadfile calls xferrecv_doimport, "
        "owner_xferrecv.diag->paper is %d, *filelenp is %d\n",
        (int) owner_xferrecv.diag->paper, *filelenp);

    final = xferrecv_doimport (*buffp + offset, *filelenp,
        extender != NULL? extender: &Extend_Diag);

    ftracef1 ("returned to loadfile, final block transfer was %d bytes\n",
        final);

    if (final < 0) return FALSE;

    *filelenp = owner_xferrecv.filelen + final;      /*total size*/
  }

  return TRUE;
}

/*Export text area code*/
static BOOL exportTextArea (diagrec *diag, char *filename,
    fileIO_method method, int *maxbuf)

{ int  filehandle, i, ok;
  draw_objptr textArea;
  char *text;
  int  found = FALSE;
  draw_objptr hdrptr;

  ftracef0 ("draw_file: exportTextArea\n");
  claim_xfersend (diag, method, maxbuf);

  textArea.bytep = NULL;
  /*Check there is only one object selected*/
  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
  { if (hdrptr.objhdrp->tag == draw_OBJTEXTAREA)
    { if (found)
      { Error (FALSE, "TextX1");
        return FALSE;
      }
      else
      { found = TRUE;
        textArea = hdrptr;
      }
    }
  }

  /*Check there are an

y at all selected*/
  if (!found)
  { Error (FALSE, "TextX2");
    return FALSE;
  }

  text = & (draw_text_findEnd (textArea)->text[0]);

  ftracef1("exportTextArea: file size = %d bytes\n",strlen(text));

  /*Create and open the file*/
  if (!open_save (filename, FileType_Text, strlen (text), &filehandle)) return FALSE;

  /*Write the text*/
  ok = draw_file_write_bytes (filehandle,
                             &draw_selection->owner->paper,
                             text - draw_selection->owner->paper,
                             strlen (text));

  /*Close file, even if an error has already occured!*/
  ok &= draw_file_close_file (filehandle);

  return ok;
}

BOOL draw_file_file_exportTextArea (char *filename, void *handle)
{ ftracef0 ("draw_file_exportTextArea\n");
  return (exportTextArea ((diagrec*)handle, filename, via_FILE,0));
}

BOOL draw_file_ram_exportTextArea (void *handle, int *maxbuf)
{ ftracef0 ("draw_file_ram_exportTextArea\n");
  return (exportTextArea ((diagrec*)handle,"Wimp$Scrap", via_RAM,maxbuf));
}

/*New code to export a file as EPSF. Note that |method| is always via_FILE.
  J R C 28th Sep 1993*/
static BOOL exportEPSF (diagrec *diag, char *filename, fileIO_method method,
    int *maxbuf)

{ int job, ok = TRUE, old_driver;
  os_error *error = NULL;
  BOOL done_select_driver = FALSE;

  ftracef0 ("draw_file: exportEPSF\n");

  claim_xfersend (diag, method, maxbuf);

  /*Create and open the file*/
  if (!open_save (filename, 0xFF5, 0, &job))
    return FALSE;

  /*Select the PostScript printer driver.*/
  if ((error = os_swix1r (PDriver_SelectDriver, -2, &old_driver)) != NULL)
    goto finish;
  if ((error = os_swix1 (PDriver_SelectDriver, 0 /*PostScript*/)) != NULL)
    goto finish;
  done_select_driver = TRUE;

  if ((error = draw_print_to_file (diag, job, /*illustration?*/ TRUE)) !=
      NULL)
    goto finish;

finish:
  if (done_select_driver)
  { os_error *error1;

    error1 = os_swix1 (PDriver_SelectDriver, old_driver);
    if (error == NULL) error = error1;
  }

  /*Close file, even if an error has already occured*/
  if (!draw_file_close_file (job))
    ok = FALSE;

  if (error != NULL)
  { ok = FALSE;
    wimpt_complain (error);
  }

  return ok;
}

BOOL draw_file_file_exportEPSF (char *filename, void *handle)
{ ftracef0 ("draw_file_exportEPSF\n");
  return exportEPSF ((diagrec *) handle, filename, via_FILE, 0);
}

/*New code to export JPEG's. |Method| is always via_FILE. J R C 21st Sep 1994*/
static BOOL exportJPEG (diagrec *diag, char *filename, fileIO_method method,
    int *maxbuf)

{ int ok = TRUE, f;
  draw_objptr hdrptr;
  void       *jpegptr;

  ftracef0 ("draw_file: exportJPEG\n");

  claim_xfersend (diag, method, maxbuf);

  hdrptr.bytep = diag->paper + draw_selection->array [0];
  jpegptr = &hdrptr.jpegp->image;

  /*Create and open the file*/
  if ((ok = open_save (filename, FileType_JPEG, 0, &f)) == FALSE)
    goto finish;

  /* Save the data. */
  if ((ok = draw_file_write_bytes (f, (char **)&jpegptr, 0, hdrptr.jpegp->len)) == FALSE)
    goto finish;

finish:
  /*Close file, even if an error has already occured*/
  if (!draw_file_close_file (f))
    ok = FALSE;

  return ok;
}

BOOL draw_file_file_exportJPEG (char *filename, void *handle)
{ ftracef0 ("draw_file_exportJPEG\n");
  return exportJPEG ((diagrec *) handle, filename, via_FILE, 0);
}

int draw_file_size (diagrec *diag)

{ char font_table [256];
  int size;
  draw_objptr hdrptr, limit;

  ftracef0 ("draw_file_size\n");

  /*Find fonts used in each object*/
  memset (font_table, 0, 256);
  limit.bytep = diag->paper + diag->misc->solidlimit;
  for (hdrptr.bytep = diag->paper + diag->misc->solidstart;
      hdrptr.bytep < limit.bytep; hdrptr.bytep += hdrptr.objhdrp->size)
    draw_file_fontuse_object (hdrptr, font_table);

  size = 0;
  (void) save_all_data (NULL, font_table, diag, 0, &size);

  ftracef1 ("size %d\n", size);
  return size;
}

int draw_file_selection_size (diagrec *diag)

{ char font_table [256];
  int size, i;
  draw_objptr hdrptr;

  ftracef0 ("draw_file_selection_size\n");

  /*find fonts used in each selected object*/
  memset (font_table, 0, 256);
  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    draw_file_fontuse_object (hdrptr, font_table);

  size = 0;
  (void) save_selected_data (NULL, font_table, diag, 0, &size);

  ftracef1 ("size %d\n", size);
  return size;
}

int draw_file_sprites_size (diagrec *diag)

{ int size, i;
  draw_objptr hdrptr;

  ftracef0 ("draw_file_sprites_size\n");
  diag = diag;

  size = sizeof (sprite_area) - 4;
  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    switch (hdrptr.objhdrp->tag)
    { case draw_OBJSPRITE:
        size += hdrptr.spritep->sprite.next;
      break;

      case draw_OBJTRFMSPRITE:
        size += hdrptr.trfmspritep->sprite.next;
      break;
    }

  ftracef1 ("size %d\n", size);
  return size;
}

int draw_file_text_size (diagrec *diag)

{ int size, i;
  draw_objptr hdrptr;

  ftracef0 ("draw_file_text_size\n");
  diag = diag;

  size = 0;
  for (i = 0; hdrptr = draw_select_find (i), hdrptr.bytep != NULL; i++)
    if (hdrptr.objhdrp->tag == draw_OBJTEXTAREA)
      size += strlen (draw_text_findEnd (hdrptr)->text);

  ftracef1 ("size %d\n", size);
  return size;
}

#if ALLOW_DFILES
/*---------------------------------------------------------------------------*/

/*Fetch a 'D' format file.*/

/*The file is loaded into a heap block (which is later freed), then
scaned and converted into 'draw_obj_start','draw_obj_addpath_move',
'draw_obj_addpath_curve','draw_obj_complete' etc calls.*/

/*Text objects reference a fontlist object created before scanning,
which holds the names of arthur fonts equivalent to 'D's laser fonts.*/

/*The data between ghoststart & ghostlimit then looks similar to that
OSFILED from a proper Draw file (except for naff BBoxes).*/

/*N.B. draw_obj_complete is used, NOT draw_obj_finish, to prevent BBox
calculation (fontref-to-fontname not yet known) and to prevent
merger of naff data with the main data base.*/

/*The heap will shift, as we enter objects*/

/*---------------------------------------------------------------------------*/

typedef enum
{ D_TAGEND  = 0,
  D_TAGOBJ  = 1,
  D_TAGLINE = 2,
  D_TAGTEXT = 3,
  D_TAGELL  = 4
} d_tagtype;

char *filebufptr;
int   filelen, fileoff;

#define cvt_Dc2dbc (A) ((int) ((A)*256 + 128) )

int getbyte (void)
{ return * (filebufptr+fileoff++);
}

double getfloat (void)
{ /*Mutilate + hurt a number from 5 (Roger) to 8 (IEEE) bytes
  Thank you Stuart*/

/*
  Roger format is :
    0 : exponent (excess 128)
    1 : b7 mantissa sign, b6-b0 msb's of mantissa
  2-4 : lower bits of mantissa (Total mantissa bits = 31)

  IEEE format is :
  0-3 : b31 mantissa sign, b30-b20 exponent (excess 1023), b19-b0 msb's of mant
  4-7 : lower bits of mantissa

Roger 1.0 is 81 00 00 00 00
IEEE  1.0 is 03 FF 00 00 00 00 00 00
*/

  union { unsigned int i[2];  double fp; } res;

  unsigned int md = getbyte ();
  unsigned int mc = getbyte ();
  unsigned int mb = getbyte ();
  unsigned int ma = getbyte ();
  unsigned int exp = ((getbyte () + 0x37E) << 20) & 0x7FF00000;

  unsigned int mant = ((ma << 24) | (mb << 16) | (mc << 8) | md) << 1;
                                                        /*Reorder the bytes*/
  unsigned int sign = (ma << 24) & 0x80000000;

  ftracef0 ("draw_file: getfloat\n");
  /*ftracef3 ("sign %x, exp %x, mant %x\n", sign >> 31, exp, mant);*/
  res.i[0] = sign | exp | (mant >> 12);
  res.i[1] = mant << 20;

  return res.fp;
}

void cnvtstyle (diagrec *diag, int style)
{ int fillcol;
  int linecol = BLACK;  /*It usually is*/
  int linewid;

  ftracef0 ("draw_file: cnvtstyle\n");
  switch ((style >> 4) & 0xF)
    { case 1:  fillcol = 0xF0F0F000; break;   /*wimp colour 0*/
      case 2:  fillcol = 0xE0E0E000; break;   /*1*/
      case 3:  fillcol = 0xA0A0A000; break;   /*3*/
      case 4:  fillcol = 0x60606000; break;   /*5*/
      case 5:  fillcol = 0x10101000; break;   /*7*/
      default: fillcol = TRANSPARENT;
    }

  switch (style & 0xF)
    { case 1:  linewid =  160; break;  /*1..9 are differing widths*/
      case 2:  linewid =  320; break;  /*in black*/
      case 3:  linewid =  480; break;
      case 4:  linewid =  640; break;
      case 5:  linewid =  960; break;
      case 6:  linewid = 1280; break;
      case 7:  linewid = 1600; break;
      case 8:  linewid = 1920; break;
      case 9:  linewid = 2560; break;
      case 0:  linecol = TRANSPARENT;  /*0 no outline, drop into*/
      default: linewid = THIN; break;  /*thin*/
    }

  draw_obj_setpath_colours (diag, fillcol,linecol,linewid);
  draw_obj_setpath_style (diag, join_bevelled,cap_butt,cap_butt,
                         wind_evenodd,0,0);
}

int fontsizecnvttab[] = {  6,  8, 10, 12, 14, 16, 18, 20,
                          24, 28, 32, 36, 48, 60, 72, 96, };

char *fontnamecnvttab[] =
{ "",
  "Homerton.Medium"    , "Homerton.Medium.Oblique",
  "Homerton.Bold"      , "Homerton.Bold.Oblique"  ,

  "Trinity.Bold"       , "Trinity.Bold.Italic"    ,
  "Trinity.Medium"     , "Trinity.Medium.Italic"  ,

  "Corpus.Medium"      , "Corpus.Bold"            ,
  "Corpus.Bold.Oblique", "Corpus.Medium.Oblique"  ,
};

typedef enum
{ SYSTEM,
  HOMERTON_MEDIUM      , HOMERTON_MEDIUM_OBLIQUE,
  HOMERTON_BOLD        , HOMERTON_BOLD_OBLIQUE  ,
  TRINITY_BOLD         , TRINITY_BOLD_ITALIC    ,
  TRINITY_MEDIUM       , TRINITY_MEDIUM_ITALIC  ,
  CORPUS_MEDIUM        , CORPUS_BOLD            ,
  CORPUS_BOLD_OBLIQUE  , CORPUS_MEDIUM_OBLIQUE
} indexintofontnametab;

void cnvtfont (diagrec *diag, int font,int size)
{ int fontsize = fontsizecnvttab[size]*dbc_OnePoint;
  indexintofontnametab fontindx;

  ftracef0 ("draw_file: cnvtfont\n");
  switch (font)
    { case  1: case 13:
        fontindx = HOMERTON_MEDIUM;         break;

      case  2: case 16:
        fontindx = HOMERTON_MEDIUM_OBLIQUE; break;

      case  3: case 14:
        fontindx = HOMERTON_BOLD;           break;

      case  4: case 15:
        fontindx = HOMERTON_BOLD_OBLIQUE;   break;

      case  5: case 17: case 21:
        fontindx = TRINITY_BOLD;            break;

      case  6: case 18: case 22:
        fontindx = TRINITY_BOLD_ITALIC;     break;

      case  7: case 20: case 24:
        fontindx = TRINITY_MEDIUM;          break;

      case  8: case 19: case 23: case 25:
        fontindx = TRINITY_MEDIUM_ITALIC;   break;

      case  9:
        fontindx = CORPUS_MEDIUM;           break;

      case 10:
        fontindx = CORPUS_BOLD;             break;

      case 11:
        fontindx = CORPUS_BOLD_OBLIQUE;     break;

      case 12:
        fontindx = CORPUS_MEDIUM_OBLIQUE;   break;

      default:
        fontindx = SYSTEM;
    }

  draw_obj_settext_font (diag, fontindx, fontsize,fontsize);
  draw_obj_settext_colour (diag, BLACK,WHITE);  /*black on (probably) white*/
}

static BOOL fetch_Dfile (diagrec *diag, char *name,int filelen)
{ d_tagtype  tag;

  ftracef1 ("draw_file: fetch_Dfile: loading %s\n", name);

  ftracef1 ("draw_file: fetch_Dfile: flex_alloc (,, %d)\n", filelen);
  if (!FLEX_ALLOC ((flex_ptr) &filebufptr, filelen))      /*claim block*/
  { werr (0, "No room - to load D file"); return FALSE; }

  /*From here on, 'goto freeblk_report_err' if an error occurs*/
  if (!draw_file_get (name, &filebufptr,0, &filelen) )
    goto freeblk_report_err;

  fileoff = 0;

/*Output a fileheader, so that this looks like an Draw file
that has been OsFiled in.*/

  if (wimpt_complain (draw_obj_checkspace (diag, sizeof (draw_fileheader)))
    goto freeblk_report_err;

  draw_obj_fileheader (diag);

/*Then output a font list
it doesn't matter if any or all entries arn't needed*/

  { int i;
    int objsize = sizeof (draw_fontliststrhdr);

    /*enter all font names from convertion table (0th entry not used)*/

    for (i = 1; i < (sizeof (fontnamecnvttab)/sizeof (char*)); i++)
    { objsize += sizeof (draw_fontref) + strlen (fontnamecnvttab[i]) + 1;
    }
    objsize = (objsize + 3) & (-4); /*plus 0..3 nulls to a word*/

    if (wimpt_complain (draw_obj_checkspace (diag, objsize)))
      goto freeblk_report_err;

ftracef0 ("start output of fontlist:\n");

    draw_obj_start (diag, draw_OBJFONTLIST);

    /*0th entry not used*/
    for (i = 1; i < (sizeof (fontnamecnvttab)/sizeof (char*)); i++)
    { ftracef2 ("  including '%s' as ref %d ", (int)fontnamecnvttab[i],i);
      draw_obj_addfontentry (diag, i,fontnamecnvttab[i]);
    }

ftracef0 ("complete output of fontlist:\n");
    draw_obj_addtext_term (diag);  /*pad to word boundary*/
    draw_obj_complete (diag);
  }

  while (D_TAGEND != (tag = getbyte ()) )
    { double x0 = getfloat (); double y0 = getfloat ();       /*bounding box*/
      (void) getfloat (); (void) getfloat ();

      switch (tag)
      { case D_TAGOBJ:
        { if (wimpt_complain (draw_obj_checkspace (diag, sizeof (draw_groustr)))
            goto freeblk_report_err; }

          draw_obj_start (diag, draw_OBJGROUP);

          while (D_TAGOBJ != (tag = getbyte ()) )
          { switch (tag) /*2*/
            { case D_TAGLINE:
                { int linecount = getbyte ();
                  int style     = getbyte ();
                  int i;

                  if (wimpt_complain (draw_obj_checkspace (diag,
                                       sizeof (draw_pathstr) +
                                       sizeof (drawmod_path_linetostr)*linecount
                                       + sizeof (drawmod_path_termstr)))
                    goto freeblk_report_err;

                  draw_obj_start (diag, draw_OBJPATH);
                  cnvtstyle (diag, style);
                  { double x = getfloat (); double y = getfloat ();

                    draw_obj_addpath_move (diag, cvt_Dc2dbc (x0+x),
                                                cvt_Dc2dbc (y0+y));

                    for (i = 1; i <= linecount; i++)
                    { x = getfloat (); y = getfloat ();
                      draw_obj_addpath_line (diag, cvt_Dc2dbc (x0+x),
                                                  cvt_Dc2dbc (y0+y));
                    }
                    draw_obj_addpath_term (diag);
                  }
                  draw_obj_complete (diag);
                  break;
                }

              case D_TAGTEXT:
                { int font   = getbyte ();
                  int size   = getbyte ();

                  double x = getfloat ();
                  double y = getfloat ();

                  int textoff = fileoff;
                  int need = sizeof (draw_textstr);

                  while (13 != getbyte ()) need++; /*string is CR terminated*/

                  if (wimpt_complain (draw_obj_checkspace (diag, need)))
                    goto freeblk_report_err;

                  draw_obj_start (diag, draw_OBJTEXT);
                  draw_obj_setcoord (diag, cvt_Dc2dbc (x0 + x),
                      cvt_Dc2dbc (y0 + y));
                  cnvtfont (diag, font, size);
                  draw_obj_addstring (diag, (char*)filebufptr+textoff);
                  draw_obj_complete (diag);
                  break;
                }

              default:
                { goto unknown_tag;
                }
            }       /*switch (tag) 2*/
          }

          draw_obj_complete (diag);    ftracef0 ("end of object\n");
          break;
        }

        case D_TAGLINE:
        { int linecount = getbyte ();
          int style     = getbyte ();
          int i;

          if (wimpt_complain (draw_obj_checkspace (diag, sizeof (draw_pathstr) +
                                      sizeof (drawmod_path_linestr)*linecount
                                      + sizeof (drawmod_path_termstr)))
            goto freeblk_report_err;

          draw_obj_start (diag, draw_OBJPATH);
          cnvtstyle (diag, style);

          { double x = getfloat (); double y = getfloat ();
            draw_obj_addpath_move (diag, cvt_Dc2dbc (x0+x),cvt_Dc2dbc (y0+y));

            for (i = 1; i <= linecount; i++)
            { x = getfloat (); y = getfloat ();
              draw_obj_addpath_line (diag, cvt_Dc2dbc (x0+x),cvt_Dc2dbc (y0+y));
            }
            draw_obj_addpath_term (diag);
          }
          draw_obj_complete (diag);
          break;
        }

        case D_TAGTEXT:
        { int font = getbyte ();
          int size = getbyte ();
          int textoff = fileoff;
          int need = sizeof (draw_textstr);

          while (13 != getbyte ()) need++; /*string is CR terminated*/

          if (wimpt_complain (draw_obj_checkspace (diag, need)));
            goto freeblk_report_err;

          draw_obj_start (diag, draw_OBJTEXT);
          draw_obj_setcoord (diag, cvt_Dc2dbc (x0),cvt_Dc2dbc (y0));
          cnvtfont (diag, font,size);
          draw_obj_addstring (diag, (char*)filebufptr+textoff);
          draw_obj_complete (diag);
          break;
        }

        default:
        { goto unknown_tag;
        }
      } /*switch (tag)*/
    }

  FLEX_FREE ((flex_ptr) &filebufptr);  /*dispose of temporary file buffer*/

  return TRUE;  /*exit OK*/

unknown_tag:
  werr (0, "Unknown tag type found in a 'D' file");

freeblk_report_err:       /*NB jump here on error to dispose of file buffer*/
  draw_obj_flush (diag);
  FLEX_FREE ((flex_ptr) &filebufptr);

  return FALSE;
}
#endif
