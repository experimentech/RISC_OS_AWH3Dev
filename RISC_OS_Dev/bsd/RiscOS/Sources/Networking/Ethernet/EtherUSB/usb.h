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
#ifndef USB_H_INCLUDED
#define USB_H_INCLUDED

#include <stdint.h>
#include <stdbool.h>
#include "kernel.h"

// Device speeds
#define USB_SPEED_LOW  (1u)
#define USB_SPEED_FULL (2u)
#define USB_SPEED_HI   (3u)

// Control pipe request types. Or one of each of these.
#define USB_REQ_WRITE        (0u<<7)
#define USB_REQ_READ         (1u<<7)

#define USB_REQ_TP_STANDARD  (0u<<5)
#define USB_REQ_TP_CLASS     (1u<<5)
#define USB_REQ_TP_VENDOR    (2u<<5)

#define USB_REQ_TO_DEVICE    (0u<<0)
#define USB_REQ_TO_INTERFACE (1u<<0)
#define USB_REQ_TO_ENDPOINT  (2u<<0)
#define USB_REQ_TO_OTHER     (3u<<0)

// Common cases
#define USB_REQ_VENDOR_WRITE (USB_REQ_WRITE|USB_REQ_TP_VENDOR)
#define USB_REQ_VENDOR_READ  (USB_REQ_READ|USB_REQ_TP_VENDOR)

// Standard control pipe requests.
#define USB_REQ_GET_STATUS        0u
#define USB_REQ_CLEAR_FEATURE     1u
#define USB_REQ_SET_FEATURE       3u
#define USB_REQ_SET_ADDRESS       5u
#define USB_REQ_GET_DESCRIPTOR    6u
#define USB_REQ_SET_DESCRIPTOR    7u
#define USB_REQ_GET_CONFIGURATION 8u
#define USB_REQ_SET_CONFIGURATION 9u
#define USB_REQ_GET_INTERFACE     10u
#define USB_REQ_SET_INTERFACE     11u
#define USB_REQ_SYNCH_FRAME       12u

// Returns type field from a descriptor,
static inline unsigned usb_descriptor_type(const void* descriptor)
{
  return ((const uint8_t*)descriptor)[1];
}

static inline size_t usb_descriptor_size(const void* descriptor)
{
  return ((const uint8_t*)descriptor)[0];
}

// Returns pointer to next descriptor, or NULL if no more.
static inline const void* usb_descriptor_next(const void* descriptor)
{
  const uint8_t* p = (const uint8_t*)descriptor;
  p += p[0];
  return (p[0]<2) ? NULL : p;
}

// Returns pointer to first descriptor (device descriptor).
static inline const void* usb_descriptor_list(const USBServiceCall* s)
{
  return (const uint8_t*)s + s->descoff;
}

// Calls 'fn' for each USB device currently connected.
typedef _kernel_oserror* (usb_scan_devices_fn)(const USBServiceCall*,
                                               void* handle);

_kernel_oserror* usb_scan_devices(usb_scan_devices_fn* fn, void* handle);

// Finds a interface descriptor, returns NULL if not present.
const usb_interface_descriptor_t*
  usb_find_interface(const USBServiceCall* s,
                     unsigned              config_no,
                     unsigned              interface_no,
                     unsigned              alternate_no);

// Read the location of a device within the device tree
_kernel_oserror* usb_location(const char *name,
                              uint8_t *location);

// Sends request to device's control pipe and await reply.
_kernel_oserror* usb_control(const char* name,
                             uint8_t     request_type,
                             uint8_t     request,
                             uint16_t    value,
                             uint16_t    index,
                             uint16_t    length,
                             void*       data);

// Sends a set configuration command to the device over its control pipe.
_kernel_oserror* usb_set_config(const char* name, unsigned config);

// Selects a interface alternate.
_kernel_oserror* usb_set_interface(const char* name,
                                   unsigned    interface,
                                   unsigned    alternate);

// Handle for an open USB pipe.
typedef struct usb_pipe* usb_pipe_t;

// Purge all data in a usb buffer.
_kernel_oserror* usb_buffer_purge(usb_pipe_t pipe);

// Start a read transfer.
_kernel_oserror* usb_start_read(usb_pipe_t pipe);

// Opens a endpoint for reading/writing, if NULL returned, it is guarented
// that fh is a valid file handle, otherwise fh is zero. The string passed
// through is the devicefs filepath, with printf formating.
typedef enum { USBRead, USBWrite } usb_open_t;

// Called when Tx data sent or Rx data recieved.
typedef void (usb_handler_fn)(usb_pipe_t pipe, void* handler_ws);

#ifdef __CC_NORCROFT
#pragma -v1
#endif

_kernel_oserror* usb_open(const char*     device_name,
                          usb_pipe_t*     pipe,
                          usb_open_t      mode,
                          usb_handler_fn* handler_fn,
                          void*           handler_ws,
                          const char*     device_fmt,
                          ...);

#ifdef __CC_NORCROFT
#pragma -v0
#endif

// If *fs!=0 then purge all buffers associated with the device and
// close it. Sets *pipe to 0 on success. 'name' can be NULL if the device has
// been destroyed (e.g. was unplugged).
_kernel_oserror* usb_close(usb_pipe_t* pipe);

// Non-blocking write upto 'size' bytes to usb endpoint. 'size' updated with
// the actual number of bytes written. Ether all or nothing is written.
_kernel_oserror* usb_write(usb_pipe_t  pipe,
                           const void* data,
                           size_t*     size);

// Non-blocking read of up to up to 'size' bytes from a usb endpoint. 'size'
// is updated with the actual number of bytes read.
_kernel_oserror* usb_read(usb_pipe_t   pipe,
                          void*        data,
                          size_t*      size);

// Returns free or used bytes in a USB pipe's buffer.
size_t usb_buffer_free(usb_pipe_t pipe);
size_t usb_buffer_used(usb_pipe_t pipe);

// By default, short packets are only sent if the data sent is not an
// exact multiple of the of the pipe's max packet size. Calling this
// forces them to be sent at the end of all USB writes.
_kernel_oserror* usb_force_short_xfer(usb_pipe_t pipe);

// Init/uninit calls - must respect returned errors.
_kernel_oserror* usb_initialise(void);
_kernel_oserror* usb_finalise(void);

// Notify of Service_Reset
void usb_service_reset(void);

#endif
