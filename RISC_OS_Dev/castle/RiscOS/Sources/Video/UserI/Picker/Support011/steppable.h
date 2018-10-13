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
#ifndef steppable_H
#define steppable_H

/*steppable_s.h - support for a slider with adjust arrows and a writable
icon*/

/*From OSLib*/
#ifndef os_H
   #include "os.h"
#endif

#ifndef wimp_H
   #include "wimp.h"
#endif

/*From Support*/
#ifndef callback_H
   #include "callback.h"
#endif

#ifndef task_H
   #include "task.h"
#endif

typedef struct steppable_s *steppable_s;

 /* Types for the callbacks generated by this module.
  */
typedef os_error *steppable_value_changed (steppable_s v, int value,
      osbool dragging, void *);

typedef os_error *steppable_caret_moved (steppable_s, wimp_w, wimp_i,
      void *);

typedef
   struct steppable_steppable
   {  task_r r;
      callback_l list;
      wimp_w w;
      int value;
      int min; int max; int div;
      /*the slider*/
      wimp_i knob; wimp_i track;
      /*adjusters*/
      wimp_i up; wimp_i down;
      /*writable*/
      wimp_i writable; int prec;
      steppable_value_changed *value_changed_fn;
      steppable_caret_moved *caret_moved_fn;
      void *handle;
   }
   steppable_steppable;

 /* Function to register all the callbacks needed by the given steppable_s,
  * and map them to calls to the given callback functions. Also sets the
  * steppable_s to the given initial value.
  */

extern os_error *steppable_register (steppable_steppable *, steppable_s *);

 /* Function to deregister the callbacks and dispose of the steppable_s.
  */

extern os_error *steppable_deregister (steppable_s v);

 /* Function to set a steppable_s to a value, updating the icons
  * appropriately.
  */

extern os_error *steppable_set_value (steppable_s v, int value);

 /* Function to get the value of a steppable_s.
  */

extern os_error *steppable_get_value (steppable_s v, int *value);

#endif
