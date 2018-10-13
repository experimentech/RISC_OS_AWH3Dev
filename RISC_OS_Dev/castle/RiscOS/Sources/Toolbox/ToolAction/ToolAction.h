#ifndef toolaction_H
#define toolaction_H

/* C header file for ToolAction
 * written by DefMod (07 Jun 2001) on Fri Sep 28 12:04:39 2018
 * Castle 
 */

/*OSLib---efficient, type-safe, transparent, extensible,
   register-safe A P I coverage of RISC O S*/
/*Copyright © 1994 Jonathan Coxhead*/

/*
      OSLib is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 1, or (at your option)
   any later version.

      OSLib is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
   along with this programme; if not, write to the Free Software
   Foundation, Inc, 675 Mass Ave, Cambridge, MA 02139, U S A.
*/

#ifndef types_H
#include "oslib/types.h"
#endif

#ifndef os_H
#include "oslib/os.h"
#endif

#ifndef toolbox_H
#include "oslib/toolbox.h"
#endif

#if defined NAMESPACE_OSLIB
  namespace OSLib {
#endif

/**********************************
 * SWI names and SWI reason codes *
 **********************************/
#undef  ToolAction_ToolAction
#define ToolAction_ToolAction                   0x140140
#undef  XToolAction_ToolAction
#define XToolAction_ToolAction                  0x160140
#undef  ToolAction_SetIdent
#define ToolAction_SetIdent                     0x140140
#undef  ToolAction_GetIdent
#define ToolAction_GetIdent                     0x140141
#undef  ToolAction_SetAction
#define ToolAction_SetAction                    0x140142
#undef  ToolAction_GetAction
#define ToolAction_GetAction                    0x140143
#undef  ToolAction_SetClickShow
#define ToolAction_SetClickShow                 0x140144
#undef  ToolAction_GetClickShow
#define ToolAction_GetClickShow                 0x140145
#undef  ToolAction_SetState
#define ToolAction_SetState                     0x140146
#undef  ToolAction_GetState
#define ToolAction_GetState                     0x140147
#undef  ToolAction_SetPressed
#define ToolAction_SetPressed                   0x140148
#undef  ToolAction_GetPressed
#define ToolAction_GetPressed                   0x140149

/************************************
 * Structure and union declarations *
 ************************************/
typedef struct toolaction_object                toolaction_object;
typedef struct toolaction_action_selected       toolaction_action_selected;

/********************
 * Type definitions *
 ********************/
struct toolaction_object
   {  char *ident_off;
      int ident_off_limit;
      char *ident_on;
      int ident_on_limit;
      bits action_no;
      char *click_show_name;
      bits adjust_action_no;
      char *adjust_click_show_name;
      char *ident_fade;
      int ident_fade_limit;
   };

struct toolaction_action_selected
   {  osbool on;
   };

typedef bits toolaction_set_ident_flags;

/************************
 * Constant definitions *
 ************************/
#define error_TOOL_ACTION_OUT_OF_MEMORY         0x80E920u
#define error_TOOL_ACTION_CANT_CREATE_ICON      0x80E921u
#define error_TOOL_ACTION_CANT_CREATE_OBJECT    0x80E922u
#define toolaction_GENERATE_SELECTED_EVENT      ((gadget_flags) 0x1u)
#define toolaction_IS_TEXT                      ((gadget_flags) 0x2u)
      /*idents are displayed as text, else are sprite names*/
#define toolaction_ON                           ((gadget_flags) 0x4u)
      /*Initial state*/
#define toolaction_AUTO_TOGGLE                  ((gadget_flags) 0x8u)
      /*Toggle state on every click*/
#define toolaction_NO_PRESSED_SPRITE            ((gadget_flags) 0x10u)
      /*Don't use R5 validation command*/
#define toolaction_AUTO_REPEAT                  ((gadget_flags) 0x20u)
      /*Auto repeat whilst button is held down*/
#define toolaction_SHOW_TRANSIENT               ((gadget_flags) 0x40u)
      /*Show object transiently*/
#define toolaction_SHOW_AS_POP_UP               ((gadget_flags) 0x80u)
      /*Show object aligned to top right of gadget*/
#define toolaction_HAS_FADE_SPRITE              ((gadget_flags) 0x100u)
      /*Has separate sprite for when faded*/
#define toolaction_SELECT_WHEN_OVER             ((gadget_flags) 0x200u)
      /*Button selects when pointer is over it*/
#define class_TOOL_ACTION                       ((toolbox_class) 0x4014u)
#define action_TOOL_ACTION_SELECTED             0x140140u
#define toolaction_SELECTED_ADJUST              0x1u
#define toolaction_SELECTED_SELECT              0x4u
#define toolaction_SET_IDENT_OFF                0
#define toolaction_SET_IDENT_ON                 1
#define toolaction_SET_IDENT_FADE               2
#define toolaction_SET_IDENT_WHICH              ((toolaction_set_ident_flags) 0xFu)

/*************************
 * Function declarations *
 *************************/

#ifdef __cplusplus
   extern "C" {
#endif

/* ------------------------------------------------------------------------
 * Function:      toolaction_set_ident()
 *
 * Description:   Set the ident string for off or on, depending on the
 *                flags
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *                ident - value of R4 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140140.
 */

extern os_error *xtoolaction_set_ident (toolaction_set_ident_flags flags,
      toolbox_o obj,
      toolbox_c cmp,
      char const *ident);
extern void toolaction_set_ident (toolaction_set_ident_flags flags,
      toolbox_o obj,
      toolbox_c cmp,
      char const *ident);

/* ------------------------------------------------------------------------
 * Function:      toolaction_get_ident()
 *
 * Description:   Read the ident string for off or on, depending on the
 *                flags
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *                ident - value of R4 on entry
 *                size - value of R5 on entry
 *
 * Output:        used - value of R5 on exit (X version only)
 *
 * Returns:       R5 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140141.
 */

extern os_error *xtoolaction_get_ident (toolaction_set_ident_flags flags,
      toolbox_o obj,
      toolbox_c cmp,
      char *ident,
      int size,
      int *used);
extern int toolaction_get_ident (toolaction_set_ident_flags flags,
      toolbox_o obj,
      toolbox_c cmp,
      char *ident,
      int size);

/* ------------------------------------------------------------------------
 * Function:      toolaction_set_action()
 *
 * Description:   Set the actions to be raised when the gadget is clicked
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *                select_action_no - value of R4 on entry
 *                adjust_action_no - value of R5 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140142.
 */

extern os_error *xtoolaction_set_action (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      bits select_action_no,
      bits adjust_action_no);
extern void toolaction_set_action (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      bits select_action_no,
      bits adjust_action_no);

/* ------------------------------------------------------------------------
 * Function:      toolaction_get_action()
 *
 * Description:   Read the actions to be raised when the gadget is clicked
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *
 * Output:        select_action_no - value of R0 on exit (X version only)
 *                adjust_action_no - value of R1 on exit
 *
 * Returns:       R0 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140143.
 */

extern os_error *xtoolaction_get_action (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      bits *select_action_no,
      bits *adjust_action_no);
extern bits toolaction_get_action (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      bits *adjust_action_no);

/* ------------------------------------------------------------------------
 * Function:      toolaction_set_click_show()
 *
 * Description:   Set the objects to be shown when the gadget is clicked
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *                select_show_obj - value of R4 on entry
 *                adjust_show_obj - value of R5 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140144.
 */

extern os_error *xtoolaction_set_click_show (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      toolbox_o select_show_obj,
      toolbox_o adjust_show_obj);
extern void toolaction_set_click_show (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      toolbox_o select_show_obj,
      toolbox_o adjust_show_obj);

/* ------------------------------------------------------------------------
 * Function:      toolaction_get_click_show()
 *
 * Description:   Read the objects to be shown when the gadget is clicked
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *
 * Output:        select_show_obj - value of R0 on exit (X version only)
 *                adjust_show_obj - value of R1 on exit
 *
 * Returns:       R0 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140145.
 */

extern os_error *xtoolaction_get_click_show (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      toolbox_o *select_show_obj,
      toolbox_o *adjust_show_obj);
extern toolbox_o toolaction_get_click_show (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      toolbox_o *adjust_show_obj);

/* ------------------------------------------------------------------------
 * Function:      toolaction_set_state()
 *
 * Description:   Set the state
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *                on - value of R4 on entry
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140146.
 */

extern os_error *xtoolaction_set_state (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      osbool on);
extern void toolaction_set_state (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      osbool on);

/* ------------------------------------------------------------------------
 * Function:      toolaction_get_state()
 *
 * Description:   Read the state
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *
 * Output:        on - value of R0 on exit (X version only)
 *
 * Returns:       R0 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC6 with R2 = 0x140147.
 */

extern os_error *xtoolaction_get_state (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      osbool *on);
extern osbool toolaction_get_state (bits flags,
      toolbox_o obj,
      toolbox_c cmp);

/* ------------------------------------------------------------------------
 * Function:      toolaction_set_pressed()
 *
 * Description:   Set the pressed state
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *                pressed - value of R4 on entry
 *
 * Other notes:   Calls SWI 0x44EC7 with R2 = 0x140148.
 */

extern os_error *xtoolaction_set_pressed (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      osbool pressed);
extern void toolaction_set_pressed (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      osbool pressed);

/* ------------------------------------------------------------------------
 * Function:      toolaction_get_pressed()
 *
 * Description:   Read the pressed state
 *
 * Input:         flags - value of R0 on entry
 *                obj - value of R1 on entry
 *                cmp - value of R3 on entry
 *
 * Output:        pressed - value of R0 on exit (X version only)
 *
 * Returns:       R0 (non-X version only)
 *
 * Other notes:   Calls SWI 0x44EC8 with R2 = 0x140149.
 */

extern os_error *xtoolaction_get_pressed (bits flags,
      toolbox_o obj,
      toolbox_c cmp,
      osbool *pressed);
extern osbool toolaction_get_pressed (bits flags,
      toolbox_o obj,
      toolbox_c cmp);

#ifdef __cplusplus
   }
#endif

#if defined NAMESPACE_OSLIB
  } 
#endif

#endif
