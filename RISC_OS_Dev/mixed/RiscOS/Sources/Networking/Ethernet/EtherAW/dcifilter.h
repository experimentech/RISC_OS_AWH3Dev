/*
 * Copyright (c) 2017, Colin Granville
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name Colin Granville may not be used to endorse or promote
 *       products derived from this software without specific prior written
 *       permission.
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


#ifndef DCIFILTER_H
#define DCIFILTER_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#include "dci.h"

typedef struct dcifilter_t dcifilter_t;

_kernel_oserror*        dcifilter_new(const Dib*, dcifilter_t** out);
void *                  dcifilter_delete(dcifilter_t* filter);          /* return NULL */
void                    dcifilter_release_module(dcifilter_t* filter, void *pw);

uint32_t                dcifilter_getUnwantedFrames(dcifilter_t* filter);
/* Called from modules DCI Transmit Swi */
_kernel_oserror*        dcifilter_manage(dcifilter_t*, dci_FilterArgs_t*);

/* Filter ethernet packet received from device */

/* packet_type */
#define DCIFILTER_PT_UNICAST            0
#define DCIFILTER_PT_PROMISCUOUS        1
#define DCIFILTER_PT_BROADCAST          2
#define DCIFILTER_PT_MULTICAST          3
#define DCIFILTER_PT_UNKNOWN            4


/* Return values */
#define DCIFILTER_BLOCKED       0
#define DCIFILTER_OK            1

int                     dcifilter_receivedPacket(dcifilter_t*, uint8_t* packet, size_t size, uint32_t packet_type, bool has_errors);

#endif
