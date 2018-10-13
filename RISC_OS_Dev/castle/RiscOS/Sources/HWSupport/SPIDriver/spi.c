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
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>

#include "swis.h"

#include "debuglib/debuglib.h"
#include "callx/callx.h"
#include "Global/Services.h"
#include "Global/HALDevice.h"
#include "Interface/SPIDriver.h"

#include "header.h"
#include "spi.h"
#include "module.h"
#include "asm.h"



// Internally the device driver always runs SPI transfers as background tasks
// that perform a callback on completion/error. The 'foreground' transfers are
// achieved by setting up an internal background handler and looping in the
// foreground until the callback handler indicates completion by writing to
// a block allocated on the stack. The format of this block is:-
typedef struct CallBkRec
{   /* Keep in sync with 'asm_callbackhandler' */
    int r[5];
    int stat;
} CallBkRec;



//#define BCD(x) ((((x)/100)<<8) + (((x)/10%10)<<4) + ((x)%10))
//
//static void cleantext(char *text, size_t len)
//{
//    while (len)
//    {
//        int c = *text;
//        if (c < 32 || c == 127) *text = ' ';
//        text++;
//        len--;
//    }
//}


/* Handle the callback from the hardware driver */
static _kernel_oserror *driver_callback(_kernel_oserror *error, const _kernel_swi_regs *r)
{
  r=r;
  error=error;
    return NULL;
}

_kernel_oserror *driver_callback_handler(_kernel_swi_regs *r,void *pw)
{
    (void) pw;
    return driver_callback(NULL, r);
}

_kernel_oserror *driver_error_handler(_kernel_swi_regs *r,void *pw)
{
    (void) pw;
    return driver_callback(module_error(r->r[0]), r);
}

_kernel_oserror *SPI_Initialise(_kernel_swi_regs *r, void *pw)
{
  (void) pw;
  spi_devicelist *p = spidevbase;

  switch(r->r[0])
  {
    case SWII_ListDevices: /* return a spidevice_list* for devices owned */ 
       r->r[0] = (int)p;
      dprintf("SWIinitialise, return devlist pointer %x %x\n",(int)spidevbase,(int)p);
       return (NULL);
    case SWII_ReadCapabilities: /* Return a RMA spi_capabilities struct* */
                                /* r->r[0]for spidevice *(r->r[0]) or NULL  */
                                /* if none; ownership is passed to caller */
      dprintf("SWIinitialise, readcapabilities\n");
      while(p)
      {
        if(p->spidev==(spidevice*)r->r[1])
        {
//          struct spi_capabilities * spicap=NULL;
            
            dprintf("SWIinitialise, readcapabilities gave %x\n",(int)&(p->cap));
            r->r[0]= (int)&(p->cap);
            return NULL;
        }
        p=p->next;
      }
      break;
    case SWII_SetConfiguration:
      dprintf("SWIinitialise, setconfig device: %x buffer: %x\n",r->r[1],r->r[2]);
      while(p)
      {
        if(p->spidev==(spidevice*)r->r[1])
        {
            p->spidev->hal_config(&(p->spidev->dev),(spi_settings *)r->r[2]);
        }
        p=p->next;
      }
      


      
      break;
    // r1 -> device
    // r2 = reason code 
    //     0 = return r->r[0] = pointer to null terminated
    //         list of spi_pinmaplist structures
    //     1 = map pinspec in r3 to usage in r4 as
    //         bits7-4 = relevant chip select, 3-0 = bit significance
    //     2 = set pins to address in r4
    //     3 = clear all pinmapping    
    case SWII_PinMap:
     dprintf("SWIinitialise, PinMap device: %x reason: %d\n",r->r[1],r->r[2]);
      r->r[0] = 0;
      while(p)
      {
        if(p->spidev==(spidevice*)r->r[1])
        {
       dprintf(" Device found %x %x %x\n",r->r[2],r->r[3],r->r[4]); 
          r->r[0]=( p->spidev->hal_pinmap(&(p->spidev->dev),r->r[2], r->r[3], r->r[4]));
          dprintf("result %x\n",r->r[0]);
          return(NULL);
        }
        p=p->next;
      }
      break;      
  }
  return (NULL);
}
_kernel_oserror *SPI_Control(_kernel_swi_regs *r, void *pw)
{
    (void) pw;
    r->r[0] = 0;
    return (NULL); 
}


// Initiate a SPI transfer
// Transfer can be foreground or background, in which case
//  a routine will be called back on completion
// Routine is called with a pointer to a buffer containing
//  the bitstream to send to the device, and a pointer to a buffer
//  to receive the returned bitstream.
// On Entry:
//  r0 = spi_transfer pointer 
_kernel_oserror *SPI_Transfer(_kernel_swi_regs *r, void *pw)
{
    (void) pw;
    spi_devicelist *p = spidevbase;
      while(p)
      {
        if(p->spidev==((spi_transfer*)r->r[0])->spisettings->dev)
        {
          dprintf("start transfer to %x\n", ((spi_transfer*)r->r[0])->spisettings->channel) ;
          p->spidev->hal_transfer(&(p->spidev->dev),((spi_transfer*)r->r[0]));
          // check if dumb polled transfer is needed
          switch(((spi_transfer*)r->r[0])->dma_mode)
          {
            case 0: // polled data reansfer
            { // if here a polled data transfer in foreground is needed
              // compute burst length needed
              int wrcount = ((spi_transfer*)r->r[0])->burstlength;
              int tmp = p->cap.datawidth*8; // in bits
              int rdcount = wrcount / tmp;            
              if(wrcount%tmp) rdcount++;              
              wrcount = rdcount;
              unsigned * wrd =(unsigned *)((spi_transfer*)r->r[0])->wr_addr; 
              unsigned * rdd =(unsigned *)((spi_transfer*)r->r[0])->rd_addr;
              unsigned * wrbuf =(unsigned *)(p->cap.wrfifoaddr); 
              unsigned * rdbuf =(unsigned *)(p->cap.rdfifoaddr);
              volatile unsigned * wrp =(unsigned *)(p->cap.wrpolladdr); 
              volatile unsigned * rdp =(unsigned *)(p->cap.rdpolladdr);
              unsigned rpollmask = (unsigned)(p->cap.rdpollmask);
              unsigned wpollmask = (unsigned)(p->cap.wrpollmask);
              // should check polarity at this point ************ ignore for now
              
              // allow a max of 5 secs for this transfer
              int starttime,now=0;
              _swix(OS_ReadMonotonicTime,_OUT(0),&starttime);
              starttime+=((spi_transfer*)r->r[0])->timeout;
              while ((rdcount || wrcount) && (now<starttime))
              {
  //              unsigned flags;
                _swix(OS_ReadMonotonicTime,_OUT(0),&now);
                asm_ReadDMB();
                if(wrcount && (*wrp & wpollmask))
                {
                  *wrbuf = *wrd++;
                  wrcount--;
                  DMBwrite();
                }
                if(rdcount && (*rdp & rpollmask))
                {
                  *rdd++ = *rdbuf ;
                  rdcount--;
                }
              }
            }  
            break;
            case 1: // use dma foreground mode
              {
                
              }
              break;
            case 3: // use dma background mode
              {
                
              }
              break;
            default: break;
          } 
          break;
        }
        p=p->next;
      }
    r->r[0] = 0;
    return (NULL); 
}
_kernel_oserror *SPI_Status(_kernel_swi_regs *r, void *pw)
{
    (void) pw;
    r->r[0] = 0;
    return (NULL); 
}
_kernel_oserror *CommandDevices(void)
{
  spi_devicelist *p = spidevbase;
  
  printf("%s\n",module_lookup("I01"));
  while(p)
  {
  printf("%s at %p\n",p->spidev->dev.description, p->spidev->dev.address);
  p=p->next;
  }
  
    
    return (NULL); 
}

