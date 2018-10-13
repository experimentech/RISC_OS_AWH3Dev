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
/****************************************************************************
 * This source file was written by Acorn Computers Limited. It is part of   *
 * the RISCOS library for writing applications in C for RISC OS. It may be  *
 * used freely in the creation of programs for Archimedes. It should be     *
 * used with Acorn's C Compiler Release 3 or later.                         *
 *                                                                          *
 ***************************************************************************/
/*
 * Title: fontselect.h
 * Purpose: Consistent interface to font choosing
 *
 */

#ifndef __fontselect_h
#define __fontselect_h


typedef BOOL (*fontselect_fn)(char *font_name, double width, double height, wimp_eventstr *event );

/* --------------------------- fontselect_init -----------------------------
 * Description:   Read in the font list and prepare data for the font selector window
 *
 * Parameters:
 * Returns:       TRUE if initialisation succeeded.
 * Other Info:
 */
int fontselect_init( void );




/* --------------------------- fontselect_closedown -----------------------------
 * Description:   Close the font selector windows if they are open, and free the font selector data structures
 *
 * Parameters:
 * Returns:
 * Other Info:    This call is provided to return the machine to the state it was in before a call of fontselect_init()
 */
void fontselect_closedown( void );



/* --------------------------- fontselect_closewindows -----------------------------
 * Description:   Close the font selector windows if they are open
 *
 * Parameters:
 * Returns:
 * Other Info:    This call will close the font selector windows and unattach the handlers, if they are open.
 */
void fontselect_closewindows( void );



/* --------------------------- fontselect_selector -----------------------------
 * Description:   Opens up or reopens the font chooser window.
 *
 * Parameters:    char *title                -- The title for the window (can be NULL if flags SETTITLE is clear)
 *                int flags                  -- The flags for the call (see below)
 *                char *font_name            -- The font name to set the window contents to (only if SETFONT is set)
 *                double width               -- The width in point size of the font
 *                double height              --
 *                fontselect_fn unknown_icon --
 * Returns:       The window handle of the font selector main window, if the function
 *                call was successful. Otherwise it returns 0.
 * Other Info:    The flags word allows the call to have different effects.
 *                    If fontselect_SETFONT is set then the window contents wil be updated to reflect the font choice passed in
 *                    If fontselect_SETTITLE is set then the title of the window will be set, otherwise title is ignored.
 *                    If fontselect_REOPEN is set then the font selector will only open the window if it is already open. This
 *                      lets the application update the contents of the window only if it is currently open.
 *                Note that the fontselect_init() must be called before this routine.
 */
int fontselect_selector( char *title, int flags, char *font_name, double width, double height, fontselect_fn unknown_icon_routine );

#define fontselect_REOPEN    0x001
#define fontselect_SETTITLE  0x002
#define fontselect_SETFONT   0x004



/* ---------------------------- fontselect_attach_menu ----------------------------
 * Description:   Attaches a menu to all four font selector windows
 *
 * Parameters:    menu mn                        -- menu to attach
 *                event_menu_proc menu_processor -- menu processor for the menu events
 *                void *handle                   -- handle to pass to the menu processor
 * Returns:       TRUE if the menus were attached, FALSE otherwise
 * Other Info:    none.
 */

BOOL fontselect_attach_menu( menu mn, event_menu_proc menu_processor, void *handle );



#endif


/* end fontselect.h */
