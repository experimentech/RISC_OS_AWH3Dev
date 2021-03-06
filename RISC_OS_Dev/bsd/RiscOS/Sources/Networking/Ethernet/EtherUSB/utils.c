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

#include <stdarg.h>
#include <stdio.h>
#include <stdbool.h>
#include "swis.h"
#include "SyncLib/SyncLib.h"

#include "module.h"
#include "utils.h"

// This is generated by CMHG
#include "EtherUSBHdr.h"

#define DADEBUG 0
#define SYSLOG 1
#define TIMERMOD 0

#if DEBUG
static unsigned s_sec  = 0;
static unsigned s_msec = 0;

void syslog(const char* fmt, ...)
{
  char blk[256];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(blk, sizeof(blk), fmt, ap);
  va_end(ap);

  void (*write_fn)(char) = NULL;
  if (DADEBUG && !_swix(0x531c0, _OUT(0), &write_fn))
  {
    unsigned sec  = 0;
    unsigned msec = 0;
    if (TIMERMOD && !_swix(0x490c2, _OUTR(0,1), &sec, &msec))
    {
      char blk2[20];
      snprintf(blk2, sizeof(blk2),
               "%10u.%06u: ",
               sec-s_sec,
               msec>s_msec ? msec-s_msec : s_msec-msec);

      s_sec  = sec;
      s_msec = msec;
      const char* ch = blk2;
      while (*ch) write_fn(*ch++);
    }

    const char* ch = blk;
    while (*ch) write_fn(*ch++);
    write_fn('\r');
    write_fn('\n');
  }
  if (SYSLOG && !_swix(0x4c88e, _IN(0), 1))
  {
    _swix(0x4c880, _INR(0,2), Module_Title, blk, 64);
    _swix(0x4c88e, _IN(0), 0);
  }
}

void syslog_data(const void* data, size_t size)
{
  if (SYSLOG && !_swix(0x4c88e, _IN(0), 1))
  {
    _swix(0x4c88a, _INR(0,4), Module_Title, 64, data, size, 0);
    _swix(0x4c88e, _IN(0), 0);
  }
}

void syslog_flush(void)
{
  _swix(0x4c882, _IN(0), Module_Title);
}
#endif

_kernel_oserror* cs_wait(uint32_t centiseconds)
{
  uint32_t start;
  _kernel_oserror* e = _swix(OS_ReadMonotonicTime, _OUT(0), &start);
  if (e) return e;

  while(true)
  {
    uint32_t now;
    e = _swix(OS_ReadMonotonicTime, _OUT(0), &now);
    if (e || ((now-start)>centiseconds)) break;
  }
  return e;
}


// Defined in asm.s
extern void asm_ticker_handler(void*);

// Must match asm.s
#define CALLBACK_STATE_UNREQUIRED 0u
#define CALLBACK_STATE_REQUIRED   1u
#define CALLBACK_STATE_PENDING    2u

// The first three words of this structure are accessed from a ticker event
struct callback
{
  void (*handler)(void);     // Address to call.
  void*             r12;     // Value of r12 to call with.
  volatile uint32_t state;   // State, changed by asm ticker handler, 1->2
};

// Holds data for pending calls.
typedef struct callback_t
{
  struct callback_t* prev;
  struct callback_t* next;
  callback_fn*       fn;
  void*              handle;
  uint32_t           time;
} callback_t;

static struct callback s_callback;
static bool            s_ticker        = false;
static callback_t*     s_callback_list = NULL;


static _kernel_oserror* callback_request_now(void)
{
  // Need to stop ticker getting in the way here, otherwise we might
  // schedule two callbacks.
  uint32_t current_state = atomic_update(CALLBACK_STATE_PENDING, &s_callback.state);
  _kernel_oserror* e = NULL;
  __asm
  {
    TEQ        current_state,#CALLBACK_STATE_PENDING
    BEQ        asm_exit
    MOV        R0,s_callback.handler
    MOV        R1,s_callback.r12
    SWI        OS_AddCallBack | XOS_Bit, {R0-R1}, {R0, PSR}, {LR}
    MOVVS      e,R0
    MOVVS      s_callback.state, current_state
  asm_exit:
  }
  return e;
}

_kernel_oserror* callback_initialise(void* private_word)
{
  if (s_ticker) return NULL;
  s_callback.handler = &callback_hook;
  s_callback.r12 = private_word;
  s_callback.state = CALLBACK_STATE_UNREQUIRED;

  _kernel_oserror* e = _swix(OS_CallEvery, _INR(0,2),
                             CALLBACK_TICKER_FREQ,
                             &asm_ticker_handler,
                             &s_callback);
  if (e) return e;

  s_ticker = true;
  return NULL;
}

_kernel_oserror* callback_finalise(void)
{
  if (s_ticker)
  {
    _kernel_oserror* e = _swix(OS_RemoveTickerEvent, _INR(0,1),
                               &asm_ticker_handler, &s_callback);
    if (e) return e;
    s_ticker = false;
  }

  if (s_callback.state == CALLBACK_STATE_PENDING)
  {
    _kernel_oserror* e = _swix(OS_RemoveCallBack, _INR(0,1),
                               s_callback.handler, s_callback.r12);
    if (e) return e;
    s_callback.state = CALLBACK_STATE_UNREQUIRED;
  }

  while (s_callback_list)
  {
    callback_t* c = s_callback_list;
    LINKEDLIST_REMOVE(s_callback_list, c);
    xfree(c);
  }

  return NULL;
}

_kernel_oserror* callback(callback_fn* fn, uint32_t cs_delay, void* handle)
{
  uint32_t now;
  _kernel_oserror* e = _swix(OS_ReadMonotonicTime, _OUT(0), &now);
  if (e) return e;

  callback_t* cb = xalloc(sizeof(callback_t));
  if (!cb) return err_translate(ERR_NO_MEMORY);

  cb->fn = fn;
  cb->handle = handle;
  cb->time = now + cs_delay;

  LINKEDLIST_INSERT(s_callback_list, cb);

  if (cs_delay==CALLBACK_ASAP)
  {
    return callback_request_now();
  }
  else
  {
    if (s_callback.state==CALLBACK_STATE_UNREQUIRED)
      s_callback.state = CALLBACK_STATE_REQUIRED;
  }
  return NULL;
}



_kernel_oserror* callback_cancel(callback_fn*     fn,
                                 void*            handle)
{
  callback_t* next = s_callback_list;
  while (next)
  {
    callback_t* c = next;
    next = next->next;
    if (c->fn==fn && c->handle==handle)
    {
      LINKEDLIST_REMOVE(s_callback_list, c);
      xfree(c);
      break;
    }
  }
  return NULL;
}


_kernel_oserror *callback_hook_handler(_kernel_swi_regs *r, void *pw)
{
  // In transient callback, no where to send errors... The callback state
  // should be pending - so the ticker handler won't touch the state.
  uint32_t now;
  _kernel_oserror* e = _swix(OS_ReadMonotonicTime, _OUT(0), &now);
  if (e) return NULL;

  bool asap = false;

  callback_t* next = s_callback_list;
  while (next)
  {
    callback_t* c = next;
    next = next->next;
    if (now>=c->time && (now - c->time) < 0x80000000)
    {
      uint32_t cs_delay = c->fn(c->handle);
      if (cs_delay==CALLBACK_REMOVE)
      {
        LINKEDLIST_REMOVE(s_callback_list, c);
        xfree(c);
      }
      else
      {
        c->time = now + cs_delay;
        if (cs_delay==CALLBACK_ASAP) asap = true;
      }
    }
  }

  s_callback.state = s_callback_list
    ? CALLBACK_STATE_REQUIRED
    : CALLBACK_STATE_UNREQUIRED;

  if (asap) callback_request_now();

  UNUSED(r);
  UNUSED(pw);

  return NULL;
}
