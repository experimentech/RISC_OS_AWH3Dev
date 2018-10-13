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
#ifndef MBUF_H_INCLUDED
#define MBUF_H_INCLUDED

// MBufManager module SWIs
#define Mbuf_OpenSession  0x4a580
#define Mbuf_CloseSession 0x4a581
#define Mbuf_Memory       0x4a582
#define Mbuf_Statistic    0x4a583
#define Mbuf_Control      0x4a584

// MbufManager Service Calls
#define Service_MbufManagerStatus_Started   0     // Can call MBuf SWIs
#define Service_MbufManagerStatus_Stopping  1     // Note: no open sessions
#define Service_MbufManagerStatus_Scavenge  2     // Try to freeup mbufs.

// MBuf packet types...
#define MBUF_MT_FREE         0       // On free list
#define MBUF_MT_DATA         1       // Data
#define MBUF_MT_HEADER       2       // Header
#define MBUF_MT_LRXDATA      15      // Large Data

#include <stddef.h>
#include <stdint.h>
#include "kernel.h"

typedef struct
{
  int   len;                    // Total packet length.
  void* data;
} mbuf_pkthdr_t;

typedef struct mbuf_t
{
  struct mbuf_t*     next;      // => Next mbuf in chain
  struct mbuf_t*     list;      // => Next mbuf (chain) in list.
  ptrdiff_t          off;       // Offset to data from mbuf.
  size_t             len;       // Data byte count.
  const ptrdiff_t    inioff;    // Initial offset to data from mbuf (const).
  const size_t       inilen;    // Initial byte count.
  uint8_t            type;      // Private to client.
  const uint8_t      sys1;      // Private to mbuf manager.
  const uint8_t      sys2;      // Private to mbuf manager.
  uint8_t            flags;     // Private to client.
  mbuf_pkthdr_t      pkthdr;    // Private to client.
} mbuf_t;

typedef struct mbuf_ctl mbuf_ctl_t;

struct mbuf_ctl
{
  // Private to mbuf manager - never read/write.
  int32_t            opaque;

  // Client initialises before session
  uint32_t           mbcsize;    // sizeof(mbuf_ctl_t)
  uint32_t           mbcvers;    // Version of mbuf spec client using.
  uint32_t           flags;
  uint32_t           advminubs;  // Advisory minimum underlying block size.
  uint32_t           advmaxubs;  // Advisory maximum underlying block size.
  uint32_t           mincontig;  // Client required min ensure_contig.
  uint32_t           spare1;     // 0

  // MBuf manager initialises.
  uint32_t           minubs;     // Minimum underlying block size.
  uint32_t           maxubs;     // Maximum underlying block size.
  uint32_t           maxcontig;  // Maximum contiguify block size.
  uint32_t           spare2;     // Reserved.

  // Allocation routines
  mbuf_t* (*alloc  )(mbuf_ctl_t*, size_t bytes, void* ptr);
  mbuf_t* (*alloc_g)(mbuf_ctl_t*, size_t bytes, void* ptr, unsigned flags);
  mbuf_t* (*alloc_u)(mbuf_ctl_t*, size_t bytes, void* ptr);
  mbuf_t* (*alloc_s)(mbuf_ctl_t*, size_t bytes, void* ptr);
  mbuf_t* (*alloc_c)(mbuf_ctl_t*, size_t bytes, void* ptr);

  // Ensuring routines
  mbuf_t* (*ensure_safe  )(mbuf_ctl_t*, mbuf_t* mb);
  mbuf_t* (*ensure_contig)(mbuf_ctl_t*, mbuf_t* mb, size_t bytes);

  // Free routines
  void (*free      )(mbuf_ctl_t*, mbuf_t* mb);
  void (*freem     )(mbuf_ctl_t*, mbuf_t* mb);
  void (*dtom_free )(mbuf_ctl_t*, mbuf_t* mb);
  void (*dtom_freem)(mbuf_ctl_t*, mbuf_t* mb);

  // Support routines
  mbuf_t* (*dtom       )(mbuf_ctl_t*, void* ptr);
  int     (*any_unsafe )(mbuf_ctl_t*, mbuf_t* mb);
  int     (*this_unsafe)(mbuf_ctl_t*, mbuf_t* mb);
  size_t  (*count_bytes)(mbuf_ctl_t*, mbuf_t* mb);
  mbuf_t* (*cat        )(mbuf_ctl_t*, mbuf_t* old, mbuf_t* new);
  mbuf_t* (*trim       )(mbuf_ctl_t*, mbuf_t* mb, int bytes, void* ptr);
  mbuf_t* (*copy       )(mbuf_ctl_t*, mbuf_t* mb, size_t offset, size_t len);
  mbuf_t* (*copy_p     )(mbuf_ctl_t*, mbuf_t* mb, size_t offset, size_t len);
  mbuf_t* (*copy_u     )(mbuf_ctl_t*, mbuf_t* mb, size_t offset, size_t len);
  mbuf_t* (*import     )(mbuf_ctl_t*, mbuf_t* mb, size_t bytes, void* ptr);
  mbuf_t* (*export     )(mbuf_ctl_t*, mbuf_t* mb, size_t bytes, void* ptr);
};

// Global mbuf handle/NULL if no active session.
extern mbuf_ctl_t* g_mbuf;

// Attempt to open mbuf manager session with specified advisory block
// sizes. Pass zero if don't care.
_kernel_oserror* mbuf_initialise(size_t minubs,
                                 size_t maxubs,
                                 size_t mincontig);

// Closes mbuf managers session if it is open.
_kernel_oserror* mbuf_finalise(void);

#endif
