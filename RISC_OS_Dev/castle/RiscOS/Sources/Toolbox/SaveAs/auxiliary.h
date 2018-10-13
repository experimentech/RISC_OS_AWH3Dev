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
/* Title:   auxiliary.h
 * Purpose: support functions for the SaveAs object class
 * Author:  TGR
 * History: 16-Feb-94: TGR: created
 *
 *
 */

#ifndef __auxiliary_h
#define __auxiliary_h

#include "kernel.h"

#ifndef __toolbox_h
#include "objects.toolbox.h"
#endif

#ifndef __saveas_h
#include "objects.saveas.h"
#endif

#ifndef __wimp_h
#include "twimp.h"
#endif

#ifndef __mem_h
#include "mem.h"
#endif

#include "object.h"
#include "task.h"

#define mem_freek(A) mem_free(A,"SaveAs")
#define mem_alloc(A) mem_allocate(A,"SaveAs")

/*
extern ObjectID          global_menu;
*/
extern SaveAsInternal   *global_next;
extern int               global_window_count;  /* No. of _displayed_ windows */

extern EventInterest   messages_of_interest[];

extern EventInterest   events_of_interest[];

extern EventInterest   toolbox_events_of_interest[];

/*
extern _kernel_oserror *dialogue_completed (ObjectID object_id);
*/
extern _kernel_oserror *save_completed (SaveAsInternal *internal, char *filename);
extern SaveAsInternal  *find_internal (TaskDescriptor *t, ObjectID sub_object_id);
extern SaveAsInternal  *find_internal_from_ref (TaskDescriptor *t, int ref);
extern _kernel_oserror *show_actual (void);
extern _kernel_oserror *transfer_block (TaskDescriptor *t, SaveAsInternal *internal, void *buffer, size_t buffer_size, size_t transfer_size, int destination_task, int your_ref, void *destination_buffer);
void find_file_icon (int filetype, char *buffer);

extern _kernel_oserror *da_wimp_send_message(int swi, _kernel_swi_regs *in, _kernel_swi_regs *out);

#endif
