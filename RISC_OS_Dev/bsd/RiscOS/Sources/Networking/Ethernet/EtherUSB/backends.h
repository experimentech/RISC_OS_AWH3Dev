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
#ifndef BACKENDS_H_INCLUDED
#define BACKENDS_H_INCLUDED

#include "kernel.h"

// Names, needed for product binding.
#define N_AX88172  "AX88172"
#define N_AX88772  "AX88772"
#define N_CDC      "CDC"
#define N_PEGASUS  "Pegasus"
#define N_MCS7830  "MCS7830"
#define N_SMSC95XX "SMSC95xx"
#define N_SMSC75XX "SMSC75xx"
#define N_SMSC78XX "SMSC78xx"

// Registers and initialises backend.
_kernel_oserror* ax88172_register(void);
_kernel_oserror* ax88772_register(void);
_kernel_oserror* cdc_register(void);
_kernel_oserror* pegasus_register(void);
_kernel_oserror* mcs7830_register(void);
_kernel_oserror* smsc95xx_register(void);
_kernel_oserror* smsc75xx_register(void);
_kernel_oserror* smsc78xx_register(void);

#endif
