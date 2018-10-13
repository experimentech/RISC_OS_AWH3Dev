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
#ifndef NOVIDEO_GVTYPES_H
#define NOVIDEO_GVTYPES_H

#include <stdint.h>

/* Pointer update */

typedef struct
{
	uint8_t width; /* unpadded width in bytes */
	uint8_t height; /* in pixels */
	uint8_t padding[2]; /* 2 bytes of padding for field alignment */
	void *buffLA; /* logical address of buffer holding pixel data */
	void *buffPA; /* corresponding physical address of buffer */
} shape_t;

/* GraphicsV_UpdatePointer (must match register usage) */

typedef struct {
	uint32_t flags;
	int32_t x;
	int32_t y;
	const shape_t *shape;
} gvupdatepointer_t;

/* GraphicsV_Render */

typedef struct
{
	/* 0,0 = bottom-left of screen :( */
	uint32_t src_left;
	uint32_t src_bottom;
	uint32_t dest_left;
	uint32_t dest_bottom;
	uint32_t width; /* -1 */
	uint32_t height; /* -1 */
} copyrect_params_t;

typedef struct
{
	/* All inclusive. 0,0 = bottom-left of screen :( */
	uint32_t left;
	uint32_t top;
	uint32_t right;
	uint32_t bottom;
	uint32_t *oraeor;
} fillrect_params_t;

/* GraphicsV_PixelFormats */

typedef struct
{
	int32_t ncolour;
	uint32_t modeflags;
	uint32_t log2bpp;
} pixelformat_t;

/* Mode selector / overlay descriptor */

typedef struct
{
	uint32_t var;
	uint32_t val;
} modevarpair_t;

typedef struct
{
	uint32_t flags;
	uint32_t xres;
	uint32_t yres;
	uint32_t log2bpp;
	uint32_t framerate;
	modevarpair_t modevars[1];
} modeselector_t;

#endif
