//
// Copyright (c) 2006, James Peacock
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met: 
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of RISC OS Open Ltd nor the names of its contributors
//       may be used to endorse or promote products derived from this software
//       without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
#ifndef UTILS_H_INCLUDED
#define UTILS_H_INCLUDED

#include <stdlib.h>
#include <stdint.h>

#include "kernel.h"

//---------------------------------------------------------------------------
// SysLog output, printf style formatting.
//---------------------------------------------------------------------------
#if DEBUG
#ifdef __CC_NORCROFT
#pragma -v1
#endif

void syslog(const char* fmt, ...);

#ifdef __CC_NORCROFT
#pragma -v0
#endif

void syslog_data(const void* data, size_t size);

void syslog_flush(void);
#endif

//---------------------------------------------------------------------------
// Heap allocation, in case I want to move it out of the RMA later...
//---------------------------------------------------------------------------

static inline void xfree(void* p)
{
  free(p);
}

static inline void* xalloc(size_t s)
{
  return malloc(s);
}

//---------------------------------------------------------------------------
// Compiler tricks
//---------------------------------------------------------------------------

#define UNUSED(k)       (k)=(k)
#define STRINGIFY(k)    #k
#define STR(k)          STRINGIFY(k)

//---------------------------------------------------------------------------
// Doubly Linked List Helpers
//---------------------------------------------------------------------------

#define LINKEDLIST_INSERT(anchor, entry) \
  ((void)( ((entry)->prev=0), \
           ((entry)->next=(anchor)), \
           ((anchor) ? (anchor)->prev=(entry) : 0), \
           ((anchor)=(entry)))\
  )

//
// BIG WARNING: don't use the same variable for 'anchor' and 'entry'.
//
#define LINKEDLIST_REMOVE(anchor, entry) \
  ((void)( ((entry)->prev \
              ? ((entry)->prev->next = (entry)->next) \
              : ((anchor) = (entry)->next)), \
           ((entry)->next \
              ? ((entry)->next->prev = (entry)->prev) \
              : 0)) \
  )

//---------------------------------------------------------------------------
// Blocking wait. Duration is in centiseconds.
//---------------------------------------------------------------------------
_kernel_oserror* cs_wait(uint32_t centiseconds);

//---------------------------------------------------------------------------
// Central callback dispatcher. Hooked off OS_AddCallBack. Returns
// approximate number of centiseconds before it would like to be recalled, or
// CALLBACK_REMOVE if it wants to be removed from the queue. The delays are
// in centiseconds.
//---------------------------------------------------------------------------
typedef uint32_t callback_delay_t;
typedef callback_delay_t (callback_fn)(void* handle);

#define CALLBACK_REMOVE ((callback_delay_t)0xffffffffu)
#define CALLBACK_ASAP   ((callback_delay_t)0u)

_kernel_oserror* callback(callback_fn*     fn,
                          callback_delay_t cs_delay,
                          void*            handle);

_kernel_oserror* callback_cancel(callback_fn*     fn,
                                 void*            handle);

// It is important to do error checking on the return values.
_kernel_oserror* callback_initialise(void* private_word);
_kernel_oserror* callback_finalise(void);

#endif
