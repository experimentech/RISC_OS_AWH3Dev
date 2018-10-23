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
#include <string.h>
#include <stddef.h>
#include <stdbool.h>
#include "modhead.h"
#include "swis.h"

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Global/HALEntries.h"
#include "Global/GraphicsV.h"
#include "Global/VduExt.h"

#include "DebugLib/DebugLib.h"

#include "graphicsv.h"
#include "consts.h"
#include "misc.h"

static int do_null(_kernel_swi_regs *r)
{
	/* Nothing */
	(void) r;
	return 0;
}

static int do_vsync(_kernel_swi_regs *r)
{
	/* Nothing */
	(void) r;
	return 1;
}

static int do_setmode(_kernel_swi_regs *r)
{
	/* TODO (required) */
	return 1;
}

static int do_setblank(_kernel_swi_regs *r)
{
	/* TODO (optional) */
	return 1;
}

static int do_updatepointer(_kernel_swi_regs *r)
{
	/* TODO (optional - displayfeatures can indicate software pointer use) */
	return 1;
}

static int do_setdmaaddress(_kernel_swi_regs *r)
{
	/* TODO (required) */
	return 1;
}

static int do_vetmode(_kernel_swi_regs *r)
{
	/* TODO (required) */
	return 1;
}

static int do_displayfeatures(_kernel_swi_regs *r)
{
	/* TODO (required) */
	return 1;
}

static int do_framestoreaddress(_kernel_swi_regs *r)
{
	/* TODO (optional - depends on displayfeatures result) */
	return 1;
}

static int do_writepaletteentry(_kernel_swi_regs *r)
{
	/* TODO (required for <= 8bpp) */
	return 1;
}

static int do_writepaletteentries(_kernel_swi_regs *r)
{
	/* TODO (required for <= 8bpp) */
	return 1;
}

static int do_readpaletteentry(_kernel_swi_regs *r)
{
	/* TODO (optional) */
	return 1;
}

static int do_render(_kernel_swi_regs *r)
{
	/* TODO (optional) */
	return 1;
}

static int do_iicop(_kernel_swi_regs *r)
{
	/* TODO (optional) */
	return 1;
}

static int do_pixelformats(_kernel_swi_regs *r)
{
	/* TODO (required) */
	return (MODE_8BPP | MODE_16BPP | MODE_32BPP);
	//return 1;
}

static int do_readinfo(_kernel_swi_regs *r)
{
	const void *src = NULL;
	int len = 0;
	int version = 0;
	switch(r->r[0])
	{
	case GVReadInfo_Version:
		src = &version;
		len = sizeof(version);
		for(int i=0,j=Module_VersionNumber;i<6;i++,j/=10)
			version |= (j % 10)<<(i*4+8);
		break;
	case GVReadInfo_ModuleName: /* Only one module instance assumed */
	case GVReadInfo_DriverName:
		src = Module_Title;
		len = sizeof(Module_Title); /* Includes terminator */
		break;
	}
	if(!len)
		return 1;
	int copy = ((len < r->r[2])?len:r->r[2]);
	memcpy((void *) r->r[1],src,copy);
	r->r[2] -= len;
	r->r[4] = 0;
	return 0;
}

int graphicsv_handler(_kernel_swi_regs *r,void *pw)
{
	(void) pw;
	if((((uint32_t)r->r[4])>>24) != graphicsv_driver_number)
		return 1;
	uint16_t func = (uint16_t) r->r[4];
	int ret = 1;
	switch(func)
	{
	case GraphicsV_Complete:		ret = do_null(r); break;
	case GraphicsV_VSync:			ret = do_vsync(r); break;
	case GraphicsV_SetMode:			ret = do_setmode(r); break;
	case GraphicsV_SetBlank:		ret = do_setblank(r); break;
	case GraphicsV_UpdatePointer:		ret = do_updatepointer(r); break;
	case GraphicsV_SetDMAAddress:		ret = do_setdmaaddress(r); break;
	case GraphicsV_VetMode:			ret = do_vetmode(r); break;
	case GraphicsV_DisplayFeatures:		ret = do_displayfeatures(r); break;
	case GraphicsV_FramestoreAddress:	ret = do_framestoreaddress(r); break;
	case GraphicsV_WritePaletteEntry:	ret = do_writepaletteentry(r); break;
	case GraphicsV_WritePaletteEntries:	ret = do_writepaletteentries(r); break;
	case GraphicsV_ReadPaletteEntry:	ret = do_readpaletteentry(r); break;
	case GraphicsV_Render:			ret = do_render(r); break;
	case GraphicsV_IICOp:			ret = do_iicop(r); break;
	case GraphicsV_PixelFormats:		ret = do_pixelformats(r); break;
	case GraphicsV_ReadInfo:		ret = do_readinfo(r); break;
	default:				ret = 1; break;
	}
	return ret;
}
