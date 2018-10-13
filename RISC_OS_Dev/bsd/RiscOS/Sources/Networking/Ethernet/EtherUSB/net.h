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
#ifndef NET_H_INCLUDED
#define NET_H_INCLUDED

#include <stdint.h>

#include "kernel.h"
#include "sys/dcistructs.h"
#include "sys/errno.h"

typedef struct net_device net_device_t;
typedef struct net_filter_t net_filter_t;
typedef struct net_tx net_tx_t;
typedef struct net_config_t net_config_t;
typedef struct net_status_t net_status_t;
typedef struct net_abilities_t net_abilities_t;

typedef enum { net_speed_unknown = 0,
               net_speed_10Mb,
               net_speed_100Mb,
               net_speed_1000Mb
} net_speed_t;

typedef enum { net_duplex_unknown = 0,
               net_duplex_half,
               net_duplex_full
} net_duplex_t;

typedef enum { net_link_unknown = 0,
               net_link_10BaseT_Half,
               net_link_10BaseT_Full,
               net_link_100BaseTX_Half,
               net_link_100BaseTX_Full,
               net_link_100BaseT4,
               net_link_1000BaseT_Half,
               net_link_1000BaseT_Full
} net_link_t;

typedef enum { net_autoneg_none = 0,
               net_autoneg_started,
               net_autoneg_reconfigure,
               net_autoneg_complete,
               net_autoneg_failed
} net_autoneg_t;

//---------------------------------------------------------------------------
// Called to attempt to bind a device to the backend, returning
// err_unsupported if the backend cannot support it; otherwise it should
// allocate workspace (store the value in *private), parse the options and
// stash any settings in its workspace. It should not open any USB pipes.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (net_open_fn)(const USBServiceCall* usb,
                                       const char*           options,
                                       void**                private);

//---------------------------------------------------------------------------
// Called if open is successful, but before the interface is announced.
// Should open the USB pipes and initialise the device. Returning an
// error will cause the driver to call the close_fn. This MUST update the
// dev->abilities and dev->status, see below.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (net_start_fn)(net_device_t* dev,
                                        const char* options);

//---------------------------------------------------------------------------
// Called to shutdown the device, before the close_fn is called. All USB
// pipes should be closed. MUST not return an error unless removing the
// EtherUSB module is not safe.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (net_stop_fn)(net_device_t* dev);

//---------------------------------------------------------------------------
// Called when unbinding a device from the backend. If dev->gone, then the
// device was unplugged and is no longer accessible, otherwise the driver
// should shut it down cleanly and release all resources. MUST not return
// an error unless removing the EtherUSB module is not safe.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (net_close_fn)(void** private);

//---------------------------------------------------------------------------
// Called to attempt to send a packet. Return &err_tx_blocked if it can't
// be sent yet.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (net_transmit_fn)(net_device_t*   dev,
                                           const net_tx_t* pkt);

//---------------------------------------------------------------------------
// Chance to augment output of *EJInfo, a NULL function pointer causes no
// extra information to be output.
//---------------------------------------------------------------------------
typedef void (net_info_fn)(const net_device_t* dev,
                           bool verbose);

//---------------------------------------------------------------------------
// Called to (re)configure deviceof *EJLink, a NULL function pointer means
// that the device can't be explicitly configured. The requirements will
// not contradict the 'abilitites', see below, declared by the device when
// starting. The device should update the 'status', see below and return
// NULL on success; or return an error.
//
// If non-NULL, then this is called immediately after the device is
// initialised.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (net_config_fn)(net_device_t*       dev,
                                         const net_config_t* config);

//---------------------------------------------------------------------------
// Called, if non-NULL, before dev->status is used to give the backend
// the chance to update the information provided.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (net_status_fn)(net_device_t* dev);

//---------------------------------------------------------------------------
// Backend description.
//---------------------------------------------------------------------------
typedef struct
{
  const char*       name;
  const char*       description;
  net_open_fn*      open;
  net_start_fn*     start;
  net_stop_fn*      stop;
  net_close_fn*     close;
  net_transmit_fn*  transmit;
  net_info_fn*      info;
  net_config_fn*    config;
  net_status_fn*    status;
} net_backend_t;

//---------------------------------------------------------------------------
// EUI48
//---------------------------------------------------------------------------
#define ETHER_ADDR_LEN 6
#define ETHER_MAX_LEN  1518

//---------------------------------------------------------------------------
// Ethernet frame header
//---------------------------------------------------------------------------
typedef __packed struct
{
  uint8_t        dst_addr[ETHER_ADDR_LEN];
  uint8_t        src_addr[ETHER_ADDR_LEN];
  uint16_t       type;                      // Network byte order.
} net_header_t;

//---------------------------------------------------------------------------
// Layout of tx data passed to backends when.
//---------------------------------------------------------------------------
struct net_tx
{
  net_tx_t* next;                           // Next pointer for linking
  size_t size;                              // Size of 'data'
  uint8_t prefix[TX_PREFIX_SIZE];           // Backend scratch space
  net_header_t header;                      // Ethernet packet header
  uint8_t data[TX_MAX_DATA_SIZE];           // Ethernet packet data
  uint8_t suffix[TX_SUFFIX_SIZE];           // Backend scratch space
};

//---------------------------------------------------------------------------
// This structure should be regularly updated to reflect the devices current
// status. NOTE that the MAC address MUST be filled in during the
// net_start_fn. The struct is always available as dev->status. Initially,
// all fields are 0.
//---------------------------------------------------------------------------
struct net_status_t
{
  net_speed_t   speed;                 // Current network speed of device.
  net_duplex_t  duplex;                // Current duplex setting.
  net_link_t    link;                  // Link technology.
  net_autoneg_t autoneg;               // Autonegotiation status.
  uint8_t       mac[ETHER_ADDR_LEN];   // MAC address, MUST BE SET.
  unsigned      remote_faults;         // Remote fault count.
  unsigned      jabbers;               // Jabber count.
  unsigned      ok                :1;  // Is the device functional?
  unsigned      up                :1;  // Is the link 'up'?
  unsigned      broadcast         :1;  // Are Rx broadcast packets enabled?
  unsigned      multicast         :1;  // Are Rx multicast packets enabled?
  unsigned      promiscuous       :1;  // Is in promiscuous mode?
  unsigned      polarity_incorrect:1;  // Is the line polarity incorrect?
  unsigned      tx_pause          :1;  // Tx pauses enabled.
  unsigned      rx_pause          :1;  // Rx pauses enabled.
};

//---------------------------------------------------------------------------
// This structure should be updated during the net_start_fn to indicate
// which features the device supports. This will be used by *EJConfig
//---------------------------------------------------------------------------
struct net_abilities_t
{
  unsigned speed_10Mb            :1;
  unsigned speed_100Mb           :1;
  unsigned speed_1000Mb          :1;
  unsigned half_duplex           :1;
  unsigned full_duplex           :1;
  unsigned autoneg               :1;
  unsigned multicast             :1;
  unsigned promiscuous           :1;
  unsigned tx_rx_loopback        :1; // Tx packets will be received.
  unsigned loopback              :1; // Supports loopback mode.
  unsigned mutable_mac           :1; // Can redefine MAC address.
  unsigned tx_pause              :1; // Supports asymmetric pause towards link partner
  unsigned rx_pause              :1; // Supports asymmetric pause towards self
  unsigned symmetric_pause       :1; // Supports symmetric pause
};

//---------------------------------------------------------------------------
// This structure is passed as an argument to the backend net_config_fn, if
// non-NULL. It is always called after the net_start_fn and may be called
// at any time until the net_stop_fn. Is defaulted to zero which means don't
// alter anything. For 'speed', 'duplex' and 'link' the 'unknown' value
// indicates that it wasn't specified.
//---------------------------------------------------------------------------
struct net_config_t
{
  net_speed_t  speed;       // Preferred speed.
  net_duplex_t duplex;      // Preferred duplex setting.
  net_link_t   link;        // Preferred link type.
  bool         autoneg;     // Force link auto negotiation.
  bool         multicast;   // Enable multicast mode.
  bool         promiscuous; // Enable promiscuous mode.
  bool         allow_tx_pause;
  bool         allow_rx_pause;
  bool         allow_symmetric_pause;
};

//---------------------------------------------------------------------------
// Non-backend specifc device data. Backends MUST NOT alter any of this
// except for the net_status_t and net_abilities_t structs.
//---------------------------------------------------------------------------
struct net_device
{
  struct net_device*   next;                // Next in linked list.
  struct net_device*   prev;                // Previous in linked list.
  char                 name[20];            // DeviceFS name of USB device.
  uint16_t             vendor;              // USB device vendor
  uint16_t             product;             // USB device product
  uint8_t              bus;                 // USB bus number.
  uint8_t              address;             // USB device number.
  uint8_t              speed;               // USB speed.
  uint8_t              usb_location[6];     // Location in USB device tree
  bool                 gone;                // Device unplugged.
  volatile uint8_t     tx_guard;            // Transmit Semaphore.
  const net_backend_t* backend;             // Backend used to talk to it.
  Dib                  dib;                 // DCI device info block.
  char                 location[64];        // Textual location description.
  size_t               mtu;                 // Current MTU.
  void*                private;             // Backend private word.
  net_filter_t*        specific_filters;    // Filter linked list.
  net_filter_t*        sink_filter;         // NULL or owns sink.
  net_filter_t*        monitor_filter;      // NULL or owns monitor filter.
  net_filter_t*        ieee_filter;         // NULL or owns IEEE filter.
  size_t               packet_tx_count;     // Packets sucessfully sent.
  size_t               packet_rx_count;     // Packets recieved.
  size_t               packet_unwanted;     // Packets with nowhere to go.
  size_t               packet_tx_errors;    // Packets unable to be sent.
  size_t               packet_rx_errors;    // Packets with rx errors.
  size_t               packet_tx_bytes;     // Tx byte count.
  size_t               packet_rx_bytes;     // Rx byte count.
  size_t               queue_tx_overflows;  // No. discarded op pkts
  size_t               queue_tx_max_usage;  // Max tx queue length.
  net_status_t         status;              // Driver should update these.
  net_abilities_t      abilities;           // Driver should update these.
  net_tx_t             tx_packet;
};

//---------------------------------------------------------------------------
// Initialisation/Finalisation
//---------------------------------------------------------------------------

// Call to register a backend.
_kernel_oserror* net_register_backend(const net_backend_t* backend);

// Call on exit to ensure everything shutdown etc.
_kernel_oserror* net_finalise(void);

//---------------------------------------------------------------------------
// Service call handlers
//---------------------------------------------------------------------------

// Checks a device to see if any backend can handle it, handle=NULL.
// Takes no action if device is not supported.
_kernel_oserror* net_check_device(const USBServiceCall* dev, void* handle);

// Notify of device removal. 'name' is DeviceFS name, e.g. 'USB1'
_kernel_oserror* net_dead_device(const char* name);

// Someone is scanning for network interfaces.
_kernel_oserror* net_enumerate_drivers(_kernel_swi_regs* r);

// Protocol module is dying and wants to release all claimed frame types.
_kernel_oserror* net_protocol_dying(_kernel_swi_regs* r);

//---------------------------------------------------------------------------
// Backend specific functions
//---------------------------------------------------------------------------

// Send a packet to wherever it is meant to go or discard it. Error is 0 if
// there was no packet RX error or a device specific error code.
_kernel_oserror* net_receive(net_device_t* dev,
                             const void*   pk,
                             size_t        size,
                             uint32_t      error);

// Attempts to send next queued packet by calling dev's backend.
_kernel_oserror* net_attempt_transmit(net_device_t* dev);

//---------------------------------------------------------------------------
// (Re)configure device
//---------------------------------------------------------------------------
_kernel_oserror* net_configure(unsigned unit, const char* arg_string);

//---------------------------------------------------------------------------
// Generation of default MAC address for devices which don't have one.
//---------------------------------------------------------------------------
void net_default_mac(unsigned unit, uint8_t* mac);

//---------------------------------------------------------------------------
// Look up the configured MAC address for the machine. Returns false if no
// MAC exists, or if it's already in use by another driver.
//---------------------------------------------------------------------------
bool net_machine_mac(uint8_t* mac);

//---------------------------------------------------------------------------
// *Command output.
//---------------------------------------------------------------------------

// General information to stdout.
_kernel_oserror* net_info(unsigned unit, bool verbose);

//---------------------------------------------------------------------------
// DCI Driver SWI implementations. These are all required to be reentrant
//---------------------------------------------------------------------------

// Get flags (DCI_Inquire). Reentrant.
_kernel_oserror* net_inquire(_kernel_swi_regs* r);

// Get MTU (DCI_GetNetworkMTU). Reentrant.
_kernel_oserror* net_get_network_mtu(_kernel_swi_regs* r);

// Send some data (DCI_Transmit). Reentrant.
_kernel_oserror* net_transmit(_kernel_swi_regs* r);

// Claim/release packet types (DCI_Filter). Reentrant
_kernel_oserror* net_filter(_kernel_swi_regs* r);

// Statistics
_kernel_oserror* net_stats(_kernel_swi_regs* r);

//---------------------------------------------------------------------------

#endif
