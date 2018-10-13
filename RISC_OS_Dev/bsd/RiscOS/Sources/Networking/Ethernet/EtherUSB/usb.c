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

#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "swis.h"
#include "kernel.h"
#include "Global/Services.h"
#include "Global/OsBytes.h"
#include "Global/RISCOS.h"
#include "Global/ModHand.h"
#undef   Module_Title
#include "Global/FSNumbers.h"
#include "Global/Upcall.h"
#include "Interface/HighFSI.h"
#include "Interface/USBDriver.h"
#include "AsmUtils/irqs.h"

#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "EtherUSBHdr.h"
#include "net.h"

#define DEBUG_TX 0
#define DEBUG_RX 0

_kernel_oserror* usb_scan_devices(usb_scan_devices_fn* fn, void* handle)
{
  USBServiceAnswer* next = NULL;

  _kernel_oserror* e = _swix(OS_ServiceCall, _INR(0,2)|_OUT(2),
                             Service_USB_Connected,
                             Service_USB,
                             0,
                             &next);
  while (next)
  {
    const USBServiceAnswer* current = next;
    next = next->link;

    if (!e) e = fn(&current->svc, handle);
    _swix(OS_Module, _IN(0)|_IN(2), ModHandReason_Free, current);
  }

  return e;
}

const usb_interface_descriptor_t*
  usb_find_interface(const USBServiceCall* s,
                     unsigned              config_no,
                     unsigned              interface_no,
                     unsigned              alternate_no)
{
  bool correct_config = false;

  const void* descriptor = usb_descriptor_list(s);
  while (descriptor)
  {
    const unsigned type = usb_descriptor_type(descriptor);
    const size_t   size = usb_descriptor_size(descriptor);

    if (type==UDESC_CONFIG &&
        size>=sizeof(usb_config_descriptor_t))
    {
      if (correct_config) return NULL;
      const usb_config_descriptor_t* c = descriptor;
      correct_config = (c->bConfigurationValue==config_no);
    }
    else if (correct_config &&
             type==UDESC_INTERFACE &&
             size>=sizeof(usb_interface_descriptor_t))
    {
      const usb_interface_descriptor_t* i = descriptor;
      if (i->bInterfaceNumber==interface_no &&
          i->bAlternateSetting==alternate_no) return i;
    }

    descriptor = usb_descriptor_next(descriptor);
  }
  return NULL;
}


_kernel_oserror* usb_location(const char *name,
                              uint8_t *location)
{
  return _swix(DeviceFS_CallDevice, _INR(0,1)|_IN(3),
               (1u<<31) + 4,
               name,
               location);
}

_kernel_oserror* usb_control(const char* name,
                             uint8_t     request_type,
                             uint8_t     request,
                             uint16_t    value,
                             uint16_t    index,
                             uint16_t    length,
                             void*       data)
{
  return _swix(DeviceFS_CallDevice, _INR(0,1)|_INR(3,6),
               1u<<31,
               name,
               request_type | (request<<8) | (value<<16),
               index | (length<<16),
               data,
               0);
}

_kernel_oserror* usb_set_config(const char* name, unsigned config)
{
  return usb_control(name,
                     USB_REQ_WRITE | USB_REQ_TP_STANDARD | USB_REQ_TO_DEVICE,
                     USB_REQ_SET_CONFIGURATION,
                     config,
                     0,
                     0,
                     NULL);
}

_kernel_oserror* usb_set_interface(const char* name,
                                   unsigned    interface,
                                   unsigned    alternate)
{
  return usb_control
    (name,
     USB_REQ_WRITE | USB_REQ_TP_STANDARD | USB_REQ_TO_INTERFACE,
     USB_REQ_SET_INTERFACE,
     alternate,
     interface,
     0,
     NULL);
}



struct usb_pipe
{
  usb_pipe_t       prev;
  usb_pipe_t       next;
  usb_open_t       direction;
  uint32_t         file_handle;
  uint32_t         buffer_handle;
  uint32_t         buffer_internal;
  uint32_t         buffer_code;
  uint32_t         buffer_r12;
  uint32_t         usb_handle;
  usb_handler_fn*  handler_fn;
  void*            handler_ws;
  char             device_name[20];
  char             file_name[];
};

static usb_pipe_t s_pipes;


_kernel_oserror* usb_open(const char*     device_name,
                          usb_pipe_t*     pipe,
                          usb_open_t      mode,
                          usb_handler_fn* handler_fn,
                          void*           handler_ws,
                          const char*     ft,
                          ...)
{
  *pipe = NULL;

  va_list ap;
  va_start(ap, ft);

  va_list ap2;
  va_copy(ap2, ap);
  const size_t len = vsnprintf(NULL, 0, ft, ap2)+1;
  va_end(ap2);

  usb_pipe_t p = xalloc(sizeof(struct usb_pipe) + len);
  if (p) vsnprintf(p->file_name, len, ft, ap);
  va_end(ap);

  if (!p) return err_translate(ERR_NO_MEMORY);

  strncpy(p->device_name, device_name, sizeof(p->device_name)-1);
  p->handler_fn = handler_fn;
  p->handler_ws = handler_ws;
  p->direction = mode;
  p->file_handle = 0;

  _kernel_oserror* e = _swix(OS_Find, _INR(0,1)|_OUT(0),
                             mode==USBRead ? 0x4f : 0x8f,
                             p->file_name,
                             &p->file_handle);

  if (!e) e = _swix(DeviceFS_CallDevice, _INR(0,2)|_OUT(3)|_OUT(5),
                    (1u<<31) + 7u,
                    p->device_name,
                    p->file_handle,
                    &p->buffer_handle,
                    &p->usb_handle);

  if (!e) e = _swix(Buffer_InternalInfo, _IN(0)|_OUTR(0,2),
                    p->buffer_handle,
                    &p->buffer_internal,
                    &p->buffer_code,
                    &p->buffer_r12);

  if (!e && mode==USBWrite)
  {
    size_t size = 0;
    _swix(Buffer_GetInfo, _IN(0)|_OUT(5), p->buffer_handle, &size);
    _swix(Buffer_Threshold, _INR(0,1), p->buffer_handle, size);
    _swix(Buffer_ModifyFlags, _INR(0,2), p->buffer_handle, 0x8, 0xfffffff7);
  }

  if (!e && mode==USBRead)
  {
    // Disable read buffer padding weirdness.
    e = _swix(DeviceFS_CallDevice, _INR(0,4),
              (1u<<31) + 8u,
              p->device_name,
              p->usb_handle,
              0x00000001,
              0xfffffffe);
  }


  if (!e)
  {
    int irq = ensure_irqs_off();
    LINKEDLIST_INSERT(s_pipes, p);
    restore_irqs(irq);
    *pipe = p;
    return NULL;
  }

  syslog("usb_open() for '%s' failed with '%s'", p->file_name, e->errmess);

  if (p->file_handle!=0) _swix(OS_Find, _INR(0,1), 0, p->file_handle);
  xfree(p);

  return e;
}

_kernel_oserror* usb_force_short_xfer(usb_pipe_t pipe)
{
  return _swix(DeviceFS_CallDevice, _INR(0,4),
              (1u<<31) + 8u,
              pipe->device_name,
              pipe->usb_handle,
              0x00000002,
              0xfffffffd);
}

#if 0
_kernel_oserror* usb_clear_stall(usb_pipe_t pipe)
{
  return _swix(DeviceFS_CallDevice, _INR(0,2),
              (1u<<31) + 5u,
              pipe->device_name,
              pipe->file_handle);
}
#endif

_kernel_oserror* usb_close(usb_pipe_t* pipe)
{
  if (!*pipe) return NULL;

  int irq = ensure_irqs_off();
  LINKEDLIST_REMOVE(s_pipes, *pipe);
  restore_irqs(irq);

  if ((*pipe)->file_handle!=0)
  {
    _kernel_oserror* e =_swix(OS_Byte, _INR(0,1),
                              OsByte_FlushBuffer, (*pipe)->buffer_handle);

    if (e) syslog("%s: usb_close() error during buffer flush: %s",
                           (*pipe)->file_name,e->errmess);

    e = _swix(OS_Find, _INR(0,1), 0, (*pipe)->file_handle);
    (*pipe)->file_handle = 0;

    if (e) syslog("%s: usb_close() failed close: %s",
                           (*pipe)->file_name,e->errmess);
  }

  xfree(*pipe);
  *pipe = NULL;
  return NULL;
}

size_t usb_buffer_free(usb_pipe_t pipe)
{
  size_t buf_free;
  __asm
  {
    MOV      R0,#7
    MOV      R1,pipe->buffer_internal
    MOV      R12,pipe->buffer_r12
    BLX      pipe->buffer_code,{R0,R1,R12},{R2},{LR,PSR}
    MOV      buf_free,R2
  }
  return buf_free;
}

size_t usb_buffer_used(usb_pipe_t pipe)
{
  size_t buf_used;

  __asm
  {
    MOV      R0,#6
    MOV      R1,pipe->buffer_internal
    MOV      R12,pipe->buffer_r12
    BLX      pipe->buffer_code,{R0,R1,R12},{R2},{LR,PSR}
    MOV      buf_used,R2
  }
  return buf_used;
}

_kernel_oserror* usb_write(usb_pipe_t  pipe,
                           const void* data,
                           size_t*     size)
{
  size_t buf_free;
  int32_t start_time, time_now;

  _swix(OS_ReadMonotonicTime, _OUT(0), &start_time);

  for (;;)
  {
    __asm
    {
      MOV      R0,#7
      MOV      R1,pipe->buffer_internal
      MOV      R12,pipe->buffer_r12
      BLX      pipe->buffer_code,{R0,R1,R12},{R2},{LR,PSR}
      MOV      buf_free,R2
    }

    // Must block until room is available in buffer.
    // Returning if no room available causes a drastic slowdown.
    // Blocking normally should only be for a maximum 1-2ms.
    if (buf_free >=*size) break;
    
    // But timeout incase the loop blocks too long.
    _swix(OS_ReadMonotonicTime, _OUT(0), &time_now);
    if (time_now - start_time > 10) break;
  } 

  if (buf_free<*size)
  {
    *size = 0;
    return NULL;
  }

  if (DEBUG_TX) syslog("usb_write(): %zu bytes, buffer space %zu",
                       *size, buf_free);

  __asm
  {
    MOV      R0,#1
    MOV      R1,pipe->buffer_internal
    MOV      R2,data
    MOV      R3,*size
    MOV      R12,pipe->buffer_r12
    BLX      pipe->buffer_code,{R0-R3,R12},{},{R2,R3,LR,PSR}
  }

  return NULL;
}

_kernel_oserror* usb_start_read(usb_pipe_t pipe)
{
  if (DEBUG_RX) syslog("usb_start_read()");

  // r3 is undocumented and is the amount of data being requested.
  // This is kept as a large value so that usb IN requests return
  // as much data as is available.
  _kernel_oserror *e = _swix(DeviceFS_CallDevice, _INR(0,3),
                             3, pipe->device_name,
                             pipe->usb_handle, 1u<<30);

  if (e) syslog("usb_start_read() failed with '%s'", e->errmess);
  return e;
}


_kernel_oserror* usb_read(usb_pipe_t   pipe,
                          void*        data,
                          size_t*      size)
{
  if (DEBUG_RX) syslog("usb_read()");

  if (!pipe || pipe->file_handle==0)
  {
    *size = 0;
    return NULL;
  }

  size_t bufused = 0;
  __asm
  {
    MOV      R0,#6
    MOV      R1,pipe->buffer_internal
    MOV      R12,pipe->buffer_r12
    BLX      pipe->buffer_code,{R0,R1,R12},{R2},{LR,PSR}
    MOV      bufused,R2
  }

  size_t to_read = *size;
  if (to_read>bufused) to_read = bufused;

  if (DEBUG_RX) syslog("  size=%zu, bufused=%zu", *size, bufused);

  if (to_read==0)
  {
    *size = 0;
    return NULL;
  }

  __asm
  {
    MOV      R0,#3
    MOV      R1,pipe->buffer_internal
    MOV      R2,data
    MOV      R3,to_read
    MOV      R12,pipe->buffer_r12
    BLX      pipe->buffer_code,{R0-R3,R12},{},{R2,R3,LR,PSR}
    MOV      R0,#8
    BLX      pipe->buffer_code,{R0,R1,R12},{},{LR,PSR}
  }

  *size = to_read;
  return NULL;
}

int usb_upcall_hook_handler(_kernel_swi_regs *r, void *pw)
{
  if (r->r[0]!=UpCall_DeviceRxDataPresent) return 1;
  
  usb_pipe_t pipe = s_pipes;
  while (pipe)
  {
    if (r->r[0]==UpCall_DeviceRxDataPresent && r->r[1]==pipe->file_handle &&
                pipe->direction==USBRead)
    {
      // Data has entered a previously empty DeviceFS read stream
      // buffer.
      if (DEBUG_RX) syslog("Rx Buffer data present");
      if (pipe->handler_fn) pipe->handler_fn(pipe, pipe->handler_ws);
      return 1;
    }
    pipe = pipe->next;
  }

  UNUSED(pw);

  return 1;
}

int usb_fscontrol_hook_handler(_kernel_swi_regs *r, void *pw)
{
  if ((r->r[0] != FSControl_Shut) && (r->r[0] != FSControl_ShutDown))
    return 1;

  UNUSED(pw);

  syslog("fscontrol_hook_handler shut/shutdown detected");
  /* Assume FileSwitch hasn't received the message yet. Go round and shutdown all devices with open pipes. */
  while(s_pipes)
  {
    net_dead_device(s_pipes->device_name);
  }
  syslog("fscontrol_hook_handler done");

  return 1;
}

int usb_find_hook_handler(_kernel_swi_regs *r, void *pw)
{
  if (r->r[0] != OSFind_Close)
    return 1;

  UNUSED(pw);

  if (r->r[1])
  {
    /* Do we own this file? */
    usb_pipe_t pipe = s_pipes;
    while (pipe)
    {
      if(pipe->file_handle == r->r[1])
      {
        syslog("find_hook_handler file close detected");
        net_dead_device(pipe->device_name);
        return 1;
      }
      pipe = pipe->next;
    }
  }
  else
  {
    /* Is DeviceFS current FS? */
    int fs;
    _kernel_oserror *e = _swix(OS_Args,_INR(0,1)|_OUT(1),0,0,&fs);
    if(!e && (fs == fsnumber_DeviceFS))
    {
      syslog("find_hook_handler close all detected");
      /* Assume FileSwitch hasn't received the message yet. Go round and shutdown all devices with open pipes. */
      while(s_pipes)
      {
        net_dead_device(s_pipes->device_name);
      }
      syslog("find_hook_handler done");
    }
  }
  return 1;
}

static bool s_upcall_claimed = false;
static bool s_fscontrol_claimed = false;
static bool s_find_claimed = false;

_kernel_oserror* usb_initialise(void)
{
  if (s_upcall_claimed) return NULL;

  unsigned version = 0;
  _kernel_oserror* e = _swix(USBDriver_Version, _OUT(0), &version);
  if (e || version<49) return err_translate(ERR_USB_TOO_OLD);

  e = _swix(OS_Claim, _INR(0,2), UpCallV, &usb_upcall_hook, g_module_pw);
  if (!e) s_upcall_claimed = true;

  if (!e) e = _swix(OS_Claim, _INR(0,2), FSCV, &usb_fscontrol_hook, g_module_pw);
  if (!e) s_fscontrol_claimed = true;

  if (!e) e = _swix(OS_Claim, _INR(0,2), FindV, &usb_find_hook, g_module_pw);
  if (!e) s_find_claimed = true;

  if(e) usb_finalise();

  return e;
}

_kernel_oserror* usb_finalise(void)
{
  _kernel_oserror *e = NULL;

  if (s_upcall_claimed)
  {
    e = _swix(OS_Release, _INR(0,2), UpCallV, &usb_upcall_hook, g_module_pw);
    if(e)
      return e;
    s_upcall_claimed = false;
  }

  if (s_fscontrol_claimed)
  {
    e = _swix(OS_Release, _INR(0,2), FSCV, &usb_fscontrol_hook, g_module_pw);
    if(e)
      return e;
    s_fscontrol_claimed = false;
  }

  if (s_find_claimed)
  {
    e = _swix(OS_Release, _INR(0,2), FindV, &usb_find_hook, g_module_pw);
    if(e)
      return e;
    s_find_claimed = false;
  }

  return e;
}

void usb_service_reset(void)
{
  /* FileSwitch will reclaim its vectors on Service_Reset, so to ensure we're on the vector chain before it we must do the same thing */
  _swix(OS_Claim, _INR(0,2), FSCV, &usb_fscontrol_hook, g_module_pw);
  _swix(OS_Claim, _INR(0,2), FindV, &usb_find_hook, g_module_pw);
}
