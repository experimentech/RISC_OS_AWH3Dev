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
#ifndef gadget_H
#define gadget_H

/* C header file for Gadget
 * written by DefMod (Aug 30 1995) on Tue Sep  5 16:29:18 1995
 * Jonathan Coxhead, Acorn Computers Ltd
 */

#ifndef types_H
#include "types.h"
#endif

#ifndef toolbox_H
#include "toolbox.h"
#endif

/**********************************
 * SWI names and SWI reason codes *
 **********************************/
#undef  Gadget_GetFlags
#define Gadget_GetFlags                         0x40
#undef  Gadget_SetFlags
#define Gadget_SetFlags                         0x41
#undef  Gadget_SetHelpMessage
#define Gadget_SetHelpMessage                   0x42
#undef  Gadget_GetHelpMessage
#define Gadget_GetHelpMessage                   0x43
#undef  Gadget_GetIconList
#define Gadget_GetIconList                      0x44
#undef  Gadget_SetFocus
#define Gadget_SetFocus                         0x45
#undef  Gadget_GetType
#define Gadget_GetType                          0x46
#undef  Gadget_MoveGadget
#define Gadget_MoveGadget                       0x47
#undef  Gadget_GetBBox
#define Gadget_GetBBox                          0x48

/************************************
 * Structure and union declarations *
 ************************************/
typedef struct gadget_object                    gadget_object;
typedef struct gadget_extension                 gadget_extension;
typedef struct gadget_extension_list            gadget_extension_list;

/********************
 * Type definitions *
 ********************/
typedef bits gadget_flags;

struct gadget_object
   {  gadget_flags flags;
      toolbox_class class_no;
//      short size;
      os_box bbox;
      toolbox_c cmp;
      toolbox_msg_reference help_message;
      int help_limit;
      int gadget [UNKNOWN];
   };

#define gadget_OBJECT(N) \
   struct \
      {  gadget_flags flags; \
         toolbox_class class_no; \
//         short size; \
         os_box bbox; \
         toolbox_c cmp; \
         toolbox_msg_reference help_message; \
         int help_limit; \
         int gadget [N]; \
      }

#define gadget_SIZEOF_OBJECT(N) \
   (offsetof (gadget_object, gadget) + \
         (N)*sizeof ((gadget_object *) NULL)->gadget)

typedef bits gadget_feature;

struct gadget_extension
   {  int type;
      gadget_flags valid_flags;
      gadget_feature features;
   };

struct gadget_extension_list
   {  gadget_extension gadget [UNKNOWN];
   };

/************************
 * Constant definitions *
 ************************/
#define gadget_FADED                            ((gadget_flags) 0x80000000u)
#define gadget_AT_BACK                          ((gadget_flags) 0x40000000u)
#define gadget_NO_HANDLER                       0x0u
#define gadget_DEFAULT_HANDLER                  0x1u
#define gadget_PRIVATE_HANDLER                  0x2u
#define gadget_FEATURE_ADD_SHIFT                0
#define gadget_FEATURE_ADD                      ((gadget_feature) 0x3u)
#define gadget_FEATURE_REMOVE_SHIFT             2
#define gadget_FEATURE_REMOVE                   ((gadget_feature) 0xCu)
#define gadget_FEATURE_POST_ADD_SHIFT           4
#define gadget_FEATURE_POST_ADD                 ((gadget_feature) 0x30u)
#define gadget_FEATURE_METHOD_SHIFT             6
#define gadget_FEATURE_METHOD                   ((gadget_feature) 0xC0u)
#define gadget_FEATURE_CLICK_SHIFT              10
#define gadget_FEATURE_CLICK                    ((gadget_feature) 0xC00u)
#define gadget_FEATURE_PLOT_SHIFT               16
#define gadget_FEATURE_PLOT                     ((gadget_feature) 0x30000u)
#define gadget_FEATURE_SET_FOCUS_SHIFT          18
#define gadget_FEATURE_SET_FOCUS                ((gadget_feature) 0xC0000u)
#define gadget_FEATURE_MOVE_SHIFT               20
#define gadget_FEATURE_MOVE                     ((gadget_feature) 0x300000u)
#define gadget_FEATURE_FADE_SHIFT               22
#define gadget_FEATURE_FADE                     ((gadget_feature) 0xC00000u)

/*************************
 * Function declarations *
 *************************/

#ifdef __cplusplus
   extern "C" {
#endif

/* ------------------------------------------------------------------------
 * Function:      gadget_get_flags()
 *
 * Description:   Gets the flags for a particular gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *
 * Output:        flags_out - value of R0 on exit (X version only)
 *
 * Returns:       R0 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x40.
 */

extern os_error *xgadget_get_flags (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      gadget_flags *flags_out);
extern gadget_flags gadget_get_flags (bits flags,
      toolbox_o window,
      toolbox_c gadget);

/* ------------------------------------------------------------------------
 * Function:      gadget_set_flags()
 *
 * Description:   Sets the flags for a particular gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *                flags_in - value of R4 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x41.
 */

extern os_error *xgadget_set_flags (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      gadget_flags flags_in);
extern void gadget_set_flags (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      gadget_flags flags_in);

/* ------------------------------------------------------------------------
 * Function:      gadget_set_help_message()
 *
 * Description:   Sets the help message for a particular gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *                help_message - value of R4 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x42.
 */

extern os_error *xgadget_set_help_message (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      char const *help_message);
extern void gadget_set_help_message (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      char const *help_message);

/* ------------------------------------------------------------------------
 * Function:      gadget_get_help_message()
 *
 * Description:   Gets the help message that is associated with a
 *                particular gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *                help_message - value of R4 on entry
 *                size - value of R5 on entry
 *
 * Output:        used - value of R5 on exit (X version only)
 *
 * Returns:       R5 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x43.
 */

extern os_error *xgadget_get_help_message (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      char *help_message,
      int size,
      int *used);
extern int gadget_get_help_message (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      char *help_message,
      int size);

/* ------------------------------------------------------------------------
 * Function:      gadget_get_icon_list()
 *
 * Description:   Gets the list of icon handles that are associated with a
 *                gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *                buffer - value of R4 on entry
 *                size - value of R5 on entry
 *
 * Output:        used - value of R5 on exit (X version only)
 *
 * Returns:       R5 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x44.
 */

extern os_error *xgadget_get_icon_list (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      wimp_i *buffer,
      int size,
      int *used);
extern int gadget_get_icon_list (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      wimp_i *buffer,
      int size);

/* ------------------------------------------------------------------------
 * Function:      gadget_set_focus()
 *
 * Description:   Sets the type for the specified gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x45.
 */

extern os_error *xgadget_set_focus (bits flags,
      toolbox_o window,
      toolbox_c gadget);
extern void gadget_set_focus (bits flags,
      toolbox_o window,
      toolbox_c gadget);

/* ------------------------------------------------------------------------
 * Function:      gadget_get_type()
 *
 * Description:   Gets the type for the specified gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *
 * Output:        type - value of R0 on exit (X version only)
 *
 * Returns:       R0 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x46.
 */

extern os_error *xgadget_get_type (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      int *type);
extern int gadget_get_type (bits flags,
      toolbox_o window,
      toolbox_c gadget);

/* ------------------------------------------------------------------------
 * Function:      gadget_move_gadget()
 *
 * Description:   Moves an already created gadget in the specified window
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *                bbox - value of R4 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x47.
 */

extern os_error *xgadget_move_gadget (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      os_box const *bbox);
extern void gadget_move_gadget (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      os_box const *bbox);

/* ------------------------------------------------------------------------
 * Function:      gadget_get_bbox()
 *
 * Description:   Gets the bounding box of a gadget
 *
 * Input:         flags - value of R0 on entry
 *                window - value of R1 on entry
 *                gadget - value of R3 on entry
 *                bbox - value of R4 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x48.
 */

extern os_error *xgadget_get_bbox (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      os_box *bbox);
extern void gadget_get_bbox (bits flags,
      toolbox_o window,
      toolbox_c gadget,
      os_box *bbox);

#ifdef __cplusplus
   }
#endif

#endif
