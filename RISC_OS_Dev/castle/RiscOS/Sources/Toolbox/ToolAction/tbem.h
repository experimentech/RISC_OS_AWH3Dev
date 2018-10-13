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

#define xwimp_set_icon_state(a,b,c,d)               ((os_error *)_swix(Wimp_SetIconState, _BLOCK(1), a,b,c,d))
#define xwimp_get_icon_state(a)                     ((os_error *)_swix(Wimp_GetIconState, _IN(1), a))
#define xwimp_get_window_state(a)                   ((os_error *)_swix(Wimp_GetWindowState, _IN(1), a))
#define xwimp_delete_icon(a,b)                      ((os_error *)_swix(Wimp_DeleteIcon, _BLOCK(1), a,b))

#undef  Window_SupportExternal
#define Window_SupportExternal                  0x82887
#undef  XWindow_SupportExternal
#define XWindow_SupportExternal                 0xA2887
#undef  WindowSupportExternal_CreateIcon
#define WindowSupportExternal_CreateIcon        0x0
#undef  WindowSupportExternal_CreateObject
#define WindowSupportExternal_CreateObject      0x2
#undef  WindowSupportExternal_CreateGadget
#define WindowSupportExternal_CreateGadget      0x3
#undef  WindowSupportExternal_Alloc
#define WindowSupportExternal_Alloc             0x4
#undef  WindowSupportExternal_Free
#define WindowSupportExternal_Free              0x5
#undef  WindowSupportExternal_Realloc
#define WindowSupportExternal_Realloc           0x6

#undef  Window_RegisterExternal
#define Window_RegisterExternal                 0x82885
#undef  XWindow_RegisterExternal
#define XWindow_RegisterExternal                0xA2885
#undef  Window_DeregisterExternal
#define Window_DeregisterExternal               0x82886
#undef  XWindow_DeregisterExternal
#define XWindow_DeregisterExternal              0xA2886

/************************
 * Constant definitions *
 ************************/
#define windowsupportexternal_HANDLER_ADD       1
#define windowsupportexternal_HANDLER_REMOVE    2
#define windowsupportexternal_HANDLER_FADE      3
#define windowsupportexternal_HANDLER_METHOD    4
#define windowsupportexternal_HANDLER_CLICK     6
#define windowsupportexternal_HANDLER_PLOT      9
#define windowsupportexternal_HANDLER_SET_FOCUS 10
#define windowsupportexternal_HANDLER_MOVE      11
#define windowsupportexternal_HANDLER_POST_ADD  12

#define xwindowsupportexternal_create_icon(a,b,c)   ((os_error *)_swix(Window_SupportExternal, _INR(0,2)|_OUT(0), a,WindowSupportExternal_CreateIcon,b,c))
#define xwindowsupportexternal_create_object(a,b,c) ((os_error *)_swix(Window_SupportExternal, _INR(0,2)|_OUT(0), a,WindowSupportExternal_CreateObject,b,c))
#define xwindowsupportexternal_alloc(a,b,c)         ((os_error *)_swix(Window_SupportExternal, _INR(0,2)|_OUT(0), a,WindowSupportExternal_Alloc,b,c))
#define xwindowsupportexternal_free(a,b)            ((os_error *)_swix(Window_SupportExternal, _INR(0,2), a,WindowSupportExternal_Free,b))

#define xwindow_register_external(a,b,c)            ((os_error *)_swix(Window_RegisterExternal, _INR(0,2), a,b,c))
#define xwindow_deregister_external(a,b,c)          ((os_error *)_swix(Window_DeregisterExternal, _INR(0,2), a,b,c))

#define xtoolbox_delete_object(a,b)                 ((os_error *)_swix(Toolbox_DeleteObject, _INR(0,1), a,b))
#define xtoolbox_raise_toolbox_event(a,b,c,d)       ((os_error *)_swix(Toolbox_RaiseToolboxEvent, _INR(0,3), a,b,c,d))
#define xtoolbox_show_object(a,b,c,d,e,f)           ((os_error *)_swix(Toolbox_ShowObject, _INR(0,5), a,b,c,d,e,f))
