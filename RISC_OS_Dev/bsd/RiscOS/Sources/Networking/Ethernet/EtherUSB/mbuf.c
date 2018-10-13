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

#include "mbuf.h"
#include "swis.h"

extern mbuf_ctl_t* g_mbuf = NULL;
static mbuf_ctl_t  s_mbuf;

_kernel_oserror* mbuf_initialise(size_t minubs,
                                 size_t maxubs,
                                 size_t mincontig)
{
  if (g_mbuf) return NULL;
  s_mbuf.mbcsize = sizeof(s_mbuf);
  s_mbuf.mbcvers = 100;
  s_mbuf.flags   = 0;
  s_mbuf.advminubs = minubs;
  s_mbuf.advmaxubs = maxubs;
  s_mbuf.mincontig = mincontig;
  s_mbuf.spare1    = 0;

  _kernel_oserror* e = _swix(Mbuf_OpenSession, _IN(0), &s_mbuf);
  if (!e) g_mbuf = &s_mbuf;
  return e;
}

_kernel_oserror* mbuf_finalise(void)
{
  if (!g_mbuf) return NULL;
  _kernel_oserror* e = _swix(Mbuf_CloseSession, _IN(0), &s_mbuf);
  if (!e) g_mbuf = NULL;
  return e;
}
