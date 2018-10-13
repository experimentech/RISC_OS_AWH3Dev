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


#include "dci.h"


/* Implementation of declarations in mbufs.h */

struct mbctl MBCTL;

_kernel_oserror* mb_entryinit(void)
{
        mbctl.mbcsize         = sizeof(mbctl);
        mbctl.mbcvers         = MBUF_MANAGER_VERSION;
        mbctl.flags           = 0;
        mbctl.advminubs       = MINCONTIG;
        mbctl.advmaxubs       = ETHERMTU;
        mbctl.mincontig       = MINCONTIG;
        mbctl.spare1          = 0;
        return _swix(Mbuf_OpenSession, _IN(0), &MBCTL);
}

_kernel_oserror* mb_closesession(void)
{
        if (mbctl.mbcsize == 0) return NULL;
        _kernel_oserror* err = _swix(Mbuf_CloseSession, _IN(0), &MBCTL);
        if (err == NULL) mbctl.mbcsize = 0;
        return err;
}

