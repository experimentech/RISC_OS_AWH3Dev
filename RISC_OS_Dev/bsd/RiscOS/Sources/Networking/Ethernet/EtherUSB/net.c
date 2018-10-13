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
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <stdarg.h>

#include "swis.h"
#include "kernel.h"
#include "AsmUtils/irqs.h"
#include "Global/NewErrors.h"
#include "Global/Variables.h"
#include "Global/ModHand.h"
#undef   Module_Title
#include "SyncLib/SyncLib.h"

#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "net.h"
#include "mbuf.h"
#include "products.h"
#include "config.h"
#include "EtherUSBHdr.h"


#define DEBUG_DATA  0
#define DEBUG_PKTS  0
#define DEBUG_SCAN  0
#define DEBUG_QUEUE 0

typedef struct backend_t
{
  struct backend_t*    next;                          // Next list.
  struct backend_t*    prev;                          // Previous list.
  const net_backend_t* backend;                       // Implementation
} backend_t;

static backend_t*    s_backends = NULL;               // Owns data.
static net_device_t* s_devices = NULL;                // Owns data.
static net_device_t* s_units[MODULE_MAX_UNITS];       // Unit no -> device.

struct net_filter_t
{
  struct net_filter_t*   next;
  struct net_filter_t*   prev;
  uint32_t               frame_type;
  uint8_t                addr_level;
  uint8_t                err_level;
  uint32_t               r12;
  uint32_t               handler;
  uint32_t               flags;
};


//---------------------------------------------------------------------------
// Generation of default MAC address for devices which don't have one. The
// MAC address is generated from the machine's unique ID, or failing that
// a hard coded one.
//
// Most significant byte:
//   b0   : Flag: 0=>unicast, 1=>multicast.
//   b1   : Flag: 0=>globally unique, 1=>locally administered.
//   b2-b3: zero.
//   b4-b7: unit number.
// unit number
//---------------------------------------------------------------------------
void net_default_mac(unsigned unit, uint8_t* mac)
{
  mac[0] = 2 | (((uint8_t)unit) << 4);

  unsigned id_lo = 0;
  unsigned id_hi = 0;
  _kernel_oserror* e = _swix(OS_ReadSysInfo, _IN(0)|_OUTR(0,1),
                             5, &id_lo, &id_hi);

  if (!e && (id_lo!=0 || id_hi!=0))
  {
    // Crude hash to reduce 64 bit machine ID to 40 bits.
    mac[1] = ((id_lo >> 0 ) & 0xff) ^ ((id_hi >> 8 ) & 0xff);
    mac[2] = ((id_lo >> 8 ) & 0xff) ^ ((id_hi >> 16) & 0xff);
    mac[3] = ((id_lo >> 16) & 0xff) ^ ((id_hi >> 24) & 0xff);
    mac[4] = ((id_lo >> 24) & 0xff);
    mac[5] = ((id_hi >> 0 ) & 0xff);
  }
  else
  {
    // Machine has no ID, use a default one.
    mac[1] = 0x07;
    mac[2] = 0x21;
    mac[3] = 0x68;
    mac[4] = 0x16;
    mac[5] = 0x03;
  }
}

//---------------------------------------------------------------------------
// Look up the configured MAC address for the machine. Returns false if no
// MAC exists, or if it's already in use by another driver.
//---------------------------------------------------------------------------
bool net_machine_mac(uint8_t* mac)
{
  unsigned int mac2[2] = {0,0};
  _kernel_oserror* e = _swix(OS_ReadSysInfo, _IN(0)|_OUTR(0,1),
                             4, &mac2[0], &mac2[1]);

  if (e || ((mac2[0] == 0) && (mac2[1] == 0)))
  {
    return false;
  }

  // We have a MAC, now enumerate all the devices on the system to check it
  // isn't already in use (e.g. motherboard NIC on Iyonix)
  ChDib *drivers = NULL;
  e = _swix(OS_ServiceCall,_INR(0,1)|_OUT(0),0,Service_EnumerateNetworkDrivers,&drivers);
  if (e)
    return false;
  bool found = false;
  while(drivers)
  {
    if(drivers->chd_dib && drivers->chd_dib->dib_address &&
       (drivers->chd_dib->dib_address != mac) &&
       !memcmp(drivers->chd_dib->dib_address,mac2,ETHER_ADDR_LEN))
      found = true;
    ChDib *next = drivers->chd_next;
    _swix(OS_Module,_IN(0)|_IN(2),ModHandReason_Free,drivers);
    drivers = next;
  }

  if (!found)
    memcpy(mac,mac2,ETHER_ADDR_LEN);

  return !found;
}

//---------------------------------------------------------------------------
// Hack to aid device writes and help stop stalls due to not being able
// to tell when a USB read has finished.
//---------------------------------------------------------------------------
static callback_delay_t prod_writes(void* h)
{
  net_device_t* dev = h;
  net_attempt_transmit(dev);
  return 5;
}

//---------------------------------------------------------------------------
// Prod status. Save each backend from having to do this. Only called if
// the backend supports the status call.
//---------------------------------------------------------------------------
static callback_delay_t prod_status(void* h)
{
  net_device_t* dev = h;
  const net_backend_t* backend = dev->backend;
  _kernel_oserror* e = backend->status(dev);

  callback_delay_t delay = 100;
  if (e)
  {
    syslog("%s: status error: %s", dev->name, e->errmess);
    delay = 500;
  }

  return delay;
}

//---------------------------------------------------------------------------
// Set Inet$EtherType if not already set. This violates the DCI specification
// slightly, but is probably the least worst option. See !ReadMe for
// reasoning behind this.
//---------------------------------------------------------------------------
static callback_delay_t set_inet_variables(void* h)
{
  char value[20];

  size_t size = 0;
  _kernel_oserror *e = _swix(OS_ReadVarVal, _INR(0,4)|_OUT(2),
                             "Inet$EtherType",
                             value, sizeof(value)-1, 0, 3,
                             &size);
  if ((e && (e->errnum==ErrorNumber_VarCantFind)) || size==0)
  {
    e = NULL;
    for (unsigned unit=0; unit!=MODULE_MAX_UNITS; ++unit)
    {
      if (s_units[unit])
      {
        snprintf(value, sizeof(value), MODULE_DCI_NAME "%u", unit);
        e = _swix(OS_SetVarVal, _INR(0,4),
                  "Inet$EtherType", value, strlen(value), 0, VarType_String);
        break;
      }
    }
  }

  if (e) syslog("Can't set Inet$... variables: %s", e->errmess);

  UNUSED(h);

  return CALLBACK_REMOVE;
}

//---------------------------------------------------------------------------
// Deregisters device, informs backend of its demise and frees resources.
//---------------------------------------------------------------------------
static _kernel_oserror* device_destroy(net_device_t* dev)
{
  syslog("%s: removed",dev->name);

  _kernel_oserror* e = callback_cancel(&prod_writes, dev);
  if (!e && dev->backend->status) e = callback_cancel(&prod_status, dev);

  if (!e) e = _swix(OS_ServiceCall, _INR(0,3),
                    &(dev->dib),
                    Service_DCIDriverStatus,
                    DCIDRIVER_DYING,
                    DCIVERSION);

  if (e) return e;

  if (dev->backend->stop) dev->backend->stop(dev);
  if (dev->backend->close) dev->backend->close(&(dev->private));
  s_units[dev->dib.dib_unit] = NULL;
  LINKEDLIST_REMOVE(s_devices, dev);

  while (dev->specific_filters)
  {
    net_filter_t* r = dev->specific_filters;
    LINKEDLIST_REMOVE(dev->specific_filters, r);
    xfree(r);
  }

  xfree(dev->sink_filter);
  xfree(dev->monitor_filter);
  xfree(dev->ieee_filter);

  xfree(dev);
  return NULL;
}

//---------------------------------------------------------------------------
// TX packet buffer functions
//---------------------------------------------------------------------------
static inline void tx_push(int irqs_disabled, net_tx_t* volatile* list, net_tx_t* packet)
{
  if (!irqs_disabled) _kernel_irqs_off();
  
  packet->next = *list;
  *list = packet;
  
  if (!irqs_disabled) _kernel_irqs_on();
}

static inline net_tx_t* tx_pop(int irqs_disabled, net_tx_t* volatile* list)
{
  if (!irqs_disabled) _kernel_irqs_off();
  
  net_tx_t* packet = *list;
  if (packet != NULL) *list = packet->next;
  
  if (!irqs_disabled) _kernel_irqs_on();
  
  return packet;
}

//---------------------------------------------------------------------------
// Registers a device, binds it to a backend and asks the backend to
// initialise it.
//---------------------------------------------------------------------------
static _kernel_oserror* device_create(const USBServiceCall* dev,
                                      const net_backend_t*  backend,
                                      const char*           options,
                                      void*                 private)
{
  net_device_t* d = xalloc(sizeof(net_device_t));

  assert(sizeof(d->name)==sizeof(dev->devname));

  if (!d) return err_translate(ERR_NO_MEMORY);

  memcpy(d->name, dev->devname, sizeof(dev->devname));

  memset(&d->status, 0, sizeof(d->status));
  memset(&d->abilities, 0, sizeof(d->abilities));

  d->vendor = dev->ddesc.idVendor;
  d->product = dev->ddesc.idProduct;
  d->bus = dev->bus;
  d->address = dev->devaddr;
  d->speed = dev->speed;

  {
    _kernel_oserror *e = usb_location(d->name,d->usb_location);
    if(e)
    {
      xfree(d);
      return e;
    }
  }

  d->gone = false;
  d->tx_guard = 0;
  d->backend = backend;
  d->dib.dib_swibase = EtherUSB_00;
  d->dib.dib_name = (unsigned char *)MODULE_DCI_NAME;
  d->dib.dib_unit = MODULE_MAX_UNITS;
  d->dib.dib_address = d->status.mac;
  d->dib.dib_module = (unsigned char *)Module_Title;
  d->dib.dib_location = (unsigned char *)d->location;
  d->dib.dib_slot.sl_slotid = DIB_SLOT_USB_BUS(dev->bus);
  d->dib.dib_slot.sl_minor = dev->devaddr;
  d->dib.dib_slot.sl_pcmciaslot = 0;
  d->dib.dib_slot.sl_mbz = 0;
  d->dib.dib_inquire = 0;

  snprintf(d->location, sizeof(d->location),
           msg_translate("Loc"),
           d->bus, d->address, d->name);

  d->mtu = 1500;
  d->private = private;
  d->specific_filters = NULL;
  d->sink_filter = NULL;
  d->monitor_filter = NULL;
  d->ieee_filter = NULL;
   
  d->packet_tx_count = 0;
  d->packet_rx_count = 0;
  d->packet_unwanted = 0;
  d->packet_tx_errors = 0;
  d->packet_rx_errors = 0;
  d->packet_tx_bytes = 0;
  d->packet_rx_bytes = 0;
  d->queue_tx_overflows = 0;
  d->queue_tx_max_usage = 0;

  {
    bool reserved[MODULE_MAX_UNITS];
    _kernel_oserror *e = config_reserved_units(reserved,d);
    if(e)
    {
      xfree(d);
      return e;
    }
    if(d->dib.dib_unit == MODULE_MAX_UNITS)
    {
      for(unsigned i=0; i!=MODULE_MAX_UNITS; ++i)
      {
        if (!reserved[i] && !s_units[i])
        {
          d->dib.dib_unit = i;
          break;
        }
      }
    }
  }

  LINKEDLIST_INSERT(s_devices, d);

  if (backend->start)
  {
    _kernel_oserror* e = backend->start(d, options);
    if (e)
    {
      LINKEDLIST_REMOVE(s_devices, d);
      xfree(d);
      return e;
    }
  }

  syslog("%s: backend '%s', MAC %02X:%02X:%02X:%02X:%02X:%02X",
         dev->devname, backend->name,
         d->dib.dib_address[0], d->dib.dib_address[1], d->dib.dib_address[2],
         d->dib.dib_address[3], d->dib.dib_address[4], d->dib.dib_address[5]);

  {
    uint32_t inquire = ( INQ_HASSTATS |
                         INQ_HWADDRVALID |
                         INQ_RXERRORS );

    const net_abilities_t* a = &d->abilities;
    if (a->multicast        ) inquire |= INQ_MULTICAST;
    if (a->promiscuous      ) inquire |= INQ_PROMISCUOUS;
    if (a->tx_rx_loopback   ) inquire |= INQ_CANREFLECT;
    if (a->mutable_mac      ) inquire |= INQ_SOFTHWADDR;

    d->dib.dib_inquire = inquire;
  }

  net_config_t config;

  {
    _kernel_oserror* e = config_new_device(d, &config);

    if (!e && d->dib.dib_unit>=MODULE_MAX_UNITS) e = err_translate(ERR_TOO_MANY_UNITS);
    if (!e && s_units[d->dib.dib_unit]) e = err_translate(ERR_UNIT_IN_USE);
    if (!e && backend->status) e = callback(&prod_status, 100, d);
    if (!e) e = callback(&set_inet_variables, 1, NULL);
    if (e)
    {
      LINKEDLIST_REMOVE(s_devices, d);
      if (backend->stop) backend->stop(d);
      xfree(d);
      return e;
    }
  }

  d->dib.dib_slot.sl_minor = d->dib.dib_unit;
  s_units[d->dib.dib_unit] = d;

  _swix(OS_ServiceCall, _INR(0,3),
        &(d->dib),
        Service_DCIDriverStatus,
        DCIDRIVER_STARTING,
        DCIVERSION);

  syslog("%s: bound to interface %s%u",
         dev->devname, d->dib.dib_name, d->dib.dib_unit);

  if (backend->config)
  {
    // Consider failure to config here a soft error as it may be able
    // to correct it using *EJConfig.
    _kernel_oserror* e = backend->config(d, &config);
    if (e) syslog("%s: config: %s", dev->devname, e->errmess);
  }

  return NULL;
}

//---------------------------------------------------------------------------
// Checks a device to see if any backend can handle it.
// Takes no action if device is not supported.
//---------------------------------------------------------------------------
static inline bool backend_match(const char* s1, const char* s2)
{
  while (*s1 && *s2 && tolower(*s1)==tolower(*s2)) ++s1,++s2;
  return (*s1==*s2);
}

_kernel_oserror* net_check_device(const USBServiceCall* dev, void* handle)
{
  if (DEBUG_SCAN)
  {
    static const char *speed;

    switch (dev->speed)
    {
      case USB_SPEED_FULL: speed = "Full";      break;
      case USB_SPEED_LOW:  speed = "Low";       break;
      case USB_SPEED_HI:   speed = "Hi";        break;
      default:             speed = "<UNKNOWN>"; break;
    }
    syslog("Checking '%s' %02x:%02x:%02x [%s speed]",
                         dev->devname,
                         dev->ddesc.bDeviceClass,
                         dev->ddesc.bDeviceSubClass,
                         dev->ddesc.bDeviceProtocol,
                         speed);
  }

  const char* backend_name = NULL;
  const char* options = NULL;
  if (products_match(dev, &backend_name, &options))
  {
    if (!backend_name || backend_name[0]<=32)
    {
      syslog("Device '%s' 0x%04hX:0x%04hX intentionally ignored",
              dev->devname, dev->ddesc.idVendor, dev->ddesc.idProduct);
      return NULL;
    }
  }

  const backend_t* bbackend = s_backends;
  while (bbackend)
  {
    const net_backend_t* backend = bbackend->backend;
    bbackend = bbackend->next;

    if (backend_name && !backend_match(backend_name, backend->name))
      continue;

    if (backend && backend->open)
    {
      void* private = NULL;
      _kernel_oserror* e = backend->open(dev, options, &private);
      if (!e)
      {
        e = device_create(dev, backend, options, private);
        if (!e) return NULL;

        syslog("%s: Removed as unable to start device: %s",
                dev->devname, e->errmess);

        if (backend->close) backend->close(&private);
        return NULL;
      }
      if (e && e->errnum!=err_translate(ERR_UNSUPPORTED)->errnum) return e;
      if (e && DEBUG_SCAN) syslog("  Unsupported.");
      if (backend_name) return NULL;
    }
  }
  if (backend_name)
  {
    syslog("Unknown backend name specified in products list: '%s'",
            backend_name);
  }

  UNUSED(handle);

  return NULL;
}

//---------------------------------------------------------------------------
// Lookup a device from a unit number, returns NULL if unknown.
//---------------------------------------------------------------------------
static inline net_device_t* net_from_unit(unsigned unit)
{
  return (unit>=MODULE_MAX_UNITS) ? NULL : s_units[unit];
}

//---------------------------------------------------------------------------
// Notify of device removal. 'name' is DeviceFS name, e.g. 'USB1'
//---------------------------------------------------------------------------

_kernel_oserror* net_dead_device(const char* name)
{
  net_device_t* dev = s_devices;
  while (dev)
  {
    if (strcoll(name, dev->name)==0)
    {
      dev->gone = true;
      return device_destroy(dev);
    }
    dev = dev->next;
  }
  return NULL;
}

//---------------------------------------------------------------------------
// Called on module initialisation to register backends.
//---------------------------------------------------------------------------
_kernel_oserror* net_register_backend(const net_backend_t* backend)
{
  syslog("Adding backend: %s",backend->name);

  backend_t* b = xalloc(sizeof(backend_t));
  if (!b) return err_translate(ERR_NO_MEMORY);

  b->backend = backend;
  LINKEDLIST_INSERT(s_backends, b);
  return NULL;
}

//---------------------------------------------------------------------------
// Called on module death.
//---------------------------------------------------------------------------

_kernel_oserror* net_finalise(void)
{
  net_device_t* dev = s_devices;
  _kernel_oserror* e = NULL;
  while (dev)
  {
    net_device_t* tdev = dev;
    dev = dev->next;
    e = device_destroy(tdev);
    if (e) syslog("%s: error shutting down: %s", tdev->name, e->errmess);
  }

  if (e) return e;

  while (s_backends)
  {
    backend_t* b = s_backends;
    s_backends = s_backends->next;
    xfree(b);
  }

  return NULL;
}

//---------------------------------------------------------------------------
// Send a packet to wherever it is meant to go or discard it.
//---------------------------------------------------------------------------
_kernel_oserror* net_receive(net_device_t* dev,
                             const void* pk,
                             size_t size,
                             uint32_t error)
{
  if (size<sizeof(net_header_t))
  {
    syslog("Receive: packet too short: %zu/%u",size,sizeof(net_header_t));
    ++dev->packet_rx_errors;
    return NULL;
  }

  const net_header_t* hdr = pk;
  const uint32_t type = (hdr->type >> 8) | ((hdr->type & 0xff) << 8);
  const net_filter_t* handler = NULL;

  if (DEBUG_PKTS)
    syslog("Receive: type=&%04X size=%zu err=%u "
           "%02x:%02x:%02x:%02x:%02x:%02x -> "
           "%02x:%02x:%02x:%02x:%02x:%02x",
           type,
           size,
           error,
           hdr->src_addr[0], hdr->src_addr[1], hdr->src_addr[2],
           hdr->src_addr[3], hdr->src_addr[4], hdr->src_addr[5],
           hdr->dst_addr[0], hdr->dst_addr[1], hdr->dst_addr[2],
           hdr->dst_addr[3], hdr->dst_addr[4], hdr->dst_addr[5]);

  if (DEBUG_PKTS && DEBUG_DATA) syslog_data(pk, size);

  if (type>1500)
  {
    // Ethernet 2.0 frame
    handler = dev->monitor_filter;
    if (!handler)
    {
      handler = dev->specific_filters;
      while (handler)
      {
        if (handler->frame_type == type) break;
        handler = handler->next;
      }
      if (!handler) handler = dev->sink_filter;
    }
  }
  else
  {
    // IEEE 802.3
    handler = dev->ieee_filter;
  }

  ++dev->packet_rx_count;
  dev->packet_rx_bytes += size;
  if (error) ++dev->packet_rx_errors;

  if (!handler)
  {
     ++dev->packet_unwanted;
     return NULL;
  }

  if (error && handler->err_level==0)
  {
    ++dev->packet_unwanted;
    return NULL;
  }

  RxHdr rx;
  rx.rx_tag = 0;
  rx.rx_ptr = NULL;
  for (size_t i=0; i!=ETHER_ADDR_LEN; ++i) rx.rx_src_addr[i] = hdr->src_addr[i];
  for (size_t i=0; i!=ETHER_ADDR_LEN; ++i) rx.rx_dst_addr[i] = hdr->dst_addr[i];
  rx._spad[0] = 0;
  rx._spad[1] = 0;
  rx._dpad[0] = 0;
  rx._dpad[1] = 0;
  rx.rx_frame_type = type;
  rx.rx_error_level = error;

  mbuf_t* mbuf1 = g_mbuf->alloc_u(g_mbuf, sizeof(RxHdr), &rx);
  if (!mbuf1) return err_translate(ERR_NO_MEMORY);

  mbuf_t* mbuf2 = g_mbuf->alloc_u(g_mbuf,
                                  size - sizeof(net_header_t),
                                  (void*)(hdr+1));
  if (!mbuf2)
  {
    g_mbuf->freem(g_mbuf, mbuf1);
    return err_translate(ERR_NO_MEMORY);
  }

  mbuf1->type = MBUF_MT_HEADER;
  mbuf2->type = MBUF_MT_DATA;

  mbuf1->next = mbuf2;
  mbuf1->list = NULL;
  mbuf2->list = NULL;

  if (handler->flags & FILTER_NO_UNSAFE)
  {
    mbuf1 = g_mbuf->ensure_safe(g_mbuf, mbuf1);
  }

  __asm
  {
    mov r0,&dev->dib
    mov r1,mbuf1
    mov r12,handler->r12
    blx handler->handler,{r0,r1,r12},{},{LR,PSR}
  }

  return NULL;
}

//---------------------------------------------------------------------------
// _Inquire
//---------------------------------------------------------------------------
_kernel_oserror* net_inquire(_kernel_swi_regs* r)
{
  net_device_t* dev = net_from_unit(r->r[1]);
  if (!dev) return err_translate(ERR_BAD_UNIT);
  r->r[2] = dev->dib.dib_inquire;
  return NULL;
}

//---------------------------------------------------------------------------
// _GetNetworkMTU
//---------------------------------------------------------------------------
_kernel_oserror* net_get_network_mtu(_kernel_swi_regs* r)
{
  net_device_t* dev = net_from_unit(r->r[1]);
  if (!dev) return err_translate(ERR_BAD_UNIT);
  r->r[2] = dev->mtu;
  return NULL;
}

//---------------------------------------------------------------------------
// Send some data (DCI_Transmit).
//---------------------------------------------------------------------------
// Note there can be multiple mbuf chains representing multiple packets.



//---------------------------------------------------------------------------
// Attempts to send next queued packet by calling dev's backend.
//---------------------------------------------------------------------------


typedef struct 
{
  int                   flags;
  int                   if_unit;
  unsigned int          type;                   // Ethernet packet type
  mbuf_t*               mbuf_list;              // List of mbufs to send
  const uint8_t*        dst_addr;               // Destination ethernet address 
  const uint8_t*        src_addr;               // Source ethernet address if
                                                // TX_FAKESOURCE flag set
} dci4transmit_t;

static _kernel_oserror* tx_error(_kernel_oserror* e, dci4transmit_t* args)
{
  mbuf_t* next;
  mbuf_t* mbuf;

  if (args == NULL || (args->flags & TX_PROTOSDATA) != 0) return e;
  
  // Delete mbuf list if protocol doesn't own the data
  for (mbuf = args->mbuf_list; mbuf != NULL; mbuf = next)
  {
    next = mbuf->list;
    g_mbuf->freem(g_mbuf, mbuf);
  }
 
  return e;
}

_kernel_oserror* net_transmit(_kernel_swi_regs* r)
{
  _kernel_oserror* e = NULL;
  
  dci4transmit_t* args = (void*) r;
  
  if (args->mbuf_list == NULL) return e;
  
  net_device_t* dev = net_from_unit(args->if_unit);
   
  if (dev == NULL) 
  {
    return tx_error(err_translate(ERR_BAD_UNIT),args);
  }

  uint8_t guard = atomic_update_byte(1, &dev->tx_guard);
  
  if (guard != 0)
  {
      return tx_error(err_translate(ERR_TX_BLOCKED),args);
  }

  // free up any buffered packets that can be inserted into usb buffer now
  for (mbuf_t* mbuf = args->mbuf_list; mbuf; mbuf = mbuf->list)
  {
      // Skip an mbuf that is too big
      size_t size = g_mbuf->count_bytes(g_mbuf, mbuf);
      if (size>TX_MAX_DATA_SIZE) {e = err_translate(ERR_MESSAGE_TOO_BIG); continue;}
      
      
      dev->tx_packet.size = size + sizeof(net_header_t);
      dev->tx_packet.header.type = ((args->type >> 8) & 0x00ff) |
                              ((args->type << 8) & 0xff00) ;

      const uint8_t* src = (args->flags & TX_FAKESOURCE)
                         ? args->src_addr
                         : (dev->status.mac);

      const uint8_t* dst = args->dst_addr;

      for (size_t i=0; i!=ETHER_ADDR_LEN; ++i) dev->tx_packet.header.src_addr[i] = src[i];
      for (size_t i=0; i!=ETHER_ADDR_LEN; ++i) dev->tx_packet.header.dst_addr[i] = dst[i];

      g_mbuf->export(g_mbuf, mbuf, size, dev->tx_packet.data);
      
      e = dev->backend->transmit(dev, &dev->tx_packet); /* blocking in usb_write */
        
      if (e)
      {
        ++dev->packet_tx_errors;
        break;
      }
      
      ++dev->packet_tx_count;
      dev->packet_tx_bytes += size;
  }
  
  dev->tx_guard = 0;

  return tx_error(e,args);
}  

_kernel_oserror* net_attempt_transmit(net_device_t* dev) { dev = dev; return 0;}



//---------------------------------------------------------------------------
// Claim/release packet types (DCI_Filter).
//---------------------------------------------------------------------------

static _kernel_oserror* net_filter_impl(_kernel_swi_regs* r)
{
  net_device_t* dev = net_from_unit(r->r[1]);
  if (!dev) return err_translate(ERR_BAD_UNIT);

  const uint32_t flags = r->r[0];
  const uint32_t frame_type = (uint32_t)(r->r[2]) & 0xffff;
  const uint32_t frame_level = (uint32_t)(r->r[2]) >> 16;
  const uint32_t addr_level = r->r[3];
  const uint32_t err_level = r->r[4];
  const uint32_t r12 = r->r[5];
  const uint32_t handler = r->r[6];

  if (frame_level==0 || frame_level>FRMLVL_IEEE) return err_translate(ERR_BAD_VALUE);
  if (frame_level!=FRMLVL_E2SPECIFIC && frame_type!=0) return err_translate(ERR_BAD_VALUE);

  if (flags & FILTER_RELEASE)
  {
    // Release
    switch (frame_level)
    {
      case FRMLVL_E2SINK:
        if (!dev->sink_filter) return err_translate(ERR_BAD_FILTER_RELEASE);
        if (dev->sink_filter->r12!=r12 ||
            dev->sink_filter->handler!=handler)
          {
            return err_translate(ERR_OTHERS_FILTER_RELEASE);
          }
        xfree(dev->sink_filter);
        dev->sink_filter = NULL;
        _swix(OS_ServiceCall, _INR(0,4),
              (&dev->dib), Service_DCIFrameTypeFree,
              r->r[2], r->r[3], r->r[4]);
        return NULL;

      case FRMLVL_E2MONITOR:
        if (!dev->monitor_filter) return err_translate(ERR_BAD_FILTER_RELEASE);
        if (dev->monitor_filter->r12!=r12 ||
            dev->monitor_filter->handler!=handler)
          {
            return err_translate(ERR_OTHERS_FILTER_RELEASE);
          }
        xfree(dev->monitor_filter);
        dev->monitor_filter = NULL;
        _swix(OS_ServiceCall, _INR(0,4),
              (&dev->dib), Service_DCIFrameTypeFree,
              r->r[2], r->r[3], r->r[4]);
        return NULL;

      case FRMLVL_IEEE:
        if (!dev->ieee_filter) return err_translate(ERR_BAD_FILTER_RELEASE);
        if (dev->ieee_filter->r12!=r12 ||
            dev->ieee_filter->handler!=handler)
          {
            return err_translate(ERR_OTHERS_FILTER_RELEASE);
          }
        xfree(dev->ieee_filter);
        dev->ieee_filter = NULL;
        _swix(OS_ServiceCall, _INR(0,4),
              (&dev->dib), Service_DCIFrameTypeFree,
              r->r[2], r->r[3], r->r[4]);
        return NULL;

      case FRMLVL_E2SPECIFIC:
        for (net_filter_t* f = dev->specific_filters; f; f=f->next)
        {
          if (frame_type==f->frame_type)
          {
            if (f->r12!=r12 || f->handler!=handler)
              return err_translate(ERR_OTHERS_FILTER_RELEASE);

            LINKEDLIST_REMOVE(dev->specific_filters,f);
            xfree(f);
            _swix(OS_ServiceCall, _INR(0,4),
                  (&dev->dib), Service_DCIFrameTypeFree,
                  r->r[2], r->r[3], r->r[4]);
            return NULL;
          }
        } return err_translate(ERR_BAD_FILTER_RELEASE);
    }
    return err_translate(ERR_BAD_VALUE);
  }
  else
  {
    // Claim
    net_filter_t** f = NULL;
    switch (frame_level)
    {
      case FRMLVL_E2SINK:
        if (dev->sink_filter || dev->monitor_filter)
          return err_translate(ERR_BAD_FILTER_CLAIM);
        f = &(dev->sink_filter);
        break;

      case FRMLVL_E2MONITOR:
        if (dev->sink_filter || dev->monitor_filter || dev->specific_filters)
          return err_translate(ERR_BAD_FILTER_CLAIM);
        f = &(dev->monitor_filter);
        break;

      case FRMLVL_IEEE:
        if (dev->ieee_filter) return err_translate(ERR_BAD_FILTER_CLAIM);
        f = &(dev->ieee_filter);
        break;

      case FRMLVL_E2SPECIFIC:
        for (net_filter_t* f = dev->specific_filters; f; f=f->next)
        {
          if (frame_type==f->frame_type) return err_translate(ERR_BAD_FILTER_CLAIM);
        }
        f = &(dev->specific_filters);
        break;
    }
    if (!f) return err_translate(ERR_BAD_VALUE);

    net_filter_t* filter = xalloc(sizeof(net_filter_t));
    if (!filter) return err_translate(ERR_NO_MEMORY);

    filter->frame_type = frame_type;
    filter->addr_level = addr_level;
    filter->err_level = err_level;
    filter->r12 = r12;
    filter->handler = handler;
    filter->flags = flags;

    if (f==&(dev->specific_filters))
    {
      LINKEDLIST_INSERT(dev->specific_filters, filter);
    }
    else
    {
      filter->next = NULL;
      filter->prev = NULL;
      *f = filter;
    }
    return NULL;
  }
  return err_translate(ERR_BAD_OPERATION);
}

_kernel_oserror* net_filter(_kernel_swi_regs* r)
{
  // FIXME: Don't really want to disable IRQs for this long...
  int              irqs = ensure_irqs_off();
  _kernel_oserror* e = net_filter_impl(r);
  restore_irqs(irqs);
  return e;
}

//---------------------------------------------------------------------------
// Release all packets from a single protocol module
//---------------------------------------------------------------------------
static _kernel_oserror *net_protocol_dying_impl(_kernel_swi_regs* r)
{
  if (r->r[2]!=1) return NULL;
  const uint32_t r12 = r->r[0];
  for (net_device_t* dev=s_devices; dev; dev=dev->next)
  {
    if (dev->sink_filter && dev->sink_filter->r12==r12)
    {
      _swix(OS_ServiceCall, _INR(0,4),
            (&dev->dib), Service_DCIFrameTypeFree,
             FRMLVL_E2SINK,
             dev->sink_filter->addr_level,
             dev->sink_filter->err_level);

      xfree(dev->sink_filter);
      dev->sink_filter = NULL;
    }

    if (dev->monitor_filter && dev->monitor_filter->r12==r12)
    {
      _swix(OS_ServiceCall, _INR(0,4),
            (&dev->dib), Service_DCIFrameTypeFree,
             FRMLVL_E2MONITOR,
             dev->monitor_filter->addr_level,
             dev->monitor_filter->err_level);

      xfree(dev->monitor_filter);
      dev->monitor_filter = NULL;
    }

    if (dev->ieee_filter && dev->ieee_filter->r12==r12)
    {
      _swix(OS_ServiceCall, _INR(0,4),
            (&dev->dib), Service_DCIFrameTypeFree,
             FRMLVL_IEEE,
             dev->ieee_filter->addr_level,
             dev->ieee_filter->err_level);

      xfree(dev->ieee_filter);
      dev->ieee_filter = NULL;
    }

    net_filter_t* next = dev->specific_filters;
    while (next)
    {
      net_filter_t* f = next;
      next = next->next;
      if (f->r12==r12)
      {
        _swix(OS_ServiceCall, _INR(0,4),
              (&dev->dib), Service_DCIFrameTypeFree,
              f->frame_type | (FRMLVL_E2SPECIFIC<<16),
              f->addr_level,
              f->err_level);

        LINKEDLIST_REMOVE(dev->specific_filters, f);
        xfree(f);
      }
    }
  }
  return NULL;
}

_kernel_oserror *net_protocol_dying(_kernel_swi_regs* r)
{
  // FIXME: Don't really want to disable IRQs for this long...
  int              irqs = ensure_irqs_off();
  _kernel_oserror* e = net_protocol_dying_impl(r);
  restore_irqs(irqs);
  return e;
}

//---------------------------------------------------------------------------
// Statistics
//---------------------------------------------------------------------------
static uint8_t dci_interface_type(const net_status_t* status)
{
  switch (status->link)
  {
    case net_link_unknown:
      break;

    case net_link_10BaseT_Half:
    case net_link_10BaseT_Full:
      return ST_TYPE_10BASET;

    case net_link_100BaseTX_Half:
    case net_link_100BaseTX_Full:
      return ST_TYPE_100BASETX;

    case net_link_100BaseT4:
      return ST_TYPE_100BASET4;

    case net_link_1000BaseT_Half:
    case net_link_1000BaseT_Full:
      return ST_TYPE_1000BASET;
  }

  // Fallback to just picking one.
  switch(status->speed)
  {
    case net_speed_unknown: break;
    case net_speed_10Mb   : return ST_TYPE_10BASET;
    case net_speed_100Mb  : return ST_TYPE_100BASETX;
    case net_speed_1000Mb  : return ST_TYPE_1000BASET;
  }

  return ST_TYPE_100BASETX;
}

_kernel_oserror* net_stats(_kernel_swi_regs* r)
{
  net_device_t* dev = net_from_unit(r->r[1]);
  if (!dev) return err_translate(ERR_BAD_UNIT);

  struct stats* s = (void*)(r->r[2]);
  memset(s, 0, sizeof(struct stats));

  if ((r->r[0]) & 1)
  {
    // Return stats
    const net_status_t* status = &dev->status;
    s->st_interface_type = dci_interface_type(status);
    s->st_link_status = status->ok | (status->up<<1u);
    if (status->duplex==net_duplex_full)
    {
      s->st_link_status|=ST_STATUS_FULL_DUPLEX;
    }

    if      (status->promiscuous) s->st_link_status|=ST_STATUS_PROMISCUOUS;
    else if (status->multicast  ) s->st_link_status|=ST_STATUS_MULTICAST;
    else if (status->broadcast  ) s->st_link_status|=ST_STATUS_BROADCAST;

    s->st_link_polarity = status->polarity_incorrect ? ST_LINK_POLARITY_INCORRECT
                                                     : ST_LINK_POLARITY_CORRECT;
    s->st_tx_frames = dev->packet_tx_count;
    s->st_tx_bytes  = dev->packet_tx_bytes;
    s->st_tx_general_errors = dev->packet_tx_errors;
    s->st_rx_frames = dev->packet_rx_count;
    s->st_rx_bytes  = dev->packet_rx_bytes;
    s->st_rx_general_errors = dev->packet_rx_errors;
    s->st_unwanted_frames = dev->packet_unwanted;
    s->st_jabbers = status->jabbers;
  }
  else
  {
    // Return supported stats list.
    s->st_interface_type = 0xff;
    s->st_link_status = 0xff;
    s->st_link_polarity = 0xff;
    s->st_tx_frames = 0xffffffff;
    s->st_tx_bytes = 0xffffffff;
    s->st_tx_general_errors = 0xffffffff;
    s->st_rx_frames = 0xffffffff;
    s->st_rx_bytes = 0xffffffff;
    s->st_rx_general_errors = 0xffffffff;
    s->st_unwanted_frames = 0xffffffff;
  }
  return NULL;
}

//---------------------------------------------------------------------------
// Configure
//---------------------------------------------------------------------------
_kernel_oserror* net_configure(unsigned unit, const char* arg_string)
{
  net_device_t* dev = net_from_unit(unit);
  if (!dev) return err_translate(ERR_BAD_UNIT);

  const net_backend_t* backend = dev->backend;
  if (!backend->config) return err_translate(ERR_UNSUPPORTED);

  net_config_t cfg;
  bool doit = false;
  _kernel_oserror* e = config_parse_arguments(dev, arg_string, &cfg, &doit);
  if (!e && doit) e = backend->config(dev, &cfg);
  return e;
}

//---------------------------------------------------------------------------
// Info
//---------------------------------------------------------------------------
static void print_list(const char* name, ...)
{
  char fmt[16];

  va_list ap;
  va_start(ap, name);
  bool any = false;
  sprintf(fmt, "%%-%us : ", strlen(msg_translate("IfLen")));
  printf(fmt, msg_translate(name));
  while (true)
  {
    const char* name = va_arg(ap, const char*);
    if (!name) break;
    bool v = va_arg(ap, unsigned);
    if (v)
    {
      if (any) printf(", "); else any=true;
      printf("%s", msg_translate(name));
    }
  }
  va_end(ap);
  printf("%s\n", any ? "" : msg_translate("None"));
}

static void print_numeric(const char* fmt, const char* heading, unsigned long number)
{
  char text[16];

  sprintf(text, "%lu", number);
  printf(fmt, msg_translate(heading), text);
}

_kernel_oserror* net_info(unsigned unit_no, bool verbose)
{
  char fmt[16], text[100];

  if (unit_no<MODULE_MAX_UNITS && !s_units[unit_no]) return err_translate(ERR_BAD_UNIT);

  // Common information
  printf(msg_translate("AuthInf"), Module_Title, Module_VersionString, "James Peacock");
  putchar('\n');
  printf(msg_translate("DCI4Inf"), DCIVERSION / 100u, DCIVERSION % 100u,
                                   MODULE_DCI_NAME, MODULE_MAX_UNITS);
  printf("\n%s:\n", msg_translate("BackSup"));
  for (const backend_t* be=s_backends; be; be=be->next)
  {
    printf("  %-13s - %s\n",be->backend->name,
                            msg_translate(be->backend->description));
  }

  // Make a template for the left column headings
  sprintf(fmt, "%%-%us : %%s\n", strlen(msg_translate("IfLen")));

  for (size_t unit=0; unit!=MODULE_MAX_UNITS; ++unit)
  {
    if (unit_no<MODULE_MAX_UNITS && unit!=unit_no) continue;

    net_device_t* dev = s_units[unit];
    if (!dev) continue;

    if (dev->backend->status)
    {
      _kernel_oserror* e = dev->backend->status(dev);
      if (e) return e;
    }

    const net_status_t* status = &dev->status;

    // Heading line for this unit
    printf("\n%s%zu: %s, %s, %s\n\n",
           MODULE_DCI_NAME,
           unit,
           dev->backend->name,
           dev->location,
           !status->ok ? msg_translate("Bad")
                       : !status->up ? msg_translate("Down")
                                     : msg_translate("Up"));
    printf(fmt, msg_translate("IfDrv"), MODULE_DCI_NAME);
    print_numeric(fmt, "IfNum", unit);
    printf(fmt, msg_translate("IfLoc"), dev->location);
    sprintf(text, "%02X:%02X:%02X:%02X:%02X:%02X",
            status->mac[0], status->mac[1], status->mac[2],
            status->mac[3], status->mac[4], status->mac[5]);
    printf(fmt, msg_translate("IfEUI"), text);
    printf(fmt, msg_translate("IfBak"), dev->backend->name);
    
    if (status->up && status->ok)
    {
      // Speed and duplex
      sprintf(text, "Dit%u", dci_interface_type(status));
      strcpy(text, msg_translate(text));
      if (status->duplex!=net_duplex_unknown)
      {
        strcat(text, " ");
        strcat(text, msg_translate(status->duplex==net_duplex_half ? "DupH" : "DupF"));
      }
      printf(fmt, msg_translate("IfMed"), text);

      // Polarity
      if (status->autoneg==net_autoneg_none ||
          status->autoneg==net_autoneg_complete)
      {
        strcpy(text, msg_translate(status->polarity_incorrect ? "PolI" : "PolC"));
      }
      else
      {
        strcpy(text, msg_translate("PolU"));
      }
      printf(fmt, msg_translate("IfPol"), text);

      // Controller mode
      sprintf(text, "Mod%u%u%u", status->promiscuous ? 1 : 0,
                                 status->broadcast ? 1 : 0,
                                 status->multicast ? 1 : 0);
      strcpy(text, msg_translate(text));
      printf(fmt, msg_translate("CtMod"), text);

      // Statistics
      print_numeric(fmt, "Stat0", dev->packet_tx_count);
      print_numeric(fmt, "Stat1", dev->packet_rx_count);
      print_numeric(fmt, "Stat2", dev->packet_tx_bytes);
      print_numeric(fmt, "Stat3", dev->packet_rx_bytes);
      print_numeric(fmt, "Stat4", dev->packet_tx_errors);
      print_numeric(fmt, "Stat5", dev->packet_rx_errors);
      print_numeric(fmt, "Stat6", dev->packet_unwanted);
      print_numeric(fmt, "Stat7", dev->queue_tx_overflows);
    }

    if (verbose)
    {
      sprintf(text, "%04X_%04X", dev->vendor, dev->product);
      printf(fmt, msg_translate("VVend"), text);
      sprintf(text, "%02X_%02X_%02X_%02X_%02X_%02X",
              dev->usb_location[0], dev->usb_location[1], dev->usb_location[2],
              dev->usb_location[3], dev->usb_location[4], dev->usb_location[5]);
      printf(fmt, msg_translate("VUSBL"), text);

      const net_abilities_t* a = &dev->abilities;

      print_list("VDupe",
                 "DupH" , a->half_duplex,
                 "DupF" , a->full_duplex,
                 NULL);

      print_list("VSped",
                 "Sp10" , a->speed_10Mb,
                 "Sp100", a->speed_100Mb,
                 "Sp1000", a->speed_1000Mb,
                 NULL);

      print_list("VMode",
                 "Uni"  , 1u,
                 "BCast", 1u,
                 "Multi", a->multicast,
                 "Prom" , a->promiscuous,
                 "Loop" , a->loopback,
                 NULL);

      print_list("VOthr",
                 "ANeg" , a->autoneg,
                 "MutM" , a->mutable_mac,
                 "TxRxL", a->tx_rx_loopback,
                 "EJC"  , dev->backend->config!=NULL,
                 NULL);
    }

    // Active filters
    const net_filter_t* f;
    if (dev->specific_filters)
    {
      printf("\n%s:\n\n", msg_translate("CStd"));
      for (f = dev->specific_filters; f; f=f->next)
      {
        printf(msg_translate("Type"), f->frame_type, f->addr_level, f->err_level,
                                      f->handler, f->r12);
        putchar('\n');
      }
    }
    if (dev->ieee_filter)
    {
      printf("\n%s:\n\n", msg_translate("CIEEE"));
      f = dev->ieee_filter;
      printf(msg_translate("Type"), f->frame_type, f->addr_level, f->err_level,
                                    f->handler, f->r12);
      putchar('\n');
    }
    if (dev->monitor_filter)
    {
      printf("\n%s:\n\n", msg_translate("CMon"));
      f = dev->monitor_filter;
      printf(msg_translate("Type"), f->frame_type, f->addr_level, f->err_level,
                                    f->handler, f->r12);
      putchar('\n');
    }
    if (dev->sink_filter)
    {
      printf("\n%s:\n\n", msg_translate("CSink"));
      f = dev->sink_filter;
      printf(msg_translate("Type"), f->frame_type, f->addr_level, f->err_level,
                                    f->handler, f->r12);
      putchar('\n');
    }

    // Extra specific info
    if (DEBUG_QUEUE) printf("    TX queue usage     %-12zu\n",
                            dev->queue_tx_max_usage);

    if (dev->backend->info)
    {
      printf("\n%s:\n\n", msg_translate("BackInf"));
      dev->backend->info(dev,verbose);
    }
  }

  return NULL;
}


//---------------------------------------------------------------------------
// Someone is scanning for network interfaces.
//---------------------------------------------------------------------------

_kernel_oserror* net_enumerate_drivers(_kernel_swi_regs* r)
{
  for (const net_device_t* dev=s_devices; dev; dev=dev->next)
  {
    ChDib* dib = NULL;
    _kernel_oserror* e = _swix(OS_Module, _IN(0)|_IN(3)|_OUT(2),
                               ModHandReason_Claim, sizeof(ChDib), &dib);

    if (!e && dib)
    {
      dib->chd_next = (ChDib*)(r->r[0]);
      dib->chd_dib = (struct dib*)&dev->dib;
      r->r[0] = (uint32_t)dib;
    }
  }
  return NULL;
}

