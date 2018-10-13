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
 * Purpose: main module of a FontDbox Object module
 * Author:  TGR
 * History: 3-Mar-94: TGR: created
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
#include "rmensure.h"
#include "mem.h"
#include "messages.h"
#include "objmodule.h"

#include "objects/toolbox.h"
#include "objects/fontdbox.h"

#include "object.h"
#include "auxiliary.h"
#include "create.h"
#include "delete.h"
#include "show.h"
#include "hide.h"
#include "getstate.h"
#include "miscop.h"
#include "events.h"

#include "task.h"

#include "FontDboxHdr.h"

#define MAX_CLASS_SWI_METHODS 7
static _kernel_oserror *(*class_swi_methods [MAX_CLASS_SWI_METHODS])(_kernel_swi_regs *r, TaskDescriptor *t) =
       {
            create_object,
            delete_object,
            NULL, /*copy_object,*/
            show_object,
            hide_object,
            getstate_object,
            miscop_object
       };



/* +++++++++++++++++++++++++++++++++ finalisation code +++++++++++++++++++++++++++++++++ */

#ifndef ROM
extern int Resources(void);
#endif

extern _kernel_oserror *FontDbox_finalise (int fatal, int podule, void *pw)
{
    IGNORE(fatal);
    IGNORE(podule);
    IGNORE(pw);

    /*
     * refuse to finalise if tasks active
     */

    if (task_any_active())
        return make_error (FontDbox_TasksActive, 0);

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

   /* deregister object module */
   objmodule_deregister(0, FontDbox_ObjectClass);

    /*
     * free up memory we may have left allocated
     */

    if (global_font_list) mem_freek (global_font_list);
    if (global_stringset1) mem_freek (global_stringset1);
    if (global_plain) mem_freek (global_plain);
    if (global_system) mem_freek (global_system);

    mem_free_all ();

    return NULL;
}


/* ++++++++++++++++++++++++++++++++ initialisation code +++++++++++++++++++++++++++++++ */


extern _kernel_oserror *FontDbox_init(const char *cmd_tail, int podule_base, void *pw)
{
    _kernel_oserror *e;
    int              buffer_size      = 0;

    IGNORE(cmd_tail);
    IGNORE(podule_base);
    IGNORE(pw);

   DEBUG debug_set_var_name("FontDbox$Debug");

   DEBUG debug_output ("M","FontDbox: code initialise\n");

   if ((e = rmensure ("Window", "Toolbox.Window", "1.26")) != NULL) return e;

    /*
     * register our messages file with Resource FS and MessageTrans
     */

#ifndef ROM
   if ((e = objmodule_register_resources(Resources())) != NULL)
      return e;
#endif

    objmodule_ensure_path("FontDbox$Path", "Resources:$.Resources.FontDbox.");

    if ((e = messages_file_open ("FontDbox:Messages")) != NULL)
        return e;
   DEBUG debug_output ("M","FontDbox: looking up global_plain\n");

   if ((e = messages_file_lookup ("Plain", 0, &buffer_size, 0)) != NULL)
      return e;

   if ((global_plain = mem_alloc (buffer_size)) == NULL)
      return make_error(FontDbox_AllocFailed,0);

   if ((e = messages_file_lookup ("Plain", global_plain, &buffer_size, 0)) !=NULL)
      return e;

   buffer_size = 0;

   DEBUG debug_output ("M","FontDbox: looking up global_system\n");

   if ((e = messages_file_lookup ("System", 0, &buffer_size, 0)) != NULL)
      return e;

   if ((global_system = mem_alloc (buffer_size)) == NULL)
      return make_error(FontDbox_AllocFailed,0);

   if ((e = messages_file_lookup ("System", global_system, &buffer_size, 0)) !=NULL)
      return e;

    /* register here with the Toolbox as an Object Module */
    return objmodule_register_with_toolbox(0, FontDbox_ObjectClass, FontDbox_ClassSWI, "FontDbox:Res");
}



/* +++++++++++++++++++++++++++++++++ service handler code ++++++++++++++++++++++++++++++ */


extern void FontDbox_services(int service_number, _kernel_swi_regs *r, void *pw)
{
    _kernel_oserror *e;

    IGNORE(pw);

   DEBUG debug_output ("M","FontDbox: svc 0x%x\n",service_number);

    switch (service_number)
    {

        case Service_FontsChanged:
            DEBUG debug_output ("M","FontDbox: fonts have changed\n");

            /* new Font$Path detected */

            if ((e = cache_fonts ()) != NULL)
               raise_toolbox_oserror (e, 0, -1);

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

        case Service_ToolboxStarting:
            /*
             * register with the Toolbox as an Object Module
             */

            objmodule_register_with_toolbox(0, FontDbox_ObjectClass, FontDbox_ClassSWI, "FontDbox:Res");
            break;

        default:
            break;
    }
}

/* ++++++++++++++++++++++++++++++++++++++ SWI code +++++++++++++++++++++++++++++++++++++ */


extern _kernel_oserror *FontDbox_SWI_handler(int swi_no, _kernel_swi_regs *r, void *pw)
{
    _kernel_oserror *e = NULL;
    TaskDescriptor  *t;

   DEBUG debug_output ("M","FontDbox: SWI 0x%x\n",FontDbox_SWIChunkBase+swi_no);

     IGNORE(pw);

    switch (swi_no)
    {
        case FontDbox_ClassSWI - FontDbox_00:
            if (r->r[0] < 0 || r->r[0] >= MAX_CLASS_SWI_METHODS)
            {
                return make_error_hex(FontDbox_NoSuchMethod,1,r->r[0]);
            }
            else
            {
                t = task_find (r->r[3]);

                if (t == NULL)
                {
                    return make_error_hex(FontDbox_NoSuchTask,1,r->r[3]);
                }

            DEBUG debug_output ("M","FontDbox: class SWI method %d\n",r->r[0]);
                e = (*class_swi_methods[r->r[0]])(r, t);
            }
            break;

        case FontDbox_PostFilter - FontDbox_00:
            e = events_postfilter (r);
            break;

        case FontDbox_PreFilter - FontDbox_00:
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

extern _kernel_oserror *FontDbox_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
    IGNORE(argc);
    IGNORE(pw);
    IGNORE(arg_string);

    switch (cmd_no)
    {
        case CMD_FontDbox_Memory:
            mem_print_list();
            break;

        default:
            break;
    }

    return NULL;
}
#endif
