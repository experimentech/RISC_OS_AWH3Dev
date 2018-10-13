/*
 * Copyright (c) 2010, RISC OS Open Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#include "modhead.h"
#include "swis.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Global/NewErrors.h"
#include "Global/HALDevice.h"
#include "Global/HALEntries.h"
#include "Global/GraphicsV.h"
#include "Global/VduExt.h"
#include "Global/OSMisc.h"
#include "Global/OSMem.h"

#include "DebugLib/DebugLib.h"

#include "graphicsv.h"
#include "consts.h"

void *private_word;
int instance;

uint8_t graphicsv_driver_number;

_kernel_oserror* module_init (const char *cmd_tail, int podule_base, void *pw)
{
	(void) cmd_tail;

	_kernel_oserror* e = NULL;

	/* set up debugging */
	debug_initialise(Module_Title, "", "");
	debug_set_device(DADEBUG_OUTPUT);
	debug_set_unbuffered_files(TRUE);

	instance = podule_base;

	private_word = pw;

	/* TODO: Detect hardware, claim memory, etc. */

	/* Get a driver number */
	uint32_t temp;
	e = _swix (OS_ScreenMode, _INR(0,2)|_OUT(0), ScreenModeReason_RegisterDriver, 0, Module_Title, &temp);
	if(e)
		goto error3;
	graphicsv_driver_number = temp;

	/* TODO: Claim & enable VSync IRQ (so we can start generating GraphicsV_VSync events) */

	/* Get on GraphicsV! */
	e = _swix(OS_Claim, _INR(0,2), GraphicsV, graphicsv_entry, pw);

	if(e)
		goto error5;

	/* TODO: Any extra init here before the OS starts talking to us via GraphicsV */

	/* Tell the OS that we're ready */
	e = _swix(OS_ScreenMode, _INR(0,1), ScreenModeReason_StartDriver, graphicsv_driver_number);
	if(e)
		goto error6;

	return 0;

error6:
	/* Get off GraphicsV */
	_swix(OS_Release, _INR(0,2), GraphicsV, graphicsv_entry, pw);
error5:
	/* Release driver number */
	_swix (OS_ScreenMode, _INR(0,1), ScreenModeReason_DeregisterDriver, graphicsv_driver_number);
error3:
	dprintf(("","Failed initialisation: %s\n", e->errmess));
	return e;
}

_kernel_oserror *module_final(int fatal, int podule, void *pw)
{
	(void) podule;
	(void) fatal;

	_kernel_oserror* e = NULL;

	/* Tell the OS that we're shutting down */
	e = _swix(OS_ScreenMode, _INR(0,1), ScreenModeReason_StopDriver, graphicsv_driver_number);
	if(e)
		return e;

	/* Get off GraphicsV */
	_swix(OS_Release, _INR(0,2), GraphicsV, graphicsv_entry, pw);

	/* TODO: It's now safe to shut down the hardware, release memory, etc. */

	/* Release driver number */
	_swix(OS_ScreenMode, _INR(0,1), ScreenModeReason_DeregisterDriver, graphicsv_driver_number);

	return NULL;
}
