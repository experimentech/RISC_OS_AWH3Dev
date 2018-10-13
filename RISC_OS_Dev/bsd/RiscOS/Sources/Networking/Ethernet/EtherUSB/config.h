//
// Copyright (c) 2009, James Peacock
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
#ifndef CONFIG_H_INCLUDED
#define CONFIG_H_INCLUDED

#include <stddef.h>
#include "kernel.h"
#include "net.h"

//---------------------------------------------------------------------------
// Extract the next token from a command line. The token is written in lower
// case into blk. If the end of the input string is reached, then blk[0] is
// zero on exit. *ptr is incremented for the next call.
//---------------------------------------------------------------------------
_kernel_oserror* config_parse_token(const char** ptr,
                                    char* blk,
                                    size_t blk_size);

//---------------------------------------------------------------------------
// Extract unit number from a command line using config_parse_token,
// updates *out and *ptr on exit iff no error returned. Unit numbers can
// be plain integers or prefixed DCI unit numbers.
//---------------------------------------------------------------------------
_kernel_oserror* config_parse_unit(const char** ptr, unsigned *out);


//---------------------------------------------------------------------------
// Parses a config argument string into a net_config_t. Can pass a completely
// initinitialised 'config' in. Sets configured indicating whether any
// configuration was present.
//---------------------------------------------------------------------------
_kernel_oserror* config_parse_arguments(const net_device_t* device,
                                        const char*         arg_string,
                                        net_config_t*       config,
                                        bool*               configured);

//---------------------------------------------------------------------------
// Configures a newly inserted device taking options from any of the following
// system variables:
// EtherUSB$MAC_xxxxxxxxxxxx         (device MAC address)
// EtherUSB$VP_xxxx_xxxx             (USB vendor + product ID)
// EtherUSB$Loc_xx_xx_xx_xx_xx_xx    (USB location)
// The unit number of 'dev' may be set, other options are parsed into 'cfg'.
//---------------------------------------------------------------------------
_kernel_oserror* config_new_device(net_device_t* dev, net_config_t* cfg);

//---------------------------------------------------------------------------
// Get list of reserved unit numbers, and set unit number of device via
// EtherUSB$VP or EtherUSB$Loc system variable if possible. Note - MAC variable
// not checked, as device MAC won't be known yet.
//---------------------------------------------------------------------------
_kernel_oserror* config_reserved_units(bool flags[MODULE_MAX_UNITS],
                                       net_device_t *dev);

#endif
