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
/* Title:   show.h
 * Purpose: show a Generic Object
 * Author:  IDJ
 * History: 7-Oct-93: IDJ: created
 *          19-Sep-96:EPW: Modified show__open_window() to allow nested
 *                         windows to be opened with new wimp
 *
 */


#ifndef __show_h
#define __show_h

#include "kernel.h"

#ifndef __task_h
#include "task.h"
#endif

extern WindowInternal *ShowingAsMenu;

extern _kernel_oserror *show_object (_kernel_swi_regs *r, TaskDescriptor *t);
extern _kernel_oserror *show_do_the_show (WindowInternal *w, int r0, int r2, void *r3);
_kernel_oserror *show__open_window (int r0, wimp_NestedOpenWindow *open,WindowInternal *w, unsigned int parent_window_handle, unsigned int alignment_flags);
_kernel_oserror *show_with_panes (WindowInternal *w, wimp_NestedOpenWindow *open, unsigned int magic, unsigned int parent_window_handle, unsigned int alignment_flags);

extern void show_shutdown(int taskhandle);

#endif

