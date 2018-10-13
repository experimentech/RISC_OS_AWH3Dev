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
 * Purpose: main module of a Iconbar Object module
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
#include "rmensure.h"
#include "objmodule.h"

#include "objects/toolbox.h"
#include "string32.h"
#include "objects/iconbar.h"

#include "create.h"
#include "delete.h"
#include "show.h"
#include "hide.h"
#include "getstate.h"
#include "miscop.h"
#include "events.h"
#include "globals.h"

#include "task.h"

#include "IconBarHdr.h"


#define MAX_CLASS_SWI_METHODS 7
static _kernel_oserror *(*class_swi_methods [MAX_CLASS_SWI_METHODS])(_kernel_swi_regs *r, TaskDescriptor *t) =
       {
            create_object,
            delete_object,
            NULL /*copy_object*/,
            show_object,
            hide_object,
            getstate_object,
            miscop_object
       };




/* +++++++++++++++++++++++++++++++++ finalisation code +++++++++++++++++++++++++++++++++ */

#ifndef ROM
extern int Resources(void);
#endif

extern _kernel_oserror *Iconbar_finalise (int fatal, int podule, void *pw)
{
    /*
     * Function to clean up before module exit
     */

    IGNORE(fatal);
    IGNORE(podule);
    IGNORE(pw);

    /*
     * refuse to finalise if tasks active
     */

    if (task_any_active())
        return make_error (Iconbar_TasksActive, 0);


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

    objmodule_deregister(0, Iconbar_ObjectClass);

    /*
     * free up memory we may have left allocated
     */

    mem_free_all ();

    return NULL;
}


/* ++++++++++++++++++++++++++++++++ initialisation code +++++++++++++++++++++++++++++++ */


extern _kernel_oserror *Iconbar_init(const char *cmd_tail, int podule_base, void *pw)
{
    _kernel_oserror *e;

    IGNORE(cmd_tail);
    IGNORE(podule_base);
    IGNORE(pw);

    DEBUG debug_set_var_name("Iconbar$Debug");

    /*
     * ensure that the Toolbox is there
     */

    if ((e = rmensure ("Toolbox", "Toolbox.Toolbox", "0.00")) != NULL)
    {
        DEBUG debug_output ("init", "I:rmensure failed %s\n", e->errmess);
        return e;
    }

#ifndef ROM
    /*
     * register our resources with ResourceFS
     */

    if ((e = objmodule_register_resources(Resources())) != NULL)
    {
        DEBUG debug_output ("init", "I:resourcefs register failed %s\n", e->errmess);
        return e;
    }
#endif

    /*
     * register our messages file with MessageTrans
     */

    objmodule_ensure_path("Iconbar$Path", "Resources:$.Resources.Iconbar.");

    if ((e = messages_file_open ("Iconbar:Messages")) != NULL)
        return e;


    /*
     * register with the Toolbox as an Object Module
     */

    return objmodule_register_with_toolbox(0, Iconbar_ObjectClass, Iconbar_ClassSWI, 0);
}



/* +++++++++++++++++++++++++++++++++ service handler code ++++++++++++++++++++++++++++++ */


extern void Iconbar_services(int service_number, _kernel_swi_regs *r, void *pw)
{
    IGNORE(pw);

    DEBUG debug_output ("services", "I:service call %x\n", service_number);

    switch (service_number)
    {

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

        case Service_ToolboxStarting:
            /*
             * register with the Toolbox as an Object Module
             */

            _swix (Toolbox_RegisterObjectModule, _INR(0,3),
                        0,
                        Iconbar_ObjectClass,
                        Iconbar_ClassSWI,
                        0
                  );

            break;

        default:
            break;
    }
}

/* ++++++++++++++++++++++++++++++++++++++ SWI code +++++++++++++++++++++++++++++++++++++ */


extern _kernel_oserror *Iconbar_SWI_handler(int swi_no, _kernel_swi_regs *r, void *pw)
{
    _kernel_oserror *e = NULL;
    TaskDescriptor  *t;

    IGNORE(pw);

    DEBUG debug_output ("SWIs", "I:Iconbar SWI %d (reason %d)\n", swi_no, r->r[0]);

    switch (swi_no)
    {
        case Iconbar_ClassSWI - Iconbar_00:
            if (r->r[0] < 0 || r->r[0] >= MAX_CLASS_SWI_METHODS)
                return make_error_hex (Iconbar_NoSuchMethod, 1, r->r[0]);
            else
            {
                t = task_find (r->r[3]);

                if (t == NULL)
                {
                    return make_error_hex (Iconbar_NoSuchTask, 1, r->r[3]);
                }

                e = (*class_swi_methods[r->r[0]])(r, t);
            }
            break;

        case Iconbar_PostFilter - Iconbar_00:
            DEBUG debug_output ("postfilters", "I:Calling postfilter regs @ %p\n", &r->r[0]);
            e = events_postfilter (r);
            break;

        case Iconbar_PreFilter - Iconbar_00:
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

extern _kernel_oserror *Iconbar_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
    IGNORE(argc);
    IGNORE(pw);
    IGNORE(arg_string);

    switch (cmd_no)
    {
        case CMD_Iconbar_Memory:
            mem_print_list();
            break;

        default:
            break;
    }

    return NULL;
}
#endif
