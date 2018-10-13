/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <ctype.h>
#include <inttypes.h>
#include "kernel.h"
#include "swis.h"

#include "Global/HALDevice.h"
#include "Global/Services.h"
#include "Interface/MixerDevice.h"
#include "Interface/Sound.h"
#include "DebugLib/DebugLib.h"

#include "global.h"
#include "mess.h"
#include "modhdr.h"
#include "resmess.h"

#define LAST_KNOWN_DEVICE_MAJOR_VERSION 0

typedef struct system
{
  struct system *next;
  uint32_t number;
  struct mixer_device *device;
}
system_t;

static _kernel_oserror *GetInitialDevices(void);
static void RemoveAllDevices(void);
static void AddDevice(struct mixer_device *device);
static void RemoveDevice(struct mixer_device *device);
static void MixVolumeCommand(const char *arg_string, int argc);
static _kernel_oserror *ExamineMixerSWI(_kernel_swi_regs *r);
static _kernel_oserror *SetMixSWI(_kernel_swi_regs *r);
static _kernel_oserror *GetMixSWI(_kernel_swi_regs *r);
static _kernel_oserror *FindChannel(system_t *system, int32_t category, uint32_t index, uint32_t *channel);
static _kernel_oserror *FindSystemBlockByNumber(uint32_t system_num, system_t **system);
static _kernel_oserror *FindSystemBlockByDevice(struct mixer_device *device, system_t **system);
static _kernel_oserror *FindSystemBlockForSWI(int r0, system_t **system);

static system_t *static_SystemList = NULL;


_kernel_oserror *module_Init(const char *cmd_tail, int podule_base, void *pw)
{
  _kernel_oserror *e = NULL;
#ifndef ROM_MODULE
  bool FileRegistered = false;
#endif
  bool MessagesOpen = false;
  bool DevicesEnumerated = false;
  IGNORE(cmd_tail);
  IGNORE(podule_base);
  IGNORE(pw);
  
  debug_initialise("SoundCtrl", "null:", "");
  debug_atexit();
  debug_set_taskname_prefix(false);
  debug_set_area_level_prefix(true);
  debug_set_area_pad_limit(0);
  debug_set_device(PRINTF_OUTPUT);
  debug_set_raw_device(NULL_OUTPUT);
  debug_set_trace_device(NULL_OUTPUT);
  
  if (!e)
  {
    
#ifndef ROM_MODULE
    e = _swix(ResourceFS_RegisterFiles, _IN(0),
              resmess_ResourcesFiles());
  }
  if (!e)
  {
    FileRegistered = true;
#endif
    
    e = _swix(MessageTrans_OpenFile, _INR(0,2),
              &global_MessageFD,
              Module_MessagesFile,
              0);
  }
  if (!e)
  {
    MessagesOpen = true;
    
    e = GetInitialDevices();
  }
  if (!e)
  {
    DevicesEnumerated = true;
    
    /* Add other initialisation here */
  }
  
  if (e && DevicesEnumerated) RemoveAllDevices();
  if (e && MessagesOpen) _swix(MessageTrans_CloseFile, _IN(0),
                               &global_MessageFD);
#ifndef ROM_MODULE
  if (e && FileRegistered) _swix(ResourceFS_DeregisterFiles, _IN(0),
                                 resmess_ResourcesFiles());
#endif
  return e;
}


_kernel_oserror *module_Final(int fatal, int podule, void *pw)
{
  _kernel_oserror *e = NULL;
  IGNORE(fatal);
  IGNORE(podule);
  IGNORE(pw);
  
  if (!e)
  {
    RemoveAllDevices();
    _swix(MessageTrans_CloseFile, _IN(0),
          &global_MessageFD);
#ifndef ROM_MODULE
    _swix(ResourceFS_DeregisterFiles, _IN(0),
          resmess_ResourcesFiles());
#endif
  }
  return e;
}


void module_Service(int service_number, _kernel_swi_regs *r, void *pw)
{
  IGNORE(pw);
  switch (service_number)
  {
    case Service_Hardware:;
      struct mixer_device *device = (struct mixer_device *) r->r[2];
      switch (r->r[0] & 0xFF)
      {
        case 0:
          if (!((device->device.version>>16) > LAST_KNOWN_DEVICE_MAJOR_VERSION))
          {
            AddDevice(device);
          }
          break;
          
        case 1:
          if (!((device->device.version>>16) > LAST_KNOWN_DEVICE_MAJOR_VERSION))
          {
            RemoveDevice(device);
          }
          break;
      }
      break;
  }
  return;
}


_kernel_oserror *module_Commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
  IGNORE(pw);
  switch(cmd_no)
  {
    case CMD_MixVolume:
      MixVolumeCommand(arg_string, argc);
      break;
  }
  return NULL;
}


_kernel_oserror *module_SWI(int swi_offset, _kernel_swi_regs *r, void *pw)
{
  _kernel_oserror *e;
  IGNORE(pw);
  switch(swi_offset)
  {
    case SoundCtrl_ExamineMixer - SoundCtrl_00:
      e = ExamineMixerSWI(r);
      break;
      
    case SoundCtrl_SetMix - SoundCtrl_00:
      e = SetMixSWI(r);
      break;
      
    case SoundCtrl_GetMix - SoundCtrl_00:
      e = GetMixSWI(r);
      break;
      
    default:
      e = mess_GenerateError("BadSWI", error_SOUNDCTRL_BAD_SWI, 1, "SoundControl");
      break;
  }
  return e;
}


static _kernel_oserror *GetInitialDevices(void)
{
  int32_t r1 = 0;
  system_t *system = NULL;
  
  do
  {
    _kernel_oserror *e;
    struct mixer_device *device;
    
    e = _swix(OS_Hardware, _INR(0,1)|_IN(8)|_OUTR(1,2),
              (LAST_KNOWN_DEVICE_MAJOR_VERSION << 16) | HALDeviceType_Audio | HALDeviceAudio_Mixer,
              r1,
              4,
              &r1,
              &device);
    if (!e && r1 == -1) break;
    if (!e)
    {
      system = malloc(sizeof *system);
      if (system == NULL) e = mess_GenerateError("NoMem", error_SOUNDCTRL_NO_MEM, 0);
    }
    if (e)
    {
      RemoveAllDevices();
      return e;
    }
    if (device->device.Activate(&device->device))
    {
      system->next = static_SystemList;
      system->device = device;
      static_SystemList = system;
    }
    else
    {
      free(system);
    }
  }
  while (true);
  
  /* Now number the devices in the reverse of enumeration order */
  /* so any motherboard mixer is guaranteed to get number 0 */
  uint32_t counter = 0;
  for (system = static_SystemList; system != NULL; system = system->next)
  {
    system->number = counter++;
  }
  return NULL;
}


static void RemoveAllDevices(void)
{
  system_t *system = static_SystemList;
  system_t *next;
  for (; system != NULL; system = next)
  {
    next = system->next;
    system->device->device.Deactivate(&system->device->device);
    free(system);
  }
  return;
}


static void AddDevice(struct mixer_device *device)
{
  system_t *system = malloc(sizeof *system);
  if (system == NULL) return;

  system->device = device;

  if (device->device.Activate(&device->device))
  {
    /* Seach for a gap in the list of system numbers; if a driver module was */
    /* *RMReInited, this approach should hopefully keep the system number the same */
    system_t *prev = NULL;
    system_t *next = static_SystemList;
    uint32_t expected_number = 0;
    
    while (next != NULL && next->number == expected_number++)
    {
      prev = next;
      next = next->next;
    }
    system->number = expected_number;
    system->next = next;
    if (prev)
    {
      prev->next = system;
    }
    else
    {
      static_SystemList = system;
    }
  }
  else
  {
    free(system);
  }
  return;
}


static void RemoveDevice(struct mixer_device *device)
{
  system_t *system = static_SystemList;
  system_t *prev = NULL;
  for (; system != NULL; prev = system, system = system->next)
  {
    if (system->device == device)
    {
      if (prev)
      {
        prev->next = system->next;
      }
      else
      {
        static_SystemList = system->next;
      }
      system->device->device.Deactivate(&system->device->device);
      free(system);
      break;
    }
  }
  return;
}


static bool SoundDMA_ControllerSelection(void)
{
  uint32_t ret,flags;
  /* Check if device selection & enumeration functionality is available */
  if (_swix(Sound_ReadSysInfo, _IN(0)|_OUTR(0,1), Sound_RSI_Features, &ret, &flags))
  {
    dprintf(("", "ControllerSelection: SWI error\n"));
    return false;
  }
  if (ret || !(flags & Sound_RSI_Feature_ControllerSelection))
  {
    dprintf(("", "ControllerSelection: no\n"));
    return false;
  }
  dprintf(("", "ControllerSelection: yes\n"));
  return true;
}


static void MixVolumeCommand(const char *arg_string, int argc)
{
  int32_t category;
  uint32_t index;
  unsigned char mute;
  int32_t gain;
  system_t *system = NULL;
  uint32_t channel;

  if (SoundDMA_ControllerSelection())
  {
    /* Accept "0" or a controller ID */
    struct mixer_device *device;
    char temp[128];
    const char *controller_id;
    if ((arg_string[0] == '0') && isspace(arg_string[1]))
    {
      /* Get current device ID */
      if (_swix(Sound_ReadSysInfo, _INR(0,2), Sound_RSI_DefaultController, temp, sizeof(temp)))
      {
        return;
      }
      controller_id = temp;
    }
    else
    {
      controller_id = arg_string;
    }
    dprintf(("", "Looking for mixer for '%s'\n",controller_id));
    /* Get mixer from device ID */
    if (_swix(Sound_ControllerInfo, _INR(0,3), controller_id, &device, sizeof(device), Sound_CtlrInfo_MixerDevice))
    {
      return;
    }
    FindSystemBlockByDevice(device, &system);
  }
  else
  {
    /* Old SoundDMA, accept mixer number (using internal numbering scheme) */
    FindSystemBlockByNumber(atoi(arg_string), &system);
  }

  if (!system)
  {
    return;
  }
  
  while (*arg_string && !isspace(*arg_string))
  {
    arg_string++;
  }

  if (argc == 4)
  {
    if (sscanf(arg_string, "%"SCNd32" %"SCNu32" %c", &category, &index, &mute) == 3)
    {
      mute -= '0';
      if (mute <= 1 && FindChannel(system, category, index, &channel) == 0)
      {
        struct mixer_device_channel_state state = system->device->GetMix(system->device, channel);
        state.mute = mute;
        system->device->SetMix(system->device, channel, state);
      }
    }
  }
  else /* argc == 5 */
  {
    if (sscanf(arg_string, "%"SCNd32" %"SCNu32" %c %"SCNd32, &category, &index, &mute, &gain) == 4)
    {
      mute -= '0';
      if (mute <= 1 && FindChannel(system, category, index, &channel) == 0)
      {
        struct mixer_device_channel_state state = { mute, gain };
        system->device->SetMix(system->device, channel, state);
      }
    }
  }
  return;
}


static _kernel_oserror *ExamineMixerSWI(_kernel_swi_regs *r)
{
  system_t *system;
  _kernel_oserror *e = FindSystemBlockForSWI((uint32_t) r->r[0], &system);
  if (e) return e;
  
  uint32_t nchannels = system->device->nchannels;
  uint32_t block_size = sizeof (struct mixer_device_channel_features);
  if (system->device->device.version > 0)
    block_size += sizeof (struct mixer_device_channel_limits);
  
  uint32_t to_do = r->r[2] / block_size;
  if (to_do > nchannels) to_do = nchannels;
  
  r->r[2] -= nchannels * block_size;
  r->r[3] = block_size;
  r->r[4] = to_do;

  uint8_t *ptr = (uint8_t *) r->r[1];  
  for (uint32_t c = 0; c < to_do; c++)
  {
    *((struct mixer_device_channel_features *) ptr) = system->device->GetFeatures(system->device, c);
    ptr += sizeof(struct mixer_device_channel_features);
    if(system->device->device.version > 0)
    {
      system->device->GetMixLimits(system->device, c, (struct mixer_device_channel_limits *) ptr);
      ptr += sizeof(struct mixer_device_channel_limits);
    }
  }
  
  return e;
}


static _kernel_oserror *SetMixSWI(_kernel_swi_regs *r)
{
  system_t *system;
  uint32_t channel;
  _kernel_oserror *e = FindSystemBlockForSWI(r->r[0], &system);
  if (e) return e;

  e = FindChannel(system, (int32_t) r->r[1], (uint32_t) r->r[2], &channel);
  if (e) return e;
  
  struct mixer_device_channel_state state = { r->r[3], r->r[4] };
  system->device->SetMix(system->device, channel, state);
  
  return e;
}


static _kernel_oserror *GetMixSWI(_kernel_swi_regs *r)
{
  system_t *system;
  uint32_t channel;
  _kernel_oserror *e = FindSystemBlockForSWI(r->r[0], &system);
  if (e) return e;

  e = FindChannel(system, (int32_t) r->r[1], (uint32_t) r->r[2], &channel);
  if (e) return e;
  
  struct mixer_device_channel_state state = system->device->GetMix(system->device, channel);
  r->r[3] = (int) state.mute;
  r->r[4] = (int) state.gain;
  
  return e;
}


static _kernel_oserror *FindChannel(system_t *system, int32_t category, uint32_t index, uint32_t *channel)
{
  uint32_t c = 0;
  uint32_t nchannels = system->device->nchannels;
  struct mixer_device_channel_features features;
  for (; c < nchannels; c++)
  {
    features = system->device->GetFeatures(system->device, c);
    if (features.category == category && index-- == 0) /* note second isn't performed if first test fails */
    {
      *channel = c;
      return NULL;
    }
  }
  return mess_MakeError(error_SOUNDCTRL_BAD_CHANNEL, 0);
}


static _kernel_oserror *FindSystemBlockByNumber(uint32_t system_num, system_t **system)
{
  dprintf(("","FindSystemBlockByNumber: %u\n",system_num));
  system_t *s = static_SystemList;
  for (; s != NULL; s = s->next)
  {
    if (s->number == system_num) break;
  }
  if (s)
  {
    dprintf(("","Found\n"));
    *system = s;
    return NULL;
  }
  else
  {
    return mess_MakeError(error_SOUNDCTRL_BAD_MIXER, 0);
  }
}


static _kernel_oserror *FindSystemBlockByDevice(struct mixer_device *device, system_t **system)
{
  dprintf(("","FindSystemBlockByDevice: %x\n",device));
  system_t *s = static_SystemList;
  for (; s != NULL; s = s->next)
  {
    if (s->device == device) break;
  }
  if (s)
  {
    dprintf(("","Found\n"));
    *system = s;
    return NULL;
  }
  else
  {
    return mess_MakeError(error_SOUNDCTRL_BAD_MIXER, 0);
  }
}

static _kernel_oserror *FindSystemBlockForSWI(int r0, system_t **system)
{
  _kernel_oserror *e;
  if (SoundDMA_ControllerSelection())
  {
    /* Accept NULL or a string pointer */
    struct mixer_device *device;
    char temp[128];
    char *controller_id;
    if (!r0)
    {
      /* Get current controller ID */
      if ((e = _swix(Sound_ReadSysInfo, _INR(0,2), Sound_RSI_DefaultController, temp, sizeof(temp))) != NULL)
      {
        return e;
      }
      controller_id = temp;
    }
    else
    {
      controller_id = (char *) r0;
    }
    dprintf(("", "Looking for mixer for '%s'\n",controller_id));
    /* Get mixer from controller ID */
    if ((e = _swix(Sound_ControllerInfo, _INR(0,3), controller_id, &device, sizeof(device), Sound_CtlrInfo_MixerDevice)) != NULL)
    {
      return e;
    }
    return FindSystemBlockByDevice(device, system);
  }
  else
  {
    /* Old SoundDMA, accept mixer number (using internal numbering scheme) */
    return FindSystemBlockByNumber(r0, system);
  }
}
