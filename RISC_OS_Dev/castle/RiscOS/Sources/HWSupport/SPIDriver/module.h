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
#ifndef module_H
#define module_H

#ifndef spidriver_H
#include "Interface/SPIDriver.h"
#endif

extern void *module_wsp;
extern void (*irqtrigger)(void);
extern spi_devicelist *spidevbase;
extern void *Resources(void); /* From 'resgen' */
_kernel_oserror *module_error(unsigned);
const char *module_lookup(const char *);
extern _kernel_oserror *SPI_Version(_kernel_swi_regs *, void *);
extern _kernel_oserror *SPI_Initialise(_kernel_swi_regs *r, void *pw);
extern _kernel_oserror *SPI_Control(_kernel_swi_regs *r, void *pw);
extern _kernel_oserror *SPI_Transfer(_kernel_swi_regs *r, void *pw);
extern _kernel_oserror *SPI_Status(_kernel_swi_regs *r, void *pw);

extern _kernel_oserror *CommandDevices(void);

#endif

