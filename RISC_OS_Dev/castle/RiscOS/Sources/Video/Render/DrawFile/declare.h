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
#ifndef declare_H
#define declare_H

/*declare.h - header file for drawfile*/

#ifndef callback_H
   #include "callback.h"
#endif

#ifndef os_H
   #include "os.h"
#endif

#ifndef drawfile_H
   #include "drawfile.h"
#endif

extern os_error *declare (bits, drawfile_diagram *, int);

extern callback_fn declare_font_table;
extern callback_fn declare_group;
extern callback_fn declare_tagged;
extern callback_fn declare_text_area;

#endif
