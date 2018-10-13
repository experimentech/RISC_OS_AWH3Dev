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

#include <stdio.h>
#include "swis.h"

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Interface/SDIO.h"

#include "command.h"
#include "globals.h"
#include "message.h"
#include "register.h"
#include "swi.h"

#ifndef OS_ConvertVariform
#define OS_ConvertVariform (0xED)
#endif
#ifndef ConvertToFixedFileSize
#define ConvertToFixedFileSize (8)
#endif

/** The size threshold between SDHC and SDXC cards. In general we can treat SDHC
 * and SDXC identically - the exception is in the *SDIODevices command! */
#define SDXC_THRESHOLD (32ull << 30)

_kernel_oserror *command_sdiodevices(void)
{
  printf(message_lookup_direct("SDIODevHdr"));
  printf("\n");

  for (sdhcinode_t *sdhci = g_sdhci; sdhci != NULL; sdhci = sdhci->next)
  {
    for (uint32_t sloti = 0; sloti < sdhci->dev->slots; sloti++)
    {
      sdmmcslot_t *slot = sdhci->slot + sloti;
      if (swi_Control_lock(sdhci->bus, sloti) == NULL)
      {
        if (slot->card_detect_state == CD_ANNOUNCED)
        {
          if (slot->memory_type != MEMORY_NONE)
          {
            for (uint32_t cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
            {
              sdmmccard_t *card = slot->card + cardi;
              if (card->in_use)
              {
                const char *desc, *vendor;
                char cap_buf[12] = "", vendor_buf[4], name_buf[8];
                uint32_t version, date, year, month;
  
                switch (slot->memory_type)
                {
                  case MEMORY_MMC:       desc = "MMC card"; break;
                  case MEMORY_SD:        desc = "SD card"; break;
                  case MEMORY_SDHC_SDXC: desc = card->capacity < SDXC_THRESHOLD ? "SDHC card" : "SDXC card"; break;
                  default: desc = "Error";
                }
  
                _swix(OS_ConvertVariform, _INR(0,4), &card->capacity, cap_buf, sizeof cap_buf, 8, ConvertToFixedFileSize);
  
                if (slot->memory_type == MEMORY_MMC)
                {
                  vendor = message_lookup_direct("BadString");
                  cardreg_read_string(card->cid, CID_PNM_MMC, name_buf);
                  version = cardreg_read_int(card->cid, CID_PRV_MMC);
                  date = cardreg_read_int(card->cid, CID_MDT_MMC);
                  month = date >> 4;
                  year = (date & 0xF) + 1997; // safe to 2012, bleurgh
                }
                else
                {
                  vendor = cardreg_lookup_manufacturer(cardreg_read_string(card->cid, CID_OID_SD, vendor_buf));
                  cardreg_read_string(card->cid, CID_PNM_SD, name_buf);
                  version = cardreg_read_int(card->cid, CID_PRV_SD);
                  date = cardreg_read_int(card->cid, CID_MDT_SD);
                  month = date & 0xF;
                  year = (date >> 4) + 2000; // safe to 2255
                }
  
                printf("%3u %3u  %04X  0  %-18s %11.11s  %-9.9s %-6.6s  %X.%X %u-%02u\n",
                    sdhci->bus,
                    sloti,
                    card->rca,
                    desc,
                    cap_buf,
                    vendor,
                    name_buf,
                    version >> 4,
                    version & 0xF,
                    year,
                    month
                );
              }
            }
          }
          for (uint32_t function = 1; function <= slot->io_functions; function++)
          {
            char buffer[80-18+1]; /* output of *SDIODevices should fit in 80 columns and we start at column 18 */
            uint32_t r1;
            const char *function_name;
            _swix(OS_ServiceCall, _INR(0,1)|_OUTR(1,2), slot->fic[function-1], Service_SDIODescribeFIC, &r1, &function_name);
            if (r1 != 0)
            {
              /* Nobody offered a better name for the function */
              const char *format = message_lookup_direct("BadFIC");
              snprintf(buffer, sizeof buffer - 1, format, slot->fic[function-1]);
              function_name = buffer;
            }
            printf("%3u %3u  %04X%3u  %s\n", sdhci->bus, sloti, slot->card[0].rca, function, function_name);
          }
        }
        swi_Control_unlock(sdhci->bus, sloti);
      }
    }
  }
  
  return NULL;
}

_kernel_oserror *command_sdioslots(void)
{
  printf(message_lookup_direct("SDIOSltHdr"));
  printf("\n");

  for (sdhcinode_t *sdhci = g_sdhci; sdhci != NULL; sdhci = sdhci->next)
  {
    for (uint32_t sloti = 0; sloti < sdhci->dev->slots; sloti++)
    {
      sdmmcslot_t    *slot = sdhci->slot + sloti;
      if (swi_Control_lock(sdhci->bus, sloti) == NULL)
      {
        if (slot->card_detect_state == CD_ANNOUNCED)
        {
          printf("%3u %3u   %u.%u V   %u-bit  ",
              sdhci->bus,
              sloti,
              slot->voltage / 1000,
              (slot->voltage / 100) % 10,
              slot->lines
          );
          if (slot->freq < 1000)
            printf("%3u kHz SDR\n", slot->freq);
          else
            printf("%3u MHz SDR\n", slot->freq / 1000);
        }
        swi_Control_unlock(sdhci->bus, sloti);
      }
    }
  }

  return NULL;
}
