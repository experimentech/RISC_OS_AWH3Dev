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
/*  Amended JWB 17/5/2005 to build with current NetBSD usbdevs.h   */
/*                  */
#include <stddef.h>
#include <stdio.h>
#include "dev/usb/usbdevs.h"

struct usb_vendor {
	unsigned int	vendor;
	char		*vendorname;
};
struct usb_product {
	unsigned int	vendor;
        unsigned int    product;
	char		*productname;
};
#define	USB_KNOWNDEV_NOPROD	0x01		/* match on vendor only */

#include "dev/usb/usbdevs_data.h"

int main (void)
{
    const struct usb_vendor *kdv;
    const struct usb_product *kdp;
    int i=0;
    puts ("# USB Vendors\n");
    for (kdv = usb_vendors; i++  <usb_nvendors ; ++kdv)
    {
            printf ("V%04X:%s\n", kdv->vendor, kdv->vendorname);
    }
    
    puts ("\n# USB Products\n");
    for (kdp = usb_products, i = 0; i++ < usb_nproducts ; ++kdp)
    {
            printf ("P%04X%04X:%s\n", kdp->vendor, kdp->product,
                kdp->productname);
    }

    return 0;
}

