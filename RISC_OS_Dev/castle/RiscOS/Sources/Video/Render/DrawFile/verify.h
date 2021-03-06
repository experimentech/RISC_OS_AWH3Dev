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
#ifndef verify_H
#define verify_H

/*verify.h - header file for drawfile*/

#ifndef os_H
   #include "os.h"
#endif

#ifndef drawfile_H
   #include "drawfile.h"
#endif

extern char *verify_lookup_font_index (byte, drawfile_object *);

extern os_error *verify_diagram (drawfile_diagram *, int);

extern osbool verify_overlap (os_box *, os_box *);

extern callback_fn verify_font_table;
extern callback_fn verify_group;
extern callback_fn verify_text;
extern callback_fn verify_tagged;
extern callback_fn verify_trfm_text;

#endif
