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
/*****************************************************************************
* $Id: module,v 1.16 2016-03-10 18:32:10 rsprowson Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): 
*
* ----------------------------------------------------------------------------
* Purpose: Main relocatable module entry points
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include "kernel.h"
#include "swis.h"

#include "Global/Services.h"
#include "Global/RISCOS.h"
#include "Interface/SCSIErr.h"
#include "Interface/RTSupport.h"
#include "DebugLib/DebugLib.h"
#include "USB/USBDevFS.h"

#include "global.h"
#include "glue.h"                           
#include "modhdr.h"
#include "resmess.h"


/*****************************************************************************
* MACROS
*****************************************************************************/


/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/


/*****************************************************************************
* File scope Global variables
*****************************************************************************/
static bool Registering;
static bool No_New_Stuff;
/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/
static uint32_t RegisterSCSIDevice(void *device);
//static void DeregisterSCSIDevice(void *device, uint32_t scsi_driver_handle);
static _kernel_oserror *SearchForDevices(void);
static _kernel_oserror *CheckConnectedDevice(const USBServiceCall *service_call_block);
static _kernel_oserror *CheckDisconnectedDevice(const char *device_name);
static _kernel_oserror *RemoveAllDevices(void);

/*****************************************************************************
* Functions
*****************************************************************************/

/*****************************************************************************
* module_Init
*
* Initialisation code
*
* Assumptions
*  NONE
*
* Inputs
*  cmd_tail:    points to the string of arguments with which the module is invoked
*               (may be "", and is control-terminated, not zero terminated)
*  podule_base: 0              => first invocation, not from a podule
*               1 - 0x02FFFFFF => reincarnation number
*               >0x03000000    => first invocation, from a podule based at this address
*  pw:          the 'R12' value established by module initialisation
*
* Outputs
*  NONE
*
* Returns
*  NULL if initialisation succeeds; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_Init(const char *cmd_tail, int podule_base, void *pw)
{
  _kernel_oserror *e = NULL;
#ifdef STANDALONE
  bool FileRegistered = false;
#endif
  bool MessagesOpen = false;
  bool OnUpCallV = false;
  bool CallbackSet = false;
  No_New_Stuff = false;
  IGNORE(cmd_tail);
  IGNORE(podule_base);

  Registering = false;
  
  debug_initialise("SCSISoftUSB", "null:", 0);
//  debug_set_taskname_prefix(true);
//  debug_set_area_level_prefix(true);
//  debug_set_area_pad_limit(0);
    debug_set_unbuffered_files (TRUE);
//    debug_set_stamp_debug (TRUE);
    debug_set_device(    DADEBUG_OUTPUT);
//    debug_set_device(    PRINTF_OUTPUT);
//  debug_set_raw_device(  DEBUGIT_OUTPUT);
//  debug_set_trace_device(DEBUGIT_OUTPUT);
//  debug_set_device(NULL_OUTPUT);
//  debug_set_raw_device(NULL_OUTPUT);
//  debug_set_trace_device(NULL_OUTPUT);
  
  global_PrivateWord = pw;
  
  if (!e)
  {
#ifdef STANDALONE
    e = _swix(ResourceFS_RegisterFiles, _IN(0),
              resmess_ResourcesFiles());
  }
  if (!e)
  {
    FileRegistered = true;
#endif
    
    e = _swix(MessageTrans_OpenFile, _INR(0,2),
              &global_MessageFD,
              Module_MessagesFile,
              0);
  }
  if (!e)
  {
    MessagesOpen = true;
  }
  if (!e)
  {
    
    e = _swix(OS_Claim, _INR(0,2),
              UpCallV,
              module_upcallv_handler,
              global_PrivateWord);
  }
  if (!e)
  {
    OnUpCallV = true;
    
    e = _swix(OS_AddCallBack, _INR(0,1),
              module_callback_from_init,
              global_PrivateWord);
  }
  if (!e)
  {
    CallbackSet = true;

    /* Detection of RTSupport module
       We require at least version 0.05, because previous versions had some rather nasty bugs that are too much hassle to work around for the benefit of the two people who have old versions of RTSupport on their machine and are unable to upgrade to newer versions */
    char **mod_code;
    if(!_swix(OS_Module,_INR(0,1) | _OUT(3),18,"RTSupport",&mod_code))
    {
      /* Find and decode version number, similar to RMEnsure.
         We really need a SWI for this! */
      char *help_str = mod_code[5]+(uint32_t)mod_code;
      while(*help_str && !isdigit(*help_str))
        help_str++;
      int version=0;
      while(isdigit(*help_str))
      {
        version = (version<<4) | (*help_str-'0');
        help_str++;
      }
      int zeros=4;
      if(*help_str == '.')
      {
        help_str++;
        while(isdigit(*help_str) && zeros)
        {
          version = (version<<4) | (*help_str-'0');
          help_str++;
          zeros--;
        }
      }
      version = version<<(zeros*4);
      if(version >= 0x0500)
      {
        global_UseRTSupport = true;
      }
    }
    if(!global_UseRTSupport)
      global_RTSupportPollword = 1; /* Force pollword nonzero so we avoid pointless calls to glue_BufferThreshouldCheck */
    
  }
  if (e && CallbackSet) _swix(OS_RemoveCallBack, _INR(0,1),
                              module_callback_from_init,
                              global_PrivateWord);
  if (e && OnUpCallV) _swix(OS_Release, _INR(0,2),
                            UpCallV,
                            module_upcallv_handler,
                            global_PrivateWord);
  if (e) RemoveAllDevices();
  if (e && MessagesOpen) _swix(MessageTrans_CloseFile, _IN(0),
                               &global_MessageFD);
#ifdef STANDALONE
  if (e && FileRegistered) _swix(ResourceFS_DeregisterFiles, _IN(0),
                                 resmess_ResourcesFiles());
#endif
  return e;
}

/*****************************************************************************
* module_CallbackFromInit
*
* Callback handler for callback set in module initialisation
*
* Assumptions
*  NONE
*
* Inputs
*  r:          register block
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_CallbackFromInit(_kernel_swi_regs *r, void *pw)
{
  IGNORE(r);
  IGNORE(pw);
  /* lets see what is there .. */
  if(!No_New_Stuff)SearchForDevices();
  return NULL;
}

/*****************************************************************************
* module_Final
*
* Finalisation code
*
* Assumptions
*  NONE
*
* Inputs
*  fatal, podule, pw: the values of R10, R11 and R12 (respectively) on entry
*                     to the finalisation code
*
* Outputs
*  NONE
*
* Returns
*  NULL if finalisation succeeds; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_Final(int fatal, int podule, void *pw)
{
  IGNORE(fatal);
  IGNORE(podule);
  IGNORE(pw);
  /* For safety, ensure we're no longer on TickerV */
  _kernel_irqs_off();
  No_New_Stuff=true;

  RemoveAllDevices();
  _swix(OS_RemoveTickerEvent, _INR(0,1),
        module_scsiregister_handler,
        global_PrivateWord);
  _swix(OS_RemoveCallBack, _INR(0,1),
        module_scsiregister_cb_handler,
        global_PrivateWord);
  _swix(OS_RemoveCallBack, _INR(0,1),
        module_callback_from_init,
        global_PrivateWord);
  global_TickerList=NULL;
  if(global_CallbackType == callback_TickerV)
    _swix(OS_Release, _INR(0,2),
          TickerV,
          module_tickerv_handler,
          global_PrivateWord);
  else if(global_CallbackType == callback_RTSupport)
    _swix(RT_Deregister, _INR(0,1),
          0,
          global_RTSupportHandle);
  _swix(OS_Release, _INR(0,2),
        UpCallV,
        module_upcallv_handler,
        global_PrivateWord);
  _swix(MessageTrans_CloseFile, _IN(0),
        &global_MessageFD);
#ifdef STANDALONE
  _swix(ResourceFS_DeregisterFiles, _IN(0),
        resmess_ResourcesFiles());
#endif
  _kernel_irqs_on();
  return NULL;
}

/*****************************************************************************
* module_Service
*
* Service call handler
*
* Assumptions
*  NONE
*
* Inputs
*  service_number: service call number
*  r:              pointer to registers on entry
*  pw:             the 'R12' value
*
* Outputs
*  r:              updated or not, as appropriate
*
* Returns
*  NOTHING
*****************************************************************************/
void module_Service(int service_number, _kernel_swi_regs *r, void *pw)
{
  IGNORE(pw);
  if (No_New_Stuff)return;
  switch (service_number)
  {
    case Service_MessageFileClosed:
      /* We might want to use our message file descriptor from the background, */
      /* so re-open message file now, when filing system re-entrancy isn't an issue */
      _swix(MessageTrans_OpenFile, _INR(0,2),
            &global_MessageFD,
            Module_MessagesFile,
            0);
      break;
      
    case Service_ModulePostInit:
      if (strcmp((const char *)r->r[2], "SCSIDriver") == 0)
      {
        _swix(OS_RemoveTickerEvent, _INR(0,1),
           module_scsiregister_handler,
           global_PrivateWord);
        for (my_usb_device_t *device = global_DeviceList; device != NULL; device = device->next)
        {
          device->registered = false;
        }
        _swix(OS_CallAfter, _INR(0,2),
           1, /* No point using a long delay if SCSIDriver has only just started */
           module_scsiregister_handler,
           global_PrivateWord);

      }
      break;
      
    case Service_PreReset:
      No_New_Stuff=true;
      break;
      
    case Service_USB:
      switch (r->r[0])
      {
        case Service_USB_Attach:
          CheckConnectedDevice((const USBServiceCall *)r->r[2]);
          break;
          
        case Service_USB_USBDriverStarting:
          /* SearchForDevices(); unnecessary */
          break;
          
        case Service_USB_USBDriverDying:
          /* RemoveAllDevices(); unnecessary */
          break;
      }
      break;
      
    case Service_DeviceDead:
    {
      const char *devicename = (const char *)r->r[3];
      if (devicename && devicename[0]=='U' && devicename[1]=='S' && devicename[2]=='B')
      {
        CheckDisconnectedDevice(devicename);
      }
      break;
    }
      
    default:
      assert(false /* unserviced service call */);
      break;
  }
  return;
}

/*  module_SCSIRegister
 *  register any unregistered devices on the list from a callback
 */ 
_kernel_oserror *module_SCSIRegister(_kernel_swi_regs *r, void *pw)
{
  IGNORE(r);                         
  IGNORE(pw);
  if(Registering)   /* come back later for another pass */
  {
    _swix(OS_CallAfter, _INR(0,2),
          10,
          module_scsiregister_handler,
          global_PrivateWord);
    return NULL;
  }
  /* Instead of registering the devices directly from this ticker event, register them from a callback. This ensures SCSIDriver's malloc()s can enlarge the RMA if needed. */
  Registering = true;
  _swix(OS_AddCallBack, _INR(0,1),
        module_scsiregister_cb_handler,
        global_PrivateWord);
  return NULL;
}

/*  module_SCSIRegister_cb
 *  register any unregistered devices on the list from a callback
 */ 
_kernel_oserror *module_SCSIRegister_cb(_kernel_swi_regs *r, void *pw)
{
  IGNORE(r);                         
  IGNORE(pw);
  for (my_usb_device_t *device = global_DeviceList; device != NULL; device = device->next)
  {
    if(!device->registered)
    {
      dprintf(("","Registering scsi device for %x \n",device));
      device->scsi_driver_handle =RegisterSCSIDevice(device);
      device->registered = true;
    }  
  }
  Registering = false;
  return NULL;
}


/*****************************************************************************
* module_Commands
*
* Command handler
*
* Assumptions
*  NONE
*
* Inputs
*  arg_string: command tail
*  argc:       number of parameters
*  cmd_no:     index into cmhg's list of commands
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_Commands(const char *arg_string, int argc, int cmd_no, void *pw)
{
  _kernel_oserror *e = NULL;
  IGNORE(arg_string);
  IGNORE(argc);
  IGNORE(pw);
  switch (cmd_no)
  {
    case CMD_SCSISoftUSB_PopUpDelay:
      if(argc)
      {
        uint32_t delay;
        /* Use something that will generate an error if the user got it wrong! */
        e = _swix(OS_ReadUnsigned,_INR(0,1)|_OUT(2),10,arg_string,&delay);
        if(e)
          return e;
        global_PopUpDelay = delay;
      }
      else
      {        
        const char *msg;
        e = _swix(MessageTrans_Lookup,_INR(0,2)|_OUT(2),&global_MessageFD,"CDELAY",NULL,&msg);
        if(e)
          return e;
        printf(msg,global_PopUpDelay,'\n'); /* What would be worse - using two fixed-size buffers to prepare the message string, or this atrocity? */
      }
      break;
  }
  return e;
}

/*****************************************************************************
* RegisterSCSIDevice
*
* Tries to register a device with SCSIDriver
*
* Assumptions
*  NONE
*
* Inputs
*  device: our private handle for this device
*
* Outputs
*  NONE
*
* Returns
*  the handle required to deregister the device (actually device/bus ID)
*****************************************************************************/
static uint32_t RegisterSCSIDevice(void *device)
{
  uint32_t scsi_driver_handle = -1; /* invalid value for error case */
  _swix(SCSI_Register, _INR(0,3)|_OUT(0),
        0, /* register device, not bus */
        module_scsi_handler,
        global_PrivateWord,
        device,
        &scsi_driver_handle);
  dprintf(("","Got scsi device handle %x \n",scsi_driver_handle));
  return scsi_driver_handle;
}

/*****************************************************************************
* DeregisterSCSIDevice
*
* Tries to deregister a device with SCSIDriver
*
* Assumptions
*  NONE
*
* Inputs
*  device:             our private handle for this device
*  scsi_driver_handle: SCSIDriver's handle for this device (actually device/bus ID)
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
static void DeregisterSCSIDevice(void *device, uint32_t scsi_driver_handle)
{
  dprintf(("","DeRegister scsi handle %x \n",scsi_driver_handle));
  _swix(SCSI_Deregister, _INR(0,3),
        scsi_driver_handle,
        module_scsi_handler,
        global_PrivateWord,
        device);
  return;
}

/*****************************************************************************
* SearchForDevices
*
* Scans the USB buses for devices of mass storage class and SCSI sub-class,
* creates devices for them on our fake SCSI bus, and informs SCSIDriver
*
* Assumptions
*  NONE
*
* Inputs
*  NONE
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *SearchForDevices(void)
{
  USBServiceAnswer *item;
  RETURN_ERROR(_swix(OS_ServiceCall, _INR(0,2)|_OUT(2),
                     Service_USB_Connected,
                     Service_USB,
                     NULL,
                     &item));
  _kernel_oserror *e = NULL;
  while (item)
  {
    if (!e) e = CheckConnectedDevice(&item->svc);
    USBServiceAnswer *nextitem = item->link;
    free(item);
    item = nextitem;
  }
  return e;
}

/*****************************************************************************
* CheckConnectedDevice
*
* Vets a device for being of mass storage class and SCSI sub-class,
* and if so, creates a device for it on our fake SCSI bus, and informs SCSIDriver
*
* Assumptions
*  NONE
*
* Inputs
*  NONE
*
* Outputs
*  NONE
*
* Returns
*  NULL 
*****************************************************************************/
static _kernel_oserror *CheckConnectedDevice(const USBServiceCall *service_call_block)
{
  const char *ptr = (const char *) &service_call_block->ddesc;
  uint32_t bytes_left = service_call_block->sclen - (size_t) &((USBServiceCall *)0)->ddesc;
  uint32_t bytes_in_this_descriptor;
  uint16_t vendor = 0;
  uint16_t product = 0;
  while (bytes_left >= 2 &&
         (bytes_in_this_descriptor = ((usb_descriptor_t *)ptr)->bLength) != 0 &&
         bytes_left >= bytes_in_this_descriptor)
  {
    if (((usb_descriptor_t *)ptr)->bDescriptorType == UDESC_DEVICE)
    {
      const usb_device_descriptor_t *device = (const usb_device_descriptor_t *) ptr;
      vendor = device->idVendor;
      product = device->idProduct;
    }
    else if (((usb_descriptor_t *)ptr)->bDescriptorType == UDESC_INTERFACE)
    {
      const usb_interface_descriptor_t *interface = (const usb_interface_descriptor_t *) ptr;
      if (interface->bInterfaceClass == 8          /* mass storage class */
#ifdef LIMITED_SCOPE      
      && (interface->bInterfaceSubClass == 6        /* SCSI  */
          || interface->bInterfaceSubClass == 5     /* floppy */
         ) 
      && (interface->bInterfaceProtocol == 0       /* control/bulk/interrupt with command completion interrupt */
          || interface->bInterfaceProtocol == 1    /* control/bulk/interrupt without command completion interrupt  */
          || interface->bInterfaceProtocol == 0x50 /* bulk-only */
          )
#endif
         )
      {
        my_usb_device_t *device = (my_usb_device_t *)((char *) calloc(1, sizeof *device) - 4);
        if (device != NULL)
        {
          device->interface = interface->bInterfaceNumber;
          device->alternate = interface->bAlternateSetting;
          device->subclass = interface->bInterfaceSubClass;
          device->protocol = interface->bInterfaceProtocol;
          device->bulk_in_endpoint = 0xFF;
          device->bulk_out_endpoint = 0xFF;
          device->interrupt_endpoint = 0xFF;
          device->vendor = vendor;
          device->product = product;
          strcpy(device->devicefs_name, service_call_block->devname);
          ptr += bytes_in_this_descriptor;
          bytes_left -= bytes_in_this_descriptor;
          while (bytes_left >= 2 &&
                 (bytes_in_this_descriptor = ((usb_descriptor_t *)ptr)->bLength) != 0 &&
                 bytes_left >= bytes_in_this_descriptor &&
                 ((usb_descriptor_t *)ptr)->bDescriptorType >= UDESC_ENDPOINT)
          {
            if (((usb_descriptor_t *)ptr)->bDescriptorType == UDESC_ENDPOINT)
            {
              usb_endpoint_descriptor_t *endpoint = (usb_endpoint_descriptor_t *) ptr;
              if ((endpoint->bmAttributes & 3) == 2 /* bulk endpoint */)
              {
                if ((endpoint->bEndpointAddress & 0x80) != 0 /* in */)
                {
                  if (device->bulk_in_endpoint == 0xFF)
                  {
                    device->bulk_in_endpoint = endpoint->bEndpointAddress;
                    device->bulk_in_maxpacketsize = endpoint->wMaxPacketSize;
                  }
                }
                else /* out */
                {
                  if (device->bulk_out_endpoint == 0xFF)
                  {
                    device->bulk_out_endpoint = endpoint->bEndpointAddress;
                    device->bulk_out_maxpacketsize = endpoint->wMaxPacketSize;
                  }
                }
              }
              else if ((endpoint->bmAttributes & 3) == 3 /* interrupt endpoint */ &&
                       (endpoint->bEndpointAddress & 0x80) != 0 /* in */)
              {
                if (device->interrupt_endpoint == 0xFF)
                {
                  device->interrupt_endpoint = endpoint->bEndpointAddress;
                  device->interrupt_maxpacketsize = endpoint->wMaxPacketSize;
                }
              }
            }
            ptr += bytes_in_this_descriptor;
            bytes_left -= bytes_in_this_descriptor;
          }
          if (device->bulk_in_endpoint == 0xFF ||
              device->bulk_out_endpoint == 0xFF ||
             (device->interrupt_endpoint == 0xFF && interface->bInterfaceProtocol == 0))
          {
            /* Cannot find required endpoint(s) */
            free((char *)device + 4);
            return NULL;
          }
          else
          {
            if (glue_AttachDevice(device, &device->maxlun))
            {
              /* Add to end of device list, so we maintain the USB device number order */
              device->next = NULL;
              for (my_usb_device_t *prev = global_DeviceList; true; prev = prev->next)
              {
                if (prev && !prev->next)
                {
                  prev->next = device;
                  break;
                }
                else if (!prev)
                {
                  global_DeviceList = device;
                  break;
                }
              }
//              glue_ResetDevice(device, 0);
              _swix(OS_RemoveTickerEvent, _INR(0,1),
                    module_scsiregister_handler,
                    global_PrivateWord);
              device->registered = false;
              char *state = getenv("Wimp$State");
              uint32_t delay = global_PopUpDelay;
              if(!delay || !state || strcmp(state,"desktop"))
                 delay = 1; /* Use shortest possible delay when outside the desktop (or if user specified delay of 0!) */
              _swix(OS_CallAfter, _INR(0,2),
                    delay,
                    module_scsiregister_handler,
                    global_PrivateWord);
            }
            else
            {
              /* Error during attach */
              free((char *)device + 4);
            }
            return NULL;
          }
        }
        else
        {
          /* Memory allocation error */
          return NULL;
        }
      }
    }
    ptr += bytes_in_this_descriptor;
    bytes_left -= bytes_in_this_descriptor;
  }
  return NULL; /* not a mass storage device (that we understand) */
}

/*****************************************************************************
* CheckDisconnectedDevice
*
* Vets a device for being one we were using, and if so marks our fake device
* as removed, and informs SCSIDriver
*
* Assumptions
*  NONE
*
* Inputs
*  NONE
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *CheckDisconnectedDevice(const char *device_name)
{
  my_usb_device_t *prev = NULL;
  my_usb_device_t *next;
  for (my_usb_device_t *device = global_DeviceList; device != NULL; device = next)
  {
    next = device->next;
    if (strcmp(device->devicefs_name, device_name) == 0)
    {
      device->dying = true; /* no more commands can be started */
      glue_DetachDevice(device);
      DeregisterSCSIDevice(device, device->scsi_driver_handle);
      if (prev == NULL)
      {
        global_DeviceList = next;
      }
      else
      {
        prev->next = next;
      }
      free((char *)device + 4);
    }
    else
    {
      prev = device;
    }
  }
  return NULL;
}

/*****************************************************************************
* RemoveAllDevices
*
* Marks all our fake device as removed, and informs SCSIDriver
*
* Assumptions
*  NONE
*
* Inputs
*  NONE
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *RemoveAllDevices(void)
{
  for (my_usb_device_t *device = global_DeviceList; device != NULL; device = global_DeviceList)
  {
    
    device->dying = true;
    glue_DetachDevice(device);
    DeregisterSCSIDevice(device, device->scsi_driver_handle);
    global_DeviceList = device->next;
    char buf[32]; /* *USBReset + sizeof(my_usb_device.devicefs_name) */
    char *p=device->devicefs_name;
    int i;
    for(i=0;i<32;i++)
    {
      if(isalpha(*p))
      {
        buf[i]=*(p++);
      }
      else
      {
        buf[i] = 0;
        break;
      }
    }
    strcat(buf,"Reset ");strcat(buf,p);
    dprintf(("",buf));
    _kernel_oscli(buf);
    free((char *)device + 4);
  }
  return NULL;
}

/*****************************************************************************
* module_SCSIHandler
*
* Entry point from SCSIDriver module
*
* Assumptions
*  NONE
*
* Inputs
*  r:          register block (cmhg actually provides r0-r11)
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block (or SCSI error number)
*****************************************************************************/
_kernel_oserror *module_SCSIHandler(_kernel_swi_regs *r, void *pw)
{
  _kernel_oserror *e = NULL;
  IGNORE(pw);
  switch ( ((int *)r)[11] )
  {
    case 0: /* Features */
      r->r[1] = (1<<1) | (1<<5); /* supports background ops and scatter lists */
      break;
      
    case 1: /* Reset bus */
      e = (_kernel_oserror *)(ErrorNumber_SCSI_SWIunkn & 0xFF); /* shouldn't happen */
      break;
      
    case 2: /* Reset device */
    case 3: /* Abort */
      glue_ResetDevice((my_usb_device_t *)r->r[8], 0);
      break;
      
    case 4: /* Foreground op */
      e = (_kernel_oserror *)(ErrorNumber_SCSI_SWIunkn & 0xFF); /* shouldn't happen */
      break;
      
    case 5: /* Background op */
    {
      my_usb_device_t *device = (my_usb_device_t *)r->r[8];
//      uint32_t lun = (r->r[0] >> 10) & 0x3F;
      uint32_t lun = (r->r[0] >> 5) & 0x7;
      if (lun > device->maxlun)
      {
        e = (_kernel_oserror *)(ErrorNumber_SCSI_NoDevice & 0xFF);
      }
      else
      {
        e = glue_DoCommand(device,
                           lun,
                           r->r[0] & (3 << 24),
                           (char *) r->r[2],
                           r->r[1],
                           (scatter_entry_t *) r->r[3],
                           r->r[4],
                           (void (*)(void)) r->r[6],
                           (void *) r->r[5],
                           (void *) r->r[7]);
        r->r[0] = -1; /* operation still in progress */
      }
      break;
    }
      
    case 6: /* Cancel background operation */
      glue_ResetDevice((my_usb_device_t *)r->r[8], r->r[0] & (1<<11) ? 0 : r->r[0] & (1<<12) ? 1 : 2);
      break;
      
    default: /* Unknown reason code */
      e = (_kernel_oserror *)(ErrorNumber_SCSI_SWIunkn & 0xFF);
      break;
  }
  return e;
}

/*****************************************************************************
* module_TickerVHandler
*
* TickerV/RTSupport handler and callback processor
*
* Assumptions
*  NONE
*
* Inputs
*  r:          register block
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL
*****************************************************************************/
_kernel_oserror *module_TickerVHandler(_kernel_swi_regs *r, void *pw)
{
  IGNORE(r);
  IGNORE(pw);
  static bool semaphore = false;
  if (semaphore)
    return NULL;
  semaphore = true;
  my_usb_device_t *device = global_TickerList;
  if(global_CallbackType == callback_RTSupport) /* If we're using TickerV, the RTSupport pollword is kept at 1 so we skip calling glue_BufferThresholdCheck */
    global_RTSupportPollword = 0;
  while (device != NULL)
  {
    my_usb_device_t *next = device->next_ticker; /* read now in case it delinks itself */
    glue_Tick(device);
    device = next;
  }
  semaphore = false;
  return NULL;
}
/*****************************************************************************
* module_UpCallVHandler
*
* UpCallV handler
*
* Assumptions
*  NONE
*
* Inputs
*  r:          register block
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL
*****************************************************************************/
_kernel_oserror *module_UpCallVHandler(_kernel_swi_regs *r, void *pw)
{
  IGNORE(pw);
  if (((r->r[0] == 8) || (r->r[0] == 9) /* Buffer filling/emptying */ ) && global_TickerList && !global_RTSupportPollword) glue_BufferThresholdCheck(r->r[1],r->r[0]==8);
  if (!No_New_Stuff && (r->r[0] == 11 /* stream closed */)) glue_ReopenStream(r->r[3]);
  return NULL;
}


/*****************************************************************************
* END OF FILE
*****************************************************************************/
