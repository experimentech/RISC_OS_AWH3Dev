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
/* File:    object.h
 * Purpose: Processing objects
 * Author:  Ian Johnson
 * History: 10-Aug-93: IDJ:   created
 *
 */

#ifndef __object_h
#define __object_h

#ifndef __Toolbox_h
#include "objects.toolbox.h"
#endif

#include "kernel.h"

/**************************************** object data structure *******************************/

/* On creating an Object, the client is passed back an ObjectID which is in fact a pointer
   to one of these structures (but he doesn't know it).

   Objects are stored in a linked list for each client task.  On every task swap,
   the global variable "task" is set to the task descriptor for the current task.

   The Toolbox maintains a data structure for each Object (see below), which contains
   a copy of the original template header.  Only the class, flags, version and name
   fields are of any relevance though.

   The Toolbox passes a pointer to the object template to an Object module which will
   do with it as it wishes, and return an internal handle which it uses to identify
   that Object.
*/

#define GUARD_WORD   0x544a424f      /* 'OBJT' */

typedef struct object
{
    struct object        *next;                /* next in chain of Objects for client task */
    struct object        *prev;                /* previous in chain of Objects for client task */
    int                   guard;               /* guard word (must be OBJT) */
    ObjectTemplateHeader  header;              /* the original template header (tweaked) */
    int                   state;               /* state of the object as known by the Toolbox */
    ObjectID              self_id;             /* to help object ID validation */
    void                 *client_handle;       /* as set by Toolbox_SetClientHandle */
    ObjectID              parent_id;           /* Object which showed this one */
    ComponentID           parent_component;    /* component causing show */
    ObjectID              ancestor_id;
    ComponentID           ancestor_component;
    void                 *internal_handle;     /* internal handle returned by class module */
    unsigned int          reference_count;     /* inc when create/copy, dec when delete */
} object_t;



/* ********************************** client SWIs ****************************/

extern _kernel_oserror *object_create (_kernel_swi_regs *r);

/*
 *   Entry:  R0 = flags
 *           R1 -> name of template
 *      OR   R1 -> description block (if bit 1 of flags set)
 *
 *   Exit:
 *           R0 = ID of created Object
 *
 */


extern _kernel_oserror *object_delete (_kernel_swi_regs *r);

/*
 *   Entry:
 *           R0  =  flags
 *                  bit 0 set means delete recursively
 *           R1  =  Object ID
 *
 *   Exit:
 *                  R1-R9 preserved.
 *
 */


extern _kernel_oserror *object_show (_kernel_swi_regs *r);

/*
 *   Entry:
 *           R0  =  flags
 *           R1  =  Object ID
 *           R2  =  -1
 *   OR      R2  -> buffer giving Object-specific data for showing this
 *                Object
 *           R3  =  Parent Object ID
 *           R4  =  Parent Component ID
 *
 *   Exit:
 *           R1-R9 preserved
 *
 */


extern _kernel_oserror *object_hide (_kernel_swi_regs *r);

/*
 *   Entry:
 *           R0  =  flags
 *           R1  =  Object ID
 *
 *   Exit:
 *           R1-R9 preserved
 *
 */


extern _kernel_oserror *object_get_state (_kernel_swi_regs *r);

/*
 *   Entry:
 *           R0  =  flags
 *           R1  =  Object ID
 *
 *   Exit:
 *           R0  =  state
 *
 */


extern _kernel_oserror *object_miscop (_kernel_swi_regs *r);
extern _kernel_oserror *object_set_client_handle (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object ID
 *         R2  =  client handle
 *
 *   Exit:
 *         R1-R9 preserved
 *
 */


extern _kernel_oserror *object_get_client_handle (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object ID
 *
 *   Exit:
 *         R0 = client handle for this Object
 *
 */


extern _kernel_oserror *object_get_class (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object ID
 *
 *   Exit:
 *         R0 = Object class
 *
 */


extern _kernel_oserror *object_get_parent (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object ID
 *
 *   Exit:
 *         R0 = Parent ID
 *         R1 = Parent component ID
 *
 */


extern _kernel_oserror *object_get_ancestor (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object ID
 *
 *   Exit:
 *         R0 = Ancestor ID
 *         R1 = Ancestor component ID
 *
 */


extern _kernel_oserror *object_get_template_name (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object ID
 *         R2  -> buffer
 *         R3  =  size of buffer
 *
 *   Exit:
 *        if R2 was zero
 *           R3 = length of buffer required
 *         else
 *            Buffer pointed at by R2 holds template name
 *            R3 holds number of bytes written to buffer
 *
 */


/********************************* class module SWIs *************************/

extern _kernel_oserror *object_get_internal_handle (_kernel_swi_regs *r);
/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object ID
 *
 *   Exit:
 *         R0  =  internal handle
 *
 */


extern _kernel_oserror *object_register_module (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object Class
 *         R2  =  Class SWI Number
 *
 *   Exit:
 *         R1-R9 preserved
 *
 */


extern _kernel_oserror *object_deregister_module (_kernel_swi_regs *r);

/*
 *   Entry:
 *         R0  =  flags
 *         R1  =  Object Class
 *
 *   Exit:
 *         R1-R9 preserved
 *
 */

/***************************************** object manipulation **************************/

extern void object_remove_list (void);


#endif
