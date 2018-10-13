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
/* Title:   Menu.c
 * Purpose: main module of a Menu Object module
 * Author:  TGR
 * History: 2-Nov-93: TGR: created from IDJ template
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"
#include "swis.h"
#include "Global/Services.h"

#include "const.h"
#include "macros.h"
#include "string32.h"
#include "messages.h"
#include "objects/toolbox.h"
#include "objects/menu.h"
#include "debug.h"
#include "rmensure.h"
#include "mem.h"
#include "os.h"
#include "objmodule.h"

#include "auxiliary.h"
#include "create.h"
#include "delete.h"
#include "show.h"
#include "hide.h"
#include "getstate.h"
#include "miscop.h"
#include "events.h"

#include "task.h"

#include "MenuHdr.h"


#define MAX_CLASS_SWI_METHODS 7


static _kernel_oserror *(*class_swi_methods [MAX_CLASS_SWI_METHODS])(_kernel_swi_regs *r, TaskDescriptor *t) =
      {
         create_menu,
         delete_menu,
         NULL, /*copy_menu,*/
         show_menu,
         hide_menu,
         getstate_menu,
         miscop_menu
      };


/* +++++++++++++++++++++++++++++++++ finalisation code +++++++++++++++++++++++++++++++++ */

#ifndef ROM
extern int Resources(void);
#endif


extern _kernel_oserror *Menu_finalise (int fatal, int podule, void *pw)
{
    IGNORE(fatal);
    IGNORE(podule);
    IGNORE(pw);

    /*
     * refuse to finalise if tasks active
     */

    if (task_any_active())
        return make_error (Menu_TasksActive, 0);

   /*
    * close our messages file
    */

   messages_file_close ();


#ifndef ROM
    /*
     * ... and deregister from ResourceFS
     */

    objmodule_deregister_resources(Resources());
#endif

   /* hide menus before deletion */

   if (global_menu.flags & GLOBAL_MENU_INFO_FLAGS_IS_SHOWING) {

       DEBUG debug_output ("M","Menu: hiding menus\n");
       _swix(Wimp_CreateMenu, _IN(1), -1);
   }

   /* deregister object module */
   objmodule_deregister(0, Menu_ObjectClass);

   /*
    * free up memory we may have left allocated
    */

   DEBUG debug_output ("M","Menu: exiting\n");
   mem_free_all ();

   return NULL;
}


/* ++++++++++++++++++++++++++++++++ initialisation code +++++++++++++++++++++++++++++++ */


extern _kernel_oserror *Menu_init(const char *cmd_tail, int podule_base, void *pw)
{
   _kernel_swi_regs  regs;
   _kernel_oserror  *e;

   IGNORE(cmd_tail);
   IGNORE(podule_base);
   IGNORE(pw);

   DEBUG debug_set_var_name("Menu$Debug");

   rmensure ("Toolbox", "Toolbox.Toolbox", "1.29");

   /*
    * register our messages file with Resource FS and MessageTrans
    */

#ifndef ROM
   objmodule_register_resources(Resources());
#endif

   DEBUG debug_output ("M","Menu: code initialise\n");

   objmodule_ensure_path("Menu$Path", "Resources:$.Resources.Menu.");
   if ((e = messages_file_open ("Menu:Messages")) != NULL)
      return e;


   /* WIMP hack .... explanation follows:
    *   On RISC OS 3.50 and above a call to Wimp_CreateMenu with 'KEEP' as the menu handle
    *   (wimp_KeepMenu) will allow menus to stay on screen after an adjust click _even_
    *   over successive calls to Wimp_Poll. On lower versions, however we merely alter
    *   a byte in WIMP workspace to do the same thing. This was NOT my idea - TGR
    *
    *   Find out what version of OS it is, if it's lower than 350 then remember workspace
    *   pointer for future use, if not set the pointer to NULL to indicate its redundance.
    */

   regs.r[0] = 7;

   if ((e = _kernel_swi (Wimp_ReadSysInfo, &regs, &regs)) != NULL)
      return e;

   if (regs.r[0] < 350) {
      regs.r[0] = os_Module_LookupModuleName;
      regs.r[1] = (int) "WindowManager";

      if ((e = _kernel_swi (OS_Module, &regs, &regs)) != NULL)
         return e;

      global_wimp_wrkspc = (int *) regs.r[4]; /* NULL by default (see auxiliary.c) */
   }

   /* register here with the Toolbox as an Object Module */
   return objmodule_register_with_toolbox(0, Menu_ObjectClass, Menu_ClassSWI, 0);
}



/* +++++++++++++++++++++++++++++++++ service handler code ++++++++++++++++++++++++++++++ */


extern void Menu_services(int service_number, _kernel_swi_regs *r, void *pw)
{
   IGNORE(pw);

   DEBUG debug_output ("M","Menu: svc 0x%x\n",service_number);

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
            objmodule_register_with_toolbox(0, Menu_ObjectClass, Menu_ClassSWI, 0);
            break;

      default:
         break;
   }
}

/* ++++++++++++++++++++++++++++++++++++++ SWI code +++++++++++++++++++++++++++++++++++++ */


extern _kernel_oserror *Menu_SWI_handler(int swi_no, _kernel_swi_regs *r, void *pw)
{
   _kernel_oserror *e = NULL;
   TaskDescriptor  *t;

   DEBUG debug_output ("M","Menu: SWI 0x%x\n",Menu_SWIChunkBase+swi_no);

   IGNORE(pw);

   switch (swi_no)
   {
      case Menu_ClassSWI - Menu_00:
       if (r->r[0] < 0 || r->r[0] >= MAX_CLASS_SWI_METHODS)
       {
         return make_error_hex(Menu_NoSuchMethod,1,r->r[0]);
       }
       else
       {
         t = task_find (r->r[3]);
         if (t == NULL)
         {
           return make_error_hex(Menu_NoSuchTask,1,r->r[3]);
         }
         DEBUG debug_output ("M","Menu: class SWI method %d\n",r->r[0]);
         e = (*class_swi_methods[r->r[0]])(r, t);
       }
       break;

     case Menu_PostFilter - Menu_00:
       e = events_postfilter (r);
       break;

     case Menu_PreFilter - Menu_00:
       e = events_prefilter (r);
       break;

     case Menu_UpdateTree - Menu_00:
       e = update_tree ();
       break;

     default:
       e = error_BAD_SWI;
       break;
   }

   return e;
}

#if debugging
/* ++++++++++++++++++++++++++++++++++++++ star commands ++++++++++++++++++++++++++++++++++++*/

extern _kernel_oserror *Menu_commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
    IGNORE(argc);
    IGNORE(pw);
    IGNORE(arg_string);

    switch (cmd_no)
    {
        case CMD_Menu_Memory:
            mem_print_list();
            break;

        default:
            break;
    }

    return NULL;
}
#endif
