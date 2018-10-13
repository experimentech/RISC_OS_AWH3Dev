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

#if 0
#define debuginit(k) dprintf k
#else
#define debuginit(k) /* Disabled */
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <locale.h>
#include <time.h>

#include "os.h"
#include "wimp.h"
#include "wimpt.h"
#include "win.h"
#include "event.h"
#include "res.h"
#include "template.h"
#include "dbox.h"
#include "dboxquery.h"
#include "msgs.h"
#include "menu.h"

#include "Options.h"
#include "allerrs.h"
#include "malloc+.h"
#include "listfiles.h"
#include "memmanage.h"
#include "actionwind.h"
#include "Initialise.h"
#include "Buttons.h"
#include "debug.h"

#define Window_Title_Height 40
#define Character_Height 32

#define Template_Filename "FilerAct:Templates"
#define Messages_Filename "FilerAct:Messages"

#define No 0
#define Yes (!No)

/* Global error buffer. */
os_error errbuf = { 0, "" };

/*
     This routine removes the unknown event processor
*/
static void remove_processor( void )
{
    win_remove_unknown_event_processor( message_event_handler, &env );

    closedown_memmanagement();
}

static void near_mouse_position_window( char *window_name )
{
    template *tplt = template_find( window_name );
    wimp_mousestr ptr;
    os_error *err;
    int x_offset;
    int y_offset;

    err = wimp_get_point_info( &ptr );
    if ( !err )
    {
        x_offset = (ptr.x - Window_Title_Height - Character_Height) -
                   tplt->window.box.x0;
        y_offset = (ptr.y - Window_Title_Height - Character_Height) -
                   tplt->window.box.y1;

        tplt->window.box.x0 += x_offset;
        tplt->window.box.x1 += x_offset;
        tplt->window.box.y0 += y_offset;
        tplt->window.box.y1 += y_offset;
    }
}


/*
     This routine initialises file_action when it is entered.
     It does:
     *    Register our deactivation routine and activate ourselves
     *    Prefer the base invocation of Filer_Action
     *    Initialise wimplib
     *    Initialise the action environment
*/
static wimp_msgaction Messages[] = {
    wimp_MPREQUIT,
    wimp_MSETSLOT,
    wimp_MHELPREQUEST,
    wimp_MFilerSelectionDirectory,
    wimp_MFilerAddSelection,
    wimp_MFilerAction,
    wimp_MFilerControlAction,
    wimp_MCLOSEDOWN /* list terminator (0, but with the right type) */
};

os_error *initialise( action_environment *env, int argc, char *argv[] )
{
    os_error *err;

    IGNORE(argc); /* keep the compiler quiet */
    IGNORE(argv); /* keep the compiler quiet */

    overflowing_initialise();

    /*
         Pull in some resources
    */
    res_init("FilerAct");
    msgs_init();
    wimpt_messages(Messages);
    wimpt_init(msgs_lookup("89"));
    template_init();
    debuginit(( "Resources initialised\n" ));

    #ifdef debug
    /* Test errors. */
    {
        os_error *err;
        err = error( mb_slotsize_too_small );
        debuginit(( "%d: %s\n", err->errnum, err->errmess ));
        err = error( mb_malloc_failed );
        debuginit(( "%d: %s\n", err->errnum, err->errmess ));
        err = error( mb_unexpected_state );
        debuginit(( "%d: %s\n", err->errnum, err->errmess ));
        err = error( mb_broken_templates );
        debuginit(( "%d: %s\n", err->errnum, err->errmess ));
    }
    #endif

    /*
         Get the memmanagement onto the right footing
    */
    err = init_memmanagement();
    if ( err )
         return err;

    /*
         re-position the window near the mouse
    */
    near_mouse_position_window( MAIN_TEMPLATE_NAME );

    /*
         start up the dbox wimplib stuff
    */
    dbox_init();

    /*
         Add event processor here, so that deactivate_myself can cleanly
         remove it
    */
    win_add_unknown_event_processor( message_event_handler, env );
    atexit( remove_processor );

    /*
         create a window for ourself
    */
    env->status_box = dbox_new( MAIN_TEMPLATE_NAME );
    if ( env->status_box == NULL )
            return error( mb_broken_templates );
    env->window_handle = dbox_syshandle( env->status_box );

    /*
         Attach the button event handler
    */
    dbox_eventhandler( env->status_box, button_event_handler, env );

    /*
            Give ourself a menu
    */
    env->option_menu = menu_new( msgs_lookup( "90" ), msgs_lookup( "91" ));
    if ( env->option_menu == NULL )
            return error( mb_malloc_failed );
    event_attachmenu( dbox_syshandle( env->status_box ), env->option_menu, (event_menu_proc)option_menu_handler, env );

    /*
         Attach idle event handler to dialogue box
    */
    dbox_raw_eventhandler( env->status_box, idle_event_handler, env );

    /*
         Direct idle events at the dialogue box
    */
    win_claim_idle_events( dbox_syshandle( env->status_box ));

    /*
         Enable only those events we're interested in
    */
    event_setmask( (wimp_emask)(wimp_EMPTRLEAVE | wimp_EMPTRENTER | wimp_EMUSERDRAG) );

    /*
         Initialise an empty search context and boxchange information.
         Also initialise memory flexing state.
    */
    create_search_context( &env->test_search );
    env->boxchange_direction = 0;
    env->flex_memory = No;
    env->disable_flex = No;
    env->in_error = No;
    #ifdef USE_PROGRESS_BAR
    env->progress = 0;
    #endif

    last_top_info_field = NULL;

    /*
         Make sure we don't go away when the window's closed
    */
    win_activeinc();

    dboxquery( 0 );

    setlocale( LC_ALL, "" );

    return NULL;
}
