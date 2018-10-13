/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "Licence").
 * You may not use this file except in compliance with the Licence.
 *
 * You can obtain a copy of the licence at
 * cddl/RiscOS/Sources/HWSupport/SD/SDIODriver/LICENCE.
 * See the Licence for the specific language governing permissions
 * and limitations under the Licence.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the Licence file. If applicable, add the
 * following below this CDDL HEADER, with the fields enclosed by
 * brackets "[]" replaced with your own identifying information:
 * Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright 2012 Ben Avison.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef INTERFACE_SDHCIDEVICE_H
#define INTERFACE_SDHCIDEVICE_H

#include <stdint.h>
#include "Global/HALDevice.h"

/** SDHCI slot info structure */
typedef struct
{
  uint32_t       flags;
  volatile void *stdregs;
}
sdhci_slotinfo_t;

/** SDHCI HAL device structure */
typedef struct sdhcidevice
{
  struct device     dev;
  uint32_t          flags;
  uint32_t          slots;
  sdhci_slotinfo_t *slotinfo;
  void            (*WriteRegister)(struct sdhcidevice *, uint32_t, volatile void *, uint32_t, uint32_t);
  uint64_t        (*GetCapabilities)(struct sdhcidevice *, uint32_t);
  uint32_t        (*GetVddCapabilities)(struct sdhcidevice *, uint32_t);
  void            (*SetVdd)(struct sdhcidevice *, uint32_t, uint32_t);
  void            (*SetBusMode)(struct sdhcidevice *, uint32_t, bool);
  void            (*PostPowerOn)(struct sdhcidevice *, uint32_t);
  void            (*SetBusWidth)(struct sdhcidevice *, uint32_t, uint32_t);
  uint32_t        (*GetMaxCurrent)(struct sdhcidevice *, uint32_t);
  uint32_t        (*SetSDCLK)(struct sdhcidevice *, uint32_t, uint32_t);
  uint32_t        (*GetTMCLK)(struct sdhcidevice *, uint32_t);
  void            (*SetActivity)(struct sdhcidevice *, uint32_t, uint32_t);
  bool            (*GetCardDetect)(struct sdhcidevice *, uint32_t);
  bool            (*GetWriteProtect)(struct sdhcidevice *, uint32_t);
  void            (*TriggerCommand)(struct sdhcidevice *, uint32_t, uint16_t, uint16_t);
}
sdhcidevice_t;

#endif
/* In the exported copy of this file, the Hdr2H translation of hdr.SDHCIDevice will follow. */
