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
#include <stdio.h>
#include <string.h>
#include "swis.h"
#include "Global/Services.h"
#include "SyncLib/SyncLib.h"

#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "net.h"
#include "mbuf.h"
#include "products.h"
#include "backends.h"
#include "config.h"

// This is generated by CMHG
#include "EtherUSBHdr.h"

// Module state.
static enum { st_inactive, st_active, st_dead } s_module_state = st_inactive;
static int s_msg_block[4];
static _kernel_oserror s_msg_buffer;
void* g_module_pw = NULL;

//-------------------------------------------------------------------------
// Attempt to start driver
//-------------------------------------------------------------------------
static _kernel_oserror* start_driver(void)
{
  if (s_module_state==st_dead) return NULL;
  _kernel_oserror* e = mbuf_initialise(MODULE_MBUF_MIN_UBS,
                                       MODULE_MBUF_MAX_UBS,
                                       MODULE_MBUF_MIN_CONTIG);
  if (e)
  {
    syslog("Unable to start driver at the moment: %s",e->errmess);
  }
  else
  {
    s_module_state = st_active;
    syslog("Driver started");
    usb_scan_devices(&net_check_device, NULL);
  }
  return e;
}

static callback_delay_t start_callback(void* h)
{
  // Need to have our SWIs available to other modules.
  start_driver();

  UNUSED(h);
  
  return CALLBACK_REMOVE;
}

//-------------------------------------------------------------------------
// Module message code
//-------------------------------------------------------------------------

_kernel_oserror *err_translate(int which)
{
  struct {
    int errnum;
    char errmess[8];
  } token;

  if (which < ERR_MAX)
  {
      // One from this module
      token.errnum = MODULE_ERROR_BASE + which;
  }
  else
  {
      // Literal (shared) error number
      token.errnum = which;
  }
  sprintf(token.errmess, "E%02x", which);
  return _swix(MessageTrans_ErrorLookup, _INR(0,3),
            &token, s_msg_block, &s_msg_buffer, sizeof(s_msg_buffer));
}

const char *msg_translate(const char *token)
{
  if (_swix(MessageTrans_Lookup, _INR(0,7),
            s_msg_block, token,  &s_msg_buffer, sizeof(s_msg_buffer),
            0, 0, 0, 0) != NULL)
  {
    return "";
  }

  return (const char *)&s_msg_buffer;
}

//-------------------------------------------------------------------------
// Module initialisation code
//-------------------------------------------------------------------------

_kernel_oserror *module_init(const char *cmd_tail,
                             int         podule_base,
                             void       *pw)
{
  _kernel_oserror *e;

#ifndef ROM
  // Register the messages for RAM based modules
  e = _swix(ResourceFS_RegisterFiles, _IN(0), Resources());
  if (e) return e;
#endif
  // Try open, report fail
  e = _swix(MessageTrans_OpenFile, _INR(0,2), s_msg_block, Module_MessagesFile, 0);
  if (e)
  {
#ifndef ROM
    _swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
#endif
    return e;
  }

  if (podule_base==1) e = err_translate(ERR_REINSTANTIATE);

  syslog(" ");
  syslog(Module_Title " " Module_VersionString " starting");

  g_module_pw = pw;
  s_module_state = st_dead;

  // Module initialisation
  synclib_init();
  if (!e) e = callback_initialise(pw);
  if (!e) e = usb_initialise();

  // Register backends
  if (!e) e = cdc_register();
  if (!e) e = ax88172_register();
  if (!e) e = ax88772_register();
  if (!e) e = pegasus_register();
  if (!e) e = mcs7830_register();
  if (!e) e = smsc95xx_register();
  if (!e) e = smsc78xx_register();
  if (!e) e = smsc75xx_register();

  // Start interfaces on callback so our SWIs are available for protocol
  // modules to call when they notice Service_DCIDriverStatus.
  if (!e) e = callback(&start_callback, CALLBACK_ASAP, NULL);

  if (e)
  {
    syslog("Error during initialisation: '%s'", e->errmess);
    if (module_final(1,0,pw))
    {
      // Unsafe to return a error in this case.
      syslog("Unable to clean up after initialisation error");
      return NULL;
    }
    return e;
  }

  s_module_state = st_inactive;

  UNUSED(cmd_tail);
  UNUSED(pw);

  return NULL;
}

//-------------------------------------------------------------------------
// Module finalisation code
//-------------------------------------------------------------------------

_kernel_oserror *module_final(int fatal, int podule, void *pw)
{
  s_module_state = st_dead;
  _kernel_oserror* e = net_finalise();
  if (!e) e = usb_finalise();
  if (!e) e = callback_finalise();
  if (!e) e = mbuf_finalise();

  _swix(MessageTrans_CloseFile, _IN(0), s_msg_block);
#ifndef ROM
  _swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
#endif

  if (e)
  {
    syslog("Unexpected error during finalisation: '%s'", e->errmess);
    return e;
  }
  syslog(Module_Title " stopped");

  UNUSED(fatal);
  UNUSED(pw);
  UNUSED(podule);
  
  return NULL;
}


//-------------------------------------------------------------------------
// Module service call handler
//-------------------------------------------------------------------------

void module_service(int service_number, _kernel_swi_regs *r, void *pw)
{
  switch (service_number)
  {
    case Service_USB:
      switch (r->r[0])
      {
        case Service_USB_Attach:
          if (s_module_state==st_active)
            net_check_device((const USBServiceCall*)(r->r[2]), NULL);
          break;
        // Service_USB_USBDriverStarting not required as devices are attached via Service_USB_Attach
      }
      break;

    case Service_DeviceDead:
      if (r->r[3]!=0 && s_module_state==st_active)
        net_dead_device((const char*)(r->r[3]));
      break;

    case Service_MbufManagerStatus:
      if (s_module_state==st_inactive &&
          r->r[0]==Service_MbufManagerStatus_Started) start_driver();

    case Service_EnumerateNetworkDrivers:
      if (s_module_state==st_active) net_enumerate_drivers(r);
      break;

    case Service_DCIProtocolStatus:
      if (r->r[2]==DCIPROTOCOL_DYING && s_module_state==st_active) net_protocol_dying(r);
      break;

    case Service_DeviceFSStarting:
      usb_scan_devices(&net_check_device, NULL);
      // Service_DeviceFSDying not required as devices are removed in Service_DeviceDead
      break;

    case Service_Reset:
      usb_service_reset();
      break;

#ifndef ROM
    case Service_ResourceFSStarting:
      (*(void (*)(void *, void *, void *, void *))r->r[2])(Resources(), 0, 0, (void *)r->r[3]);
      break;
#endif
  }
  UNUSED(pw);
}

//---------------------------------------------------------------------------
// Module SWI dispatcher
//---------------------------------------------------------------------------

#define MODULE_SWI(name) (name - EtherUSB_00)

_kernel_oserror *module_swi(int swi_offset, _kernel_swi_regs *r, void *pw)
{
  // All this lot need to be reentrant.
  switch(swi_offset)
  {
    case MODULE_SWI(EtherUSB_DCIVersion):
      r->r[1] = DCIVERSION;
      return NULL;

    case MODULE_SWI(EtherUSB_Inquire):
      return net_inquire(r);

    case MODULE_SWI(EtherUSB_GetNetworkMTU):
      return net_get_network_mtu(r);

    case MODULE_SWI(EtherUSB_SetNetworkMTU):
      return err_translate(ERR_BAD_OPERATION);

    case MODULE_SWI(EtherUSB_Transmit):
      return net_transmit(r);

    case MODULE_SWI(EtherUSB_Filter):
      return net_filter(r);

    case MODULE_SWI(EtherUSB_Stats):
      return net_stats(r);

    case MODULE_SWI(EtherUSB_MulticastRequest):
      return err_translate(ERR_BAD_OPERATION);
  }
  UNUSED(pw);
  
  return error_BAD_SWI;
}

//---------------------------------------------------------------------------
// *EJConfig
//---------------------------------------------------------------------------
static _kernel_oserror* ejconfig(const char* arg_string)
{
  unsigned unit;
  _kernel_oserror* e = config_parse_unit(&arg_string, &unit);
  if (!e) e = net_configure(unit, arg_string);
  return e;
}

//---------------------------------------------------------------------------
// *EJInfo
//---------------------------------------------------------------------------
static _kernel_oserror* ejtest(const char* arg_string)
{
  UNUSED(arg_string);
  
  return NULL;
}

//---------------------------------------------------------------------------
// *EJInfo
//---------------------------------------------------------------------------
static _kernel_oserror* ejinfo(const char* arg_string)
{
  unsigned unit = MODULE_MAX_UNITS;
  bool verbose = false;

  char blk[20];
  while(true)
  {
    _kernel_oserror* e = config_parse_token(&arg_string, blk, sizeof(blk));
    if (e) return e;
    if (blk[0]==0) break;

    if      (strcmp(blk, "-v"      )==0) verbose = true;
    else if (strcmp(blk, "-verbose")==0) verbose = true;
    else
    {
      const char* b = blk;
      e = config_parse_unit(&b, &unit);
      if (e) return e;
    }
  }
  return net_info(unit, verbose);
}

//---------------------------------------------------------------------------
// Module *Command dispatcher
//---------------------------------------------------------------------------
_kernel_oserror *module_command(const char *arg_string,
                                int argc,
                                int cmd_no,
                                void *pw)
{
  switch (cmd_no)
  {
    case CMD_EJInfo:
      return ejinfo(arg_string);

    case CMD_EJTest:
      return ejtest(arg_string);

    case CMD_EJProducts:
      return products_list();

    case CMD_EJConfig:
      return ejconfig(arg_string);
  }
  UNUSED(pw);
  UNUSED(argc);

  return NULL;
}
