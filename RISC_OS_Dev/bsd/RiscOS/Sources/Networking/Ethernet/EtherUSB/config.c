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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "swis.h"
#include "Global/NewErrors.h"
#include "Global/Variables.h"

#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "config.h"
#include "net.h"

//---------------------------------------------------------------------------

_kernel_oserror* config_parse_token(const char** ptr,
                                    char* blk,
                                    size_t blk_size)
{
  const char* p = *ptr;
  while (*p==32 || *p==9) ++p;
  char* blk_end = blk + blk_size;
  while (*p>32 && blk!=blk_end) *blk++ = tolower(*p++);
  if (blk==blk_end) return err_translate(ERR_BAD_SYNTAX);
  *blk = 0;
  *ptr = p;
  return NULL;
}

//---------------------------------------------------------------------------

_kernel_oserror* config_parse_unit(const char** ptr, unsigned *out)
{
  const char prefix[] = MODULE_DCI_NAME;

  char blk[sizeof(prefix)+10];
  const char* end = *ptr;
  _kernel_oserror* e = config_parse_token(&end, blk, sizeof(blk));
  if (e) return e;
  const char* p = blk;
  if (memcmp(blk, prefix, sizeof(prefix)-1)==0) p += sizeof(prefix)-1;
  if (!*p) return err_translate(ERR_BAD_UNIT);

  unsigned unit = 0;
  while (*p)
  {
    const char ch = *p++;
    if (ch<'0' || ch>'9') return err_translate(ERR_BAD_UNIT);
    unit = unit * 10 + ch-'0';
    if (unit>=MODULE_MAX_UNITS) return err_translate(ERR_BAD_UNIT);
  }
  *out = unit;
  *ptr = end;
  return NULL;
}
//---------------------------------------------------------------------------

#define REQUIRE(abs, field) if (!(abs)->field) return err_translate(ERR_UNSUPPORTED)

_kernel_oserror* config_parse_arguments(const net_device_t* dev,
                                        const char*         arg_string,
                                        net_config_t*       cfg,
                                        bool*               configured)
{
  const net_abilities_t* abs = &dev->abilities;
  *configured = false;
  memset(cfg, 0, sizeof(net_config_t));

  // Default to using auto-negotiation if device claims to support it
  if (abs->autoneg) cfg->autoneg = true;
  // Allow all supported pause modes by default
  cfg->allow_tx_pause = abs->tx_pause;
  cfg->allow_rx_pause = abs->rx_pause;
  cfg->allow_symmetric_pause = abs->symmetric_pause;

  char blk[20];
  while(true)
  {
    _kernel_oserror *e = config_parse_token(&arg_string, blk, sizeof(blk));
    if (e) return e;
    if (blk[0]==0) break;
    *configured = true;

    if (strcmp(blk, "auto")==0)
    {
      REQUIRE(abs, autoneg);
      cfg->autoneg = true;
    }
    else if (strcmp(blk, "noauto")==0)
    {
      cfg->autoneg = false;
    }
    else if (strcmp(blk, "1000")==0)
    {
      REQUIRE(abs, speed_1000Mb);
      cfg->speed = net_speed_1000Mb;
    }
    else if (strcmp(blk, "100")==0)
    {
      REQUIRE(abs, speed_100Mb);
      cfg->speed = net_speed_100Mb;
    }
    else if (strcmp(blk, "10")==0)
    {
      REQUIRE(abs, speed_10Mb);
      cfg->speed = net_speed_10Mb;
    }
    else if (strcmp(blk, "half")==0)
    {
      REQUIRE(abs, half_duplex);
      cfg->duplex = net_duplex_half;
    }
    else if (strcmp(blk, "full")==0)
    {
      REQUIRE(abs, full_duplex);
      cfg->duplex = net_duplex_full;
    }
    else if (strcmp(blk, "promiscuous")==0)
    {
      REQUIRE(abs, promiscuous);
      cfg->promiscuous = true;
    }
    else if (strcmp(blk, "multicast")==0)
    {
      REQUIRE(abs, multicast);
      cfg->multicast = true;
    }
   else
    {
      return err_translate(ERR_BAD_SYNTAX);
    }
  }

  if (!cfg->autoneg)
  {
    // For manual configuration, ensure all required parameters have been provided
    if ((cfg->speed == net_speed_unknown) || (cfg->duplex == net_duplex_unknown)
    // Manually configured 1Gb links aren't supported yet (would require manual MASTER-SLAVE resolution?)
        || (cfg->speed == net_speed_1000Mb)
       )
    {
      return err_translate(ERR_BAD_CONFIG);
    }
  }

  return NULL;
}

#undef REQUIRE

//---------------------------------------------------------------------------
_kernel_oserror* config_new_device(net_device_t* d, net_config_t* config)
{
  const net_status_t* s = &d->status;
  char name[48];
  snprintf(name, sizeof(name), "EtherUSB$MAC_%02X%02X%02X%02X%02X%02X",
           s->mac[0], s->mac[1], s->mac[2], s->mac[3], s->mac[4], s->mac[5]);

  const char* value = getenv(name);
  if (!value)
  {
    snprintf(name, sizeof(name), "EtherUSB$VP_%04X_%04X",
             d->vendor, d->product);
    value = getenv(name);
  }
  if (!value)
  {
    snprintf(name, sizeof(name), "EtherUSB$Loc_%02X_%02X_%02X_%02X_%02X_%02X",
             d->usb_location[0], d->usb_location[1], d->usb_location[2],
             d->usb_location[3], d->usb_location[4], d->usb_location[5]);
    value = getenv(name);
  }
  if (!value)
  {
    value = "";
  }
  else
  {
    syslog("%s: configure '%s'", d->name, value);

    _kernel_oserror* e = config_parse_unit(&value, &d->dib.dib_unit);
    if (e)
    {
      char token[8];
      e = config_parse_token(&value, token, sizeof(token));
      if (e) return e;

      if (!(token[0]=='a' && token[1]=='n' && token[2]=='y' && token[3]==0))
      {
        return err_translate(ERR_BAD_UNIT);
      }
    }
    else
    {
      syslog("%s: taking unit number from %s",d->name,name);
      d->dib.dib_slot.sl_minor = d->dib.dib_unit;
    }
  }

  bool configured = false;
  _kernel_oserror* e = config_parse_arguments(d, value, config, &configured);
  return e;
}


//---------------------------------------------------------------------------
_kernel_oserror* config_reserved_units(bool flags[MODULE_MAX_UNITS],net_device_t *d)
{
  memset(flags, 0, MODULE_MAX_UNITS);

  const char* name = NULL;
  while (true)
  {
    char value[256];
    size_t size = 0;

    _kernel_oserror *e = _swix(OS_ReadVarVal, _INR(0,4)|_OUTR(2,3),
                               "EtherUSB$MAC_*",
                               value, sizeof(value)-1, name, VarType_Expanded,
                               &size, &name);

    if (e)
    {
      if (e->errnum == ErrorNumber_VarCantFind)
        break;
      return e;
    }

    value[size] = 0;
    const char* ptr = value;
    unsigned unit = MODULE_MAX_UNITS;
    e = config_parse_unit(&ptr, &unit);
    if (!e && unit<MODULE_MAX_UNITS) flags[unit] = true;
  }

  name = NULL;
  while (true)
  {
    char value[256];
    size_t size = 0;

    _kernel_oserror *e = _swix(OS_ReadVarVal, _INR(0,4)|_OUTR(2,3),
                               "EtherUSB$VP_*",
                               value, sizeof(value)-1, name, VarType_Expanded,
                               &size, &name);

    if (e)
    {
      if (e->errnum == ErrorNumber_VarCantFind)
        break;
      return e;
    }

    value[size] = 0;
    const char* ptr = value;
    unsigned unit = MODULE_MAX_UNITS;
    e = config_parse_unit(&ptr, &unit);
    if (!e && unit<MODULE_MAX_UNITS)
    {
      flags[unit] = true;
      unsigned long vendor,product;
      if(sscanf(name+12,"%lx_%lx",&vendor,&product) == 2)
      {
        if((vendor == d->vendor) && (product == d->product))
        {
          syslog("%s: taking unit number from %s",d->name,name);
          d->dib.dib_unit = d->dib.dib_slot.sl_minor = unit;
        }
      }
    }      
  }

  name = NULL;
  while (true)
  {
    char value[256];
    size_t size = 0;

    _kernel_oserror *e = _swix(OS_ReadVarVal, _INR(0,4)|_OUTR(2,3),
                               "EtherUSB$Loc_*",
                               value, sizeof(value)-1, name, VarType_Expanded,
                               &size, &name);

    if (e)
    {
      if (e->errnum == ErrorNumber_VarCantFind)
        break;
      return e;
    }

    value[size] = 0;
    const char* ptr = value;
    unsigned unit = MODULE_MAX_UNITS;
    e = config_parse_unit(&ptr, &unit);
    if (!e && unit<MODULE_MAX_UNITS)
    {
      flags[unit] = true;
      unsigned long location[6];
      if(sscanf(name+13,"%lx_%lx_%lx_%lx_%lx_%lx",&location[0],&location[1],&location[2],&location[3],&location[4],&location[5]) == 6)
      {
        if((location[0] == d->usb_location[0])
        && (location[1] == d->usb_location[1])
        && (location[2] == d->usb_location[2])
        && (location[3] == d->usb_location[3])
        && (location[4] == d->usb_location[4])
        && (location[5] == d->usb_location[5]))
        {
          syslog("%s: taking unit number from %s",d->name,name);
          d->dib.dib_unit = d->dib.dib_slot.sl_minor = unit;
        }
      }
    }      
  }

  return NULL;
}

