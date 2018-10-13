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


#include "mii.h"
#include "utils.h"
#include "debug.h"
#include "device.h"
#include "AsmUtils/irqs.h"

void mii_hardresetPhy(device_t* device)
{
   dprintf_here("hardreset bcr was %x\n",mii_getReg(device, MII_BCR));
   if (device->flags & DF_I_HAL_HAS_PHY_PWRRST)
   {
   /* ensure phy is powered up, and give it a hardware reset pulse */
     device->hal_device->phy.PwrRst(PhyPwrOn,(void*)device->hal_pw);
     utils_delay_us(500);
     device->hal_device->phy.PwrRst(PhyPwrOn + PhyHWRst,(void*)(device->hal_pw));
     utils_delay_us(500);
     device->hal_device->phy.PwrRst(PhyPwrOn,(void*)(device->hal_pw));
     utils_delay_us(50);   /* a decent wait to ensure phy is up and running at thie point*/
   }
}

void mii_resetPhy(device_t* device)
{
        if(device->flags && DF_I_PHY_AR8035)
        {
          dprintf_here("bcr was %x\n",mii_getReg(device, MII_BCR));
          mii_modifyReg(device, MII_BCR, ~MII_BCR__PWRDOWN, 0);
        }
        mii_setReg(device, MII_BCR, MII_BCR__RESET);

        /* it should reset within 0.5secs */
        int i;
        for (i = 10000; i; i++)
        {
                if ((mii_getReg(device, MII_BCR) & MII_BCR__RESET) == 0) break;
                utils_delay_us(50);
        }
}

void mii_reAutoNegotiate(device_t* device)
{
        mii_modifyReg(device, MII_BCR, MII_BCR__REAUTONEG, MII_BCR__REAUTONEG);

        for (int i = 100; i; i++)
        {
                if ((mii_getReg(device, MII_BCR) & MII_BCR__RESET) == 0) break;
                utils_delay_us(50);
        }
}

uint32_t mii_getReg(device_t* device, int reg)
{

        int irq_state = ensure_irqs_off();

        device_setReg(device, ENET_EIR, ENET_EIR__MII);                         /* clear event */

        device_setReg(device, ENET_MMFR, ENET_MMFR__ST(1) |                     /* clause 22 */
                                         ENET_MMFR__OP(2) |                     /* read */
                                         ENET_MMFR__TA(2) |                     /* turnaround time */
                                         ENET_MMFR__PHYADR(1) |
                                         ENET_MMFR__REGADR(reg));
        uint32_t val = 0;
        for (int i = 500; i; i--)
        {
                if (device_getReg(device, ENET_EIR) & ENET_EIR__MII)
                {
                        val = ENET_MMFR__DATA(device_getReg(device, ENET_MMFR));
                        break;
                }
                utils_delay_us(2);
        }

        restore_irqs(irq_state);

        return val;
}

void mii_setReg(device_t* device, int reg, uint32_t value)
{
        int irq_state = ensure_irqs_off();

        device_setReg(device, ENET_EIR, ENET_EIR__MII);                         /* clear event */


        device_setReg(device, ENET_MMFR, ENET_MMFR__ST(1) |                     /* clause 22 */
                                         ENET_MMFR__OP(1) |                     /* write */
                                         ENET_MMFR__TA(2) |                     /* turnaround time */
                                         ENET_MMFR__PHYADR(1) |
                                         ENET_MMFR__REGADR(reg) |
                                         ENET_MMFR__DATA(value));


        for (int i = 0; i < 500; i++)
        {
                if (device_getReg(device, ENET_EIR) & ENET_EIR__MII) break;
                utils_delay_us(2);
        }

        restore_irqs(irq_state);
}

void mii_modifyReg(device_t* device, int reg, uint32_t bic, uint32_t eor)
{
        int irq_state = ensure_irqs_off();

        uint32_t val = mii_getReg(device, reg);
        val &= ~bic;
        val ^= eor;
        mii_setReg(device, reg, val);

        restore_irqs(irq_state);
}


uint32_t mii_mmd_get(device_t* device, int reg, int address)
{
        int irq_state = ensure_irqs_off();

        mii_setReg(device, MII_MMD_ACR, MII_MMS_ACR__ADDR | MII_MMS_ACR__DEVAD(reg));
        mii_setReg(device, MII_MMD_AADR, address);
        mii_setReg(device, MII_MMD_ACR, MII_MMS_ACR__DATA | MII_MMS_ACR__DEVAD(reg));
        uint32_t val = mii_getReg(device, MII_MMD_AADR);

        restore_irqs(irq_state);
        return val & 0xffff;
}


void mii_mmd_set(device_t* device, int reg, int address, uint32_t val)
{
        int irq_state = ensure_irqs_off();

        mii_setReg(device, MII_MMD_ACR, MII_MMS_ACR__ADDR | MII_MMS_ACR__DEVAD(reg));
        mii_setReg(device, MII_MMD_AADR, address);
        mii_setReg(device, MII_MMD_ACR, MII_MMS_ACR__DATA | MII_MMS_ACR__DEVAD(reg));
        mii_setReg(device, MII_MMD_AADR, val & 0xffff);

        restore_irqs(irq_state);
}

void mii_mmd_modify(device_t* device, int reg, int address, uint32_t bic, uint32_t eor)
{
        int irq_state = ensure_irqs_off();

        bic &= 0xffff;
        eor &= 0xffff;
        mii_setReg(device, MII_MMD_ACR, MII_MMS_ACR__ADDR | MII_MMS_ACR__DEVAD(reg));
        mii_setReg(device, MII_MMD_AADR, address);
        mii_setReg(device, MII_MMD_ACR, MII_MMS_ACR__DATA | MII_MMS_ACR__DEVAD(reg));
        uint32_t val = mii_getReg(device, MII_MMD_AADR);
        val &= ~bic;
        val ^= eor;
        mii_setReg(device, MII_MMD_AADR, val);

        restore_irqs(irq_state);
}

