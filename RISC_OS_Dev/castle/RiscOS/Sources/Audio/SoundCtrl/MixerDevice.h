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
#ifndef GLOBAL_MIXERDEVICE_H
#define GLOBAL_MIXERDEVICE_H

#pragma force_top_level
#pragma include_only_once

#include <stdbool.h>
#include <stdint.h>
#include "Global/HALDevice.h"

struct mixer_device_channel_features
{
  bool fixed: 1;
  bool mono: 1;
  bool default_mute: 1;
  unsigned : 13;
  signed category: 16;
};

struct mixer_device_channel_state
{
  bool mute: 1;
  int32_t gain;
};

struct mixer_device_channel_limits
{
  int32_t mingain;
  int32_t maxgain;
  int32_t step;
};  

struct mixer_device
{
  struct device device;
  struct device *controller;
  uint32_t nchannels;
  struct mixer_device_channel_features (*GetFeatures)(struct mixer_device *, uint32_t channel);
  void (*SetMix)(struct mixer_device *, uint32_t channel, struct mixer_device_channel_state state);
  __value_in_regs struct mixer_device_channel_state (*GetMix)(struct mixer_device *, uint32_t channel);
  void (*GetMixLimits)(struct mixer_device *, uint32_t channel, struct mixer_device_channel_limits *); /* API 0.1 extension */
};

enum
{
  mixer_CATEGORY_SPEAKER    = -1,
  mixer_CATEGORY_HEADPHONES = -2,
  mixer_CATEGORY_LINE_OUT   = -3,
  mixer_CATEGORY_AUX_OUT    = -4,
  mixer_CATEGORY_SYSTEM     = 0,
  mixer_CATEGORY_MIC        = 1,
  mixer_CATEGORY_LINE_IN    = 2,
  mixer_CATEGORY_AUX_IN     = 3,
};

#endif
