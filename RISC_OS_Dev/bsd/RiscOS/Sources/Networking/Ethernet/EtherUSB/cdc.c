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

/*
 * Backend for devices compatible with the USB communications device class.
 */

#include <stddef.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>

#include "backends.h"
#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "net.h"

#define USB_DEVICE_CLASS_CDC 0x02
#define USB_INTERFACE_CLASS_CDC 0x02
#define USB_INTERFACE_CLASS_CDC_ETHERNET 0x06
#define USB_INTERFACE_CLASS_DATA 0x0a

typedef __packed struct
{
  uint8_t   bLength;
  uint8_t   bDescriptorType;
  uint8_t   bDescriptorSubType;
  uint16_t  bcdCDC;
} usb_cdc_header_descriptor_t;

typedef __packed struct
{
  uint8_t   bLength;
  uint8_t   bDescriptorType;
  uint8_t   bDescriptorSubType;
  uint8_t   bMasterInterface;
  uint8_t   bSlaveInterface[];
} usb_cdc_union_descriptor_t;

typedef __packed struct
{
  uint8_t   bLength;
  uint8_t   bDescriptorType;
  uint8_t   bDescriptorSubType;
  uint8_t   iMACAddress;                 // Index of string descriptor.
  uint32_t  bmEthernetStatistics;        // Mask of supported stats.
  uint16_t  wMaxSegmentSize;             // Max segment size of ethernet dev.
  uint16_t  wNumberOfMCFilters;          // b15: imperfect, b0-14:no filters.
  uint8_t   bNumberPowerFilters;         // No. pattern filters for wakeup.
} usb_cdc_ethernet_descriptor_t;

typedef struct
{
  uint8_t  config;
  uint8_t  master_if;
  uint8_t  master_alt;
  uint8_t  slave_if;
  uint8_t  slave_alt;
  usb_pipe_t rx_pipe;
  usb_pipe_t tx_pipe;
} ws_t;

static _kernel_oserror* device_open(const USBServiceCall* usb,
                                    const char*          options,
                                    void**               private)
{
  if (usb->ddesc.bDeviceClass!=USB_DEVICE_CLASS_CDC ||
      usb->ddesc.bDeviceSubClass!=0 ||
      usb->ddesc.bDeviceProtocol!=0)
  {
    return err_translate(ERR_UNSUPPORTED);
  }

  const usb_cdc_header_descriptor_t*   cdc_header   = NULL;
  const usb_cdc_union_descriptor_t*    cdc_union    = NULL;
  const usb_cdc_ethernet_descriptor_t* cdc_ethernet = NULL;
  const usb_config_descriptor_t*       config       = NULL;

  // Scan the descriptors to pick out the ones we are interested in.
  const void* descriptor = usb_descriptor_list(usb);
  while (descriptor)
  {
    const unsigned type = usb_descriptor_type(descriptor);
    const size_t   size = usb_descriptor_size(descriptor);

    if (type==UDESC_CONFIG && size>=sizeof(usb_config_descriptor_t))
    {
      config = descriptor;
      cdc_header = NULL;
      cdc_union = NULL;
      cdc_ethernet = NULL;
    }
    else if (config && type==UDESC_CS_INTERFACE && size>=3)
    {
      const uint8_t* p = (const uint8_t*)descriptor;
      switch (p[2])
      {
        case 0x00:
          // Header - indicates a concatenated set of functional descriptors
          // for a interface.
          if (size>=sizeof(usb_cdc_header_descriptor_t))
          {
            cdc_header = descriptor;
            cdc_union = NULL;
            cdc_ethernet = NULL;
          }
          break;

        case 0x06:
          // Union: Specifies master and at least one slave interface
          // numbers as 0 based index in this configuration.
          // The master is the controlling interface.
          // The slave is the data inteface.
          if (cdc_header &&
              !cdc_union &&
              size>=sizeof(usb_cdc_union_descriptor_t) &&
              size>=5)
          {
            cdc_union = descriptor;
          }
          break;

        case 0x0f:
          // Ethernet:
          if (cdc_header &&
              !cdc_ethernet &&
              size>=sizeof(usb_cdc_ethernet_descriptor_t))
          {
            cdc_ethernet = descriptor;
          }
          break;
      }
    }
    descriptor = usb_descriptor_next(descriptor);
  }

  if (!(config      &&
        cdc_header  &&
        cdc_union   &&
        cdc_ethernet)) return err_translate(ERR_UNSUPPORTED);

  const usb_interface_descriptor_t* master =
    usb_find_interface(usb, config->bConfigurationValue,
                       cdc_union->bMasterInterface, 0);

  if (!master) return err_translate(ERR_UNSUPPORTED);

  // Find slave interface alternative with suitable looking endpoints.
  // Some devices, including my cable modem, seem to get these the wrong
  // way round...
  const usb_interface_descriptor_t* slave = NULL;
  const usb_interface_descriptor_t* reversed_slave = NULL;

  for (unsigned alt=0; alt!=256; ++alt)
  {
    const usb_interface_descriptor_t* s
      = usb_find_interface(usb, config->bConfigurationValue,
                           cdc_union->bSlaveInterface[0], alt);

    if (!s) break;
    if (s->bInterfaceClass==USB_INTERFACE_CLASS_DATA &&
        s->bNumEndpoints>=2)
    {
      slave = s;
      break;
    }

    if (!reversed_slave &&
        s->bInterfaceClass       ==USB_INTERFACE_CLASS_CDC &&
        s->bInterfaceSubClass    ==USB_INTERFACE_CLASS_CDC_ETHERNET &&
        master->bInterfaceClass  ==USB_INTERFACE_CLASS_DATA &&
        master->bNumEndpoints    >=2)
    {
      reversed_slave = s;
    }
  }

  if (!slave && reversed_slave)
  {
    slave = master;
    master = reversed_slave;
  }

  if (!slave) return err_translate(ERR_UNSUPPORTED);

  ws_t* ws = xalloc(sizeof(ws_t));
  if (!ws) return err_translate(ERR_NO_MEMORY);

  ws->config     = config->bConfigurationValue;
  ws->master_if  = master->bInterfaceNumber;
  ws->master_alt = master->bAlternateSetting;
  ws->slave_if   = slave->bInterfaceNumber;
  ws->slave_alt  = slave->bAlternateSetting;
  ws->rx_pipe    = 0;
  ws->tx_pipe    = 0;

  *private = ws;
  return NULL;
}


static _kernel_oserror* device_start(net_device_t* dev, const char* options)
{
  ws_t* ws = dev->private;

  // Setting the slave interface should kick the device into life.
  _kernel_oserror* e = usb_set_config(dev->name, ws->config);
  if (!e) e = usb_set_interface(dev->name, ws->master_if, ws->master_alt);
  if (!e) e = usb_set_interface(dev->name, ws->slave_if, ws->slave_alt);

  if (!e) e = usb_open(dev->name,
                       &ws->rx_pipe,
                       USBRead,
                       NULL,
                       NULL,
                       "Devices#bulk:$.%s",
                       dev->name);

  if (!e) e = usb_open(dev->name,
                       &ws->tx_pipe,
                       USBWrite,
                       NULL,
                       NULL,
                       "Devices#bulk:$.%s",
                       dev->name);
  if (e)
  {
    usb_close(&ws->rx_pipe);
    usb_close(&ws->tx_pipe);
    return e;
  }

  return NULL;
}

static _kernel_oserror* device_stop(net_device_t* dev)
{
  ws_t* ws = dev->private;
  usb_close(&ws->rx_pipe);
  usb_close(&ws->tx_pipe);
  return NULL;
}

static _kernel_oserror* device_close(void** private)
{
  xfree(*private);
  return NULL;
}

static _kernel_oserror* device_transmit(net_device_t* dev,
                                        const net_tx_t* pkt)
{
  return err_translate(ERR_TX_BLOCKED);
}


static const net_backend_t s_backend = {
  .name        = N_CDC,
  .description = "DescCDC",
  .open        = device_open,
  .start       = device_start,
  .stop        = device_stop,
  .close       = device_close,
  .transmit    = device_transmit,
  .info        = NULL,
  .config      = NULL
};

_kernel_oserror* cdc_register(void)
{
  return net_register_backend(&s_backend);
}

