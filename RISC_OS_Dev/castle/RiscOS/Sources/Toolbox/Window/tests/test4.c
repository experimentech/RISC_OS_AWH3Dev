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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"



#include "<Toolbox$Common>.const.h"
#include "<Toolbox$Common>.macros.h"
#include "<Toolbox$Common>.services.h"
#include "<Toolbox$Common>.debug.h"
#include "<Toolbox$Common>.mem.h"
#include "<Toolbox$Common>.wimp.h"
#include "<Toolbox$Common>.style.h"
#include "<Toolbox$Common>.string32.h"
#include "<Toolbox$Common>.objects.toolbox.h"
#include "<Toolbox$Common>.objects.menu.h"
#include "<Toolbox$Common>.objects.iconbar.h"
#include "<Toolbox$Common>.objects.window.h"


wimp_PollBlock  blk;
IDBlock idblk;
int  fd[4];
int  tbevent[64];


/* In order to avoid linking in headers from the program being tested ... */

#define TEMPLATE_MENUFLAGS_GENERATE_EVENT 0x00000001
#define TEMPLATE_MENUFLAGS_TICK           0x00000001
#define TEMPLATE_MENUFLAGS_DOTTED_LINE    0x00000002
#define TEMPLATE_MENUFLAGS_FADED          0x00000100
#define TEMPLATE_MENUFLAGS_SPRITE         0x00000200
#define TEMPLATE_MENUFLAGS_SUBMENU        0x00000400

#define object_FCREATE_ON_LOAD            0x00000001
#define object_FSHOW_ON_CREATE            0x00000002
#define object_FSHARED                    0x00000004
#define object_FANCESTOR                  0x00000008


static MenuTemplateHeader header = {TEMPLATE_MENUFLAGS_GENERATE_EVENT, "WindowTest", 11, "WindowTest Main Menu", 21, 1};


static MenuTemplateEntry entry0 = {
      0,
      0,
      "Quit",
      5,
      NULL,
      NULL,
      NULL,
      1234,
      "Click to quit Window Test",
      sizeof "Click to quit Window Test"+1
   };

static struct testmenu
{
        MenuTemplateHeader  hdr;   /* in struct to get contiguity of memory */
        MenuTemplateEntry   entries[1];
} mt;

static ObjectTemplateHeader obj_temp_hdr_m = {
   Menu_ObjectClass,
   object_FCREATE_ON_LOAD,
   100,
   "WindowTest",
   sizeof mt + sizeof (ObjectTemplateHeader),
   NULL,
   (void *) 0,
   sizeof mt
};


static IconbarTemplate t = {   Iconbar_HasText | Iconbar_GenerateSelectAboutToBeShown,
                               -1,
                               0,
                               "letter",
                               sizeof ("letter")+1,
                               "foo",
                               6,
                               0,
                               0,
                               0,
                               0,
                               0,
                               "This is a test application for the toolbox.",
                               sizeof ("This is a test application for the toolbox.")+1
                             };

static ObjectTemplateHeader hdr = {0x82900,
                                   3,   /* autoshow/autocreate */
                                   100,
                                   "iconbar",
                                   sizeof t + sizeof (ObjectTemplateHeader),
                                   NULL,
                                   (void *)0,   /* cheat */
                                   sizeof (t)};


static WindowTemplate wt = {Window_AutoOpen|Window_AutoClose,
                            "This is a window",
                            sizeof "This is a window" + 1,
                            "crosshairs",
                            sizeof "crosshairs" + 1,
                            8,
                            4,
                            NULL,
                            0,
                            NULL,
                            0,
                            NULL,
                            {
                                {400, 300, 1200, 900},   /* box */
                                0,   /* scx */
                                0,   /* scy */
                                -1,  /* behind */
                                wimp_WINDOWFLAGS_MOVEABLE|
                                wimp_WINDOWFLAGS_AUTOREDRAW|
                                wimp_WINDOWFLAGS_AUTOREPEAT_SCROLL_REQUEST|   /* flags */
                                wimp_WINDOWFLAGS_HAS_BACK_ICON|
                                wimp_WINDOWFLAGS_HAS_CLOSE_ICON|
                                wimp_WINDOWFLAGS_HAS_TITLE_BAR|
                                wimp_WINDOWFLAGS_HAS_TOGGLE_ICON|
                                wimp_WINDOWFLAGS_HAS_VSCROLLBAR|
                                wimp_WINDOWFLAGS_HAS_ADJUST_SIZE_ICON|
                                wimp_WINDOWFLAGS_HAS_HSCROLLBAR|
                                wimp_WINDOWFLAGS_USE_NEW_FLAGS,
                                {'\x07','\x02','\x00','\x01','\x03','\x01','\x0c','\x00'},
                                {0, -1000, 1000, 0},   /* ex */
                                wimp_ICONFLAGS_TEXT|
                                wimp_ICONFLAGS_HCENTRE|
                                wimp_ICONFLAGS_VCENTRE|
                                wimp_ICONFLAGS_INDIRECT, /* title_flags */
                                wimp_BUTTON_NEVER,       /* work area flags */
                                NULL,                    /* sprite area */
                                0,                       /* min_size */
                                {0},                     /* title data - fix up later */
                                0                        /* nicons */
                            }
                           };

static ObjectTemplateHeader whdr = {Window_ObjectClass,
                                    object_FCREATE_ON_LOAD,
                                   100,
                                   "window1",
                                   sizeof wt + sizeof (ObjectTemplateHeader),
                                   NULL,
                                   (void *)0,   /* cheat */
                                   sizeof (wt)};

#include "test4.h"

static void report (int num, char *message, char *extra)
{
    _kernel_oserror e;
    _kernel_swi_regs regs;

    e.errnum = num;
    sprintf (e.errmess, "%s: %s", extra, message);

    regs.r[0] = (int)&e;
    regs.r[1] = 0;
    regs.r[2] = (int)"foo";
    _kernel_swi (Wimp_ReportError, &regs, &regs);
}


int main()
{
  _kernel_swi_regs r;
  _kernel_oserror *e;
  ObjectID icon_id = 0, menu_id = 0, window_id = 0, window_id_from_template = 0;
  int gadget_id, action_gadget_id, loop, wfid1, wfid2 ;
  void *sprite_area ;
  int group_number = 0 ;

  debug_set_var_name ("test4$debug") ;

  /* fix up window title data */
  wt.window.title.indirect_text.buffer = "Window Title";
  wt.window.title.indirect_text.valid_string = NULL;
  wt.window.title.indirect_text.buff_len = sizeof "Window Title" + 1;

  wt.num_gadgets = 0 ;
  wt.gadgets = NULL ;

  /* Menu template ... */

  mt.hdr        = header;
  mt.entries[0] = entry0;

  r.r[0] = 0;
  r.r[1] = 310;
  r.r[2] = r.r[3] = 0;
  r.r[4] = (int)"<test4$dir>";
  r.r[5] = (int)fd;
  r.r[6] = (int)&idblk;
  if ((e = _kernel_swi(Toolbox_Initialise, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "Toolbox_Initialise");

  wt.window.sprite_area = sprite_area = (void *) r.r[2] ;

  /*
   * set up an iconbar,menu and window object template hdr.
   */

  hdr.body = (void *)&t;
  obj_temp_hdr_m.body = (void *)&mt;
  whdr.body = (void *)&wt;

  /*
   * create objects
   */

  r.r[0] = 1;  /* create from memory block */
  r.r[1] = (int)&hdr;
  if ((e = _kernel_swi (Toolbox_CreateObject, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "iconbar Toolbox_ObjectCreate");
  else
      icon_id = (ObjectID)r.r[0];

  r.r[0] = 1;  /* create from memory block */
  r.r[1] = (int)&obj_temp_hdr_m;
  if ((e = _kernel_swi (Toolbox_CreateObject, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "menu Toolbox_ObjectCreate");
  else
      menu_id = (ObjectID)r.r[0];

  r.r[0] = 1;  /* create from memory block */
  r.r[1] = (int)&whdr;
  if ((e = _kernel_swi (Toolbox_CreateObject, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "window Toolbox_ObjectCreate");
  else
      window_id = (ObjectID)r.r[0];

  r.r[0] = 0 ;  /* create from template */
  r.r[1] = (int)"window";
  if ((e = _kernel_swi (Toolbox_CreateObject, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "res Toolbox_ObjectCreate (should fail)");
  else
      window_id_from_template = (ObjectID)r.r[0];



  /* attach menu to iconbar icon */

  r.r[0] = 0;
  r.r[1] = (int)icon_id;
  r.r[2] = Iconbar_SetMenu;
  r.r[3] = (int)menu_id;
  if ((e = _kernel_swi (Toolbox_ObjectMiscOp, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "Toolbox_ObjectMiscOp, Iconbar_SetMenu");

  /* attach window to iconbar icon */

  r.r[0] = Iconbar_SetShow_Select;
  r.r[1] = (int)icon_id;
  r.r[2] = Iconbar_SetShow;
  r.r[3] = (int)window_id;
  if ((e = _kernel_swi (Toolbox_ObjectMiscOp, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "Toolbox_ObjectMiscOp, Iconbar_SetShow");

  /* attach menu to window */

  r.r[0] = 0;
  r.r[1] = (int)window_id;
  r.r[2] = Window_SetMenu;
  r.r[3] = (int)menu_id;
  if ((e = _kernel_swi (Toolbox_ObjectMiscOp, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "Toolbox_ObjectMiscOp, Window_SetMenu");

  /* set window's title */

  r.r[0] = 0;
  r.r[1] = (int)window_id;
  r.r[2] = Window_SetTitle;
  r.r[3] = (int)"New Title";
  if ((e = _kernel_swi (Toolbox_ObjectMiscOp, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "Toolbox_ObjectMiscOp, Window_SetTitle");

  /*
   * Now add gadgets from header...
   */

  for (loop = 0; loop < MAX_TEST_GADGETS; loop++)
  {
    switch (gadgets[loop].hdr.type)
    {
      case 0:
      {
        gadgets[loop].data.action_button.text = ACTION_BUTTON_TEXT ;
        gadgets[loop].data.action_button.max_text_len = ACTION_BUTTON_TEXTLEN ;
        gadgets[loop].data.action_button.click_show = NULL ;
        gadgets[loop].data.action_button.event = -1 ;
        break ;
      }
      case 1:
      {
        gadgets[loop].data.option_button.label = OPTION_BUTTON_TEXT ;
        gadgets[loop].data.option_button.max_label_len = OPTION_BUTTON_TEXTLEN ;
        gadgets[loop].data.option_button.event = -1 ;
        break ;
      }
      case 2:
      {
        if (gadgets[loop].hdr.flags & LabelledBox_Sprite)
          gadgets[loop].data.labelled_box.label = "medusa" ;
        else
          gadgets[loop].data.labelled_box.label = LABELLED_BOX_TEXT ;
        break ;
      }
      case 3:
      {
        gadgets[loop].data.label.label = LABEL_TEXT ;
        break ;
      }
      case 4:
      {
        gadgets[loop].data.radio_button.label = RADIO_BUTTON_TEXT ;
        gadgets[loop].data.radio_button.max_label_len = RADIO_BUTTON_TEXTLEN ;
        gadgets[loop].data.radio_button.event = -1 ;
        gadgets[loop].data.radio_button.group_number = group_number / 6 ;
        group_number++ ;
        break ;
      }
      case 5:
      {
        gadgets[loop].data.display_field.text = DISPLAY_FIELD_TEXT ;
        gadgets[loop].data.display_field.max_text_len = DISPLAY_FIELD_TEXTLEN ;
        break ;
      }
      case 6:
      {
        gadgets[loop].data.writable_field.text = WRITABLE_FIELD_TEXT ;
        gadgets[loop].data.writable_field.max_text_len = WRITABLE_FIELD_TEXTLEN ;
        gadgets[loop].data.writable_field.allowable = WRITABLE_FIELD_ALLOWABLE ;
        gadgets[loop].data.writable_field.before = -1 ;
        gadgets[loop].data.writable_field.after = -1 ;
        break ;
      }
    }
    r.r[0] = 0 ;
    r.r[1] = (int) window_id ;
    r.r[2] = Window_AddGadget ;
    r.r[3] = (int) &gadgets[loop] ;
    if ((e = _kernel_swi (Toolbox_ObjectMiscOp, &r, &r)) != NULL)
      report (e->errnum, e->errmess, "Window_AddGadget in loop");
  }

  while (1)
  {
    r.r[0] = 0;
    r.r[1] = (int)&blk;
    if ((e = _kernel_swi (Wimp_Poll, &r, &r)) != NULL)
     report (e->errnum, e->errmess, "Wimp_Poll");

    if ((r.r[0] == wimp_ESEND || r.r[0] == wimp_ESEND_WANT_ACK) && blk.msg.hdr.action == 0)
      exit(0);

    if (r.r[0] == wimp_ENULL)
      ;
    else if (r.r[0] == wimp_EKEY)
    {
      r.r[0] = blk.key_pressed.key_code ;
      if ((e = _kernel_swi (Wimp_ProcessKey, &r, &r)) != NULL)
        report (e->errnum, e->errmess, "Wimp_ProcessKey");

    }
    else if (r.r[0] == wimp_ETOOLBOX_EVENT)
    {
      switch (blk.toolbox_event.hdr.event_code)
      {
        case Toolbox_Error:
        {
          ToolboxErrorEvent *event = (ToolboxErrorEvent *)&blk.toolbox_event;
          report (event->errnum, event->errmess, "toolbox error message");
        }
        break;

        case DisplayField_ValueChanged:
        {
          DEBUG debug_output ("test4", "Received toolbox event DisplayField_ValueChanged (%s)\n\r",
                              (char *) &blk.toolbox_event.data.words[1]) ;
        }
        break ;

        case WritableField_ValueChanged:
        {
          DEBUG debug_output ("test4", "Received toolbox event WritableField_ValueChanged (%s)\n\r",
                              (char *) &blk.toolbox_event.data.words[1]) ;
        }
        break ;

        case ActionButton_Selected:
        {
          DEBUG debug_output ("test4", "Received toolbox event ActionButton_Selected (%d)\n\r",
                              blk.toolbox_event.data.words[0]) ;
        }
        break ;

        case OptionButton_StateChanged:
        {
          DEBUG debug_output ("test4", "Received toolbox event OptionButton_StateChanged (%d %d)\n\r",
                              blk.toolbox_event.data.words[0], blk.toolbox_event.data.words[1]) ;
        }
        break ;

        case RadioButton_StateChanged:
        {
          DEBUG debug_output ("test4", "Received toolbox event RadioButton_StateChanged (%d %d)\n\r",
                              blk.toolbox_event.data.words[0], blk.toolbox_event.data.words[1]) ;
        }
        break ;

/*
        case Toolbox_ObjectCreated:
        {
          DEBUG debug_output ("test4", "Received toolbox event ObjectAutoCreated %s\n\r",
                              (char *) &blk.toolbox_event.data.words[1]) ;
        }
 */
        case Iconbar_Clicked:
        {
          IconbarClickedEvent *event = (IconbarClickedEvent *)&blk.toolbox_event;
          if (event->flags & Iconbar_Clicked_Adjust)
          {
            r.r[0] = 0 ;
            r.r[1] = (int) window_id ;
            r.r[2] = OptionButton_GetState ;
            r.r[3] = gadget_id ;
            if ((e = _kernel_swi (Toolbox_ObjectMiscOp, &r, &r)) != NULL)
                report (e->errnum, e->errmess, "Toolbox_ObjectMiscOp, OptionButton_GetState");

      	    r.r[4] = r.r[0] ? 0 : 1 ;
      	    r.r[0] = 0 ;
      	    r.r[1] = (int) window_id ;
      	    r.r[2] = OptionButton_SetState ;
      	    r.r[3] = gadget_id ;
            if ((e = _kernel_swi (Toolbox_ObjectMiscOp, &r, &r)) != NULL)
                report (e->errnum, e->errmess, "Toolbox_ObjectMiscOp, OptionButton_SetState");
          }
        }
        break;


        case 1234:
          exit(0);
          break;

        default:
          DEBUG debug_output ("test4", "Got event %d\n\r") ;
          break ;

      } /* Switch */
    } /* if */
  } /* While */
}
