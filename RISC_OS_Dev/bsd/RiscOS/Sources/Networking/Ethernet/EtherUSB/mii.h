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
#ifndef MII_H_INCLUDED
#define MII_H_INCLUDED

#include <stdbool.h>
#include <stdint.h>
#include "kernel.h"
#include "net.h"

//---------------------------------------------------------------------------
// Basic MII Registers - all PHYs support these.
//---------------------------------------------------------------------------
#define MII_CONTROL             0
#define MII_STATUS              1

//---------------------------------------------------------------------------
// Extended MII Registers - only PHYs with the MII_STATUS_EXTENDED_CAP bit
// set in the status register support these.
//---------------------------------------------------------------------------
#define MII_PHY_ID0              2
#define MII_PHY_ID1              3
#define MII_NWAY_ADVERT          4
#define MII_NWAY_PARTNER         5
#define MII_NWAY_EXPANSTION      6
#define MII_NWAY_NEXT_PG_TX      7

#define MII_MASTER_SLAVE_CONTROL 9
#define MII_MASTER_SLAVE_STATUS  10

#define MII_EXTENDED_STATUS      15 /* Only exists if MII_STATUS_EXTD_STATUS is set */

// More registers in the range 8-15 exist on some MIIs, but are not supported
// here yet.
// Registers 16+ are vendor-specific and must be managed by the appropriate
// backend driver.

//---------------------------------------------------------------------------
// Control register fields (reg 0)
//---------------------------------------------------------------------------
#define MII_CONTROL_RESET       (1u<<15)
#define MII_CONTROL_LOOPBACK    (1u<<14)
#define MII_CONTROL_SPEED100    (1u<<13)
#define MII_CONTROL_NWAY_ENABLE (1u<<12)
#define MII_CONTROL_POWER_DOWN  (1u<<11)
#define MII_CONTROL_ISOLATE     (1u<<10)
#define MII_CONTROL_NWAY_RESET  (1u<<9)
#define MII_CONTROL_FULL_DUPLEX (1u<<8)
#define MII_CONTROL_COLL_TEST   (1u<<7)
#define MII_CONTROL_SPEED1000   (1u<<6)
#define MII_CONTROL_UNI_ENABLE  (1u<<5)

//---------------------------------------------------------------------------
// Status register fields (reg 1)
//---------------------------------------------------------------------------
#define MII_STATUS_100BaseT4      (1u<<15)
#define MII_STATUS_100BaseTX_Full (1u<<14)
#define MII_STATUS_100BaseTX_Half (1u<<13)
#define MII_STATUS_10BaseT_Full   (1u<<12)
#define MII_STATUS_10BaseT_Half   (1u<<11)
#define MII_STATUS_100BaseT2_Full (1u<<10)
#define MII_STATUS_100BaseT2_Half (1u<<9)
#define MII_STATUS_EXTD_STATUS    (1u<<8)
#define MII_STATUS_UNI_ABILITY    (1u<<7)
#define MII_STATUS_MFPRE_SUP      (1u<<6)
#define MII_STATUS_NWAY_COMP      (1u<<5)
#define MII_STATUS_REM_FAULT      (1u<<4)
#define MII_STATUS_NWAY_ABILITY   (1u<<3)
#define MII_STATUS_LINK_STATUS    (1u<<2)
#define MII_STATUS_JABBER_DET     (1u<<1)
#define MII_STATUS_EXTENDED_CAP   (1u<<0)

//---------------------------------------------------------------------------
// Auto-negotiation advertisement (reg 4)
// Bits 0-4 are the selector field: 1?
//---------------------------------------------------------------------------
#define MII_ADVERT_NEXT_PAGE      (1u<<15)
#define MII_ADVERT_ZERO14         (1u<<14) // Reserved: write as zero
#define MII_ADVERT_REM_FAULT      (1u<<13)
#define MII_ADVERT_ZERO12         (1u<<12) // Reserved: zero?
#define MII_ADVERT_ASYM_PAUSE     (1u<<11)
#define MII_ADVERT_SYM_PAUSE      (1u<<10)
#define MII_ADVERT_100BaseT4      (1u<<9)
#define MII_ADVERT_100BaseTX_Full (1u<<8)
#define MII_ADVERT_100BaseTX_Half (1u<<7)
#define MII_ADVERT_10BaseT_Full   (1u<<6)
#define MII_ADVERT_10BaseT_Half   (1u<<5)

//---------------------------------------------------------------------------
// Auto-negotiation partner (reg 5)
//---------------------------------------------------------------------------
#define MII_PARTNER_NEXT_PAGE      (1u<<15)
#define MII_PARTNER_ACK            (1u<<14)
#define MII_PARTNER_REM_FAULT      (1u<<13)
#define MII_PARTNER_ASYM_PAUSE     (1u<<11)
#define MII_PARTNER_SYM_PAUSE      (1u<<10)
#define MII_PARTNER_100BaseT4      (1u<<9)
#define MII_PARTNER_100BaseTX_Full (1u<<8)
#define MII_PARTNER_100BaseTX_Half (1u<<7)
#define MII_PARTNER_10BaseT_Full   (1u<<6)
#define MII_PARTNER_10BaseT_Half   (1u<<5)

//---------------------------------------------------------------------------
// MASTER-SLAVE control (reg 9)
//---------------------------------------------------------------------------
#define MII_MS_CTRL_1000BaseT_Full (1u<<9)
#define MII_MS_CTRL_1000BaseT_Half (1u<<8)

//---------------------------------------------------------------------------
// MASTER-SLAVE status (reg 10)
//---------------------------------------------------------------------------
#define MII_MS_STAT_1000BaseT_Full (1u<<11)
#define MII_MS_STAT_1000BaseT_Half (1u<<10)

//---------------------------------------------------------------------------
// Extended status (reg 15)
//---------------------------------------------------------------------------
#define MII_EXTD_STATUS_1000BaseX_Full (1u<<15)
#define MII_EXTD_STATUS_1000BaseX_Half (1u<<14)
#define MII_EXTD_STATUS_1000BaseT_Full (1u<<13)
#define MII_EXTD_STATUS_1000BaseT_Half (1u<<12)

//---------------------------------------------------------------------------
// Functions to read/write to a PHY register. 'handle' is passed
// through from mii_*() functions, below.
//---------------------------------------------------------------------------
typedef _kernel_oserror* (mii_read_fn)(void*     handle,
                                       unsigned  reg,
                                       uint16_t* value);

typedef _kernel_oserror* (mii_write_fn)(void*     handle,
                                        unsigned  reg,
                                        uint16_t  value);

//---------------------------------------------------------------------------
// A struct like this is needed for each PHY to be controlled. You MUST
// call mii_initialise() before passing the mii_t to any other function
// in here. Once initialised, the mii_t should not be altered by anything
// other than the functions here.
//---------------------------------------------------------------------------
typedef struct
{
  void*          handle;            // As passed in to initialise
  mii_read_fn*   read;              // As passed in to initialise
  mii_write_fn*  write;             // As passed in to initialise
  bool           ok;                // Reset worked.
  bool           autoneg;           // Autoneg configured to be on.
  bool           negotiating;       // Autoneg in process.
} mii_t;

void mii_initialise(mii_t* mii,
                    mii_read_fn* reader,
                    mii_write_fn* writer,
                    void* handle);

//---------------------------------------------------------------------------
// Does this look like a valid PHY? Returns NULL if so and
// err_bad_phy if not. This may not be reliable - only use for finding
// the PHY address if the device offers no other way to get it.
//---------------------------------------------------------------------------
_kernel_oserror* mii_present(mii_t* mii);

//---------------------------------------------------------------------------
// Reset and initialise device.
//---------------------------------------------------------------------------
_kernel_oserror* mii_reset(mii_t* mii);

//---------------------------------------------------------------------------
// Shutdown PHY.
//---------------------------------------------------------------------------
_kernel_oserror* mii_shutdown(mii_t* mii);

//---------------------------------------------------------------------------
// Read PHY capabilities, must be called directly after a reset.
//---------------------------------------------------------------------------
_kernel_oserror* mii_abilities(mii_t* mii, net_abilities_t* ab);

//---------------------------------------------------------------------------
// Read PHY status. This always updates the 'up' flag
//---------------------------------------------------------------------------
_kernel_oserror* mii_link_status(mii_t* mii, net_status_t* status);

//---------------------------------------------------------------------------
// Reconfigure PHY. The 'cfg' must satisfy the requirements returmed by
// mii_abilities(). Status is updated.
//---------------------------------------------------------------------------
_kernel_oserror* mii_configure(mii_t* mii,
                               net_status_t* status,
                               const net_config_t* cfg);

#endif
