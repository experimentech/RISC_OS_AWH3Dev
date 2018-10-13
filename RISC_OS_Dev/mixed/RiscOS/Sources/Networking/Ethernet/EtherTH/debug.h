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



#ifndef DEBUG_H
#define DEBUG_H

#include "debuglib/debuglib.h"

#ifdef DEBUGLIB

#define dprintf_here(...)\
        do \
        { \
                unsigned int t;\
                _swix(OS_ReadMonotonicTime,_OUT(0),&t);\
                dprintf(("","%s(%d)- %d: ",__func__,__LINE__,t));\
                dprintf(("",__VA_ARGS__));\
        } while (0)

#else
    #define dprintf_here(...) do {} while (0)
#endif


#define dprintf_regs(r) \
        dprintf_here("r0=%x r1=%x r2=%x r3=%x r4=%x r5=%x r6=%x\n", \
                      r->r[0], r->r[1], r->r[2], r->r[3], r->r[4], r->r[5], r->r[6]);

#endif
