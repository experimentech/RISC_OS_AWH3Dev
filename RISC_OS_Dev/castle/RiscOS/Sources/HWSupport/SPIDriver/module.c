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
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

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

void *module_wsp;
void (*irqtrigger)(void);
void (*DMBwrite)(void);
static int msg_struct[4];
static _kernel_oserror msg_buff;
/* anchor for linked list of devices */
spi_devicelist * spidevbase = NULL;

const char *module_lookup(const char *token)
{
    if (_swix(MessageTrans_Lookup, _INR(0,7),
              msg_struct, token, &msg_buff, sizeof(msg_buff), 0, 0, 0, 0) != NULL)
    {
        return "";
    }
    return (const char *)&msg_buff;
}

_kernel_oserror *module_error(unsigned err)
{
    char token[12];
    _kernel_oserror *e;

    if (err > 256) return (_kernel_oserror *) err;

    sprintf(token, "@@@@E%02x", err);
    e = _swix(MessageTrans_ErrorLookup, _INR(0,3),
              token, msg_struct, &msg_buff, sizeof(msg_buff));
    if (e->errnum == 0x40404040)
    {
        /* Same error number out as went in, looked up OK */
        msg_buff.errnum = SPI_ErrorBase + err;
    }
    return e;
}

_kernel_oserror *module_initialise(const char *cmd_tail, int podule_base, void *pw)
{
    (void) cmd_tail;
    (void) podule_base;
    _kernel_oserror *err = NULL;
    int count;
    void *haldevice;
    uint32_t flags;
    spi_devicelist *this,*thisnext;
    
    module_wsp = pw;
    debug_initialise ("SPIDriver", "", 0);
    debug_set_device(DADEBUG_OUTPUT);
    debug_set_unbuffered_files (TRUE);
    debug_set_stamp_debug (TRUE);

#ifndef ROM
    err = _swix(ResourceFS_RegisterFiles, _IN(0), Resources());
    if (err != NULL) goto failinit;
#endif
    err = _swix(MessageTrans_OpenFile, _INR(0,2), msg_struct, Module_MessagesFile, 0);
    if (err != NULL) goto faildereg;

    callx_init(pw);

    if(!_swix(OS_PlatformFeatures,_IN(0)|_OUTR(0,1),0,&flags,&irqtrigger))
    {
      if(!(flags & 2))
        irqtrigger = NULL;
    }

//    _swix(OS_ServiceCall, _IN(1), Service_SCSIStarting);
    /* try to find any HAL SPI devices */
    count = 0;
    while (count != -1 )
    {
    _swix(OS_Hardware, _INR(0,1) | _IN(8) | _OUTR(1,2),   
           HALDeviceType_Comms + HALDeviceComms_SPI + (0<<16), 
           count,                                         
           4,                                             
           &count,                                        
           &haldevice);
   
           if(count != -1)
             {
               /* claim a spidev_list structure */
               if(this=malloc(sizeof(struct spi_devicelist)),this)
               {
                 if(spidevbase)
                   {
                     thisnext=spidevbase;
                     while(thisnext->next)
                     {
                       thisnext=thisnext->next;
                     }
                     thisnext->next = this;
                   }
                 else
                   {
                     thisnext=spidevbase;
                     spidevbase=this;
                   }
                 this->next = NULL;
                 this->spidev = haldevice;
                 this->spidev->dev.Activate(&(this->spidev->dev));
                 // now record the capabilities
                 this->spidev->hal_cap(&(this->spidev->dev),
                                        (void*)&(this->cap));
               }
                     
dprintf("device found: @ count %x haldevice %p &haldevice %p\n",count,haldevice,&haldevice);
dprintf("baseaddptr: %p struct %p %s next %p\n",&spidevbase,this,this->spidev->dev.description,this->next);
                  
               }
//    _swix(0x531c3,_IN(0),"$.tsst");           
    }
    // get our DMB write routine address
    asm_DMBInit(&DMBwrite);
    return NULL;

faildereg:
#ifndef ROM
    _swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
failinit:
#endif
    return err;
}

_kernel_oserror *module_finalise(int fatal, int podule, void *pw)
{
    (void) fatal;
    (void) podule;
    (void) pw;
    spi_devicelist * this=spidevbase, *next;



    callx_remove_all_callbacks();
    callx_remove_all_callafters();
    callx_remove_all_calleverys();

    /* Tidy up the messages (and deregister from ResourceFS if not in ROM) */
    _swix(MessageTrans_CloseFile, _IN(0), msg_struct);
#ifndef ROM
    _swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
#endif

/* remove any spidevice structures found */
if(this)
  {
    next = this->next;
    this->spidev->dev.Deactivate(&(this->spidev->dev));
    free(this);
    this = next;
  }

  
  
    
    return NULL;
}

void module_service_handler(int service_number, _kernel_swi_regs *r, void *pw)
{
    (void) pw;
#ifndef ROM
    if (service_number == Service_ResourceFSStarting)
    {
        /* Reregister our resources */
        (*(void (*)(void *, void *, void *, void *))r->r[2])(Resources(), 0, 0, (void *)r->r[3]);
    }
#else
    (void) service_number;
    (void) r;
#endif
}

_kernel_oserror *SPI_Version(_kernel_swi_regs *r, void *pw)
{
    (void) pw;
    r->r[0] = 0;
    return (NULL); 
}
_kernel_oserror *module_swi_handler(int swi_offset, _kernel_swi_regs *r, void *pw)
{
    (void) pw;

    switch (swi_offset)
    {
        case SPID_Version - SPID_00:
            return SPI_Version(r,pw);
        case SPID_Initialise - SPID_00:
            return SPI_Initialise(r,pw);
        case SPID_Control - SPID_00:
            return SPI_Control(r,pw);
        case SPID_Transfer - SPID_00:
            return SPI_Transfer(r,pw);
        case SPID_Status - SPID_00:
            return SPI_Status(r,pw);
//        case SPID_Deregister - SPID_00:
//            return SPI_Deregister(r,pw);
//        case SPID_Register - SPID_00:
//            return SPI_Register(r,pw);
    }
    return module_error(SPI_SWIunkn);
}

_kernel_oserror *module_cmd_handler(const char *arg_string, int argc, int cmd_no, void *pw)
{
    (void) arg_string;
    (void) argc;
    (void) cmd_no;
    (void) pw;
    switch(cmd_no)
    {
    case CMD_SPIDevices:
      return CommandDevices();
    }
    
    /* Only *Devices */



    return module_error(SPI_UnKnCmd);
}

