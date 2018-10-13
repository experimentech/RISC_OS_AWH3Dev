/*
 * Copyright (c) 2012, RISC OS Open Ltd
 * All rights reserved.
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
#ifndef FILTERING_H
#define FILTERING_H

typedef void (*filter_handler_t)(Dib *, struct mbuf *);

typedef struct filter
{
	uint32_t         type;
	uint8_t          errorlevel;
	uint8_t          addresslevel;
	uint8_t          flags;
	void            *pw;
	filter_handler_t handler;
	struct filter   *next;
} filter_t;

/* Devious address level evaluation. Incoming packets are in one of
 * 4 classes, and protocol modules set one of 4 address levels, so
 * there's a matrix of 16 filtering outcomes
 *
 *                       SPECIFIC  BROADCAST MULTICAST SPECIFIC
 *                       AND MINE                      BUT NOT MINE
 * ADDRLVL_SPECIFIC      keep      drop      drop      drop
 * ADDRLVL_NORMAL        keep      keep      drop      drop
 * ADDRLVL_MULTICAST     keep      keep      keep      drop
 * ADDRLVL_PROMISCUOUS   keep      keep      keep      keep
 *
 * which can be encoded as a mask and indexed using a 4 bit shift
 */
#define IS_MINE                   3
#define IS_BROADCAST              2
#define IS_MULTICAST              1
#define IS_SPECIFIC               0
#define IS_A_KEEPER(lvl,cls)      ((0xFEC8 & (1 << ((cls) | ((lvl) << 2)))) != 0)
#define IS_GOOD_ENOUGH(lvl,err)   (((lvl) == ERRLVL_ERRORS) || (!err))

/* Filter manipulation */
void filter_protocol_remove(uint8_t, void *);
void filter_destroy(uint8_t);
_kernel_oserror *filter_add(uint8_t, uint32_t, uint32_t, uint32_t, filter_handler_t, void *, uint32_t);
_kernel_oserror *filter_remove(uint8_t, uint32_t, uint32_t, uint32_t, filter_handler_t, void *);
void filter_to_protocol(Dib *, struct mbuf *, filter_handler_t, void *);
void filter_input(uint8_t, uint8_t, RxHdr *, struct mbuf *);

#endif
