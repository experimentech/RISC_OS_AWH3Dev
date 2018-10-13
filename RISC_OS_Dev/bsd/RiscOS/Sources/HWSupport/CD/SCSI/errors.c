/*
 * Copyright (c) 2011, RISC OS Open Ltd
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
#include "swis.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Interface/CDErrors.h"

#include "DebugLib/DebugLib.h"

#include "globals.h"
#include "errors.h"

typedef struct {
	uint32_t num;
	const char token[8];
} msgerr;

static const msgerr errors[Error_MAX] =
{
	{ CDFSDRIVERERROR__INVALID_PARAMETER, "BadParm" }, /* Error_BadArgs */
	{ CDFSDRIVERERROR__BAD_RESPONSE, "BadResp" }, /* Error_BadResponse */
	{ CDFSDRIVERERROR__NOT_AUDIO_TRACK, "NotAud" }, /* Error_NotAudio */
	{ CDFSDRIVERERROR__NO_SUCH_TRACK, "NoTrack" }, /* Error_NoTrack */
	{ CDFSDRIVERERROR__SWI_NOT_SUPPORTED, "SWINSup" }, /* Error_Unsupported */
};

_kernel_oserror *geterror(Error e)
{
	return _swix(MessageTrans_ErrorLookup,_INR(0,2),&errors[e],&messages,0);
}
