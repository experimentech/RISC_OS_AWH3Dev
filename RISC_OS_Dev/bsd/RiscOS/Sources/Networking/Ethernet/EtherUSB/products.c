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

#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "swis.h"
#include "Global/Variables.h"
#include "Global/NewErrors.h"
#include "sys/param.h"

#include "USB/USBDevFS.h"
#include "usb.h"
#include "module.h"
#include "products.h"
#include "utils.h"
#include "backends.h"


typedef struct
{
  uint16_t    vendor;
  uint16_t    product;
  const char* backend_name;
  const char* options;
} product_t;

static const product_t s_products[] = {
//  Vendor  Product Backend  Options
//  ------  ------- -------- -------
  { 0x0b95, 0x772b, N_AX88772 , ""   },
  { 0x0b95, 0x772a, N_AX88772 , ""   },
  { 0x0b95, 0x7720, N_AX88772 , ""   },
  { 0x05ac, 0x1402, N_AX88772 , ""   },
  { 0x9710, 0x7830, N_MCS7830 , ""   },
  { 0x0424, 0x9500, N_SMSC95XX, ""   },
  { 0x0424, 0xec00, N_SMSC95XX, ""   },
  { 0x0424, 0x9730, N_SMSC95XX, ""   },
  { 0x0424, 0x7500, N_SMSC75XX, ""   },
  { 0x0424, 0x7505, N_SMSC75XX, ""   },
  { 0x0424, 0x7800, N_SMSC78XX, ""   },

// AX88172 driver list - imported from NetBSD driver
 { 0x0b95, 0x1720, N_AX88172, ""     },
 { 0x07aa, 0x0017, N_AX88172, ""     },
 { 0x2001, 0x1a00, N_AX88172, ""     },
 { 0x077b, 0x2226, N_AX88172, ""     },
 { 0x0411, 0x003d, N_AX88172, ""     },
 { 0x0846, 0x1040, N_AX88172, ""     },
 { 0x6189, 0x182d, N_AX88172, ""     },
 { 0x086e, 0x1920, N_AX88172, ""     },

// Pegasus device list - imported from NetBSD driver
 { 0x0506, 0x4601, N_PEGASUS, "PII"  },
 { 0x07b8, 0x110c, N_PEGASUS, "PNA,PII" },
 { 0x07b8, 0x200c, N_PEGASUS, "PII"  },
 { 0x07b8, 0x4002, N_PEGASUS, "LSYS" },
 { 0x07b8, 0x4004, N_PEGASUS, "PNA"  },
 { 0x07b8, 0x4007, N_PEGASUS, "PNA"  },
 { 0x07b8, 0x400b, N_PEGASUS, "PII"  },
 { 0x07b8, 0x400c, N_PEGASUS, "PII"  },
 { 0x07b8, 0x4102, N_PEGASUS, "PII"  },
 { 0x07b8, 0x4104, N_PEGASUS, "PNA"  },
 { 0x07b8, 0xabc1, N_PEGASUS, ""     },
 { 0x07b8, 0x4003, N_PEGASUS, ""     },
 { 0x083a, 0x1046, N_PEGASUS, ""     },
 { 0x083a, 0x5046, N_PEGASUS, "PII"  },
 { 0x07a6, 0x0986, N_PEGASUS, "PNA"  },
 { 0x07a6, 0x8511, N_PEGASUS, "PII"  },
 { 0x07a6, 0x8513, N_PEGASUS, "PII"  },
 { 0x07a6, 0x8515, N_PEGASUS, "PII"  },
 { 0x3334, 0x1701, N_PEGASUS, "PII"  },
 { 0x050d, 0x0121, N_PEGASUS, "PII"  }, // Warning: vendor & product ID conflicts with Belkin Bluetooth adapter according to NetBSD source. But since we don't have a RISC OS bluetooth stack yet, I guess it's OK...
 { 0x08dd, 0x0986, N_PEGASUS, ""     },
 { 0x08dd, 0x0987, N_PEGASUS, "PNA"  },
 { 0x08dd, 0x0988, N_PEGASUS, ""     },
 { 0x08dd, 0x8511, N_PEGASUS, "PII"  },
 { 0x049f, 0x8511, N_PEGASUS, "PII"  },
 { 0x07aa, 0x0004, N_PEGASUS, ""     },
 { 0x07aa, 0x000d, N_PEGASUS, "PII"  },
 { 0x2001, 0x200c, N_PEGASUS, "LSYS,PII" },
 { 0x2001, 0x4001, N_PEGASUS, "LSYS" },
 { 0x2001, 0x4002, N_PEGASUS, "LSYS" },
 { 0x2001, 0x4003, N_PEGASUS, "PNA"  },
 { 0x2001, 0x400b, N_PEGASUS, "LSYS,PII" },
 { 0x2001, 0x4102, N_PEGASUS, "LSYS,PII" },
 { 0x2001, 0xabc1, N_PEGASUS, ""     },
 { 0x056e, 0x200c, N_PEGASUS, ""     },
 { 0x056e, 0x4002, N_PEGASUS, "LSYS" },
 { 0x056e, 0x400b, N_PEGASUS, ""     },
 { 0x056e, 0xabc1, N_PEGASUS, "LSYS" },
 { 0x056e, 0x4005, N_PEGASUS, "PII"  },
 { 0x05cc, 0x3000, N_PEGASUS, ""     },
 { 0x0e66, 0x400c, N_PEGASUS, "PII"  },
 { 0x0340, 0x811c, N_PEGASUS, "PII"  },
 { 0x04bb, 0x0904, N_PEGASUS, ""     },
 { 0x04bb, 0x0913, N_PEGASUS, "PII"  },
 { 0x0951, 0x000a, N_PEGASUS, ""     },
 { 0x066b, 0x200c, N_PEGASUS, "LSYS,PII" },
 { 0x066b, 0x2202, N_PEGASUS, "LSYS" },
 { 0x066b, 0x2203, N_PEGASUS, "LSYS" },
 { 0x066b, 0x2204, N_PEGASUS, "LSYS,PNA" },
 { 0x066b, 0x2206, N_PEGASUS, "LSYS" },
 { 0x066b, 0x400b, N_PEGASUS, "LSYS,PII" },
 { 0x0411, 0x0001, N_PEGASUS, ""     },
 { 0x0411, 0x0005, N_PEGASUS, ""     },
 { 0x0411, 0x0009, N_PEGASUS, "PII"  },
 { 0x045e, 0x007a, N_PEGASUS, "PII"  },
 { 0x0846, 0x1020, N_PEGASUS, "PII"  },
 { 0x067c, 0x1001, N_PEGASUS, "PII"  },
 { 0x08d1, 0x0003, N_PEGASUS, "PII"  },
 { 0x0707, 0x0200, N_PEGASUS, ""     },
 { 0x0707, 0x0201, N_PEGASUS, "PII"  },
 { 0x15e8, 0x9100, N_PEGASUS, ""     },
};

bool products_match(const USBServiceCall* device,
                    const char**          backend_name,
                    const char**          options)
{
  const uint16_t vendor = device->ddesc.idVendor;
  const uint16_t product =  device->ddesc.idProduct;

  static char blk[256];
  snprintf(blk, sizeof(blk), "EtherUSB$Product_%04hX_%04hX",vendor,product);

  const char* o = getenv(blk);
  if (o)
  {
    if (strlen(o)+1>=sizeof(blk))
    {
      syslog("Product/Vendor override too long");
      return false;
    }

    strcpy(blk, o);
    *backend_name = o;
    char* s = strchr(o, ':');
    if (s)
    {
      *s++=0;
      *options = s;
    }
    else
    {
      *options = "";
    }
    return true;
  }

  for (size_t i=0, e=sizeof(s_products)/sizeof(product_t); i!=e; ++i)
  {
    if (vendor==s_products[i].vendor &&
        product==s_products[i].product)
    {
      *backend_name = s_products[i].backend_name;
      *options = s_products[i].options;
      return true;
    }
  }

  return false;
}

_kernel_oserror* products_list(void)
{
  static const char *underline = "--------------------------------";
  char blk[256];
  char fmt[64];
  int  hdrvid_sz, hdrpid_sz, hdrbkend_sz, hdropts_sz;
#define hdrvid   &blk[0x00]
#define hdrpid   &blk[0x40]
#define hdrbkend &blk[0x80]
#define hdropts  &blk[0xC0]

  // Build a formatter for the product listing
  strcpy(hdrvid, msg_translate("HV"));   hdrvid_sz = MAX(strlen(hdrvid), 4);
  strcpy(hdrpid, msg_translate("HP"));   hdrpid_sz = MAX(strlen(hdrpid), 4);
  strcpy(hdrbkend, msg_translate("HB")); hdrbkend_sz = MAX(strlen(hdrbkend), 8);
  strcpy(hdropts, msg_translate("HO"));  hdropts_sz = strlen(underline);
  sprintf(fmt, "%%c %%-%u.%us%%-%u.%us%%-%u.%us%%-.%us\n",
               hdrvid_sz + 1, hdrvid_sz,
               hdrpid_sz + 1, hdrpid_sz,
               hdrbkend_sz + 1, hdrbkend_sz,
               hdropts_sz);

  // Heading
  printf(fmt, '*', hdrvid,    hdrpid,    hdrbkend,  hdropts);
  printf(fmt, '-', underline, underline, underline, underline);

  for (size_t i=0, e=sizeof(s_products)/sizeof(product_t); i!=e; ++i)
  {
    char pid[6], vid[6];

    snprintf(blk, sizeof(blk), "EtherUSB$Product_%04hX_%04hX",
             s_products[i].vendor,
             s_products[i].product);
    snprintf(vid, sizeof(vid), "%04hX", s_products[i].vendor);
    snprintf(pid, sizeof(pid), "%04hX", s_products[i].product);
    printf(fmt,
           getenv(blk) ? '-' : ' ', vid, pid,
           s_products[i].backend_name,
           s_products[i].options);
  }

  const char* name = NULL;
  while (true)
  {
    size_t size = 0;
    _kernel_oserror *e = _swix(OS_ReadVarVal, _INR(0,4)|_OUTR(2,3),
                               "EtherUSB$Product_*_*",
                               blk, sizeof(blk)-1, name, VarType_Expanded,
                               &size, &name);

    if (e) return e->errnum==ErrorNumber_VarCantFind ? NULL : e;

    if (strlen(name)==26) // strlen("EtherUSB$Product_9999_9999")
    {

      const char* vendor = strchr(name,'_');
      if (vendor)
      {
        ++vendor;
        const char* product = strchr(vendor,'_');
        if (product && product==vendor+4)
        {
           ++product;
           blk[size] = 0;
           char* options = strchr(blk, ':');
           if (options) *options++=0; else options = "";

           printf(fmt,
                  '+', vendor, product,
                  size==0 ? msg_translate("Ign") : blk,
                  options);
        }
      }
    }
  }
  return NULL;
}

