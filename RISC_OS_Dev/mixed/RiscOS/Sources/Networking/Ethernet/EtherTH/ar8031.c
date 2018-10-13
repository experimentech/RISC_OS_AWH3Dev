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


#include "ar8031_mii.h"
#include "AsmUtils/irqs.h"

void ar8031_mii_dbg_set(device_t* device, int reg, uint32_t value)
{
        int irq_state = ensure_irqs_off();

        mii_setReg(device, AR8031_MII_DPAR, reg);
        mii_setReg(device, AR8031_MII_DPDR, value & 0xffff);

        restore_irqs(irq_state);
}

uint32_t ar8031_mii_dbg_get(device_t* device, int reg)
{
        int irq_state = ensure_irqs_off();

        mii_setReg(device, AR8031_MII_DPAR, reg);
        uint32_t val = mii_getReg(device, AR8031_MII_DPDR);

        restore_irqs(irq_state);
        return val;
}


void ar8031_mii_dbg_modify(device_t* device, int reg, uint32_t bic, uint32_t eor)
{
        int irq_state = ensure_irqs_off();

        uint32_t val = ar8031_mii_dbg_get(device, reg);
        val &= ~bic;
        val ^= eor;
        ar8031_mii_dbg_set(device, reg, val);

        restore_irqs(irq_state);
}
