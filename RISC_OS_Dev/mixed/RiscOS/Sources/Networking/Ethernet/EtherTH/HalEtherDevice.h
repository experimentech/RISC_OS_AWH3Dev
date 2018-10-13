/*
 * Copyright (c) 2017, Colin Granville
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name Colin Granville may not be used to endorse or promote
 *       products derived from this software without specific prior written
 *       permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#ifndef HALETHERDEVICE_H
#define HALETHERDEVICE_H

#include <stdint.h>
#include "Global/HalDevice.h"

typedef struct HalEtherDevice_t
{
        struct device   base;
        struct
        {
                uint32_t                devicenumber;                                   /* for  OS_ClaimDeviceVector */
                void (*enable)(int on, void* hal_pw);                                   /* enable irq. 1 on, 0 off */
                int (*test)(int unused, void* hal_pw);                                  /* returns 1 if irq present */
                void (*clear)(int unused, void* hal_pw);
                volatile uint32_t*      irqRegAddr;                                     /* phy irq test address */
                uint32_t                irqBitMask;                                     /* phy irq test active bit mask */
                void *                  HAL_WS;
                uint32_t                clock;
                void (*PwrRst)(int bits, void* hal_pw);
        } phy;

} HalEtherDevice_t;
//Bit values to use with the PwrRst call above
#define  PhyPwrOn  1
#define  PhyHWRst  2

#endif
