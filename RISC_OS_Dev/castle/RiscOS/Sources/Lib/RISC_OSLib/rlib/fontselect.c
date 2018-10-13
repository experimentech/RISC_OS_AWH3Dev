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

/*
 * Title: fontselect.c
 * Purpose: Code to allow a consistent interface to font choosing
 * History: IDJ: 06-Feb-92: prepared for source release
 */


#ifndef UROM

#include <stdlib.h>
#include <stdio.h>
#include "werr.h"
#include "wimp.h"
#include "wimpt.h"
#include "win.h"
#include "event.h"
#include "baricon.h"
#include "res.h"
#include "resspr.h"
#include "menu.h"
#include "template.h"
#include "dbox.h"
#include "fontlist.h"
#include "fontselect.h"
#include "msgs.h"
#include "akbd.h"
#include "font.h"
#include <string.h>

/* ------------------------------------------------------------- */
/* Icon numbers */
/* ------------------------------------------------------------- */
#define okay_icon        0
#define cancel_icon      1
#define typeface_icon    4
#define weight_icon      7
#define style_icon       10
#define height_up_icon   15
#define width_up_icon    16
#define height_icon      17
#define width_icon       18
#define height_down_icon 19
#define width_down_icon  20
#define font_text_icon   21
#define try_icon         22

#define typeface_level          0
#define weight_level            1
#define style_level             2

#define font_pane_esg           1
#define wimp_IESG               0x00010000

#define max_font_length         40

#define null_entry_text         "(None)"


/* ------------------------------------------------------------- */
/* Structures required */
/* ------------------------------------------------------------- */
typedef struct pane_block
{
    int         level;
    wimp_w      handle;
    wimp_i      selection;
    int         no_icons;
    char        icons[1][max_font_length];
} pane_block;


typedef struct global_data
{
    font       font_handle;
    wimp_w     font_window_handle;
    pane_block *(panes_store[3]);
    double     start_width;
    double     start_height;
    int        start_typeface_selection;
    int        start_weight_selection;
    int        start_style_selection;
} global_data;

/* ------------------------------------------------------------- */
/* Global variables */
/* ------------------------------------------------------------- */
static global_data      *globals;



/* ------------------------------------------------------------- */
/* Functions required */
/* ------------------------------------------------------------- */

/* Create and open a subwindow pane */
static os_error *open_subwindow( char *name, pane_block *pane, int x_offset, int y_offset, wimp_i icon );

/* Open a subwindow */
static os_error *reopen_subwindow( wimp_w behind, wimp_w handle, int x_offset, int y_offset, wimp_i icon );

/* Produce the font selector windows */
static BOOL display_font_windows( fontselect_fn unknown_icon_routine );

/* Set the icons up in the windows */
static void set_window_states( int level );

/* Set up the icons in a single pane window */
static void set_window_icons( pane_block *pane, fontlist_node *font_ptr, BOOL flag );

/* Adjust the width up/down by a value */
static void add_to_width( double change );

/* Adjust the height up/down by a value */
static void add_to_height( double change );

/* Simple read/write icon routines */
static double read_float( wimp_i icon );
static int read_int( wimp_i icon );
static void set_float( wimp_i icon, double value );
static void set_int( wimp_i icon, int value );
static void force_icon_redraw( wimp_i icon, wimp_icon *icon_block );

/* Unknown  processor (help and mode change) */
static BOOL unknown_processor( wimp_eventstr *e, void *handle );

/* Main window handler */
static void window_process( wimp_eventstr *event, void *handle);

/* Subwindow handler */
static void subwindow_process( wimp_eventstr *e, void *handle);

/* Handle buttons in true RADIO style */
static wimp_i radio_button( wimp_w window, wimp_i icon, int esg );

/* Find the font entry at a certain level of the font tree */
static int font_find_in_tree( fontlist_node **font_ptr, char **font_name, BOOL flag, int level );

/* Read the name of the font in the windows */
static void read_font_name( char *font_name );

/* Set up the anti-aliased font for the test icon */
static void set_test_font_style( wimp_i icon );

/* Count the number of font entries at a level in the font tree */
static void count_max_font_entries( int *no_icons, int level, fontlist_node *font_ptr );

/* ------------------------------------------------------------- */
/* Create a subwindow for the main window */
/* ------------------------------------------------------------- */
os_error *open_subwindow( char *name, pane_block *pane, int x_offset, int y_offset, wimp_i icon )
{
   int             i,j,x0,x1,y0,y1,dx,dy;
   wimp_wind       *window;
   wimp_icreate    icon_create;
   os_error        *error;

   if ( (window = template_syshandle(name))==0 )
       return NULL;
   window -> nicons = 2;
   if ( (error=wimp_create_wind( window, &(pane->handle) )) !=NULL )
       return error;

   icon_create.w = pane->handle;
   wimpt_noerr( wimp_get_icon_info( pane->handle, 0 , &icon_create.i) );
   wimpt_noerr( wimp_delete_icon( pane->handle, 0 ) );
   x0 = icon_create.i.box.x0;
   x1 = icon_create.i.box.x1;
   y0 = icon_create.i.box.y0;
   y1 = icon_create.i.box.y1;
   wimpt_noerr( wimp_get_icon_info( pane->handle, 1 , &icon_create.i) );
   wimpt_noerr( wimp_delete_icon( pane->handle, 1 ) );
   dx = icon_create.i.box.x0 - x0;
   dy = icon_create.i.box.y0 - y0;

   for (i=0;i<pane->no_icons;i++)
   {
      icon_create.i.box.x0 = x0;
      icon_create.i.box.x1 = x1;
      icon_create.i.box.y0 = y0;
      icon_create.i.box.y1 = y1;
      x0 += dx; x1 += dx;
      y0 += dy; y1 += dy;
      icon_create.i.data.indirecttext.buffer = pane->icons[i];
      if ( (error=wimp_create_icon( &icon_create, &j )) !=NULL )
          return error;
   }
   return ( reopen_subwindow( -1, pane->handle, x_offset, y_offset, icon) );
}

/* ------------------------------------------------------------- */
/* Open a subwindow for the main window */
/* ------------------------------------------------------------- */
os_error *reopen_subwindow( wimp_w behind, wimp_w handle, int x_offset, int y_offset, wimp_i icon )
{
   wimp_openstr    open;
   os_error        *error;
   wimp_icon       icon_block;
   wimp_wstate     window_state;

   wimpt_noerr( wimp_get_wind_state( handle, &window_state ) );
   if ( (error=wimp_get_icon_info( globals->font_window_handle, icon, &icon_block )) !=NULL )
       return error;
   open.w = handle;
   open.box.x0 = icon_block.box.x0 + x_offset;
   open.box.y0 = icon_block.box.y0 + y_offset;
   open.box.x1 = icon_block.box.x1 + x_offset;
   open.box.y1 = icon_block.box.y1 + y_offset;
   open.x = window_state.o.x;
   open.y = window_state.o.y;
   open.behind = behind;
   return wimp_open_wind(&open);
}

/* ------------------------------------------------------------- */
/* Produce the font selector windows */
/* ------------------------------------------------------------- */
BOOL display_font_windows( fontselect_fn unknown_icon_routine )
{
   int             x_offset, y_offset;
   wimp_wind       *window_block_ptr;
   wimp_wstate     window_state;


   /* Create the dialogue box */
   if ( (window_block_ptr=template_syshandle("FontSelect")) == NULL)
   {
       werr(0, "Failed to find FontSelect template.");
       return FALSE;
   }
   else
   {

      /* Show the main window */
      if (wimpt_complain( wimp_create_wind( window_block_ptr, &window_state.o.w )))
          return FALSE;
      globals->font_window_handle = window_state.o.w;
      wimpt_noerr( wimp_get_wind_state( globals->font_window_handle, &window_state ) );
      wimpt_noerr( wimp_open_wind( &window_state.o ) );
      x_offset = window_state.o.box.x0 - window_state.o.x;
      y_offset = window_state.o.box.y1 - window_state.o.y;

      /* Open the subwindows */
      (globals->panes_store)[typeface_level]->level = typeface_level;
      if (wimpt_complain( open_subwindow("Typeface",    (globals->panes_store)[typeface_level],    x_offset, y_offset, typeface_icon    ) ))
      {
          fontselect_closewindows();
          return FALSE;
      }

      (globals->panes_store)[weight_level]->level = weight_level;
      if (wimpt_complain( open_subwindow("Weight",    (globals->panes_store)[weight_level],    x_offset, y_offset, weight_icon    ) ))
      {
          fontselect_closewindows();
          return FALSE;
      }

      (globals->panes_store)[style_level]->level = style_level;
      if (wimpt_complain( open_subwindow("Style",    (globals->panes_store)[style_level],    x_offset, y_offset, style_icon    ) ))
      {
          fontselect_closewindows();
          return FALSE;
      }


      /* Attach handlers */
      win_register_event_handler( globals->font_window_handle,                 window_process,    (void *) unknown_icon_routine );
      win_register_event_handler( (globals->panes_store)[typeface_level]->handle, subwindow_process, (void *) (globals->panes_store)[typeface_level] );
      win_register_event_handler( (globals->panes_store)[weight_level]->handle,   subwindow_process, (void *) (globals->panes_store)[weight_level] );
      win_register_event_handler( (globals->panes_store)[style_level]->handle,    subwindow_process, (void *) (globals->panes_store)[style_level] );
      win_add_unknown_event_processor( unknown_processor, NULL );
      return TRUE;
   }

   return FALSE;
}


/* ------------------------------------------------------------- */
/* Set up the icons for the windows */
/* ------------------------------------------------------------- */
void set_window_states( int level )
{
   BOOL            flag;
   int             i;
   fontlist_node   *font_ptr;

   /* If redrawing top level, then redraw the typeface window */
   font_ptr = font__tree;
   if ( level <= typeface_level )
      set_window_icons( (globals->panes_store)[typeface_level], font_ptr, FALSE);

   /* Now hunt down for our currently selected typeface */
   for ( i=0; i<(globals->panes_store)[typeface_level]->selection; i++ )
       if (font_ptr!=NULL)
           font_ptr = font_ptr->brother;

   /* For the currently selected typeface, and if the level is right, redraw the weight window */
   if (font_ptr != NULL)
   {
      flag = font_ptr -> flag;
      font_ptr = font_ptr -> son;
   }
   else
   {
      flag = TRUE;
   }
   if ( level <= weight_level )
       set_window_icons( (globals->panes_store)[weight_level], font_ptr, flag);

   /* Now hunt down the weight list for our currently selected weight */
   for (i=0; i<(globals->panes_store)[weight_level]->selection; i++)
       if (font_ptr!=NULL)
           font_ptr = font_ptr->brother;

   /* If the level is correct then redraw the style window for the current typeface and weight */
   if (font_ptr != NULL)
   {
      flag = font_ptr -> flag;
      font_ptr = font_ptr -> son;
   }
   else
   {
      flag = TRUE;
   }
   if ( level <= style_level )
       set_window_icons( (globals->panes_store)[style_level], font_ptr, flag);
}



/* ------------------------------------------------------------- */
/* Set the icons in a window */
/* ------------------------------------------------------------- */
void set_window_icons( pane_block *pane, fontlist_node *font_ptr, BOOL flag )
{
   int             i=0, last_icon=0;
   wimp_icon       icon_block;
   wimp_redrawstr  redraw_block;
   wimp_wstate     window_block;

   if (flag)
   {
      strcpy( (pane->icons)[i], null_entry_text );
      if (i == pane->selection)
           wimp_set_icon_state( pane->handle, i, wimp_ISELECTED , wimp_ISELECTED | wimp_IDELETED );
      else
           wimp_set_icon_state( pane->handle, i, 0              , wimp_ISELECTED | wimp_IDELETED );
      i++;
   }

   for (;i<pane->no_icons;i++)
   {
      if (font_ptr != NULL)
      {
         strcpy( (pane->icons)[i], font_ptr->name );
         if ( i == pane->selection )
             wimp_set_icon_state( pane->handle, i, wimp_ISELECTED , wimp_ISELECTED | wimp_IDELETED );
         else
             wimp_set_icon_state( pane->handle, i, 0              , wimp_ISELECTED | wimp_IDELETED );
         font_ptr = font_ptr->brother;
         last_icon = i;
      }
      else
      {
        wimp_get_icon_info( pane->handle, i, &icon_block );
        wimp_set_icon_state( pane->handle, i, wimp_IREDRAW,
                 wimp_ITEXT | wimp_ISPRITE | wimp_IBORDER | wimp_IFILLED | wimp_IREDRAW | wimp_ISELECTED);
        wimp_set_icon_state( pane->handle, i, icon_block.flags | wimp_IDELETED , -1 );
      }
   }

   /* Make sure there is a selection! */
   if (pane->selection > last_icon)
   {
      pane->selection = 0;
      wimp_set_icon_state( pane->handle, 0, wimp_ISELECTED , wimp_ISELECTED | wimp_IDELETED );
   }

   /* Now set the window extent */
   wimpt_noerr( wimp_get_icon_info( pane->handle, pane->selection, &icon_block ) );
   wimpt_noerr( wimp_get_wind_state( pane->handle, &window_block ) );
   window_block.o.y = (icon_block.box.y1 + icon_block.box.y0 + window_block.o.box.y1 - window_block.o.box.y0)/2;
   wimpt_noerr( wimp_get_icon_info( pane->handle, last_icon, &icon_block ) );
   if (window_block.o.y < icon_block.box.y0 + window_block.o.box.y1 - window_block.o.box.y0 )
       window_block.o.y = icon_block.box.y0 + window_block.o.box.y1 - window_block.o.box.y0 ;
   wimpt_noerr( wimp_get_icon_info( pane->handle, 0, &icon_block ) );
   if (window_block.o.y > icon_block.box.y1 )
       window_block.o.y = icon_block.box.y1 ;
   wimpt_noerr( wimp_open_wind( &window_block.o ) );
   redraw_block.w = pane->handle;
   redraw_block.box.x0 = icon_block.box.x0;
   redraw_block.box.y1 = icon_block.box.y1;
   redraw_block.box.x1 = icon_block.box.x1;
   wimpt_noerr( wimp_get_icon_info( pane->handle, last_icon, &icon_block ) );
   redraw_block.box.y0 = icon_block.box.y0;
   if (redraw_block.box.y0 > window_block.o.y + window_block.o.box.y0 - window_block.o.box.y1 )
       redraw_block.box.y0 = window_block.o.y + window_block.o.box.y0 - window_block.o.box.y1;
   wimpt_noerr( wimp_set_extent( &redraw_block ) );
}



/* ------------------------------------------------------------- */
/* Adjust the height up/down by a value */
/* ------------------------------------------------------------- */
void add_to_width( double change )
{
   double  value;

   value = change + read_float( width_icon );
   if (value<0.0) value=0.0;
   set_float( width_icon, value );

   if ( akbd_pollsh() )
   {
      value = change + read_float( height_icon );
      if (value<0.0) value=0.0;
      set_float( height_icon, value );
   }
}

/* ------------------------------------------------------------- */
/* Adjust the height up/down by a value */
/* ------------------------------------------------------------- */
void add_to_height( double change )
{
   double  value;

   value = change + read_float( height_icon );
   if (value<0.0) value=0.0;
   set_float( height_icon, value );

   if ( akbd_pollsh() )
   {
      value = change + read_float( width_icon );
      if (value<0.0) value=0.0;
      set_float( width_icon, value );
   }
}

/* ------------------------------------------------------------- */
/* Simple read/write icon routines */
/* ------------------------------------------------------------- */
double read_float( wimp_i icon )
{
   wimp_icon icon_block;

   wimpt_noerr( wimp_get_icon_info( globals->font_window_handle, icon, &icon_block ));
   return atof( icon_block.data.indirecttext.buffer );
}

int read_int( wimp_i icon )
{
   wimp_icon icon_block;

   wimpt_noerr( wimp_get_icon_info( globals->font_window_handle, icon, &icon_block ));
   return atoi( icon_block.data.indirecttext.buffer );
}

void set_float( wimp_i icon, double value )
{
   wimp_icon icon_block;

   wimpt_noerr( wimp_get_icon_info( globals->font_window_handle, icon, &icon_block ));
   sprintf(icon_block.data.indirecttext.buffer,"%g",value);
   force_icon_redraw( icon, &icon_block );
}

void set_int( wimp_i icon, int value )
{
   wimp_icon icon_block;

   wimpt_noerr( wimp_get_icon_info( globals->font_window_handle, icon, &icon_block ));
   sprintf(icon_block.data.indirecttext.buffer,"%d",value);
   force_icon_redraw( icon, &icon_block );
}

void force_icon_redraw( wimp_i icon, wimp_icon *icon_block )
{
   int             l;
   wimp_caretstr   caret ;

   wimpt_noerr(wimp_get_caret_pos(&caret)) ;

   if ((caret.w == globals->font_window_handle) && (caret.i == icon))
   {
      l = strlen( icon_block->data.indirecttext.buffer );
      if (caret.index > l) caret.index = l ;
      caret.height = caret.x = caret.y -1 ;
      wimpt_noerr(wimp_set_caret_pos(&caret)) ;
   }
   wimpt_noerr(wimp_set_icon_state( globals->font_window_handle, icon, 0, 0));
}



/* ------------------------------------------------------------- */
/* Close all the windows and free the workspace */
/* ------------------------------------------------------------- */
extern void fontselect_closedown( void )
{
   fontselect_closewindows();
   if (globals!=NULL)
   {
      if ( (globals->panes_store)[typeface_level] != NULL )
          free ( (globals->panes_store)[typeface_level] );
      if ( (globals->panes_store)[style_level] != NULL )
          free ( (globals->panes_store)[style_level] );
      if ( (globals->panes_store)[weight_level] != NULL )
          free ( (globals->panes_store)[weight_level] );
      free ( globals );
      globals=NULL;
   }
}




/* ------------------------------------------------------------- */
/* Close all the windows */
/* ------------------------------------------------------------- */
extern void fontselect_closewindows( void )
{
   win_remove_unknown_event_processor( unknown_processor, NULL );
   if (globals!=NULL)
   {
      if ((globals->panes_store)[typeface_level]->handle != -1)
      {
         wimpt_noerr( wimp_close_wind(  (globals->panes_store)[typeface_level]->handle ) );
         wimpt_noerr( wimp_delete_wind( (globals->panes_store)[typeface_level]->handle ) );
         win_register_event_handler((globals->panes_store)[typeface_level]->handle, 0, 0);
         (globals->panes_store)[typeface_level]->handle = -1;
      }
      if ((globals->panes_store)[style_level]->handle != -1)
      {
         wimpt_noerr( wimp_close_wind(  (globals->panes_store)[style_level]->handle ) );
         wimpt_noerr( wimp_delete_wind( (globals->panes_store)[style_level]->handle ) );
         win_register_event_handler((globals->panes_store)[style_level]->handle, 0, 0);
         (globals->panes_store)[style_level]->handle = -1;
      }
      if ((globals->panes_store)[weight_level]->handle != -1)
      {
         wimpt_noerr( wimp_close_wind(  (globals->panes_store)[weight_level]->handle ) );
         wimpt_noerr( wimp_delete_wind( (globals->panes_store)[weight_level]->handle ) );
         win_register_event_handler((globals->panes_store)[weight_level]->handle, 0, 0);
         (globals->panes_store)[weight_level]->handle = -1;
      }
      if ( globals->font_window_handle != -1 )
      {
         wimpt_noerr( wimp_close_wind(  globals->font_window_handle ) );
         wimpt_noerr( wimp_delete_wind( globals->font_window_handle ) );
         win_register_event_handler(globals->font_window_handle, 0, 0);
         globals->font_window_handle = -1;
      }
      if (globals->font_handle!=-1)
      {
         font_lose(globals->font_handle);
         globals->font_handle = -1;
      }
   }
}



/* ------------------------------------------------------------- */
/* Unknown event handler for ModeChange message */
/* ------------------------------------------------------------- */
static BOOL unknown_processor( wimp_eventstr *e, void *handle )
{
   font_def        font_block;
   wimp_caretstr   caret_block;

   switch (e->e)
   {
      case wimp_ESEND:
      case wimp_ESENDWANTACK:
          switch (e->data.msg.hdr.action)
          {
             case wimp_MMODECHANGE:
                 if ( globals->font_handle != -1 )
                 {
                    wimpt_noerr( font_readdef( globals->font_handle, &font_block ) );
                    wimpt_noerr( font_lose( globals->font_handle ) );
                    wimpt_noerr( font_find( font_block.name, font_block.xsize, font_block.ysize, 0,0,&globals->font_handle) );
                    wimpt_noerr( wimp_set_icon_state( globals->font_window_handle, font_text_icon,
                                        wimp_IFONT | (globals->font_handle * wimp_IFORECOL), wimp_IFONT | (0xff * wimp_IFORECOL) ) );
                    wimpt_noerr( wimp_get_caret_pos( &caret_block ) );
                    caret_block.height = -1;
                    wimpt_noerr( wimp_set_caret_pos( &caret_block ) );
                 }
                 break;
         }
          break;
   }
   return FALSE;
}



/* ------------------------------------------------------------- */
/* Reply to a help request message */
/* ------------------------------------------------------------- */
static void help_reply( wimp_eventstr *e, char *text )
{
   e->data.msg.hdr.your_ref = e->data.msg.hdr.my_ref;
   e->data.msg.hdr.action = wimp_MHELPREPLY;
   e->data.msg.hdr.size = 256;
   strcpy( e->data.msg.data.helpreply.text, text );
   wimp_sendmessage( wimp_ESEND, &(e->data.msg), e->data.msg.hdr.task );
}




/* ------------------------------------------------------------- */
/* Main window handler */
/* ------------------------------------------------------------- */
void window_process( wimp_eventstr *e, void *handle)
{
   int             i;
   int             x_offset;
   int             y_offset;
   int             data[32];
   char            buf[256];
   char            *chr_ptr;
   wimp_which_block which_block;
   char            font_name[40];
   wimp_icon       icon_block;
   wimp_wstate     pane_posn;
   fontselect_fn   unknown_icon_routine = (fontselect_fn) handle;

   handle = handle;

   switch (e->e)
   {
       case wimp_EOPEN:
/* If opening at the same position in the stack, then open it behind the rearmost pane */
           wimpt_noerr( wimp_get_wind_state( (globals->panes_store)[style_level]->handle,  &pane_posn ) );
           if (pane_posn.o.behind == e->data.o.behind)
               e->data.o.behind = (globals->panes_store)[typeface_level]->handle;

/* Open the tool window */
           wimpt_noerr( wimp_open_wind(&(e->data.o)) );

/* Get the state of the tool window, to see its new coordinates */
           wimpt_noerr( wimp_get_wind_state( e->data.o.w, (wimp_wstate *) &(e->data.o)) );

/* If opened behind the rearmost pane then open the panes in their current stack positions, else
  at the correct level (as passed in by the OPEN event) */
           if (e->data.o.behind == (globals->panes_store)[typeface_level]->handle)
               e->data.o.behind = (globals->panes_store)[style_level]->handle;
           x_offset = e->data.o.box.x0 - e->data.o.x;
           y_offset = e->data.o.box.y1 - e->data.o.y;
           wimpt_noerr( reopen_subwindow( e->data.o.behind,                    (globals->panes_store)[style_level]->handle,    x_offset, y_offset, style_icon ) );
           wimpt_noerr( reopen_subwindow( (globals->panes_store)[style_level]->handle,     (globals->panes_store)[weight_level]->handle,   x_offset, y_offset, weight_icon ) );
           wimpt_noerr( reopen_subwindow( (globals->panes_store)[weight_level]->handle,    (globals->panes_store)[typeface_level]->handle, x_offset, y_offset, typeface_icon ) );
           break;


       case wimp_ECLOSE:
/* Close the panes and then the dbox - that order is important for redraw optimisation */
           fontselect_closewindows();
           break;


       case wimp_EKEY:
/* Handle key presses which we know about */
           switch (e->data.key.chcode)
           {
               case 0x18f:
                   which_block.window = e->data.key.c.w ;
                   which_block.bit_mask = wimp_IBTYPE*0xf;
                   which_block.bit_set  = wimp_IBTYPE*0xf;
                   wimp_which_icon( &which_block, data );
                   for (i=0;(data[i]<e->data.key.c.i) && (data[i]!=-1); i++ );
                   if ( i>0 )
                   {
                       e->data.key.c.i = data[i-1];
                       e->data.key.c.x = 1<<20;
                       e->data.key.c.index = -1;
                       e->data.key.c.height = -1;
                       wimp_set_caret_pos( &(e->data.key.c) );
                       break;
                   }
                   break;
               case 0x18e:
                   which_block.window = e->data.key.c.w ;
                   which_block.bit_mask = wimp_IBTYPE*0xf;
                   which_block.bit_set  = wimp_IBTYPE*0xf;
                   wimp_which_icon( &which_block, data );
                   for (i=0;(data[i]<e->data.key.c.i) && (data[i]!=-1); i++ );
                   if ( (data[i]!=-1) && (data[i+1]!=-1) )
                   {
                       e->data.key.c.i = data[i+1];
                       e->data.key.c.x = 1<<20;
                       e->data.key.c.index = -1;
                       e->data.key.c.height = -1;
                       wimp_set_caret_pos( &(e->data.key.c) );
                       break;
                   }
                   break;
               default:
                   if ((*unknown_icon_routine)( font_name, globals->start_width, globals->start_height, e ))
                       fontselect_closewindows();
                   break;
           }
           break;


/* Handle button presses */
       case wimp_EBUT:
/* Check for 'set point size' icons */
           wimpt_noerr( wimp_get_icon_info( e->data.but.m.w, e->data.but.m.i, &icon_block ));
           if ( (icon_block.flags & (wimp_IESG*0x1f) ) == (wimp_IESG * 0x3) )
           {
               i = read_int( e->data.but.m.i );
               set_int( width_icon,  i );
               set_int( height_icon, i );
           }
           else
           {
               if ((e->data.but.m.bbits & wimp_BMID) == 0 )
               {
                   switch (e->data.but.m.i)
                   {
                       case cancel_icon:
                           (globals->panes_store)[typeface_level]->selection = globals->start_typeface_selection;
                           (globals->panes_store)[weight_level]->selection   = globals->start_weight_selection;
                           (globals->panes_store)[style_level]->selection    = globals->start_style_selection;
                           set_window_states( typeface_level );
                           set_float( width_icon, globals->start_width );
                           set_float( height_icon, globals->start_height );
                           read_font_name( font_name );
                           if ((*unknown_icon_routine)( font_name, globals->start_width, globals->start_height, e ))
                               fontselect_closewindows();
                           break;
                       case try_icon:
                           set_test_font_style( font_text_icon );
                           break;
                       case width_up_icon:
                           if (e->data.but.m.bbits & wimp_BRIGHT)
                               add_to_width( -1.0 );
                           else
                               add_to_width( 1.0 );
                           break;
                       case width_down_icon:
                           if (e->data.but.m.bbits & wimp_BRIGHT)
                               add_to_width( 1.0 );
                           else
                               add_to_width( -1.0 );
                           break;
                       case height_up_icon:
                           if (e->data.but.m.bbits & wimp_BRIGHT)
                               add_to_height( -1.0 );
                           else
                               add_to_height( 1.0 );
                           break;
                       case height_down_icon:
                           if (e->data.but.m.bbits & wimp_BRIGHT)
                               add_to_height( 1.0 );
                           else
                               add_to_height( -1.0 );
                           break;
                       default:
                           read_font_name( font_name );
                           if ((*unknown_icon_routine)( font_name, read_int(width_icon), read_int(height_icon), e ))
                               fontselect_closewindows();
                           break;
                   }
               }
           }
           break;
       case wimp_ESEND:
       case wimp_ESENDWANTACK:
           switch (e->data.msg.hdr.action)
           {
               case wimp_MHELPREQUEST:
                   if (e->data.msg.data.helprequest.m.i <= try_icon)
                   {
                       sprintf(buf,"FNTSELI%02d:\x01",e->data.msg.data.helprequest.m.i);
                       chr_ptr=msgs_lookup(buf);
                       if (*chr_ptr==1)
                           chr_ptr=msgs_lookup("FNTSELIZZ");
                       help_reply( e, chr_ptr );
                   }
                   else
                   {
                       wimp_get_icon_info( globals->font_window_handle, e->data.msg.data.helprequest.m.i, &icon_block );
                       if ( (icon_block.flags & (wimp_IESG*0x1f) ) == (wimp_IESG * 0x3) )
                       {
                           i = read_int( e->data.msg.data.helprequest.m.i );
                           sprintf(buf,msgs_lookup("FNTSELPNT"),i);
                           help_reply( e, buf );
                       }
                       else
                       {
                           read_font_name( buf );
                           if ((*unknown_icon_routine)( buf, read_int(width_icon), read_int(height_icon), e ))
                               fontselect_closewindows();
                       }
                   }
                   break;
           }
           break;
       default:
           read_font_name( font_name );
           if ((*unknown_icon_routine)( font_name, read_int(width_icon), read_int(height_icon), e ))
               fontselect_closewindows();
           break;
   }
}

/* ------------------------------------------------------------- */
/* Subwindow handler */
/* ------------------------------------------------------------- */
static void subwindow_process( wimp_eventstr *e, void *handle)
{
   int             i;
   pane_block      *pane_handle = (pane_block *) handle;
   char            buf[256];
   char            buf2[256];
   wimp_icon       icon_block;

   switch (e->e)
   {
      case wimp_EOPEN:
          wimpt_noerr( wimp_open_wind(&(e->data.o)) );
          break;
      case wimp_EBUT:
          if (( e->data.but.m.bbits & wimp_BMID) == 0)
          {
              if ( (i=radio_button( e->data.but.m.w, e->data.but.m.i, font_pane_esg ) ) != -1)
              {
                  pane_handle->selection = i;
                  set_window_states( pane_handle->level + 1 );
              }
          }
          break;
      case wimp_ESEND:
      case wimp_ESENDWANTACK:
          switch (e->data.msg.hdr.action)
          {
              case wimp_MHELPREQUEST:
                  wimp_get_icon_info( e->data.msg.data.helprequest.m.w, e->data.msg.data.helprequest.m.i, &icon_block );
                  sprintf(buf, "FNTSELW%d", pane_handle->level );
                  sprintf(buf2, msgs_lookup(buf), icon_block.data.indirecttext.buffer );
                  help_reply( e, buf2 );
                  break;
          }
      default:
          break;
   }
}



/* ------------------------------------------------------------- */
/* Handle buttons in true RADIO style */
/* ------------------------------------------------------------- */
wimp_i radio_button( wimp_w window, wimp_i icon, int esg )
{
   wimp_which_block        search;
   wimp_i                  results[23];

   search.window = window;
   search.bit_mask = (wimp_IESG * 0x1f) | wimp_ISELECTED;
   search.bit_set  = (wimp_IESG * esg) | wimp_ISELECTED;
   wimpt_noerr(wimp_which_icon( &search, results ));
   if ((results[0] == icon) || (results[0]==-1) || (icon==-1))
   {
       return (wimp_i) -1;
   }
   wimpt_noerr( wimp_set_icon_state( window, results[0], 0,              wimp_ISELECTED ) );
   wimpt_noerr( wimp_set_icon_state( window, icon,       wimp_ISELECTED, wimp_ISELECTED ) );
   return icon;
}



/* ------------------------------------------------------------- */
/* Find the font entry at a certain level of the font tree */
/* ------------------------------------------------------------- */
int font_find_in_tree( fontlist_node **font_ptr, char **font_name, BOOL flag, int level )
{
   int     i,j=0;

   while (*font_ptr!=NULL)
   {
      for (i=0;( ( (*font_name)[i]!='\0' ) && ( (*font_name)[i] == (*font_ptr)->name[i] ) ); i++);
      if ((*font_ptr)->name[i]=='\0')
      {
         if ( ( (*font_name)[i]!='.' ) || (level != style_level) )
         {
            if ( (*font_name)[i]=='.' )
            {
               *font_name += i+1;
               if (flag)
                   return j+1;
               else
                   return j;
            }
            if ( (*font_name)[i]=='\0' )
            {
               *font_name += i;
               if (flag)
                   return j+1;
               else
                   return j;
            }
         }
      }
      j++;
      *font_ptr = (*font_ptr) -> brother;
   }
   return 0;
}



/* ------------------------------------------------------------- */
/* Read the name of the font in the windows */
/* ------------------------------------------------------------- */
void read_font_name( char *font_name )
{
   int     i,j=0;
   wimp_icon       icon_block;

   font_name[0] = '\0';
   for (i=typeface_level;i<=style_level;i++)
   {
      wimpt_noerr( wimp_get_icon_info( (globals->panes_store)[i]->handle, (globals->panes_store)[i]->selection, &icon_block ) );
      if ( strcmp(icon_block.data.indirecttext.buffer, null_entry_text) == 0)
          break;
      if (j!=0)
          font_name[j++]='.';
      strcpy( &font_name[j], icon_block.data.indirecttext.buffer );
      j += strlen( icon_block.data.indirecttext.buffer );
   }
}



/* ------------------------------------------------------------- */
/* Set up the anti-aliased font for the test icon */
/* ------------------------------------------------------------- */
void set_test_font_style( wimp_i icon )
{
   wimp_caretstr   caret_block;
   os_error        *error;
   double          width, height;
   char            font_name[40];

   read_font_name( font_name );

   width = read_int(width_icon);
   height = read_int(height_icon);

   if (globals->font_handle!=-1)
       font_lose(globals->font_handle);

   error = font_find( font_name,(int)(width*16),(int)(height*16),0,0,&globals->font_handle);
   if (error==NULL)
       wimpt_noerr( wimp_set_icon_state( globals->font_window_handle, icon,
                       wimp_IFONT | (globals->font_handle * wimp_IFORECOL), wimp_IFONT | (0xff * wimp_IFORECOL) ) );
   else
   {
      wimpt_noerr( wimp_set_icon_state( globals->font_window_handle, icon,
                      0x07 * wimp_IFORECOL, wimp_IFONT | (0xff * wimp_IFORECOL) ) );
      globals->font_handle = -1;
   }
   wimpt_noerr( wimp_get_caret_pos( &caret_block ) );
   caret_block.height = -1;
   wimpt_noerr( wimp_set_caret_pos( &caret_block ) );
}



/* ------------------------------------------------------------- */
/* Count the maximum number of entries in typeface, weight and style */
/* ------------------------------------------------------------- */
void count_max_font_entries( int *no_icons, int level, fontlist_node *font_ptr )
{
   int i=1;

   while (font_ptr!=NULL)
   {
       i++;
       count_max_font_entries( no_icons, level+1, font_ptr->son );
       font_ptr = font_ptr -> brother;
   }
   if ( i>no_icons[level] )
       no_icons[level] = i;
}



/* ------------------------------------------------------------- */
/* The main font selector initialisation routine */
/* ------------------------------------------------------------- */
extern BOOL fontselect_init( void )
{
   int i, no_icons[3];

   /* List the fonts. If we get an error then return */
   if (fontlist_list_all_fonts(TRUE) == NULL)
       return FALSE;

   /* Grab global workspace */
   if ( ( globals = (global_data *)malloc( 3*sizeof(global_data) ) ) == NULL )
   {
       werr(0, "Out of memory for allocating global data for font selector" );
       return FALSE;
   }

   /* Grab the space for the panes' data */
   for (i=0;i<3;no_icons[i++]=1);
   count_max_font_entries( no_icons, typeface_level, font__tree );

   for  (i=typeface_level; i<=style_level; i++)
   {
       if ( ( (globals->panes_store)[i] = (pane_block *)malloc( sizeof(pane_block) + no_icons[i]*max_font_length ) ) == NULL )
       {
           werr(0, "Out of memory for allocating panes" );
           return FALSE;
       }
       (globals->panes_store)[i]->handle = -1;
       (globals->panes_store)[i]->selection = 0;
       (globals->panes_store)[i]->no_icons = no_icons[i];
   }

   /* Initialisation complete */
   globals->font_window_handle = -1;
   return TRUE;
}



/* ------------------------------------------------------------- */
/* Main font selector routine */
/* ------------------------------------------------------------- */
extern wimp_w fontselect_selector( char *title, int flags, char *font_name, double width, double height, fontselect_fn unknown_icon_routine )
{
   BOOL            flag;
   fontlist_node   *font_ptr;

   /* Check they have already called font_selector_init */
   if (globals == NULL)
   {
       werr(TRUE, "FontSel01:Must call font_selector_init before font_selector");
       return FALSE;
   }

   /* Set the initial font */
   if (flags & fontselect_SETFONT)
   {
      (globals->panes_store)[typeface_level]->selection = 0;
      (globals->panes_store)[weight_level]->selection   = 0;
      (globals->panes_store)[style_level]->selection    = 0;
      font_ptr = font__tree;
      if ((font_name!=NULL) && (font_ptr!=NULL))
      {
         (globals->panes_store)[typeface_level]->selection = font_find_in_tree( &font_ptr, &font_name, FALSE, typeface_level );
         if (font_ptr!=NULL)
         {
            flag = font_ptr -> flag;
            font_ptr = font_ptr->son;
            (globals->panes_store)[weight_level]->selection   = font_find_in_tree( &font_ptr, &font_name, flag, weight_level );
            if (font_ptr!=NULL)
            {
               flag = font_ptr -> flag;
               font_ptr = font_ptr->son;
               (globals->panes_store)[style_level]->selection    = font_find_in_tree( &font_ptr, &font_name, flag, style_level );
            }
         }
      }
   }

   /* Open the windows */
   if (globals->font_window_handle==-1)
   {
      if (flags & fontselect_REOPEN)
          return FALSE;
      if (!display_font_windows( unknown_icon_routine ))
          return FALSE;
   }

   /* Retitle the window */
   if (flags & fontselect_SETTITLE)
       win_settitle( globals->font_window_handle, title );

   set_window_states( typeface_level );

   globals->start_width = width;
   globals->start_height = height;
   globals->start_typeface_selection = (globals->panes_store)[typeface_level]->selection;
   globals->start_weight_selection   = (globals->panes_store)[weight_level]->selection;
   globals->start_style_selection    = (globals->panes_store)[style_level]->selection;

   /* Set up the correct font for the icon */
   set_float( width_icon, width );
   set_float( height_icon, height );
   set_test_font_style( font_text_icon );

   return globals->font_window_handle;
}




/* ------------------------------------------------------------- */
/* Attach menu to the font selector windows */
/* ------------------------------------------------------------- */
extern BOOL fontselect_attach_menu( menu mn, event_menu_proc menu_processor, void *handle )
{
    if ( (globals!=NULL) && (globals->font_window_handle != -1) )
        if ( event_attachmenu( globals->font_window_handle, mn, menu_processor, handle ) )
            if ( event_attachmenu( (globals->panes_store)[typeface_level]->handle, mn, menu_processor, handle ) )
                if ( event_attachmenu( (globals->panes_store)[weight_level]->handle, mn, menu_processor, handle ) )
                    if ( event_attachmenu( (globals->panes_store)[style_level]->handle, mn, menu_processor, handle ) )
                        return TRUE;
    return FALSE;
}

#endif /* UROM */
