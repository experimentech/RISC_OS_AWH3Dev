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
/*
     Control the Filer's action window.

This code compiles into a relocatable module which controls the Filer's
action window.

0.00  08-May-89  JSR  Copied from allfiles - a 'list all files matching
                      pattern' utility.

0.01  09-May-89  JSR  Incorporate into a wimp interface.

0.02  12-May-89  JSR  Change into being a module.

0.03  31-May-89  JSR  Change into being Filer Action Window.

0.04  20-Jun-89  JSR  First round of bug fixes:
                      Delete deletes a few before asking
                      Setting access change of title
                      Immediate display on verbose
                      Force verbose on count
                      Implement copy Local
                      Implement FilerControlAction
                      Handle pre-quit message
                      Change button name Quiet instead of Quick
                      Add stamp option
                      Return directories when copying to ensure
                         access etc gets set for them
                      Init dboxquery for quit handling

0.05  29-Jun-89  JSR  Bug fixes from FilerAct 0.01 release:
                      Restart does not quit before writing out
                         reread stuff.
                      Handle help requests

0.06  04-Jul-89  JSR  Remove const from strings.
                      Do unsigned comparison of low 4 bytes of date stamp.

0.07  29-Sep-89  JSR  Use overflowing_ memory allocation routines.
                      Treat directories as being unstamped.
                      Set time for doing doings to be twice that time
                         already taken to do one doing, bounded to between
                         Minimum_Doings_Time and Maximum_Doings_Time
                      If an error happened when setting the access to enable
                         a delete which failed, then report the access setting
                         error, not the delete error.
                      Make the top progress field keep up with the info field
                         better when writing.
                      Use standard module application generating wrapper to fix
                         ctrl-shft-f12 bug.
                      Display a summary of what was counted.
                      Add find file.
                      Fix handling of translation of rename into a copy-move for the
                         first directory.
                      Extend the functionality of copylocal to cope with non-leaf
                         destinations.
                      Adjust meaning of set access to allow 'leave alone' on access bits
0.08  16-Oct-89  JSR  Correct setting of bottom info field to not overflow its fixed buffer
                         when a long leaf name is encountered.
                      Correct error handling so that skip is present.
                      Reporting of locked errors whilst deleting improved.
                      Only allow found directories to be opened.
                      Only wimpt_complain on the first disc full.
0.09  19-Oct-89  JSR  Don't switch to Open buttons when found directory is an application.
                      Add control_action 2 to hide an operation
                      Verbose applies to count
                      Set window titles to conform to RISC_OS style.
0.10  13-Nov-89  JSR  Ensure overflowing_free is used when next_nodename is used.
                      Internationalise the text.
0.11  17-Nov-89  JSR  Declare action_environment as being file global in scope. Previously
                         the declaration of the function type button_function was assumed
                         to do this, but it doesn't.
                      Split into several parts.
                      Fix bug whereby in set_bottom_info_field a small poo was purpetrated
                         as the nul string terminator overflowed newfield.
0.12  04-Dec-89  JSR  Add the Bad_RENAME case on failed rename.
                      Relock un renamed locked files when force is on.
                      Already exists errors on renames mapped to copy-moves.
                      For NetFS owner write bit masked out on set acceses on directories (CLUDGE!).
0.13  10-Jan-90  JSR  Set the bottom info field at the end of counting as during counting.
                      Routines used locally only made static.
                      Set the title of the query box on a prequit message to match that of the
                         action window itself.
0.14  22-Jan-90  JSR  Inhibit delete progress if a locked file isn't deleted.
0.22  16-Aug-91  PJC  If start_operation fails, use werr rather than wimpt_noerr
0.30  05-Nov-93  SMC  No longer uses red error text in error version of filer action window.
*/

#if 0
#define debugact(k) dprintf k
#else
#define debugact(k) /* Disabled */
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <ctype.h>

#include "Global/FSNumbers.h"
#include "Interface/HighFSI.h"
#include "swis.h"

#include "os.h"
#include "akbd.h"
#include "wimp.h"
#include "wimpt.h"
#include "werr.h"
#include "win.h"
#include "res.h"
#include "resspr.h"
#include "template.h"
#include "msgs.h"
#include "event.h"
#include "dbox.h"
#include "dboxquery.h"
#include "flex.h"
#include "heap.h"
#include "bbc.h"

#include "Options.h"
#include "allerrs.h"
#include "malloc+.h"
#include "listfiles.h"
#include "memmanage.h"
#include "actionwind.h"
#include "Initialise.h"
#include "Buttons.h"
#include "debug.h"
#include "dboxlong.h" /* locally */

#define Option_FilerAction_Verbose              0x00000001
#define Option_FilerAction_Confirm              0x00000002
#define Option_FilerAction_Force                0x00000004
#define Option_FilerAction_Newer                0x00000008
#define Option_FilerAction_Recurse              0x00000010
#define Option_FilerAction_ConfirmDeletes       0x00000020 /* RML */
#define Option_FilerAction_Faster               0x00000040 /* RML */

#ifdef USE_STATUS_IN_TITLE
static char TitleString[64];
#endif
static char PathString[ Top_Info_Field_Length + 1 ];


#define FileChar_ManyAny '*'
#define FileChar_Any     '#'

#define HELP_MESSAGE_CONTROL_NOBUTTON "1"
#define HELP_MESSAGE_CONTROL          "2"


/*
     A chain link structure
*/
typedef struct chain_link
{
     struct chain_link *forwards;
     struct chain_link *backwards;

     /* somewhere to point at the structure in which this resides */
     void *wrapper;
}    chain_link;

typedef struct
{
     chain_link     link;
     char           *buffer;
}    buffer_header;

/*
     For c.modulewrap
*/
extern os_error *i_am_now_active( void );

#define No 0
#define Yes (!No)

#define SPACE ' '

#define Max_Invocation_Name_Length 20

/*
 *   Field masks for date stamping
 */
#define DateStamped_Mask                0xfff00000
#define DateStamp_HighByte              0x000000ff

/*
     Status indications
*/
action_environment env;
const char *last_top_info_field;
static clock_t doings_time = (10*CLK_TCK)/100;
static int UpdatePath = 0, UpdateTop = 0, UpdateBottom = 0;

#define Number_Of_Actions 10
#define Number_Of_Icon_Strings 5
#define Title_Text 0
#define Top_Progress_Line_Text 1
#define Bottom_Progress_Line_Text 2
#define Top_Info_Field_Text 3
#define Help_Message_Operation_Fillin 4

static char *icon_strings[ Number_Of_Actions ][ Number_Of_Icon_Strings ] =
{
  /* title        top       bottom      top info   help           action */
  /*            progress   progress                                      */
  {   "29",        "30",     "31",     "32",         "33"    },  /* copying */
  {   "34",        "30",     "35",     NULL/*36*/,   "37"    },  /* moving (renaming) */
  {   "38",        "39",     "40",     NULL/*41*/,   "42"    },  /* deleting */
  {   "43",        "44",     "45",     NULL/*46*/,   "47"    },  /* setting access */
  {   "48",        "49",     "50",     NULL/*51*/,   "52"    },  /* settype */
  {   "53",        "54",     "55",     NULL/*56*/,   "57"    },  /* count */
  {   "34",        "30",     "58",     "32",         "37"    },  /* copy/moving */
  {   "29",        "30",     "31",     "32",         "33"    },  /* copy local */
  {   "59",        "60",     "61",     NULL/*62*/,   "63"    },  /* stamp */
  {   "64",        "65",     "66",     NULL/*67*/,   "68"    }   /* find */
};


/*
   Changed this so we show everything in faster mode, except the "bytes to go"
   field in a copy operation
*/
static BOOL show_when_faster[ Number_Of_Actions ][2] =
{
        /*     top progress bottom progress                action */
        {               No,             Yes     },      /* copying */
        {               No,             Yes     },      /* moving (renaming) */
        {               Yes,            Yes     },      /* deleting */
        {               Yes,            Yes     },      /* setting access */
        {               Yes,            Yes     },      /* settype */
        {               Yes,            Yes     },      /* count */
        {               No,             Yes     },      /* copy/moving */
        {               No,             Yes     },      /* copy local */
        {               Yes,            Yes     },      /* stamp */
        {               Yes,            Yes     }       /* find */
};

static char *action_prompt[] =
{
     "69",
     "70",
     "71",
     "72",
     "73",
     "74",
     "75",
     "76",
     "77",
     "78"
};

#ifdef debug
static char *debug_operation(int op)
{
  switch (op)
  {
  case Action_Copying : return "Action_Copying";
  case Action_Moving : return "Action_Moving";
  case Action_Deleting : return "Action_Deleting";
  case Action_Setting_Access : return "Action_Setting_Access";
  case Action_Setting_Type : return "Action_Setting_Type";
  case Action_Counting : return "Action_Counting";
  case Action_CopyMoving : return "Action_CopyMoving";
  case Action_CopyLocal : return "Action_CopyLocal";
  case Action_Stamping : return "Action_Stamping";
  case Action_Finding : return "Action_Finding";
  }

  return "unknown";
}
#else
#define debug_operation(op) NULL
#endif

/* RML */
static void hide_faster_stuff( action_environment *env );

/*
     Establish a delayed switch on/off for the dbox.
     Delay is in centiseconds
*/
void switch_dbox_on_off( action_environment *env, int direction, int delay )
{
     env->time_to_boxchange = clock() + (delay * CLK_TCK)/100;
     env->boxchange_direction = direction;
}

/*
        a is wild b isn't
*/
static int caseless_wildcmp( const char *a, const char *b )
{
    int last_wildrover = -1;        /* first wild char after last wildcard */
    int last_realrover = -1;        /* first real char after wildcard in this test sequence */
    int wild_rover = 0;
    int real_rover = 0;
    int d;

    while ( (a[wild_rover] || b[real_rover]) )
    {
        switch( a[wild_rover] )
        {
        case FileChar_ManyAny:
            last_wildrover = ++wild_rover;  /* Carry on after * in wildcard string */
            last_realrover = real_rover;    /* try matching from here */
            break;

        case FileChar_Any:
            if ( !b[real_rover] )
                return a[wild_rover];

            wild_rover++;
            real_rover++;
            break;

        default:
            d = toupper( a[wild_rover] ) - toupper( b[real_rover] );
            if ( d )
            {
                if ( last_wildrover < 0 || !b[real_rover] )
                    return d;

                wild_rover = last_wildrover;    /* Restart after * in wilcard string */
                real_rover = ++last_realrover;  /* test one character on */
            }
            else
            {
                wild_rover++;
                real_rover++;
            }
            break;
        }
    }

    return 0;
}


/*
 * Prevent flicker when the filer action window is behind another window
*/
static void set_title(wimp_w handle, char *title) {
  wimp_winfo winfo;

  winfo.w = handle;
  if (_swix(Wimp_GetWindowInfo, _IN(1), ((unsigned int)&winfo) | 1) == NULL) {
    strcpy(winfo.info.title.indirecttext.buffer, title);
  }

  _swix(Wimp_ForceRedraw, _INR(0,2), handle, 0x4B534154, 3);
}


/*
   Set the status text displayed in the top field, or the title bar
*/
static void set_top_info_field_raw(action_environment *env, char *text)
{
    #ifdef USE_STATUS_IN_TITLE
    if (text != NULL)
    {
        char title[256];

        sprintf(title, "%s - %s", TitleString, text);
        set_title( env->window_handle, title );
    }
    else
    {
        set_title( env->window_handle, TitleString );
    }
    #else
    if (text == NULL) text = "";
    dbox_setfield( env->status_box, Top_Info_Field, text );
    #endif

    last_top_info_field = text;
}


/*
   Set the status text, from a token in the messages file
*/
static void set_top_info_field(action_environment *env, char *token)
{
    char *text = NULL;

    if (token != NULL && token[0] != '\0')
    {
        text = msgs_lookup( token );
    }

    set_top_info_field_raw(env, text);
}


void set_top_info_field_with_current_info(action_environment *env, char *token1, char *token2)
{

    if (env->current_info_token != NULL)
    {
        char buffer[Top_Info_Field_Length];

        strcpy(buffer, token1);
        strcat(buffer, env->current_info_token);
        sprintf(buffer, msgs_lookup(buffer), tolower(env->current_info[0]), &env->current_info[1]);

        set_top_info_field_raw(env, buffer);

    }
    else
    {
        set_top_info_field(env, token2);
    }

}


/*
    Set the content of the path display from the file name.
    We no longer split the path into two parts, as the display field has been made wider.
*/
static void set_bottom_info_field( action_environment *env, char *text )
{
    int l;

    IGNORE(env);

    if ( text == NULL )
    return;

    if ((l = strlen(text)) > Top_Info_Field_Length)
    {
        strncpy(PathString, text + l - Top_Info_Field_Length, Top_Info_Field_Length);
        PathString[Top_Info_Field_Length] = '\0';
    }
    else
    {
        strcpy(PathString, text);
    }

    UpdatePath = 1;

}


static void set_top_progress_field( action_environment *env, uint64_t value )
{
    env->top_progress = value;
    UpdateTop = 1;
}


/*
   Add a value to top progress. Instead of directly updating the icon, we set a flag
   that causes it to be updated on the next null poll.
*/
static void more_top_progress( action_environment *env, uint32_t change )
{
    env->top_progress += change;
    UpdateTop = 1;
}


/*
   Add a value to bottom progress. Instead of directly updating the icon, we set a flag
   that causes it to be updated on the next null poll.
*/
static void more_bottom_progress( action_environment *env, uint32_t change )
{
    env->bottom_progress += change;
    UpdateBottom = 1;
}


#ifdef USE_PROGRESS_BAR
/*
   Add a value to the progress indicator
*/
static void add_progress(action_environment *env, uint32_t progress, char *text)
{
    env->progress += progress;
    if (env->progress > INT32_MAX) env->progress = INT32_MAX;
    if (text != NULL)
    {
        debugact(( "%s: +%08x -> %08x\n", text, progress, env->progress ));
    }
}


/*
   Show the current progress indicator. Called on null poll events.
   The first time this is called, we calculate how much progress is represented by
   one OS unit. The Progress_Bar icon is then resized to be a proportion of the total
   size of the Progress_Bar_BBox icon.
*/
static void update_progress_bar(action_environment *env)
{
    static int ppos = 0, max = 0, last = 0;
    static wimp_icon i;
    int w, size;
    os_regset r;

    w = dbox_syshandle( env->status_box );

    if (ppos == 0)
    {
        wimp_icon b;
        if (wimp_get_icon_info(w, Progress_Bar, &i) != NULL) return;
        if (wimp_get_icon_info(w, Progress_Bar_BBox, &b) != NULL) return;
        max = b.box.x1 - b.box.x0;
        ppos = INT32_MAX / max; /* progress per os unit */
        i.box = b.box;
    }

    size = env->progress / ppos + 2;
    if (size > max) size = max;
    if (size >= last && size < last + 2)
        return; /* no change from last time */

    i.box.x1 = i.box.x0 + size;

    r.r[0] = w;
    r.r[1] = Progress_Bar;
    r.r[2] = i.box.x0;
    r.r[3] = i.box.y0;
    r.r[4] = i.box.x1;
    r.r[5] = i.box.y1;
    os_swix( Wimp_ResizeIcon, &r );

    wimp_set_icon_state(w, Progress_Bar, (wimp_iconflags)0, (wimp_iconflags)0);
    last = size;

    debugact(( "update_progress_bar: %08x -> %d / %d\n", env->progress, size, max ));
}
#endif


static void switch_box_to_error( action_environment *env, os_error *err )
{
    wimp_openstr o;
    template *tplt = template_find( MAIN_TEMPLATE_NAME );
    int xw;
    int yw;

    dbox_setfield( env->status_box, Error_Field, err->errmess );

    o.w = dbox_syshandle( env->status_box );
    o.x = -tplt->window.ex.x0;
    o.y = -tplt->window.ex.y1;
    o.box = tplt->window.ex;
    o.behind = -1;

    xw = ((bbc_modevar( -1, bbc_XWindLimit ) + 1) << bbc_modevar( -1, bbc_XEigFactor )) - bbc_vduvar( bbc_OrgX );
    yw = ((bbc_modevar( -1, bbc_YWindLimit ) + 1) << bbc_modevar( -1, bbc_YEigFactor )) - bbc_vduvar( bbc_OrgY );

    xw = xw/2 - (o.box.x1 + o.box.x0)/2;
    yw = yw/2 - (o.box.y1 + o.box.y0)/2;

    o.box.x0 += xw;
    o.box.y0 += yw;
    o.box.x1 += xw;
    o.box.y1 += yw;

    wimpt_noerr( wimp_open_wind( &o ));
}


static void switch_box_from_error( action_environment *env )
{
    wimp_wstate s;
    template *tplt = template_find( MAIN_TEMPLATE_NAME );
    int xw;
    int yw;

    wimpt_noerr( wimp_get_wind_state( dbox_syshandle( env->status_box ), &s ));

    xw = (s.o.box.x0 - s.o.x) - (tplt->window.box.x0 - tplt->window.scx);
    yw = (s.o.box.y1 - s.o.y) - (tplt->window.box.y1 - tplt->window.scy);

    s.o.x = tplt->window.scx;
    s.o.y = tplt->window.scy;
    s.o.box.x0 = tplt->window.box.x0 + xw;
    s.o.box.y0 = tplt->window.box.y0 + yw;
    s.o.box.x1 = tplt->window.box.x1 + xw;
    s.o.box.y1 = tplt->window.box.y1 + yw;

    wimpt_noerr( wimp_open_wind( &s.o ));
}


void switch_to_reading( action_environment *env )
{
    env->current_info = msgs_lookup( "32" );
    env->current_info_token = "32";

    set_bottom_info_field( env, next_file_to_be_read());

    set_top_progress_field( env, bytes_left_to_read());

    env->action = Check_Full_Reading;
}


/*
     Acknowledge a message
*/
static os_error *ack_message( wimp_eventstr *event )
{
     event->data.msg.hdr.your_ref = event->data.msg.hdr.my_ref;
     return wimp_sendmessage( wimp_EACK, &event->data.msg, event->data.msg.hdr.task );
}


static BOOL menus_greyed[ 3 ][ 5 ] =
{
        {       No,     No,     No,     No,     No },
        {       No,     No,     No,     No,     Yes },
        {       No,     Yes,    No,     Yes,    Yes }
};


typedef enum {none, name, access, type } destination_type;
typedef enum {mt_all, mt_notcopy, mt_information } menu_type;


static struct start_up_details_str
{
        int init_for_copy:1;
        destination_type dest;
        int return_dirs_last:1;
        int return_dirs_first:1;
        int recurse:1;
        int disable_flex:1;             /* stops flex being enabled later */
        int flex_now:1;                 /* is flex going now? */
        int partition_is_directory:1;   /* for listfiles - is a partition a dir or file */
        menu_type men;
}       start_up_details[ 10 ] =
{
        /*      copy    dest    last?   first?  recurse no flex flex    P==D?   menu                       action */
        {       Yes,    name,   No,     Yes,    Yes,    No,     Yes,    No,     mt_all          },      /* copying */
        {       No,     name,   No,     Yes,    No,     No,     No,     No,     mt_all          },      /* moving (rename) */
        {       No,     none,   Yes,    Yes,    Yes,    Yes,    No,     No,     mt_notcopy      },      /* deleting */
        {       No,     access, No,     Yes,    Yes,    Yes,    No,     Yes,    mt_notcopy      },      /* setting access */
        {       No,     type,   No,     Yes,    No,     Yes,    No,     No,     mt_notcopy      },      /* settype */
        {       No,     none,   No,     No,     Yes,    Yes,    No,     No,     mt_information  },      /* count */
        {       Yes,    name,   Yes,    Yes,    Yes,    No,     Yes,    No,     mt_all          },      /* copying/moving */
        {       Yes,    name,   No,     Yes,    Yes,    No,     Yes,    No,     mt_all          },      /* copy local */
        {       No,     none,   No,     Yes,    Yes,    Yes,    Yes,    Yes,    mt_notcopy      },      /* stamp */
        {       No,     name,   No,     Yes,    Yes,    Yes,    Yes,    Yes,    mt_information  }       /* find */
};

static void reflect_menu_flags( action_environment *env )
{
        menu_setflags( env->option_menu, 1, env->faster, menus_greyed[ start_up_details[ env->operation ].men ][ 0 ] );
        menu_setflags( env->option_menu, 2, env->confirm, menus_greyed[ start_up_details[ env->operation ].men ][ 1 ] );
        menu_setflags( env->option_menu, 3, env->verbose, menus_greyed[ start_up_details[ env->operation ].men ][ 2 ] );
        menu_setflags( env->option_menu, 4, env->force, menus_greyed[ start_up_details[ env->operation ].men ][ 3 ] );
        menu_setflags( env->option_menu, 5, env->looknewer, menus_greyed[ start_up_details[ env->operation ].men ][ 4 ] );
}

/*
     Operation has been specified, start doing it
*/
static os_error *start_operation( action_environment *env, actions_possible operation, int options, void *auxilliary_information )
{
    os_error *err;

    env->operation = operation;
    debugact(( "new operation: %s\n", debug_operation( env->operation ) ));

    dbox_setfield( env->status_box, Top_Progress_Line, msgs_lookup( icon_strings[ operation ][ Top_Progress_Line_Text ] ));
    dbox_setfield( env->status_box, Bottom_Progress_Line, msgs_lookup( icon_strings[ operation ][ Bottom_Progress_Line_Text ] ));

    #ifdef USE_STATUS_IN_TITLE
    strcpy(TitleString, msgs_lookup( icon_strings[ operation ][ Title_Text ] ));
    set_title( env->window_handle, TitleString );
    #else
    set_title( dbox_syshandle( env->status_box ), msgs_lookup( icon_strings[ operation ][ Title_Text ] ));
    #endif

    env->top_progress = 0;
    env->bottom_progress = 0;
    dbox_setlongnumeric( env->status_box, Top_Progress_Field, env->top_progress );
    dbox_setlongnumeric( env->status_box, Bottom_Progress_Field, env->bottom_progress );
    #ifdef USE_PROGRESS_BAR
    env->progress = 0;
    update_progress_bar(env);
    #endif

    env->faster    = No;
    env->faster_stuff_hidden = No;
    env->verbose   = (options & Option_FilerAction_Verbose) != 0;
    env->confirm   = (options & Option_FilerAction_Confirm) != 0;
    env->force     = (options & Option_FilerAction_Force) != 0;

    /* RML */
    if ((options & Option_FilerAction_ConfirmDeletes) && (operation==Action_Deleting)) env->confirm = Yes;

    if (options & Option_FilerAction_Faster)
    {
        env->faster = Yes;
        doings_time = CLK_TCK;          /* 1 second */
        hide_faster_stuff( env );
    }

    env->looknewer = (options & Option_FilerAction_Newer) != 0;

    env->disc_full_already = No;
    env->auto_skip_cvs = (getenv("Filer_Action$Skip") != NULL) ? Yes : No;

    switch_buttons( env, &abort_pause_buttons );
    set_faster_state( env );

    if ( env->verbose )
    {
        switch_dbox_on_off( env, 1, Display_Delay );
    }

    env->current_info_token = icon_strings[operation][Top_Info_Field_Text];
    if ( env->current_info_token )
    {
        env->current_info = msgs_lookup( env->current_info_token );
    }
    else
    {
        env->current_info = "";
    }

    env->action = Next_File;

    if ( start_up_details[ env->operation ].init_for_copy )
    {
        err = init_for_copying();
        if ( err )
            return err;
    }

    switch( start_up_details[ env->operation ].dest )
    {
    case none:
        break;

    case name:
        /*
                Store the destination directory somewhere useful
        */
        env->destination_name = overflowing_malloc( strlen( auxilliary_information ) + 1 );
        if ( env->destination_name == NULL )
                return error( mb_malloc_failed );
        strcpy( env->destination_name, auxilliary_information );
        break;

    case access:
        env->new_access = *(int *)auxilliary_information;
        break;

    case type:
        env->new_type = *(int *)auxilliary_information;
        debugact(( "new type is %d\n", env->new_type ));
        break;

    default:
        break;
    }

    return_directories_last( env->test_search, start_up_details[ env->operation ].return_dirs_last );
    return_directories_first( env->test_search, start_up_details[ env->operation ].return_dirs_first );
    recurse_search_context( env->test_search, start_up_details[ env->operation ].recurse );
    treat_partitions_as_directories( env->test_search, start_up_details[ env->operation ].partition_is_directory );
    env->disable_flex = start_up_details[ env->operation ].disable_flex;
    env->flex_memory = start_up_details[ env->operation ].flex_now;

    switch( env->operation )
    {

    case Action_Counting:

        err = selection_summary( env->test_search, &env->selection_summary );

        if ( err )
             return err;

            /* drop through into... */
    case Action_Finding:
        #ifndef CONFIRM_MEANS_CONFIRM_ALL
        env->confirm = No;
        #endif

            /* drop through into... */
    case Action_Stamping:
    case Action_Setting_Type:
    case Action_Copying:
    case Action_CopyLocal:
    case Action_Moving:
        break;

    case Action_Deleting:
        err = selection_summary( env->test_search, &env->selection_summary );
        if ( err )
                return err;

        env->locked_not_deleted = 0;
        break;

    case Action_Setting_Access:
        {
            os_regset r;
            char *first_nodename;

            recurse_search_context( env->test_search, (options & Option_FilerAction_Recurse) != 0 );

            env->directory_access_setting_mask = 0xffffffff;

            err = next_nodename( env->test_search, &first_nodename );

            if ( err || first_nodename == NULL )
                break;

            r.r[0] = FSControl_LookupFS;
            r.r[1] = (int) first_nodename;
            r.r[2] = 0;             /* truncate on . or : etc */

            err = os_swix( OS_FSControl, &r );

            overflowing_free( first_nodename );

            /*
                NetFS doesn't like OwnerWrite being set on directories.
            */
            if ( !err && r.r[1] == fsnumber_net )
                env->directory_access_setting_mask &= ~write_attribute;

            break;
        }

    default:
            break;
    }

    reflect_menu_flags( env );

    return NULL;
}


static void go_verbose( action_environment *env )
{
    wimp_wstate state;

    if ( wimp_get_wind_state( dbox_syshandle( env->status_box ), &state ) )
        return;

    dbox_showstatic( env->status_box );

    state.o.behind = -1;

    if ( wimp_open_wind( &state.o ) )
        return;

    env->verbose = Yes;
    env->boxchange_direction = 0;
}


/* JRF: Toggle the faster operation of the window.
        This is accessed from the Buttons.c source.
 */

void toggle_faster( action_environment *env )
{
    env->faster = !env->faster;
    copy_go_faster( env->faster );
    if ( env->faster )
    {
        doings_time = CLK_TCK;          /* 1 second */
        hide_faster_stuff( env );
    }
    else
    {
        doings_time = (10*CLK_TCK)/100; /* 1/10 second */
        show_faster_stuff( env );
    }
    menu_setflags( env->option_menu, 1, env->faster, menus_greyed[ start_up_details[ env->operation ].men ][ 0 ] );
}


static void go_terse( action_environment *env )
{
        env->verbose = No;
        env->boxchange_direction = 0;

        if ( (event_getmask() & wimp_EMNULL) == 0 )
        {
                dbox_hide( env->status_box );
        }
}

/*
     Control the action in progress
*/
static void control_action( action_environment *env, wimp_eventstr *event )
{
    switch ( event->data.msg.data.words[0] )
    {
    case 0:
        /*
           Acknowledge the message
        */
        ack_message( event );
        break;

    case 1:   /* show window and bring it to the front */
        go_verbose( env );
        break;

    case 2:   /* Turn verbose off - hide the window */
        go_terse( env );
        break;

    default:
        /*
           Do nothing implicitely
        */
        break;
    }
}


/*
     Message processor
*/
BOOL message_event_handler( wimp_eventstr *event, void *environment )
{
    action_environment *env = environment;
    BOOL processed = No;

    switch( event->e )
    {
    case wimp_ESEND:
    case wimp_ESENDWANTACK:

        processed = Yes;

        switch( event->data.msg.hdr.action )
        {
        case wimp_MPREQUIT:
            {
               /* amg 9th August 1994. Only return a C/S/F12 */
               /* if the flag word tells us that it was a shutdown */
               /* or there's no flag word at all */

                int size_of_prequit = event->data.msg.hdr.size;
                int flags_of_prequit = event->data.msg.data.words[0];
                wimp_t sender = event->data.msg.hdr.task;
                char query_message[ 150 ];

                wimpt_noerr( ack_message( event ));

                /*
                   Construct a context sensitive message for the query.
                */
                sprintf( query_message, msgs_lookup( "81" ), msgs_lookup( icon_strings[ env->operation ][ Help_Message_Operation_Fillin ] ) );

                switch( dboxquery( query_message ) )
                {
                case dboxquery_YES:
                    debugact(( "Discard selected\n" ));
                    if (!(size_of_prequit > sizeof(wimp_msghdr) && flags_of_prequit & 1))
                    {
                      wimp_get_caret_pos( &event->data.key.c );
                      event->data.key.chcode = akbd_Ctl | akbd_Sh | akbd_Fn12;
                      wimp_sendmessage( wimp_EKEY, (wimp_msgstr *)&event->data, sender );
                      debugact(( "sent message to &%x\n",sender ));
                    }
                    abort_operation( env );
                    break;

                case dboxquery_NO:
                case dboxquery_CANCEL:
                    debugact(( "Cancel selected\n" ));
                    break;
                }
            }
            break;

        case wimp_MSETSLOT:
            debugact(( "Slot(%d,%d) - T=%d\n", event->data.msg.data.words[0],event->data.msg.data.words[1], wimpt_task() ));
            if ( !env->disable_flex )
            {
                if ( event->data.msg.data.words[1] == wimpt_task() )
                {
                    if ( env->flex_memory &&
                        event->data.msg.data.words[0] >= 0 )
                    {
                        action_slot( event->data.msg.data.words[0] );
                    }

                    wimpt_noerr( ack_message( event ));
                }
                else
                {
                    processed = No;
                }
            }
            break;

        case wimp_MHELPREQUEST:
            event->data.msg.hdr.your_ref = event->data.msg.hdr.my_ref;
            event->data.msg.hdr.action = wimp_MHELPREPLY;
            event->data.msg.hdr.size = 256; /* enough for all messages */

            switch( event->data.msg.data.helprequest.m.i )
            {
            case Abort_Button:
            case No_Skip_Button:
            case Yes_Retry_Button:
            case Misc_Button:
            case Skip_Button:
                sprintf( event->data.msg.data.helpreply.text, msgs_lookup( HELP_MESSAGE_CONTROL ),
                    msgs_lookup( icon_strings[ env->operation ][ Help_Message_Operation_Fillin ] ),
                    msgs_lookup( env->button_actions.button_helps[ event->data.msg.data.helprequest.m.i - Abort_Button ] ));
                break;

            default:
                sprintf( event->data.msg.data.helpreply.text, msgs_lookup( HELP_MESSAGE_CONTROL_NOBUTTON ),
                        msgs_lookup( icon_strings[ env->operation ][ Help_Message_Operation_Fillin ] ));
                 break;
            }

            wimpt_noerr( wimp_sendmessage( wimp_ESEND, &event->data.msg, event->data.msg.hdr.task ));
            break;

        case wimp_MFilerSelectionDirectory:
            clear_selection( env->test_search );
            wimpt_noerr( set_directory( env->test_search, event->data.msg.data.chars ));
            env->source_directory_name_length = strlen( event->data.msg.data.chars );
            debugact(("MFilerSelectionDirectory: %s\n", event->data.msg.data.chars));
            break;

        #ifdef USE_LOAD_OPERATIONS
        case wimp_MDATALOAD:
                if ((env->operation != Action_Copying) &&
                    (env->operation != Action_Moving) &&
                    (env->operation != Action_Deleting) &&
                    (env->operation != Action_Setting_Access) &&
                    (env->operation != Action_Setting_Type) &&
                    (env->operation != Action_Counting) &&
                    (env->operation != Action_Stamping) )
                {
                  /* Generate some kind of error for the user to see */
                }
                else
                {
                  extern char *get_directory(search_handle);
                  char *ourdir=get_directory(env->test_search);
                  char *theirfile=event->data.msg.data.dataload.name;
                  int ourdirlen=strlen(ourdir);
                  processed=Yes;
                  if ( (strncmp(ourdir,theirfile,ourdirlen)==0) &&
                       (theirfile[ourdirlen]=='.') &&
                       (strchr(&theirfile[ourdirlen+1],'.')==NULL) )
                  { /* It's something we can use - yay! */
                    char *file= &theirfile[ourdirlen+1];
                    wimpt_noerr( add_selection( env->test_search, file, strlen(file) ) );
                  }
                }
                break;
        #endif

        case wimp_MFilerAddSelection:
            {
                char *pos;
                int wordlen;
                char *wordpos;

                /*
                   Wander over the string of selections peeling
                   them off, one at a time
                */
                for ( pos = &event->data.msg.data.chars[0];
                      *pos != '\0';
                      pos++ )
                {
                    /*
                         If we have a candidate word
                    */
                    if ( *pos != SPACE )
                    {
                        wordpos = strchr( pos, SPACE );

                        if ( wordpos == NULL )
                        {
                            wordlen = strlen( pos );
                        }
                        else
                        {
                            wordlen = wordpos - pos;
                        }

                        wimpt_noerr( add_selection( env->test_search, pos, wordlen ));


                        /*
                                pos is on the last character of the word
                        */
                        pos += wordlen - 1;
                    }
                }
            }
            break;

        case wimp_MFilerAction:
            {
                os_error *err;

                actions_possible action;
                int options;
                void *auxilliary_information;

                action = (actions_possible)event->data.msg.data.words[ 0 ];
                options = event->data.msg.data.words[ 1 ];
                auxilliary_information = &event->data.msg.data.words[ 2 ];

                err = start_operation( env, action, options, auxilliary_information );
                if (err)
                    werr(TRUE, err->errmess);
            }
            break;

        case wimp_MFilerControlAction:
            control_action( env, event );
            break;

        default:
            processed = No;
            break;
        }
        break;
    }

    return processed;
}


/*
   Because the display of fields is more efficient, we don't hide everything in faster mode
*/
static void hide_faster_stuff( action_environment *env )
{
    if ( env->faster && !env->faster_stuff_hidden )
    {
        if ( !show_when_faster[ env->operation ][ 0 ] )
            dbox_setfield( env->status_box, Top_Progress_Field, "-" );
        if ( !show_when_faster[ env->operation ][ 1 ] )
            dbox_setfield( env->status_box, Bottom_Progress_Field, "-" );

        env->faster_stuff_hidden = Yes;
        set_faster_state ( env );
    }
}


void show_faster_stuff( action_environment *env )
{
    if ( env->faster_stuff_hidden )
    {
        if ( !show_when_faster[ env->operation ][ 0 ] )
            dbox_setlongnumeric( env->status_box, Top_Progress_Field, env->top_progress );
        if ( !show_when_faster[ env->operation ][ 1 ] )
        {
            dbox_setlongnumeric( env->status_box, Bottom_Progress_Field, env->bottom_progress );
        }

        env->faster_stuff_hidden = No;

        set_faster_state( env );
    }
}


void option_menu_handler( action_environment *env, char *hit )
{
    switch( hit[0] )
    {
    case 1: /* faster */
        toggle_faster( env ); /* JRF: Now a function to aid the */
                              /* button */
        break;

    case 2: /* confirm */
        env->confirm = !env->confirm;
        break;

    case 3: /* verbose */
        if ( env->verbose )
            go_terse( env );
        else
            go_verbose( env );
        break;

    case 4: /* force */
        env->force = !env->force;
        break;

    case 5: /* newer */
        env->looknewer = !env->looknewer;
        break;

    default:
        break;
    }

    reflect_menu_flags( env );
}


void switch_to_writing( action_environment *env )
{
     env->current_info = msgs_lookup( "82" );
     env->current_info_token = "82";

     set_bottom_info_field( env, next_file_to_be_written());

     set_top_progress_field( env, bytes_left_to_write());

     env->action = Check_Empty_Writing;
}

/*
     Create the destination file name from the source
*/
static os_error *create_destination_localfile( action_environment *env, char *source, char **destination )
{
    char *sourcegunge;
    char *sourceleaf = source + env->source_directory_name_length + 1;
    char *destleaf;
    char *temp;

    /*
        This takes
        source = <source dir><source leaf><gunge>
        and
        dest = <dest dir><dest leaf>
        making
        destn = <destdir><dest leaf><gunge>

        or
        dest = <dest leaf>
        making
        destn = <source dir><dest leaf><gunge>
    */

    /*
        sourcegunge points to the stuff past the source leaf (which is
        one of the selected items).
    */
    if ( strchr( sourceleaf, '.' ) == 0 )
    {
        sourcegunge = source + strlen( source );
    }
    else
    {
        sourcegunge = strchr( sourceleaf, '.' );
    }

    /*
            destleaf points to the leaf part of the destination
    */
    destleaf = strrchr( env->destination_name, '.' );
    temp = strrchr( env->destination_name, ':' );

    if ( temp > destleaf )
        destleaf = temp;

    if ( destleaf == NULL )
    {
        destleaf = env->destination_name;
    }
    else
    {
        destleaf++;     /* move beyond the separator (. or :) */
    }

    if ( destleaf > env->destination_name )
    {
        /*
            Destination directory is present
        */
        *destination = overflowing_malloc( strlen( env->destination_name ) + strlen( sourcegunge ) + 1 );

        if ( *destination == NULL )
            return error( mb_malloc_failed );

        sprintf( *destination, "%s%s", env->destination_name, sourcegunge );
    }
    else
    {
        *destination = overflowing_malloc( env->source_directory_name_length + 1 + strlen( env->destination_name ) + strlen( sourcegunge ) + 1 );

        if ( *destination == NULL )
            return error( mb_malloc_failed );

        strncpy( *destination, source, env->source_directory_name_length + 1 );

        sprintf( *destination + env->source_directory_name_length + 1, "%s%s", env->destination_name, sourcegunge );
    }

    return NULL;
}

/*
     Create the destination file name from the source
*/
static os_error *create_destination_filename( action_environment *env, char *source, char **destination )
{
     *destination = overflowing_malloc( strlen( source ) - env->source_directory_name_length
                                              + strlen( env->destination_name ) + 1 );

     if ( !*destination )
          return error( mb_malloc_failed );

     sprintf( *destination, "%s%s",
                           env->destination_name,
                           &source[ env->source_directory_name_length ] );

     return NULL;
}

/*
     Add next file to read list
*/
static os_error *test_add_to_read_list( action_environment *env, BOOL *should_be_added )
{
    char *destination;
    char *source;
    os_filestr fileplace;
    os_error *err;
    int source_reload;
    int destination_reload;

    wimpt_noerr( next_nodename( env->test_search, &source ));

    if ( env->operation != Action_CopyLocal )
    {
        wimpt_noerr( create_destination_filename( env, source, &destination ));
    }
    else
    {
        wimpt_noerr( create_destination_localfile( env, source, &destination ));
    }

    source_reload = reload_of_next_node( env->test_search );

    /*
            Only look newer if source has a datestamp
    */
    if ( env->looknewer &&
         ( source_reload & DateStamped_Mask ) == DateStamped_Mask &&
         objecttype_of_next_node( env->test_search ) != object_directory  )
    {
        /*
                Get the destination's information
        */
        fileplace.action = OSFile_ReadInfo;
        fileplace.name = destination;

        err = os_file( &fileplace );

        /*
            If an error happened which wasn't 'not found' then return
            with that error. 'not found' means datestamp checking need
            not happen.
        */
        if ( err )
        {
            if ( ( err->errnum & FileError_Mask ) != ErrorNumber_NotFound )
            {
                overflowing_free( source );
                overflowing_free( destination );

                return err;
            }
        }
        else
        {
            /*
                    If destination is datestamped after source, then don't
                    add source to read list
            */
            destination_reload = fileplace.loadaddr;
            if ( ( destination_reload & DateStamped_Mask ) == DateStamped_Mask )
            {
                if ( (destination_reload & DateStamp_HighByte) >
                          (source_reload & DateStamp_HighByte) ||
                     ( (destination_reload & DateStamp_HighByte) ==
                            (source_reload & DateStamp_HighByte) &&
                       (unsigned int)fileplace.execaddr >=
                       (unsigned int)execute_of_next_node( env->test_search ) )
                   )
                {
                    overflowing_free( source );
                    overflowing_free( destination );

                    *should_be_added = No;

                    return NULL;
                }
            }
        }
    }

    overflowing_free( destination );
    overflowing_free( source );

    *should_be_added = Yes;

    return NULL;
}

/*
        This actually adds the next file to the read list.
*/
static void add_to_read_list( action_environment *env, BOOL *i_am_full )
{
    char *destination;
    char *source;

    wimpt_noerr( next_nodename( env->test_search, &source ));

    if ( env->operation != Action_CopyLocal )
    {
        wimpt_noerr( create_destination_filename( env, source, &destination ));
    }
    else
    {
        wimpt_noerr( create_destination_localfile( env, source, &destination ));
    }

    wimpt_noerr( add_file_to_chain( destination, source,
        size_of_next_node( env->test_search ),
        reload_of_next_node( env->test_search ),
        execute_of_next_node( env->test_search ),
        attributes_of_next_node( env->test_search ),
        objecttype_of_next_node( env->test_search ),
        env->force,
        i_am_full
        #ifdef USE_PROGRESS_BAR
        , progress_of_next_node( env->test_search )
        , chain_ref_ptr_of_next_node(env->test_search)
        #endif
    ));

    overflowing_free( destination );
    overflowing_free( source );

    switch_to_reading( env );
}


/*
     Get the access of a file
*/
static os_error *get_access_to_file( char *filename, int *access )
{
     os_error *err;
     os_filestr fileplace;

     fileplace.action = OSFile_ReadInfo;
     fileplace.name = filename;

     err = os_file( &fileplace );

     *access = fileplace.end;
     return err;
}


/*
     Set the access to any file
*/
static os_error *set_access_to_file( char *filename, int access )
{
     os_filestr fileplace;

     fileplace.action = OSFile_WriteAttr;
     fileplace.name = filename;
     fileplace.end = access;

     return os_file( &fileplace );
}


/*
     Attempt to delete a node
 */
static os_error *delete_node(char *name)
{
     os_filestr fileplace;
     fileplace.action = OSFile_Delete;
     fileplace.name = name;

     return os_file( &fileplace );
}


/*
     Set the access of next node
*/
static os_error *set_access( action_environment *env, int access )
{
     char *filename;
     os_error *err;

     err = next_nodename( env->test_search, &filename );

     if ( err )
          return err;

     err = set_access_to_file( filename, access );

     overflowing_free( filename );

     return err;
}


/*
     Stamp any file
*/
static os_error *stamp_file( char *filename )
{
     os_filestr fileplace;

     fileplace.action = OSFile_SetStamp;
     fileplace.name = filename;

     return os_file( &fileplace );
}


/*
     Stamp next node
*/
static os_error *stamp( action_environment *env )
{
     char *filename;
     os_error *err;

     err = next_nodename( env->test_search, &filename );

     if ( err )
          return err;

     err = stamp_file( filename );

     overflowing_free( filename );

     return err;
}


/*
        Do a rename
*/
static os_error *riscos_rename( action_environment *env )
{
    os_error *err;
    os_regset r;
    char *source;
    char *destination;
    BOOL should_be_added;

    test_add_to_read_list(env, &should_be_added);
    wimpt_noerr( next_nodename( env->test_search, &source ));
    if (!should_be_added) return 0;

    wimpt_noerr( create_destination_filename( env, source, &destination ));
    debugact(( "riscos_rename: src = %s, dest = %s\n",source,destination ));
    r.r[0] = FSControl_Rename;
    r.r[1] = (int)source;
    r.r[2] = (int)destination;

    err = os_swix( OS_FSControl, &r );

    overflowing_free( source );
    overflowing_free( destination );

    return err;
}


static os_error *Do_Next_File( action_environment *env )
{
    os_error *err;
    char *filename;
    BOOL inhibit_confirm = No;
    BOOL is_cvs_directory = No;
    uint32_t p = 0;

    err = step_to_next_node( env->test_search, &p);

    #ifdef USE_PROGRESS_BAR
    add_progress(env, p, "Do_Next_File");
    #endif

    if ( err )
        return err;

    if ( another_node( env->test_search ))
    {
        err = next_nodename( env->test_search, &filename );

        if ( err )
            return err;

        set_bottom_info_field( env, filename );

        if ( env->auto_skip_cvs )
        {
          size_t length = strlen( filename );
          if (length > 4 && strcmp(filename + length - 4, ".CVS") == 0)
          {
              is_cvs_directory = Yes;
          }
          else if (length > 8 && strcmp(filename + length - 8, "./cvstag") == 0)
          {
              is_cvs_directory = Yes;
          }
        }

        overflowing_free( filename );

        switch( env->operation )
        {
        case Action_Copying:
        case Action_CopyLocal:
            env->action = Test_Add_To_Read_List;
            inhibit_confirm = Yes;
            if ( is_cvs_directory == Yes)
            {
                skip_list_file(env->test_search);
                env->action = Next_File;
            }
            break;

        case Action_Moving:
            env->action = Attempt_1st_Rename;
            break;

        case Action_CopyMoving:
            if ( objecttype_of_next_node( env->test_search ) == object_directory &&
                 directory_is_after_contents( env->test_search ) )
            {
                env->action = Add_To_Read_List;
            }
            else
            {
                env->action = Test_Add_To_Read_List;
            }
            inhibit_confirm = Yes;
            break;

        case Action_Deleting:
            if ( objecttype_of_next_node( env->test_search ) == object_directory )
            {
                if ( directory_is_after_contents( env->test_search ) )
                {
                    env->action = Attempt_Delete;
                    inhibit_confirm = Yes;
                }
                else
                {
                    env->action = Next_File;
                }
            }
            else
            {
                env->action = Attempt_Delete;
            }
            break;

        case Action_Setting_Access:
            env->action = Attempt_Set_Access;
            break;

        case Action_Setting_Type:
            env->action = Attempt_Set_Type;
            break;

        case Action_Counting:
            more_top_progress( env, 1 );
            more_bottom_progress( env, size_of_next_node( env->test_search ) );

            #ifdef USE_PROGRESS_BAR
            add_progress(env, progress_of_next_node(env->test_search), "Action_Counting");
            #endif
            break;

        case Action_Stamping:
            env->action = Attempt_Stamp;
            break;

        case Action_Finding:
            if ( !caseless_wildcmp( env->destination_name, name_of_next_node( env->test_search )) )
            {
                set_top_info_field( env, "84" );

                if ( (objecttype_of_next_node( env->test_search ) == object_directory &&
                    name_of_next_node( env->test_search )[0] != '!') ||
                    objecttype_of_next_node( env->test_search ) == (object_directory | object_file) )
                {
                    switch_buttons( env, &open_buttons );
                }
                else
                {
                    switch_buttons( env, &run_view_buttons );
                }
            }

            /*
                Keep the user informed of what's happening
            */
            if ( objecttype_of_next_node( env->test_search ) != object_file )
            {
                more_top_progress( env, 1 );
            }
            else
            {
                more_bottom_progress( env, 1 );
            }

            #ifdef USE_PROGRESS_BAR
            add_progress(env, progress_of_next_node(env->test_search), "Action_Finding");
            #endif

            break;

        default:
            break;
        }

        /*
            Don't confirm until we are sure this file is going to
            be added to the read list.
        */
        if ( env->confirm &&
             !inhibit_confirm )
        {
            switch_buttons( env, &confirm_buttons );
            set_top_info_field( env, action_prompt[ env->operation ] );
        }
    }
    else
    {
        /*
            No more files
        */
        if ( env->operation == Action_Copying ||
             env->operation == Action_CopyMoving ||
             env->operation == Action_CopyLocal )
        {
            switch_to_writing( env );
        }
        else if ( env->operation == Action_Counting )
        {
            /*
                Change buttons, display dbox, clear
                unwanted fields etc
            */
            switch_buttons( env, &ok_button );

            set_top_info_field( env, "85" );
            set_bottom_info_field( env, env->selection_summary );
        }
        else if ( ( env->operation == Action_Deleting ||
                env->operation == Action_CopyMoving ) &&
              env->locked_not_deleted > 0 )
        {
             char top_field[ 50 ];

             switch_buttons( env, &ok_button );

             sprintf( top_field, msgs_lookup( "86" ), env->locked_not_deleted );

             set_top_info_field( env, "85" );
             set_bottom_info_field( env, top_field);

        }
        else
        {
            /*
                Finished doing everything else, so
                kill ourselves off
            */
            abort_operation( env );
        }
    }

    return NULL;
}


static os_error *Do_Test_Add_To_Read_List( action_environment *env )
{
    os_error *err;
    BOOL should_be_added;

    err = test_add_to_read_list( env, &should_be_added );

    if ( err )
        return err;

    if ( should_be_added )
    {
        env->action = Add_To_Read_List;

        /*
            Confirm if necessary.
        */
        if ( env->confirm )
        {
            switch_buttons( env, &confirm_buttons );
            set_top_info_field( env, action_prompt[ env->operation ] );
        }
    }
    else
    {
        env->action = Next_File;
    }

    return NULL;
}

static os_error *Do_Add_To_Read_List( action_environment *env )
{
    BOOL i_am_full;

    add_to_read_list( env, &i_am_full );

    if ( i_am_full )
        switch_to_writing( env );

    return NULL;
}

static os_error *Do_Check_Full_Reading( action_environment *env )
{
    os_error *err;
    BOOL i_am_full;
    BOOL need_another_file;
    BOOL that_finished_a_file;
    uint32_t p = 0;

    err = read_a_block( &i_am_full, &need_another_file, &that_finished_a_file, &p );

    if ( err )
        return err;

    #ifdef USE_PROGRESS_BAR
    add_progress(env, p, "Block read");
    #endif

    if ( i_am_full )
    {
        switch_to_writing( env );
    }
    else if ( need_another_file )
    {
        if ( another_node( env->test_search ))
        {
            env->action = Next_File;
        }
        else if ( next_file_to_be_written() == NULL )
        {
            abort_operation( env );
        }
        else
        {
            switch_to_writing( env );
        }
    }
    else
    {
        set_top_progress_field( env, bytes_left_to_read());

        if ( that_finished_a_file )
        {
            set_bottom_info_field( env, next_file_to_be_read());
        }
    }

    return NULL;
}


static os_error *Do_Check_Empty_Writing( action_environment *env )
{
    os_error *err;
    BOOL i_am_empty;
    BOOL that_finished_a_file;
    uint32_t p = 0;

    err = write_a_block( &i_am_empty, &that_finished_a_file, &p );

    if ( err )
        return err;

    #ifdef USE_PROGRESS_BAR
    add_progress(env, p, "Block write");
    #endif

    if ( i_am_empty )
    {
        switch_to_reading( env );
    }
    else if ( that_finished_a_file )
    {

        if ( env->operation != Action_CopyMoving )
        {
            if ( finished_obj_was_file )
            {
                more_bottom_progress( env, 1 );
            }

            set_bottom_info_field( env, next_file_to_be_written());
            set_top_progress_field( env, bytes_left_to_write());
        }
        else
        {
            /*
                We are copyMoving, hence:
                Attempt_Delete (will work for dirs on way up tree, but fail on way down)
            */
            env->action = Attempt_Delete;
        }
    }
    else
    {
        set_top_progress_field( env, bytes_left_to_write());
    }

    return NULL;
}


static os_error *Do_Attempt_Rename( action_environment *env, int which_one )
{
    os_error *err;

    err = riscos_rename( env );

    if ( err )
    {
        switch ( err->errnum & FileError_Mask )
        {
        case ErrorNumber_Locked:
            if ( which_one == 1 )
            {
                env->action = Attempt_Unlock;
                err = NULL;
            }
            break;

        case ErrorNumber_NotSameDisc:
        case ErrorNumber_BadRename:
        case ErrorNumber_AlreadyExists:
            if ( which_one == 1 )
                env->action = Convert_To_CopyMove;
            else
                env->action = Convert_To_CopyMove_After_Unlock;
            err = NULL;
            break;
        }
    }
    else
    {
        if ( which_one == 1 )
        {
            more_bottom_progress( env, 1 );
            env->action = Next_File;
        }
        else
        {
            env->action = Attempt_Relock;
        }
        #ifdef USE_PROGRESS_BAR
        add_progress(env, progress_of_next_node(env->test_search), "Do_Attempt_Rename");
        #endif
    }

    return err;
}


static os_error *Do_Attempt_Unlock( action_environment *env )
{
    os_error *err;
    char *filename;

    err = next_nodename( env->test_search, &filename );

    if ( err )
        return err;

    /*
        Ignore error as don't care if it fails
    */
    (void)set_access_to_file( filename, attributes_of_next_node( env->test_search ) & ~locked_attribute );

    overflowing_free( filename );

    env->action = Attempt_2nd_Rename;

    return NULL;
}


/*
    Relock destination of rename after unlocking source
*/
static os_error *Do_Attempt_Relock( action_environment *env )
{
    os_error *err;
    char *source;
    char *destination;

    err = next_nodename( env->test_search, &source );

    if ( err )
        return err;

    err = create_destination_filename( env, source, &destination );

    overflowing_free( source );

    if ( err )
        return err;

    /*
        Ignore error as don't care if it fails
    */
    (void)set_access_to_file( destination, attributes_of_next_node( env->test_search ) );

    overflowing_free( destination );

    more_bottom_progress( env, 1 );

    env->action = Next_File;

    return NULL;
}


static os_error *Do_Convert_To_CopyMove( action_environment *env, BOOL after_unlock )
{
    os_error *err;
    char *filename;

    /*
        Relock the node if necessary, don't object if this
        fails!
    */
    if ( after_unlock )
    {
        /*
            return the attributes to their old values (but ignore errors back)
        */

        err = next_nodename( env->test_search, &filename );

        if ( err )
            return err;

        (void)set_access_to_file( filename, attributes_of_next_node( env->test_search ));

        overflowing_free( filename );
    }

    init_for_copying();
    env->flex_memory = Yes;
    env->operation = Action_CopyMoving;
    env->action = Add_To_Read_List;
    return_directories_first( env->test_search, Yes );
    return_directories_last( env->test_search, Yes );
    recurse_search_context( env->test_search, Yes );

    /*
       Reset the progress bar as the operation is restarted as a copymove
    */
    #ifdef USE_PROGRESS_BAR
    debugact(( "changed operation: %s\n", debug_operation( env->operation ) ));
    listfiles_convert_to_copymove( env->test_search );
    env->progress = 0;
    #endif

    err = selection_summary( env->test_search, &env->selection_summary );

    env->locked_not_deleted = 0;

    return err;
}


static os_error *Do_Attempt_Delete( action_environment *env )
{
    os_error *err;
    char *filename;
    BOOL inhibit_progress = No;
    int prev_access;
    uint32_t p = 0;

    if ( env->operation != Action_CopyMoving )
    {
        wimpt_noerr( next_nodename( env->test_search, &filename ));
        #ifdef USE_PROGRESS_BAR
        p = progress_of_next_node(env->test_search);
        #endif
    }
    else
    {
        filename = finished_obj_source_name;
    }

    debugact(( "Do_Attempt_Delete: filename = %s p = %08x\n", filename, p ));

    /*
        JRS 29/1/92 1st attempt to delete the node without touching the access.
        In most cases this will work without further ado
     */
    err = delete_node( filename );

    /*
        If forcing delete, set no read/write access and
        unlock it. If this fails, then the delete will
        never work!
    */
    prev_access = -1; /* special value to test for */
    if ( (err != NULL) &&
         (env->force ||
         env->operation == Action_CopyMoving) )
    {
        err = get_access_to_file(filename, &prev_access);
        if ( err ) prev_access = -1;

        err = set_access_to_file(filename, prev_access & ~locked_attribute);

        if ( err && (err->errnum & FileError_Mask) != ErrorNumber_NotFound )
            return err;
        /*
            Retry deletion
         */
        err = delete_node( filename );
    }


    /*
        If it didn't work, cancel the error if its an ignorable
        error for this operation
    */
    if ( err )
    {
        /* JRS 28/1/92 test if access should be restored */
        if ( prev_access != -1 )
        {
          /*
            Put the access back to where it was
           */
            set_access_to_file( filename, prev_access);
        }

        switch( err->errnum & FileError_Mask )
        {
        case ErrorNumber_Locked:
            /*
                If forcing delete failed due to locked file then something's
                happening which the user should know about, so don't drop
                through the 'cancel this error' code.
            */
            if ( env->force )
                break;

            /*
                Otherwise, just note that one file hasn't been deleted
                due to a locked file and drop through to the 'it didn't
                get deleted, and it was there, and we don't mind' case.
            */
            env->locked_not_deleted++;

        case ErrorNumber_DirectoryNotEmpty:
            /*
                Reach here if the file didn't get deleted and it was
                there and we don't mind. If these conditions are satisfied
                then we don't want to count this object as deleted.
            */
            inhibit_progress = Yes;
            err = NULL;
            break;

        case ErrorNumber_NotFound:
            /*
                This
                entry point is used for the 'its already gone' situation,
                in which case we fib to the user that it was the user which
                caused the deletion (but it wasn't really; who cares -
                the file's gone anyway).
            */
            err = NULL;
            deleted_next_node( env->test_search, filename );
            break;

        default:
            break;
        }
    }
    else
    {
        /*
            Tell the file listing stuff we've deleted the node
        */
        deleted_next_node( env->test_search, filename );
    }

    if ( env->operation != Action_CopyMoving )
        overflowing_free( filename );

    if ( err )
        return err;

    /*
        Only update progress bar if the file was actually deleted
    */
    #ifdef USE_PROGRESS_BAR
    add_progress(env, p, "Do_Attempt_Delete");
    #endif

    if ( env->operation != Action_CopyMoving )
    {
        if ( !inhibit_progress )
        {
            /*
                Keep the user informed of what's happening
            */
            if ( objecttype_of_next_node( env->test_search ) != object_file )
            {
                more_top_progress( env, 1 );
            }
            else
            {
                more_bottom_progress( env, 1 );
            }
        }

        env->action = Next_File;
    }
    else
    {
        /*
            Update progress if it's a file we've just finished moving
        */
        if ( finished_obj_was_file )
        {
            more_bottom_progress( env, 1 );
        }

        set_bottom_info_field( env, next_file_to_be_written());

        env->action = Check_Empty_Writing;
    }

    return NULL;
}


static os_error *Do_Attempt_Set_Access( action_environment *env )
{
    os_error *err;

    if ( objecttype_of_next_node( env->test_search ) != object_file )
    {
        err =
            set_access(
                env,
                ((attributes_of_next_node( env->test_search) & (env->new_access >> 16) & 0xffff) |
                (env->new_access & ~(env->new_access >> 16) & 0xffff)) &
                env->directory_access_setting_mask );

        if ( err )
            return err;

        more_top_progress( env, 1 );
    }
    else
    {
        err =
            set_access(
                env,
                (attributes_of_next_node( env->test_search) & (env->new_access >> 16) & 0xffff) |
                (env->new_access & ~(env->new_access >> 16) & 0xffff) );

        if ( err )
            return err;

        more_bottom_progress( env, 1 );
    }

    #ifdef USE_PROGRESS_BAR
    add_progress(env, progress_of_next_node(env->test_search), "Do_Attempt_Set_Access");
    #endif

    env->action = Next_File;

    return NULL;
}


static os_error *Do_Attempt_Set_Type( action_environment *env )
{
    os_error *err;
    char *filename;
    os_filestr fileplace;

    if ( objecttype_of_next_node( env->test_search ) == object_directory )
    {
        more_top_progress( env, 1 );
    }
    else
    {

        err = next_nodename( env->test_search, &filename );

        if ( err )
            return err;

        fileplace.action = OSFile_SetType;
        fileplace.name = filename;
        fileplace.loadaddr = env->new_type;

        err = os_file( &fileplace );

        overflowing_free( filename );

        if ( err )
            return err;

        more_bottom_progress( env, 1 );

    }

    #ifdef USE_PROGRESS_BAR
    add_progress(env, progress_of_next_node(env->test_search), "Do_Attempt_Set_Type");
    #endif

    env->action = Next_File;

    return NULL;
}


static os_error *Do_Attempt_Stamp( action_environment *env )
{
    os_error *err;

    err = stamp( env );

    #ifdef USE_PROGRESS_BAR
    add_progress(env, progress_of_next_node(env->test_search), "Do_Attempt_Stamp");
    #endif

    /*
        Filter out F. S. Error 46 as this is the error generated by file
        servers which can't stamp directories
    */
    if ( err && (err->errnum & FileError_Mask) != ErrorNumber_FSError46 )
        return err;

    err = NULL;

    if ( objecttype_of_next_node( env->test_search ) == object_file )
        more_bottom_progress( env, 1 );
    else
        more_top_progress( env, 1 );

    env->action = Next_File;

    return NULL;
}


/*
     --- Activity processor for null events ---
*/
static void null_event_activity( action_environment *env )
{
    os_error *err = NULL;
    clock_t   end_time;

    end_time = clock() + doings_time;
    hide_faster_stuff( env );

    do
    {
        if ( env->action == Abort_Operation )
        {
            abort_operation( env );
        }

        if ( last_top_info_field != env->current_info )
        {
            if ( env->in_error )
            {
                #ifdef USE_RED_ERROR
                wimp_set_icon_state( dbox_syshandle( env->status_box ), Top_Info_Field, 0xc000000, 0 );
                wimp_set_icon_state( dbox_syshandle( env->status_box ), Bottom_Info_Field, 0xc000000, 0 );
                #endif

                env->in_error = No;
                switch_box_from_error( env );
            }

            set_top_info_field_raw( env, env->current_info );
        }

        switch( env->action )
        {
        case Next_File:
            err = Do_Next_File( env );
            break;

        case Test_Add_To_Read_List:
            err = Do_Test_Add_To_Read_List( env );
            break;

        case Add_To_Read_List:
            err = Do_Add_To_Read_List( env );
            break;

        case Check_Full_Reading:
            err = Do_Check_Full_Reading( env );
            break;

        case Check_Empty_Writing:
            err = Do_Check_Empty_Writing( env );
            break;

        case Attempt_1st_Rename:
            err = Do_Attempt_Rename( env, 1 );
            break;

        case Attempt_Unlock:
            err = Do_Attempt_Unlock( env );
            break;

        case Attempt_2nd_Rename:
            err = Do_Attempt_Rename( env, 2 );
            break;

        case Attempt_Relock:
            err = Do_Attempt_Relock( env );
            break;

        case Convert_To_CopyMove:
            err = Do_Convert_To_CopyMove( env, No );
            break;

        case Convert_To_CopyMove_After_Unlock:
            err = Do_Convert_To_CopyMove( env, Yes );
            break;

        case Attempt_Delete:
            err = Do_Attempt_Delete( env );
            break;

        case Attempt_Set_Access:
            err = Do_Attempt_Set_Access( env );
            break;

        case Attempt_Set_Type:
            err = Do_Attempt_Set_Type( env );
            break;

        case Attempt_Stamp:
            err = Do_Attempt_Stamp( env );
            break;

        default:
            break;
        }

      /*
          While there is not error and
              we havn't run out of time and
              we are accepting NULL events
      */
    } while ( !err &&
        clock() < end_time &&
        ( event_getmask() & wimp_EMNULL ) == 0 );


    #ifdef USE_PROGRESS_BAR
    update_progress_bar(env);
    #endif

    /*
       Update the various fields in the dialogue box, if the flags are set
    */

    if (UpdatePath)
    {
      UpdatePath = 0;
      dbox_setfield( env->status_box, Bottom_Info_Path, PathString );
    }

    if (UpdateTop)
    {
      UpdateTop = 0;
      if ( !env->faster || show_when_faster[ env->operation ][ 0 ] )
      {
        dbox_setlongnumeric( env->status_box, Top_Progress_Field, env->top_progress );
      }
    }

    if (UpdateBottom)
    {
      UpdateBottom = 0;
      if ( !env->faster || show_when_faster[ env->operation ][ 1 ] )
      {
        dbox_setlongnumeric( env->status_box, Bottom_Progress_Field, env->bottom_progress);
      }
    }


    if ( err )
    {
        if ( err->errnum == 0 )
        {
            /*
                Internally generated error - this is fatal
            */
            wimpt_noerr( err );
        }
        else
        {
            /*
                Externally generated error - give the user a chance
                to correct it.
            */

            if ( ( env->operation == Action_Copying ||
                   env->operation == Action_CopyMoving ||
                   env->operation == Action_CopyLocal ) &&
                 ( env->action == Check_Full_Reading ||
                   env->action == Check_Empty_Writing ) )
            {
                /*
                        Read/Write during a copy or copy move
                */
                switch_buttons( env, &restart_button );
            }
            else
            {
                /*
                        Attempted activity normal for operation, but failed
                */
                switch_buttons( env, &norestart_button );
            }

            /*
                Construct error indicator
            */
            if ( ( err->errnum & FileError_Mask ) == ErrorNumber_DiscFull )
            {
                set_top_info_field_with_current_info(env, "87a", "87");

                if ( env->disc_full_already )
                {
                        /*
                                Cancel the report of a second or subsequent disc full error
                        */
                        err = NULL;
                }
                else
                {
                        env->disc_full_already = Yes;
                        switch_box_to_error( env, err );
                }
            }
            else
            {
                set_top_info_field_with_current_info(env, "88a", "88");

                switch_box_to_error( env, err );
            }

            /*
                 Set the info field text to red (assuming it was black)
            */
            env->in_error = Yes;
            #ifdef USE_RED_ERROR
            wimp_set_icon_state( dbox_syshandle( env->status_box ), Top_Info_Field, 0xc000000, 0 );
            wimp_set_icon_state( dbox_syshandle( env->status_box ), Bottom_Info_Field, 0xc000000, 0 );
            #endif
        }
    }
}


/*
     --- NULL event handler for status box. ---
*/
BOOL idle_event_handler(dbox db, void *event, void *handle)
{
    BOOL handled = No;

    IGNORE(db);

    switch( ((wimp_eventstr *)event)->e )
    {
    case wimp_ENULL:
        {
            action_environment *env = handle;

            /*
                Process delayed box showing and hiding
            */
            if ( env->boxchange_direction != 0 &&
                 clock() >= env->time_to_boxchange )
            {
                if ( env->boxchange_direction > 0 )
                {
                        dbox_showstatic( env->status_box );
                }
                else
                {
                        dbox_hide( env->status_box );
                }

                env->boxchange_direction = 0;
            }

            null_event_activity( env );
        }
        handled = Yes;
        break;

    case wimp_ESEND:
    case wimp_ESENDWANTACK:
        handled = message_event_handler( event, handle );
        break;

    default:
        break;
    }

    return handled;
}


/* Fixed stack size !!!
 * 3.5k is the max required.
 * 2k is a bodge safety factor.
 */
int __root_stack_size = 3*1024+512+2*1024;
extern int disable_stack_extension;

/*
     This is the entry point for the Filer_Action module.
*/
int main( int argc, char *argv[] )
{
    disable_stack_extension = 1;

    wimpt_install_signal_handlers();

    wimpt_noerr( initialise( &env, argc, argv ));

    while (TRUE)
    {
        event_process();
    }

    return 0;
}

