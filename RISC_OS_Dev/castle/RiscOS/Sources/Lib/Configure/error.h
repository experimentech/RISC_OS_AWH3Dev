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
/******	error.h ***********************************************************\

Project:	Ursula (RISC OS for Risc PC II)
Component:	Modular Configure
Purpose:	Application error handling code, shared by multiple plug-ins

History:
Date		Who	Change
----------------------------------------------------------------------------
08/12/1997	BJGA	Renamed functions to error_foo convention
			Added these headers

\**************************************************************************/

/* The famous Kev C error handling system, hacked by Ben.
 *
 * Errors and traps are reported in the standard RISC OS fashion.
 * In particular data aborts are reported as "Internal error: Data abort at
 * &xxxxxxxx" instead of "Illegal address (eg wildly outside array bounds)".
 * This is achieved by removing the Data Abort etc handlers so they go
 * through the default handler (helpfully dumping into the register area)
 * which then raises the usual error message. The signal handlers are then
 * called as normal, but _kernel_last_oserror() now returns something
 * useful.
 *
 * Error boxes have two buttons, "Continue" and "Quit", unless the toolbox
 * hasn't initialised, in which case the only option is "Quit". "Continue"
 * will jump back into the polling loop.
 *
 * Note that RISC OS 3.50-3.60 Wimps screw up in the case of serious errors
 * (eg traps); the "May have gone wrong" preliminary box will have the wrong
 * sprite, and the "Describe"d secondary box will be missing its Quit button.
 */

/*
 * Ben's version does *not* use OSLib, is held in these files, separate from
 * the rest of the source, and can cope with the message file not having been
 * opened yet. It should also be more tolerant of errors during the error
 * report process.
 *
 * It requires the following of the main program:
 * 
 * * Global definitions (&messages should be passed to Toolbox_Initialise):
 *   #include "Error.h"
 *   MessagesFD messages;
 * 
 * * First statement in main():
 *   error_initialise ();
 * 
 * * Last statement before going into polling loop (NB this is a macro):
 *   error_recover_point();
 *
 * Must only be included by the main program, because of the jmp_buf.
 * Nasty, isn't it?
 */

/* Clib */
#include <setjmp.h>

jmp_buf restart_buf;
int init_state = 0;

extern void error_sighandler (int sig);
extern void error_initialise (void);

#define error_recover_point() \
  setjmp (restart_buf); \
  init_state = 1
