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

#include "kernel.h"

#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "mii.h"

#define DEBUG_MII 1

//---------------------------------------------------------------------------
void mii_initialise(mii_t* mii,
                    mii_read_fn* reader,
                    mii_write_fn* writer,
                    void* handle)
{
  if (DEBUG_MII) syslog("MII initialise");
  mii->handle = handle;
  mii->read = reader;
  mii->write = writer;
  mii->ok = false;
  mii->autoneg = false;
  mii->negotiating = false;
}

//---------------------------------------------------------------------------
// Does this look like a valid PHY? Returns NULL if so and
// err_bad_phy if not.
//---------------------------------------------------------------------------
_kernel_oserror* mii_present(mii_t* mii)
{
  uint16_t value;
  _kernel_oserror* e = mii->read(mii->handle, MII_STATUS, &value);
  if (e==err_translate(ERR_BAD_PHY)) return err_translate(ERR_BAD_DEVICE);
  if (e) return e;
  if (value==0) return err_translate(ERR_BAD_PHY);
  return NULL;
}

//---------------------------------------------------------------------------
// Reset PHY, driving all registers to default state. Set the control
// register reset bit and wait for it to be cleared by the device. If it
// takes over 0.5s, assume failure.
//
// Sets/clears internal 'ok' flag.
//---------------------------------------------------------------------------
_kernel_oserror* mii_reset(mii_t* mii)
{
  if (DEBUG_MII) syslog("MII reset");
  mii->negotiating = false;
  mii->ok = false;
  mii->autoneg = false;

  uint16_t control;
  _kernel_oserror* e = mii->read(mii->handle, MII_CONTROL, &control);

  if (!e) e = mii->write(mii->handle,
                         MII_CONTROL,
                         control | MII_CONTROL_RESET);
  int i = 0;
  while (!e)
  {
    if (++i==5)
    {
      e = err_translate(ERR_BAD_DEVICE);
      break;
    }

    e = mii->read(mii->handle, MII_CONTROL, &control);
    if (!e)
    {
      if (!(control & MII_CONTROL_RESET)) break;
      e = cs_wait(10);
    }
  }

  if (!e) mii->ok = true;
  return e;
}


//---------------------------------------------------------------------------
// Power down and isolate PHY. Note some devices hang if powered down and
// refuse to be powered up again, so just isolate for now.
//---------------------------------------------------------------------------
_kernel_oserror* mii_shutdown(mii_t* mii)
{
  if (DEBUG_MII) syslog("MII shutdown");
  uint16_t value;
  _kernel_oserror* e = mii->read(mii->handle, MII_CONTROL, &value);
  if (!e)
  {
    value |= MII_CONTROL_ISOLATE;
    e = mii->write(mii->handle, MII_CONTROL, value);
  }
  return e;
}

//---------------------------------------------------------------------------
// Read PHY capabilities, must be called directly after a reset.
//---------------------------------------------------------------------------
_kernel_oserror* mii_abilities(mii_t* mii, net_abilities_t* ab)
{
  if (DEBUG_MII) syslog("MII abilities");

  uint16_t status,ext_status=0;
  _kernel_oserror* e = mii->read(mii->handle, MII_STATUS, &status);
  if (e) return e;
  if (status & MII_STATUS_EXTD_STATUS)
  {
    e = mii->read(mii->handle, MII_EXTENDED_STATUS, &ext_status);
    if (e) return e;
  }

  ab->speed_10Mb  = ( (status & MII_STATUS_10BaseT_Full) ||
                      (status & MII_STATUS_10BaseT_Half) );

  ab->speed_100Mb = ( (status & MII_STATUS_100BaseTX_Full) ||
                      (status & MII_STATUS_100BaseTX_Half) ||
                      (status & MII_STATUS_100BaseT4     ) );

  // Ignore 1000BaseX since we have no way of configuring it
  ab->speed_1000Mb = ( /* (ext_status & MII_EXTD_STATUS_1000BaseX_Full) ||
                       (ext_status & MII_EXTD_STATUS_1000BaseX_Half) || */
                       (ext_status & MII_EXTD_STATUS_1000BaseT_Full) ||
                       (ext_status & MII_EXTD_STATUS_1000BaseT_Half) );

  ab->half_duplex = ( (status & MII_STATUS_10BaseT_Half  ) ||
                      (status & MII_STATUS_100BaseTX_Half) ||
                   /* (ext_status & MII_EXTD_STATUS_1000BaseX_Half) || */
                      (ext_status & MII_EXTD_STATUS_1000BaseT_Half) );

  ab->full_duplex = ( (status & MII_STATUS_10BaseT_Full  ) ||
                      (status & MII_STATUS_100BaseTX_Half) ||
                   /* (ext_status & MII_EXTD_STATUS_1000BaseX_Full) || */
                      (ext_status & MII_EXTD_STATUS_1000BaseT_Full) );

  ab->autoneg     = ((status & MII_STATUS_NWAY_ABILITY)!=0);

  ab->loopback = 1;

  return NULL;
}

//---------------------------------------------------------------------------
// Table of supported link technologies. Used for various lookups. Note that
// these are in order of the most preferred link types as required for
// resolving the result of the PHY's auto-negotiation.
//
// See IEEE Std 802.3-2008, Sections 2 & 3
//---------------------------------------------------------------------------
typedef struct
{
  uint16_t     advertised, ms_ctrl;
  uint16_t     partner, ms_stat;
  net_link_t   link;
  net_duplex_t duplex;
  net_speed_t  speed;
} link_t;

static const link_t s_links[] = {
  // 10GBaseT full
  
  { 0, MII_MS_CTRL_1000BaseT_Full, 0, MII_MS_STAT_1000BaseT_Full,
      net_link_1000BaseT_Full, net_duplex_full, net_speed_1000Mb },

  { 0, MII_MS_CTRL_1000BaseT_Half, 0, MII_MS_STAT_1000BaseT_Half,
      net_link_1000BaseT_Half, net_duplex_half, net_speed_1000Mb },

  { MII_ADVERT_100BaseTX_Full, 0, MII_PARTNER_100BaseTX_Full, 0,
      net_link_100BaseTX_Full, net_duplex_full, net_speed_100Mb },

  // 100BaseT2

  { MII_ADVERT_100BaseT4, 0, MII_PARTNER_100BaseT4, 0,
      net_link_100BaseT4, net_duplex_half, net_speed_100Mb },

  { MII_ADVERT_100BaseTX_Half, 0, MII_PARTNER_100BaseTX_Half, 0,
      net_link_100BaseTX_Half, net_duplex_half, net_speed_100Mb },

  { MII_ADVERT_10BaseT_Full, 0, MII_PARTNER_10BaseT_Full, 0,
      net_link_10BaseT_Full, net_duplex_full, net_speed_10Mb },

  { MII_ADVERT_10BaseT_Half, 0, MII_PARTNER_10BaseT_Half, 0,
      net_link_10BaseT_Half, net_duplex_half, net_speed_10Mb }
};

//---------------------------------------------------------------------------
// Autonegotiation configuration and resolution. These functions don't read
// or write to the PHY directly.
//
// See IEEE Std 802.3-2008, Section 2.
//---------------------------------------------------------------------------

static _kernel_oserror* config_autoneg(uint16_t* advertised,
                                       uint16_t* ms_ctrl,
                                       const net_config_t* cfg)

{
#if DEBUG_MII && DEBUG
  static const char* mii_link_string[] = {"Unknown",
                                         "10BaseT (Half)",
                                         "10BaseT (Full)",
                                         "100BaseTX (Half)",
                                         "100BaseTX (Full)",
                                         "100BaseT4",
                                         "1000BaseT (Half)",
                                         "1000BaseT (Full)"};
#endif
  
  // What is requested.
  net_speed_t speed   = cfg->speed;
  net_duplex_t duplex = cfg->duplex;
  net_link_t   link   = cfg->link;

  // Disable link types not matching the specification passed in cfg. This
  // assumes that 'advertised' has its default state, offering the full
  // capabilities of the device.
  bool any = false;
  for (int i=0, e=sizeof(s_links)/sizeof(link_t); i!=e; ++i)
  {
    if ((*advertised & s_links[i].advertised) || (*ms_ctrl & s_links[i].ms_ctrl))
    {
      if ((speed !=net_speed_unknown  && speed !=s_links[i].speed ) ||
          (duplex!=net_duplex_unknown && duplex!=s_links[i].duplex) ||
          (link  !=net_link_unknown   && link  !=s_links[i].link  ) )
      {
        // Supported link type incompatible with config. Mask it out.
        *advertised ^= s_links[i].advertised;
        *ms_ctrl ^= s_links[i].ms_ctrl;
        if (DEBUG_MII) syslog("  link type %i masked out:  %s", i,
                              mii_link_string[s_links[i].link]);
      }
      else
      {
        any = true;
        if (DEBUG_MII) syslog("  link type %i advertised:  %s", i,
                              mii_link_string[s_links[i].link]);
      }
    }
    else
    {
      if (DEBUG_MII) syslog("  link type %i unsupported: %s", i,
                            mii_link_string[s_links[i].link]);
    }
  }

  // Determine which level of pause support we should advertise
  (*advertised) &= ~(MII_ADVERT_SYM_PAUSE | MII_ADVERT_ASYM_PAUSE);
  if (cfg->allow_symmetric_pause)
  {
    *advertised |= MII_ADVERT_SYM_PAUSE;
    if (cfg->allow_rx_pause)
    {
      *advertised |= MII_ADVERT_ASYM_PAUSE;
    }
  }
  else if (cfg->allow_tx_pause)
  {
    *advertised |= MII_ADVERT_ASYM_PAUSE;
  }

  return any ? NULL : err_translate(ERR_UNSUPPORTED);
}

static bool resolve_link(net_status_t* status,
                         uint16_t      advertised,
                         uint16_t      ms_ctrl,
                         uint16_t      partner,
                         uint16_t      ms_stat)
{
  for (int i=0, e=sizeof(s_links)/sizeof(link_t); i!=e; ++i)
  {
    if (((advertised & s_links[i].advertised) || (ms_ctrl & s_links[i].ms_ctrl))&&
        ((partner    & s_links[i].partner) || (ms_stat & s_links[i].ms_stat)))
    {
      status->duplex = s_links[i].duplex;
      status->link   = s_links[i].link;
      status->speed  = s_links[i].speed;
      if (DEBUG_MII) syslog("  -> Link type %i", i);
      return true;
    }
  }

  status->duplex  = net_duplex_unknown;
  status->link    = net_link_unknown;
  status->speed   = net_speed_unknown;
  if (DEBUG_MII) syslog("  -> No common link type");
  return false;
}

static bool resolve_pause(net_status_t* status,
                          net_duplex_t  duplex,
                          uint16_t      advertised,
                          uint16_t      partner)
{
  status->tx_pause = false;
  status->rx_pause = false;

  // Pause only applicable to full duplex links.
  if (duplex == net_duplex_full)
  {
    const bool ap = advertised & MII_ADVERT_SYM_PAUSE;
    const bool aa = advertised & MII_ADVERT_ASYM_PAUSE;
    const bool pp = partner    & MII_PARTNER_SYM_PAUSE;
    const bool pa = partner    & MII_PARTNER_ASYM_PAUSE;

    if (!ap)
    {
      if (aa && pp && pa) status->tx_pause = true;
    }
    else if (!pp)
    {
      if (pa) status->rx_pause = true;
    }
    else
    {
      status->tx_pause = true;
      status->rx_pause = true;
    }

    if (DEBUG_MII)
    {
      syslog("  -> Tx pause: %s", status->tx_pause ? "yes" : "no");
      syslog("     Rx pause: %s", status->rx_pause ? "yes" : "no");
    }
  }

  return true;
}

//---------------------------------------------------------------------------
// Reconfigure PHY, must be reset beforehand.
//---------------------------------------------------------------------------
_kernel_oserror* mii_configure(mii_t* mii,
                               net_status_t* net_status,
                               const net_config_t* cfg)
{
  if (DEBUG_MII) syslog("MII configure");

  // Reset status.
  net_status->up = false;
  net_status->autoneg = net_autoneg_none;
  net_status->speed = net_speed_unknown;
  net_status->link = net_link_unknown;
  net_status->duplex = net_duplex_unknown;
  net_status->tx_pause = false;
  net_status->rx_pause = false;

  _kernel_oserror* e = mii_reset(mii);
  if (e) return e;

  uint16_t control;
  e = mii->read(mii->handle, MII_CONTROL, &control);
  if (e) return e;

  uint16_t status;
  e = mii->read(mii->handle, MII_STATUS, &status);
  if (e) return e;

  if (!(status & MII_STATUS_LINK_STATUS))
  {
    if (DEBUG_MII) syslog("  -> no link");
  }

  // Use auto-negotiation to configure device in preference to manual
  // configuration, even when requesting a particular link type.
  if (cfg->autoneg)
  {
    if (status & MII_STATUS_NWAY_ABILITY)
    {
      if (DEBUG_MII) syslog("MII start auto-negotiation");
      net_status->autoneg = net_autoneg_failed;
      mii->autoneg = true;

      // Configure auto-neg
      uint16_t advertise,ms_ctrl=0;
      e = mii->read(mii->handle, MII_NWAY_ADVERT, &advertise);
      if (!e && (status & MII_STATUS_EXTD_STATUS)) e = mii->read(mii->handle, MII_MASTER_SLAVE_CONTROL, &ms_ctrl);
      if (!e) e = config_autoneg(&advertise, &ms_ctrl, cfg);
      if (!e) e = mii->write(mii->handle, MII_NWAY_ADVERT, advertise);
      if (!e && (status & MII_STATUS_EXTD_STATUS)) e = mii->write(mii->handle, MII_MASTER_SLAVE_CONTROL, ms_ctrl);

      // Fire off auto-neg and wait for it to start
      control |= MII_CONTROL_NWAY_ENABLE | MII_CONTROL_NWAY_RESET;
      e = mii->write(mii->handle, MII_CONTROL, control);
      if (!e)
      {
        for (int polls=0; polls!=10; ++polls)
        {
          cs_wait(5);
          e = mii->read(mii->handle, MII_CONTROL, &control);
          if (e || !(control & MII_CONTROL_NWAY_RESET)) break;
        }

        if (!e & (control & MII_CONTROL_NWAY_RESET))
        {
          if (DEBUG_MII) syslog("  -> failed to start (timeout)");
          e = err_translate(ERR_TIMEOUT);
        }
      }
      if (!e)
      {
        net_status->autoneg = net_autoneg_started;
        mii->negotiating = true;
      }
    }
    else
    {
      // Auto-negotiation not available but config has demanded it. Shouldn't
      // get here if abilities were checked.
      e = err_translate(ERR_UNSUPPORTED);
    }
  }
  else
  {
    // Manual configuration. I don't think this works particularly well and
    // is only here as a fallback for when auto-neg is not possible.
    // E.g. currently we don't provide a way of manually configuring the PAUSE
    // mode to use.
    if (DEBUG_MII) syslog("MII manual configuration");

    control &= ~(MII_CONTROL_NWAY_ENABLE |
                 MII_CONTROL_SPEED100    |
                 MII_CONTROL_SPEED1000   |
                 MII_CONTROL_FULL_DUPLEX );

    switch (cfg->speed)
    {
      case net_speed_unknown: break;
      case net_speed_10Mb   : break;
      case net_speed_100Mb  : control |= MII_CONTROL_SPEED100; break;
      case net_speed_1000Mb : control |= MII_CONTROL_SPEED1000; break;
    }

    switch (cfg->duplex)
    {
      case net_duplex_full   : control |= MII_CONTROL_FULL_DUPLEX; break;
      case net_duplex_half   : break;
      case net_duplex_unknown: break;
    }

    e = mii->write(mii->handle, MII_CONTROL, control);
    if (!e)
    {
      net_status->speed       = cfg->speed;
      net_status->link        = net_link_unknown;
      net_status->duplex      = cfg->duplex;
    }

    mii->read(mii->handle, MII_CONTROL, &control);
  }

  return e;
}


//---------------------------------------------------------------------------
// Read current status from PHY. Could be called often so don't do too
// much in most cases.
//---------------------------------------------------------------------------
_kernel_oserror* mii_link_status(mii_t* mii, net_status_t* status)
{
  status->ok = mii->ok;
  if (!mii->ok)
  {
    status->up = false;
    return NULL;
  }

  uint16_t mii_status = 0;
  _kernel_oserror* e = mii->read(mii->handle, MII_STATUS, &mii_status);
  if (e) return e;
  status->up = ((mii_status & MII_STATUS_LINK_STATUS )!=0);

  // These two flags will have been cleared by reading the register.
  if (mii_status & MII_STATUS_REM_FAULT ) status->remote_faults++;
  if (mii_status & MII_STATUS_JABBER_DET) status->jabbers++;

  //syslog("MII: status check: %i %04X",status->up, mii_status);

  // Check to see if auto-negotiation has finished or been started by
  // someone else.
  if (mii->autoneg)
  {
    const bool negotiating = !(mii_status & MII_STATUS_NWAY_COMP);
    if (!negotiating && mii->negotiating)
    {
      if (DEBUG_MII) syslog("MII: auto-negotiation finished");
      mii->negotiating = false;
      status->autoneg = net_autoneg_failed;

      uint16_t advertise = 0,ms_ctrl = 0;
      e = mii->read(mii->handle, MII_NWAY_ADVERT, &advertise);
      if (!e && (mii_status & MII_STATUS_EXTD_STATUS)) e = mii->read(mii->handle, MII_MASTER_SLAVE_CONTROL, &ms_ctrl);

      uint16_t partner = 0,ms_stat = 0;
      if (!e) e = mii->read(mii->handle, MII_NWAY_PARTNER, &partner);
      if (!e && (mii_status & MII_STATUS_EXTD_STATUS)) e = mii->read(mii->handle, MII_MASTER_SLAVE_STATUS, &ms_stat);

      if (!e &&
          resolve_link(status, advertise, ms_ctrl, partner, ms_stat) &&
          resolve_pause(status, status->duplex, advertise, partner))
      {
        status->autoneg = net_autoneg_reconfigure;
      }
    }
    else if (negotiating && !mii->negotiating)
    {
      if (DEBUG_MII) syslog("MII: auto-negotiation started");
      status->autoneg = net_autoneg_started;
      mii->negotiating = true;
    }
  }
  return e;
}
