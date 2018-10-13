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
/*
 * Purpose: manipulation of multiple windows on a Text buffer.
 * Author: W. Stoye
 * Status: system-independent.
 *         internal to the Texts subsystem
 *         experimental
 * Requires:
 *   h.txt1
 *   BOOL same as INT
 * History:
 *   02-Nov-87: started.
 *   28-Jan-88: converted into C.
 */

/* t->windows[1] is the *primary* window. The caret of the primary
window is coincident with the gap. Between calls t->w also reflects
the primary window. Most user events cause a window implementation to
force itself to be the primary window before calling txt1. */

BOOL txt3_inittxt(txt);
/* Create the first window record, ready for the initialisation of
txtar (or whatever window implementation is being used. Return FALSE
if not enough store. */

BOOL txt3_preparetoaddwindow(txt);
/* Returns FALSE if there is no room. creates a new window object as
the primary window, such that t->w can be initialised. */

void txt3_disposeallwindows(txt);

void txt3_disposewindow(txt t, txt1_windex wi);
/* Deallocate the txt1_window and remove it from the array. MUST NOT be called
on the very last window of the text. Calls t->windows[wi]->disposewindow,
then removes it from the array. */

void txt3_setprimarywindow(txt t, void *syshandle);
/* Shuffle the array and set t->w to the window with w->syshandle the
specified value. */

void txt3_settemporarywindow(txt t, void *syshandle);
/* Make the given window available as t->w, without actually making it
the primary window. Used e.g. for redisplay of non-primaries. */

void txt3_resetprimarywindow(txt);
/* Reset t->w back to the primary window. */

BOOL txt3_foreachwindow(txt);
/* used as in while (txt3_foreachwindow(t)) { ... };. Early termination
is not allowed. Each window in turn is available as t->w during this
loop. */

/* end */
