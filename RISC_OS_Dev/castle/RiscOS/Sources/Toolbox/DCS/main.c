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
/* Title:   main.c
 * Purpose: main module of a DCS Object module
 * Author:  IDJ
 * History: 7-Oct-93: IDJ: created
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"
#include "Global/Services.h"

#include "const.h"
#include "macros.h"
#include "debug.h"
#include "mem.h"
#include "messages.h"
#include "objmodule.h"
#include "rmensure.h"

#include "objects/toolbox.h"
#include "objects/DCS.h"
#include "objects/quit.h"

#include "object.h"
#include "create.h"
#include "delete.h"
#include "show.h"
#include "hide.h"
#include "getstate.h"
#include "miscop.h"
#include "events.h"

#include "task.h"

#include "DCSHdr.h"

#define MAX_CLASS_SWI_METHODS 7
static _kernel_oserror *(*class_swi_methods [MAX_CLASS_SWI_METHODS])(_kernel_swi_regs *r, TaskDescriptor *t,int class) =
       {
            create_object,
            delete_object,
            NULL,
            show_object,
            hide_object,
            getstate_object,
            miscop_object
       };



/* +++++++++++++++++++++++++++++++++ finalisation code +++++++++++++++++++++++++++++++++ */

#ifndef ROM
extern int Resources(void);
#endif

extern _kernel_oserror *DCS_final (int fatal, int podule, void *pw)
{
    IGNORE(fatal);
    IGNORE(podule);
    IGNORE(pw);

    /*
     * if tasks are active or modules registered, refuse to die
     */

    if (task_any_active())
    {
        _kernel_oserror *e = make_error (DCS_TasksActive, 0);
        DEBUG debug_output ("finalise", "W:failed to finalise %s\n", e->errmess);
        return e;
    }

    /*
     * close our messages file
     */

    messages_file_close();


#ifndef ROM
    /*
     * ... and deregister from ResourceFS
     */

    objmodule_deregister_resources(Resources());
#endif


    /*
     * ... and deregister from Toolbox
     */

    objmodule_deregister(0, DCS_ObjectClass);
    objmodule_deregister(0, Quit_ObjectClass);

    /*
     * free up memory we may have left allocated
     */

    mem_free_all ();

    return NULL;
}


/* ++++++++++++++++++++++++++++++++ initialisation code +++++++++++++++++++++++++++++++ */

static _kernel_oserror *register_with_toolbox(void)
{
    _kernel_oserror *e;

    objmodule_ensure_path("DCS$Path", "Resources:$.Resources.DCS.");
    if ((e = objmodule_register_with_toolbox(0, DCS_ObjectClass, DCS_ClassSWI, "DCS:Res")) != NULL)
        return e;

    /* register here with the Toolbox as an Object Module */

    DEBUG debug_output ("init", "Registering with Toolbox\n");

    objmodule_ensure_path("Quit$Path", "Resources:$.Resources.Quit.");
    return objmodule_register_with_toolbox(0, Quit_ObjectClass, Quit_ClassSWI, "Quit:Res");
}

extern _kernel_oserror *DCS_init(const char *cmd_tail, int podule_base, void *pw)
{
    _kernel_oserror *e;

    IGNORE(cmd_tail);
    IGNORE(podule_base);
    IGNORE(pw);

    if ((e=rmensure("Window","Toolbox.Window","1.10")) !=NULL) return e;

    DEBUG debug_set_var_name("DCS$Debug");

#ifndef ROM
    /*
     * register our resources with ResourceFS
     */

    DEBUG debug_output ("init", "Registering messages files\n");

    objmodule_register_resources(Resources());
#endif

    /*
     * register our messages file with MessageTrans
     */

    objmodule_ensure_path("DCS$Path", "Resources:$.Resources.DCS.");
    if ((e = messages_file_open ("DCS:Messages")) != NULL)
        return e;

    /* Hmm what the **** do we do about two message files ??? */


    /* register here with the Toolbox as an Object Module */

    DEBUG debug_output ("init", "Registering with Toolbox\n");

    return (register_with_toolbox());

}



/* +++++++++++++++++++++++++++++++++ service handler code ++++++++++++++++++++++++++++++ */


extern void DCS_services(int service_number, _kernel_swi_regs *r, void *pw)
{
    IGNORE(pw);

    switch (service_number)
    {

        case Service_ToolboxStarting:
            register_with_toolbox();
            break;

        case Service_ToolboxTaskDied:
            /*
             * task dying - r0 holds task handle
             */

            task_remove (r->r[0]);

            break;

        case Service_ToolboxTaskBorn:
            /* Toolbox task has just started R0  == wimp task handle */

            /*
             * create a new "task descriptor"
             */

            task_add (r->r[0]);

            break;

        default:
            break;
    }
}

/* ++++++++++++++++++++++++++++++++++++++ SWI code +++++++++++++++++++++++++++++++++++++ */


extern _kernel_oserror *DCS_SWI_handler(int swi_no, _kernel_swi_regs *r, void *pw)
{
    _kernel_oserror *e = NULL;
    TaskDescriptor  *t;

    IGNORE(pw);

    switch (swi_no)
    {
        case DCS_ClassSWI - DCS_00:
        case Quit_ClassSWI - DCS_00:
            if (r->r[0] < 0 || r->r[0] >= MAX_CLASS_SWI_METHODS)
            {
                /* make an error here */
            }
            else
            {
                t = task_find (r->r[3]);

                if (t == NULL)
                {
                    /* make an error here */
                }

                e = (*class_swi_methods[r->r[0]])(r, t,swi_no + DCS_SWIChunkBase);
            }
            break;

        case DCS_PostFilter - DCS_00:
            e = events_postfilter (r);
            break;

        case DCS_PreFilter - DCS_00:
            e = events_prefilter (r);
            break;

        default:
            e = error_BAD_SWI;
            break;
    }

    return e;
}

#if debugging

/* ++++++++++++++++++++++++++++++++++++++ star commands ++++++++++++++++++++++++++++++++++++*/

extern _kernel_oserror *DCS_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
    IGNORE(argc);
    IGNORE(pw);
    IGNORE(arg_string);

    switch (cmd_no)
    {
        case CMD_DCS_Memory:
            mem_print_list();
            break;

        default:
            break;
    }

    return NULL;
}

#endif
