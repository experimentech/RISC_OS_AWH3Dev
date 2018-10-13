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

/* Title:    magnify.h
 * Purpose:  Display and entry of magnification factors
 *
 */

#ifndef __magnify_h
#define __magnify_h

/* ---------------------------- magnify_select ----------------------------
 * Description:  Display dialogue box to set magnification factors.
 *
 * Parameters:   int *mul, *div -- multiplication/division factors
 *               int maxmul, maxdiv -- maximum mult/div factors
 *               void(*proc)(void *) --  caller-supplied function
 *               void *phandle --  handle passed to user function
 * Returns:      void.
 * Other Info:   Displays a template called "magnifier" (which must be one of
 *               your loaded templates). Mul and div are the initial
 *               values on the left and right of the ":" in the ratio shown
 *               in the dialogue box. They are modified according to user
 *               mouse clicks on the "arrow" icons. Proc (if non-null) is
 *               called each time the magnification factor changes.
 *               The template should have the following attributes:
 *                   window flags -- moveable, auto-redraw
 *                                   Advisable to have title icon with text
 *                                   "magnifier" or similar
 *                   icon #0 -- the multiplication factor icon
 *                           -- should have indirected text flag set with
 *                           -- text something like "999" and max length 4
 *                           -- also advisable to have validation string
 *                           -- "a0-9" (allowing numeric input)
 *                           -- button type should be "writeable"
 *                   icon #1 -- the division factor icon
 *                           -- same as icon #0
 *                   icon #2 -- the increase multiplication factor icon
 *                           -- should have text flag set and contain the
 *                           -- "up-arrow" character (like for scroll bars)
 *                           -- button type should be "auto-repeat"
 *                   icon #3 -- the decrease multiplication factor icon
 *                           -- same as icon #2 except use "down-arrow" char
 *                   icon #4 -- the increase division factor icon
 *                           -- same as icon #2
 *                   icon #5 -- the decrease division factor icon
 *                              same as icon #3
 *                   icon #6 -- (optional but advisable) a text icon placed
 *                              between icons #0 and #1 as a separator
 *                              eg. ":"
 *
 *               These icons can be arranged in the window however you wish
 *               but a reasonable layout is like the "magnifier" dialogue
 *               box in !Draw or !Paint. 
 *
 */ 

void magnify_select (int *mul, int *div, int maxmul, int maxdiv,
                      void (*proc)(void *), void *phandle) ;

#endif

/* end magnify.h */
