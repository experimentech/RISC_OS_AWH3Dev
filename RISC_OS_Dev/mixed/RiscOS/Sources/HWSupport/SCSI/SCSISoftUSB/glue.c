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
* $Id: glue,v 1.14 2016-03-10 18:32:10 rsprowson Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): 
*
* ----------------------------------------------------------------------------
* Purpose: Glue between RISC OS world and BSD code
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdlib.h>
#include <stdio.h>
#include "swis.h"

#include "Global/NewErrors.h"
#include "Global/RISCOS.h"
#include "Interface/DeviceFS.h"
#include "Interface/SCSIErr.h"
#include "Interface/RTSupport.h"
#include "dev/usb/usb.h"
#include "dev/usb/usbdi.h"

#include "asm.h"
#include "global.h"
#include "glue.h"
#include "modhdr.h"
#include "umassvar.h"

#include "debug.h"


/*****************************************************************************
* MACROS
*****************************************************************************/

/* Some primitive debugging code to spit out characters via HAL_DebugTX */
#if 0
#define DEBUGCHAR(X) _swix(OS_Hardware,_IN(0)|_INR(8,9),X,0,86)
#else
#define DEBUGCHAR(X)
#endif

/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/
#define BUFFER_SIZE UMASS_MAX_TRANSFER_SIZE


/*****************************************************************************
* File scope Global variables
*****************************************************************************/
static void (*static_BufManRout)(void);
static void *static_BufManWS;


/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/
static void Callback(struct umass_softc *softc, void *void_device, int not_transferred, int status);
static void GetOnTickerV(my_usb_device_t *device);
static void GetOffTickerV(my_usb_device_t *device);
static void ProdRTSupport(void);


/*****************************************************************************
* Function prototypes - External but not defined in included headers
*****************************************************************************/
extern bool umass_attach_riscos(struct umass_softc *sc, struct usb_attach_arg *uaa, uByte InterfaceSubClass, uByte InterfaceProtocol);
extern void umass_detach(struct device *self, int flags);


/*****************************************************************************
* Functions masquerading as those inside the USB driver - already declared in dev/usb/usbdi.h
*****************************************************************************/
extern usbd_status usbd_do_request(usbd_device_handle pipe, usb_device_request_t *req, void *data);
extern usbd_status usbd_open_pipe(usbd_interface_handle iface, u_int8_t address, u_int8_t flags, usbd_pipe_handle *pipe);
extern usbd_status usbd_close_pipe(usbd_pipe_handle pipe);


/*****************************************************************************
* Function prototypes which umass.c thinks are private to itself but aren't really
*****************************************************************************/
extern usbd_status umass_setup_transfer(struct umass_softc *sc, usbd_pipe_handle pipeh, void *buffer, int buflen, int flags);
extern usbd_status umass_clear_endpoint_stall(struct umass_softc *sc, int endpt);


/*****************************************************************************
* Functions
*****************************************************************************/

/*****************************************************************************
* glue_AttachDevice
*
* Makes a mass storage USB interface ready for use.
*
* Assumptions
*  NONE
*
* Inputs
*  device: struct describing the interface to attach
*
* Outputs
*  maxlun: maximum USB logical unit number of device
*
* Returns
*  true if attached succesfully
*****************************************************************************/
bool glue_AttachDevice(my_usb_device_t *device, uint8_t *maxlun)
{
  DEBUGf("AttachDevice\n");
  struct umass_softc *softc = calloc(1, sizeof *softc);
  device->softc = softc;
  strcpy(softc->sc_dev.dv_xname, "USBMassStorage"Module_VersionString);
  softc->sc_dev.dv_cfdata = NULL; /* or something */
  softc->sc_epaddr[UMASS_BULKIN] = device->bulk_in_endpoint;
  softc->sc_epaddr[UMASS_BULKOUT] = device->bulk_out_endpoint;
  softc->sc_epaddr[UMASS_INTRIN] = device->interrupt_endpoint;
  softc->sc_maxpacket[UMASS_BULKIN] = device->bulk_in_maxpacketsize;
  softc->sc_maxpacket[UMASS_BULKOUT] = device->bulk_out_maxpacketsize;
  softc->sc_maxpacket[UMASS_INTRIN] = device->interrupt_maxpacketsize;
  /* claim packet buffers, since Glue_Tick may have trouble claimig them */
  softc->scbulkoutbuf=malloc(MAX(device->bulk_out_maxpacketsize,device->bulk_in_maxpacketsize));

  struct usb_attach_arg uaa;
  memset(&uaa, 0, sizeof uaa);
  uaa.ifaceno = device->interface;
  uaa.vendor = device->vendor;
  uaa.product = device->product;
  uaa.device = (usbd_device_handle) device;
  uaa.iface = (usbd_interface_handle) device;
  DEBUGf("using protocol %x\n,",device->protocol);
  
  bool result = umass_attach_riscos(softc, &uaa, device->subclass, device->protocol);
  
  *maxlun = softc->maxlun;
  DEBUGf("AttachDevice done\n");
  return result;
}

/*****************************************************************************
* glue_DetachDevice
*
* Closes down a mass storage USB interface.
*
* Assumptions
*  device is already delinked (so the stream closed service call won't re-open it)
*
* Inputs
*  device: struct describing the interface to detach
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
void glue_DetachDevice(my_usb_device_t *device)
{
  DEBUGf("DetachDevice\n");
  GetOffTickerV(device);
  struct umass_softc *softc = (struct umass_softc *)device->softc;
  if (device->command_active && softc->transfer_priv != NULL)
  {
    softc->transfer_priv = NULL; /* if we're interrupting ticker processing, no longer try to do a callback at end of ticker */
    DEBUGf("Calling SCSIDriver from DetachDevice\n");
    asm_DoTransferCompleteCallback((_kernel_oserror *)(ErrorNumber_SCSI_Died & 0xFF),
                                   0,
                                   device->callback,
                                   softc->transfer_datalen,
                                   device->callback_pw,
                                   device->callback_wp);
  }
  if(softc->scbulkoutbuf) free (softc->scbulkoutbuf);
  umass_detach((struct device *)softc, 0);
}

/*
void glue_ResetBus(my_usb_device_t *device)
{
  char cmd[sizeof "USBDReset xxx"] = "";
  if (strncmp(device->devicefs_name, "USBD", 4) == 0)
  {
    sprintf(cmd, "USBDReset %s", device->devicefs_name + 4);
  }
  else if (strncmp(device->devicefs_name, "USB", 3) == 0 && device->devicefs_name[3] >= '0' && device->devicefs_name[3] >= '9')
  {
    sprintf(cmd, "USBReset %s", device->devicefs_name + 3);
  }
  _swix(OS_CLI, _IN(0), cmd);
}
*/

/*****************************************************************************
* glue_ResetDevice
*
* Initiates a reset of a mass storage USB interface.
* Callback is called for any active command.
* Might someday return before the reset is complete.
*
* Assumptions
*  NONE
*
* Inputs
*  device: struct describing the interface to reset
*  reason: 0 => timeout, 1 => escape, 2 => aborted
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*
* 20050621 .. note many BBB mass storage devices do not appreciate
*             having UR_BBB_RESET issued to them. wire->methods->reset
*             (wire_bbb_reset) is now modified to omit the bulk reset
*             command and go straight to clr pipe stall stuff (riscos)
*              
*****************************************************************************/
void glue_ResetDevice(my_usb_device_t *device, int reason)
{
  DEBUGf("ResetDevice\n");
  if (device->dying) return;
  struct umass_softc *softc = (struct umass_softc *)device->softc;
  
  bool irqs_were_off = _kernel_irqs_disabled();
  if (!irqs_were_off) _kernel_irqs_off();
  if (!device->command_active)
  {
    softc->transfer_priv = NULL; /* definitely don't do a callback if we're not interrupting an ongoing operation */
  }                              /* (it may be null anyway, if ongoing operation was a reset too, has been detached, or hasn't initialised enough yet) */
  device->command_active = true; /* prevent any new commands from being started until we're done */
  device->ticker_semaphore = true; /* prevent TickerV from doing anything */
  if (!irqs_were_off) _kernel_irqs_on();
  device->background_transfer_active = false;
  
  softc->sc_methods->wire_reset(softc, STATUS_TIMED_OUT + reason, (usbd_status *)&device->status);
  while (softc->transfer_state != TSTATE_IDLE /* && !device->background_transfer_active *** reset doesn't start any of these */)
  {
    softc->sc_methods->wire_state(softc, 0 /* last xfer wasn't bulk */, (usbd_status *)&device->status);
  }
  
  if (!irqs_were_off) _kernel_irqs_off();
  /* Get off TickerV if necessary */
  GetOffTickerV(device);
  /* Ensure another command can be issued from within callback */
  device->command_active = false;
  device->ticker_semaphore = false;
  /* Do callback if necessary */
  if (softc->transfer_priv != NULL)
  {
    DEBUGf("Calling SCSIDriver from ResetDevice\n");
    asm_DoTransferCompleteCallback(device->callback_error,
                                   device->callback_status_byte,
                                   device->callback,
                                   device->callback_not_transferred,
                                   device->callback_pw,
                                   device->callback_wp);
  }
  if (!irqs_were_off) _kernel_irqs_on();
  return;
}

/*****************************************************************************
* glue_DoCommand
*
* Initiates a SCSI command addressed to a mass storage USB interface.
* Can return before the command is complete.
*
* Assumptions
*  NONE
*
* Inputs
*  device:               struct describing the interface to address
*  lun:                  logical unit number (at the USB transport layer) to address
*  direction:            direction code in bits 24/25, as for SCSI_Op
*  control_block:        pointer to SCSI control block
*  control_block_length: length of SCSI control block
*  scatter_list:         pointer to scatter list describing data
*  transfer_length:      total amount of data to transfer
*  callback:             address of callback routine
*  callback_pw:          R5 (private word) for callback
*  callback_wp:          R12 (workspace pointer) for callback
*
* Outputs
*  NONE
*
* Returns
*  RISC OS error pointer (eg if previous command is still active) or NULL
*****************************************************************************/
_kernel_oserror *glue_DoCommand(my_usb_device_t *device, uint32_t lun, uint32_t data_direction, const char *control_block, size_t control_block_length, scatter_entry_t *scatter_list, size_t transfer_length, void (*callback)(void), void *callback_pw, void *callback_wp)
{
  DEBUGf("\nDoCommand\n");
#ifdef DEBUGLIB
  DEBUGf("CDB: %02x %02x %02x %02x %02x %02x ",
  control_block[0],
  control_block[1],
  control_block[2],
  control_block[3],
  control_block[4],
  control_block[5]);
  if(control_block_length==10)DEBUGf("%02x %02x %02x %02x ",
  control_block[6],
  control_block[7],
  control_block[8],
  control_block[9]);
  DEBUGf("\nscat %p, tl %x\n",scatter_list, transfer_length);
  if(scatter_list)
  {
    DEBUGf(" %x:%x %x:%x \n",scatter_list->start, scatter_list->length,
                 (scatter_list+1)->start, (scatter_list+1)->length);
  }
#endif  
  if (device->dying) return (_kernel_oserror *)(ErrorNumber_SCSI_Died & 0xFF);
  struct umass_softc *softc = (struct umass_softc *)device->softc;
  
  bool irqs_were_off = _kernel_irqs_disabled();
  if (!irqs_were_off) _kernel_irqs_off();
  if (device->command_active)
  {
    if (!irqs_were_off) _kernel_irqs_on();
    return (_kernel_oserror *)(ErrorNumber_SCSI_QueueFull & 0xFF);
  }
  softc->transfer_priv = NULL; /* don't do callback if we're reset from interrupt, until transfer_priv is initialised */
  device->command_active = true; /* prevent any new commands from being started until we're done */
  device->ticker_semaphore = true; /* prevent TickerV from doing anything */
  if (!irqs_were_off) _kernel_irqs_on();
  device->background_transfer_active = false;
  device->current_fill=0;

  if (data_direction != DIR_NONE << 24)
  {
    /* check whether command is block oriented */
    /* and thus whether block complete is needed */
    switch(control_block[0])
    {
      case 0x08:
      case 0x28: /* read command */
      case 0x0a:
      case 0x2a: /* write command */
      case 0x0f:
      case 0x2f: /* verify command */
           {
                uint32_t maxpacket = (data_direction == (DIR_IN<<24))?device->bulk_in_maxpacketsize:device->bulk_out_maxpacketsize;
                DEBUGf(" Need part packet correction check left:%x mp:%x blocksize:%x\n",transfer_length & (maxpacket-1),maxpacket,device->block_size);
                /* If we know the device block size, round up to that instead of USB packet size */
                size_t rounded_size = transfer_length;
                if(device->block_size && !(device->block_size & (device->block_size-1)))
                {
                  rounded_size = (rounded_size+device->block_size-1) & ~(device->block_size-1);
                }
                else
                {
                  rounded_size = (rounded_size+maxpacket-1) & ~(maxpacket-1);
                }
                device->current_fill = rounded_size - transfer_length;
                transfer_length = rounded_size;
                break;
           }
      default:          
                break;
    }
    DEBUGf(" Using fill of %x\n",device->current_fill);

    /* Skip any leading null-length entries in the scatter list */
    while (scatter_list->length == 0)
    {
      scatter_list++;
      if ((uint32_t) scatter_list->start >= 0xFFFF0000u)
      {
        scatter_list = (scatter_entry_t *) ((char *) scatter_list + (int32_t) scatter_list->start);
      }
    }
  }

  /* Detect CAPACITY commands so that we can peek at the SCSI block size
     This is a hack, but is a convenient way of getting the required information
     without having to read it ourselves (and deal with devices being slow to
     initialise, removable devices, etc.)
  */
  device->is_capacity = ((control_block[0] == 0x25) && (data_direction == (DIR_IN<<24)) && (control_block_length == 10) && (transfer_length == 8));

  device->callback = callback; /* remember the address to call in SCSIDriver */
  device->callback_pw = callback_pw;
  device->callback_wp = callback_wp;
  DEBUGf("using length %x in wire_xfer\n",transfer_length);
  softc->sc_methods->wire_xfer(softc, lun, control_block, control_block_length,
                               scatter_list, transfer_length, data_direction >> 24,
                               Callback, (void *)device, (usbd_status *)&device->status);
  DEBUGf("going into wire_state, state, status = %x %x\n", softc->transfer_state, device->status);
  while (softc->transfer_state != TSTATE_IDLE && !device->background_transfer_active)
  {
    softc->sc_methods->wire_state(softc, 0 /* last xfer wasn't bulk */, (usbd_status *)&device->status);
    DEBUGf("state, state => %x %x\n", softc->transfer_state, device->status);
  }
  
  if (!irqs_were_off) _kernel_irqs_off();
  if (softc->transfer_state == TSTATE_IDLE)
  {
    /* Finished already! */
    /* Ensure another command can be issued from within callback */
    device->command_active = false;
    device->ticker_semaphore = false;
    /* Do callback */
    if (softc->transfer_priv != NULL)
    {
      DEBUGf("Calling SCSIDriver from DoCommand\n");
      asm_DoTransferCompleteCallback(device->callback_error,
                                     device->callback_status_byte,
                                     device->callback,
                                     device->callback_not_transferred,
                                     device->callback_pw,
                                     device->callback_wp);
    }
  }
  else
  {
    /* Do some background transfers */
    GetOnTickerV(device);
    device->ticker_semaphore = false;
    if(global_CallbackType == callback_RTSupport)
    {
      /* Wake up the RTSupport callback. Even if GetOnTickerV() just registered the callback with RTSupport, this code is still required because the ticker semaphore would have prevented any processing from occuring */
      ProdRTSupport();
    }
  }
  if (!irqs_were_off) _kernel_irqs_on();
  return NULL;
}

/*****************************************************************************
* glue_Tick
*
* Background processing entry point to handle a specific device.
*
* Assumptions
*  Interrupts are disabled
*  which means that we cannot rely on any memory claims
*   including auto allocate of 'unknown' quantities of buffer
*   hence all buffers used must have been pre-allocated
*
* Inputs
*  device: struct describing the interface to process
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
void glue_Tick(my_usb_device_t *device)
{
  /* Semaphore check .. out quickly if already here */
  if (device->ticker_semaphore) return;
  device->ticker_semaphore = true;

  DEBUGf("\nTick ");
  struct umass_softc *softc = (struct umass_softc *)device->softc;
  DEBUGf("Initial state, status = %x %x ", softc->transfer_state, device->status);
  
  /* Assume interrupts are disabled on entry - */
  /* this will be true for TickerV and the RTSupport wrapper */

  _kernel_oserror *e;
  size_t buffer_used;
  uint32_t maxpacket = device->current_pipe->maxpacket;
  /* Behaviour is different for reads and writes */
  if (device->current_pipe->write)
  {
    /* === WRITING === */
    DEBUGf(" WritePipe\n");
    
    /* Check the buffer occupancy (because MonitorTx purges the buffer if there's an error), */
    /* check for errors, then write as much as possible */
    buffer_used = USED_SPACE(device->current_pipe->buffer);
    DEBUGf("TXused_space = %x, TXfree=%x\n", buffer_used,FREE_SPACE(device->current_pipe->buffer));
    size_t buffer_free = (BUFFER_SIZE - 1) - buffer_used;
    if (buffer_free < device->curr_transferlength)
    {
      /* Ensure we only send in packet-size chunks, until the last packet */
      buffer_free &= ~(maxpacket - 1);
    }
    e = _swix(DeviceFS_CallDevice, _INR(0,2),
              DeviceCall_MonitorTX,
              device->devicefs_name,
              device->current_pipe->devicedriverstreamhandle);
    DEBUGf("MonitorTX returned %s\n", e ? e->errmess : "no error");
    _kernel_irqs_on();
    if (!e)
    {
      size_t pindex = 0; /* current index into the packet */
      while (buffer_free > 0 && device->curr_transferlength > 0)
      {
        size_t contig_len;
        bool padding = false;
        if (device->curr_transferlength <= device->curr_padding)
        {
          /* Padding area - limit to one USB packet per loop to keep things simple */
          contig_len = MIN(device->curr_transferlength, maxpacket);
          padding = true;
        }
        else
        {
          /* Data area - avoid reading crossing into padding area until next loop
             Also avoid crossing scatter list entry boundary */
          contig_len = MIN(device->curr_transferlength-device->curr_padding, device->curr_scatterlist->length - device->curr_offset);
        }
        contig_len = MIN(buffer_free, contig_len);
      DEBUGf("TX write contig_len:%x\n",contig_len);

        /* Attempt to fill any current partial packet, using scbulkoutbuf as temp */
        if (pindex > 0)
        {
          while (pindex < maxpacket && contig_len > 0)
          {
            char c = 0; /* Pad with 0 if necessary */
            if (!padding)
            {
              c = device->curr_scatterlist->start[device->curr_offset++];
            }
            softc->scbulkoutbuf[pindex++] = c; 
            contig_len --;
            buffer_free --;
            buffer_used ++;
            device->curr_transferlength --;
          }
          if (pindex == maxpacket)
          {
            INSERT_BLOCK(device->current_pipe->buffer, softc->scbulkoutbuf, maxpacket);
            pindex = 0;
          }
        }

        /* Copy any whole packets directly from source */        
        size_t wholepacket_len = contig_len &~ (maxpacket - 1);
        if ((wholepacket_len > 0) && !padding)
        {
          INSERT_BLOCK(device->current_pipe->buffer, device->curr_scatterlist->start + device->curr_offset, wholepacket_len);
          contig_len -= wholepacket_len;
          buffer_free -= wholepacket_len;
          buffer_used += wholepacket_len;
          device->curr_transferlength -= wholepacket_len;
          device->curr_offset += wholepacket_len;
        }

        /* Any remainder goes into scbulkoutbuf */        
        while (contig_len > 0)
        {
          char c = 0; /* Pad with 0 if necessary */
          if (!padding)
          {
            c = device->curr_scatterlist->start[device->curr_offset++];
          }
          softc->scbulkoutbuf[pindex++] = c;
          contig_len --;
          buffer_free --;
          buffer_used ++;
          device->curr_transferlength --;
        }
        if (pindex == maxpacket || device->curr_transferlength == 0)
        {
          INSERT_BLOCK(device->current_pipe->buffer, softc->scbulkoutbuf, pindex);
          pindex = 0;
        }

        /* Advance scatter list */        
        if (device->curr_transferlength > device->curr_padding)
        {
          while (device->curr_offset == device->curr_scatterlist->length)
          {
            device->curr_scatterlist++;
            device->curr_offset = 0;
            if ((uint32_t) device->curr_scatterlist->start >= 0xFFFF0000u)
            {
              device->curr_scatterlist = (scatter_entry_t *) ((char *) device->curr_scatterlist + (int32_t) device->curr_scatterlist->start);
            }
          }
        }
      }
    }
  }
  else
  {
    /* === READING === */
    DEBUGf(" ReadPipe\n");
    
    /* Repeatedly read as much as possible, *then* check for errors, to minimise data loss */
    while ((buffer_used = USED_SPACE(device->current_pipe->buffer)) > 0 && device->curr_transferlength > 0)
    {
      DEBUGf("RXused_space = %x RXfree=%x\n", buffer_used,FREE_SPACE(device->current_pipe->buffer));
      _kernel_irqs_on();
    DEBUGf("RX data needed = %x, ", device->curr_transferlength);
      while (buffer_used > 0 && device->curr_transferlength > 0)
      {
        size_t contig_len;
        bool padding = false;
        if (device->curr_transferlength <= device->curr_padding)
        {
          /* Padding area - limit to one USB packet per loop to keep things simple */
          contig_len = MIN(device->curr_transferlength, maxpacket);
          padding = true;
        }
        else
        {
          /* Data area - avoid reading crossing into padding area until next loop
             Also avoid crossing scatter list entry boundary */
          contig_len = MIN(device->curr_transferlength-device->curr_padding, device->curr_scatterlist->length - device->curr_offset);
        }
        contig_len = MIN(buffer_used, contig_len);

        if (!padding)
        {
          /* Data area */
          REMOVE_BLOCK(device->current_pipe->buffer, device->curr_scatterlist->start + device->curr_offset, contig_len);
          device->curr_offset += contig_len;
        }
        else
        {
          /* Padding area - read into scbulkoutbuf */
          REMOVE_BLOCK(device->current_pipe->buffer, softc->scbulkoutbuf, contig_len);
        }
        buffer_used -= contig_len;
        device->curr_transferlength -= contig_len;
    DEBUGf("RX still to go = %x, ", device->curr_transferlength);

        /* Advance scatter list */        
        if (device->curr_transferlength > device->curr_padding)
        {
          while (device->curr_offset == device->curr_scatterlist->length)
          {
            device->curr_scatterlist++;
            device->curr_offset = 0;
            if ((uint32_t) device->curr_scatterlist->start >= 0xFFFF0000u)
            {
              device->curr_scatterlist = (scatter_entry_t *) ((char *) device->curr_scatterlist + (int32_t) device->curr_scatterlist->start);
            }
          }
        }
      }
      _kernel_irqs_off();
    }
    DEBUGf("Still in RX buffer: = %x, ", buffer_used);
    e = _swix(DeviceFS_CallDevice, _INR(0,2),
              DeviceCall_MonitorRX,
              device->devicefs_name,
              device->current_pipe->devicedriverstreamhandle);
    DEBUGf("MonitorRX returned %s\n", e ? e->errmess : "no error");
    _kernel_irqs_on();
  }
  
  if (e || (device->current_pipe->write && buffer_used == 0) || (!device->current_pipe->write && device->curr_transferlength == 0))
  {
    if (e)
    {
      if (e->errnum >= 0x00819020 && e->errnum < 0x00819040) /* USB transfer failed */
        device->status = e->errnum - 0x00819020; /* extract BSD error code */
      else
        device->status = USBD_IOERROR; /* doesn't map to a BSD error code */
    }
    else
    {
      device->status = USBD_NORMAL_COMPLETION;
      if ((device->is_capacity) && ((softc->transfer_state == TSTATE_BBB_DATA) || (softc->transfer_state == TSTATE_CBI_DATA)) && (device->orig_scatterlist->length >= 8))
      {
        /* Peek at the block size returned in the capacity result, so that we
           can adjust our padding logic to use that block size instead of the
           USB packet size */
        uint8_t *capacity = (uint8_t *) device->orig_scatterlist->start;
        DEBUGf("CAPACITY result %08x %08x %02x %02x %02x %02x %02x %02x %02x %02x\n",device->orig_scatterlist,device->orig_scatterlist->start,capacity[0],capacity[1],capacity[2],capacity[3],capacity[4],capacity[5],capacity[6],capacity[7]);
        device->block_size = (capacity[4]<<24) | (capacity[5]<<16) | (capacity[6]<<8) | capacity[7];
      }
    }
    device->background_transfer_active = false;
    DEBUGf("going into wire_state, state, status = %x %x\n", softc->transfer_state, device->status);
    softc->sc_methods->wire_state(softc, device->orig_transferlength - device->curr_transferlength - buffer_used, (usbd_status *)&device->status);
    DEBUGf("state, status => %x %x\n", softc->transfer_state, device->status);
    while (softc->transfer_state != TSTATE_IDLE && !device->background_transfer_active)
    {
      softc->sc_methods->wire_state(softc, 0 /* last xfer wasn't bulk */, (usbd_status *)&device->status);
      DEBUGf("state, status => %x %x\n", softc->transfer_state, device->status);
    }
  }
  
  /* Finish off as appropriate */
  _kernel_irqs_off();
  device->ticker_semaphore = false;
  if (softc->transfer_state == TSTATE_IDLE)
  {
      DEBUGCHAR('I');
    device->command_active = false;
    GetOffTickerV(device);
      DEBUGCHAR('J');
    if (softc->transfer_priv != NULL)
    {
      DEBUGCHAR('K');
      DEBUGf("Calling SCSIDriver from Tick, addr=%x err=%x r0=%x r4=%x r5=%x r12=%x\n", (int)device->callback, (int)device->callback_error, device->callback_status_byte, device->callback_not_transferred, (int)device->callback_pw, (int)device->callback_wp);
      asm_DoTransferCompleteCallback(device->callback_error,
                                     device->callback_status_byte,
                                     device->callback,
                                     device->callback_not_transferred,
                                     device->callback_pw,
                                     device->callback_wp);
      DEBUGCHAR('L');
    }
  }
}

/*****************************************************************************
* glue_ReopenStream
*
* Try to cope with our streams having been closed
*
* Assumptions
*  NONE
*
* Inputs
*  file_handle: handle of stream which has been closed
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
void glue_ReopenStream(uint32_t file_handle)
{
  my_usb_device_t *device = global_DeviceList;
  while (device != NULL)
  {
    for (int i = 0; i < sizeof device->pipe / sizeof device->pipe[0]; i++)
    {
      if (device->pipe[i].handle == file_handle)
      {
        /* Try to re-open it */
        usbd_open_pipe((usbd_interface_handle) device,
                       ((struct umass_softc *)device->softc)->sc_epaddr[i],
                       i,
                       NULL);
      }
    }
    device = device->next;
  }
}


/*****************************************************************************
* glue_BufferThresholdCheck
*
* Decide whether we should wake up glue_Tick
*
* Assumptions
*  NONE
*
* Inputs
*  buffer: Buffer handle that's sent a filling/emptying upcall
*  filling: True if it's a filling upcall, false if emptying
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
void glue_BufferThresholdCheck(uint32_t buffer,bool filling)
{
  /* Scan the ticker list and see if we are actively processing this buffer */
  bool irqs_were_off = _kernel_irqs_disabled();
  if (!irqs_were_off) _kernel_irqs_off();
  DEBUGf("glue_BufferThresholdCheck: buffer %08x filling %d\n",buffer,filling);
  my_usb_device_t *device = global_TickerList;
  while(device)
  {
    if((device->current_pipe) && (device->current_pipe->buffer_handle == buffer))
    {
      /* Ignore write pipes that are filling, and read pipes that are emptying */
      if(device->current_pipe->write != filling)
      {
        DEBUGf("Match found: Waking glue_Tick!\n");
        // Set RTSupport pollword and exit
        global_RTSupportPollword = 1;
      }
      else
      {
        DEBUGf("Ignoring upcall; upcall was generated by our own activity\n");
      }
      break;
    }
    device = device->next_ticker;
  }

  if (!irqs_were_off) _kernel_irqs_on();
}

/*****************************************************************************
* Callback
*
* Callback from the BSD state machine code when the command has been completed.
*
* Assumptions
*  NONE
*
* Inputs
*  softc:           the BSD-style struct describing the device
*  void_device:     the opaque handle we supplied the BSD code - actually a
*                   pointer to our own struct describing the device
*  not_transferred: number of bytes that weren't successfully transferred
*  status:          BSD-style status code describing the reason for completion
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
static void Callback(struct umass_softc *softc, void *void_device, int not_transferred, int status)
{
  IGNORE(softc);
  my_usb_device_t *device = (my_usb_device_t *)void_device;
  DEBUGf("Callback, status %d\n",status);
  switch (status)
  {
    case STATUS_CMD_OK:
      device->callback_error = NULL;
      device->callback_status_byte = 0; /* GOOD */
      break;
      
    case STATUS_CMD_UNKNOWN:
      device->callback_error = NULL;
      device->callback_status_byte = 0x100; /* special magic value to indicate we don't know the status */
      break;
      
    case STATUS_CMD_FAILED:
      device->callback_error = NULL;
      device->callback_status_byte = 2; /* CHECK CONDITION */
      break;
      
    case STATUS_WIRE_FAILED:
      device->callback_error = (_kernel_oserror *)(ErrorNumber_SCSI_Died & 0xFF);
      break;
      
    case STATUS_TIMED_OUT:
      device->callback_error = (_kernel_oserror *)(ErrorNumber_SCSI_Timeout2 & 0xFF);
      break;
      
    case STATUS_ESCAPE:
      device->callback_error = _swix(MessageTrans_ErrorLookup, _INR(0,2),
                                     & (_kernel_oserror) { 17, "Escape" },
                                     0,
                                     0);
      break;
      
    case STATUS_ABORTED:
      device->callback_error = (_kernel_oserror *)(ErrorNumber_SCSI_AbortOp & 0xFF);
      break;
  }
  device->callback_not_transferred = not_transferred-device->current_fill;
  if (((int)device->callback_not_transferred) < 0)
  {
    device->callback_not_transferred = 0;
  }
  /* Callback to SCSIDriver is done later, when our semaphores have been released */
  return;
}

/*****************************************************************************
* RTSupportWrapper
*
* Wrapper function that sits between the RTSupport module and
* module_TickerVHandler
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
*  Time of next execution. May not return at all if the RTSupport callback is
*  no longer needed.
*****************************************************************************/
__value_in_regs rtsupport_routine_result RTSupportWrapper(void)
{
  unsigned int time;
  _kernel_oserror *e;
      DEBUGCHAR('>');
  /* Make sure IRQs are off. RTSupport will restore the correct state when/if we exit. */
  _kernel_irqs_off();
  if(global_CallbackType == callback_NONE)
  {
    /* We haven't returned from RT_Register yet. Avoid lots of nasty issues by just clearing the pollword and exiting. */
    DEBUGCHAR('~');
    global_RTSupportPollword = 0;
    goto exit;
  }
      DEBUGCHAR('0'+global_RTSupportPollword);
  _swix(OS_Hardware,_INR(8,9)|_OUT(0),0,21,&time);
  DEBUGf("RTSupportWrapper: pollword %d offset %d\n",global_RTSupportPollword,130000-time);
  /* Run TickerVHandler to perform the bulk of our work. */
  module_TickerVHandler(0,0);
      DEBUGCHAR('<');
  /* If RTSupport is active (which it should be!) and we have nothing in the ticker list, deregister ourselves */
  if((global_CallbackType == callback_RTSupport) && !global_TickerList)
  {
      DEBUGCHAR('-');
      global_CallbackType = callback_NONE; /* Pre-update since the below call should not return */
      e = _swix(RT_Deregister, _INR(0,1),
            0,
            global_RTSupportHandle);
      DEBUGCHAR('#');
  }
  /* Else get time of next execution */
exit:
  _swix(OS_ReadMonotonicTime,_OUT(0),&time);
  return (rtsupport_routine_result) { 1<<2, NULL, time+1 };
}

/*****************************************************************************
* GetOnTickerV
*
* "Does exactly what it says on the tin."
*
* Assumptions
*  NONE
*
* Inputs
*  device: pointer to device struct for device to be added to background
*          processing list
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
static void GetOnTickerV(my_usb_device_t *device)
{
  DEBUGf("GetOnTickerV\n");
  bool irqs_were_off = _kernel_irqs_disabled();
  if (!irqs_were_off) _kernel_irqs_off();
  device->next_ticker = global_TickerList;
  global_TickerList = device;
  if ((device->next_ticker == NULL) && (global_CallbackType == callback_NONE))
  {
    /* If we're using RTSupport, attempt to register with it
       If we fail to register with it (e.g. memory can't be moved when outside the wimp), fallback to TickerV */
    if(global_UseRTSupport)
    {
      DEBUGCHAR('+');
      _kernel_oserror *e = _swix(RT_Register,_INR(0,7)|_OUT(0),
            0,
            asm_RTSupportWrapper,
            *((uint32_t **)global_PrivateWord)+1,
            global_PrivateWord,
            &global_RTSupportPollword,
            0,
            0,
            "SCSISoftUSB:48",
            &global_RTSupportHandle);
      if(!e)
      {
        global_CallbackType = callback_RTSupport;
        DEBUGCHAR('+');
      }
      else
      {
        DEBUGCHAR('!');
        DEBUGf("Error registering with RTSupport: %08x %s\n",e->errnum,e->errmess);
        /* Fall through to TickerV callback */
      }
    }
    if(global_CallbackType == callback_NONE)
    {
      DEBUGCHAR('T');
      _swix(OS_Claim, _INR(0,2),
            TickerV,
            module_tickerv_handler,
            global_PrivateWord);
      global_CallbackType = callback_TickerV;
    }
 DEBUGf("\n hello tickerV ");
  }
  if (!irqs_were_off) _kernel_irqs_on();
}

/*****************************************************************************
* GetOffTickerV
*
* "Does exactly what it says on the tin."
*
* Assumptions
*  NONE
*
* Inputs
*  device: pointer to device struct for device to be removed from background
*          processing list
*
* Outputs
*  NONE
*
* Returns
*  NOTHING
*****************************************************************************/
static void GetOffTickerV(my_usb_device_t *device)
{
  DEBUGf("GetOffTickerV\n");
  bool irqs_were_off = _kernel_irqs_disabled();
  if (!irqs_were_off) _kernel_irqs_off();
  my_usb_device_t *ptr = global_TickerList;
  my_usb_device_t *prev = NULL;
  while (ptr != NULL)
  {
    if (ptr == device)
    {                                   
      if (prev == NULL)
      {
        if ((global_TickerList = ptr->next_ticker) == NULL)
        {
 DEBUGf("\n byebye tickerV ");
          if(global_CallbackType == callback_TickerV)
          {
            DEBUGCHAR('t');
            _swix(OS_Release, _INR(0,2),
                  TickerV,
                  module_tickerv_handler,
                  global_PrivateWord);
            global_CallbackType = callback_NONE;
          }
          // Can't deregister with RTSupport here - we may be inside the callback function, in which case RTSupport will kill us before we're able to send the completion callback to the SCSI driver
        }
      }
      else
      {
        prev->next_ticker = ptr->next_ticker;
      }
      break;
    }
    else
    {
      prev = ptr;
      ptr = ptr->next_ticker;
    }
  }
  if (!irqs_were_off) _kernel_irqs_on();
}

/*****************************************************************************
* ProdRTSupport
*
* Prods the RTSupport callback - either entering the callback immediately if
* we're in a foreground process, or setting the pollword if we're in an IRQ
* handler (which will cause the routine to be entered after the IRQ), or
* setting the pollword if we're already in the callback (which will cause it
* to be re-entered on exit)
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
*  NOTHING
*****************************************************************************/
static void ProdRTSupport(void)
{
  global_RTSupportPollword = 1;
  DEBUGCHAR('P');
  if(global_CallbackType != callback_RTSupport)
    return;
  int context=0;
  _kernel_oserror *e = _swix(RT_ReadInfo,_IN(0)|_OUT(0),0,&context);
  if(e)
  {
    DEBUGCHAR('@');
    DEBUGf("RT_ReadInfo: Error %08x %s\n",e->errnum,e->errmess);
    return;
  }
  if(context == 0)
  {
    bool irqs_were_off = _kernel_irqs_disabled();
    if (!irqs_were_off) _kernel_irqs_off();
    DEBUGf("ProdRTSupport: Waking callback immediately\n");
    context = 1; /* Pollword of 1 to make sure we eventually return here! */
    DEBUGCHAR('A');
    _swix(RT_Yield,_IN(1),&context);
    DEBUGCHAR('B');
    if (!irqs_were_off) _kernel_irqs_on();
  }
  else
  {
    DEBUGCHAR('C');
    DEBUGf("ProdRTSupport: Already in callback or IRQ\n");
  }
}

/*****************************************************************************
* usbd_do_request
*
* Sends a request to the default endpoint of the specified device.
* The BSD code was designed to link directly with the equivalent routine
* inside the USB driver.
*
* Assumptions
*  NONE
*
* Inputs
*  pipe: we're actually using this as our device handle
*  req:  pointer to the fixed fields of the request
*  data: pointer to the data buffer associated with the request
*
* Outputs
*  NONE
*
* Returns
*  BSD-style status code
*****************************************************************************/
usbd_status usbd_do_request(usbd_device_handle pipe, usb_device_request_t *req, void *data)
{
  DEBUGf("do_request(%x %x)\n",*(uint32_t *)req,
                             *((uint32_t *)req+1));
  _kernel_oserror *e = _swix(DeviceFS_CallDevice, _INR(0,1)|_INR(3,6),
                             DeviceCall_ExternalBase + 0,
                             ((my_usb_device_t *)pipe)->devicefs_name,
                             *(uint32_t *)req,
                             *((uint32_t *)req+1),
                             data,
                             0 /* for compatibility with Castle API variant */);
  DEBUGf("do_request() returned %s\n", e ? e->errmess : "no error");
  if (!e) return USBD_NORMAL_COMPLETION;
  return USBD_STALLED; /* we can't actually tell what the error was, but this is a likely cause */
}

/*****************************************************************************
* usbd_open_pipe
*
* Opens a bulk pipe of the specified direction to the specified endpoint of the
* specified interface.
* The BSD code was designed to link directly with the equivalent routine
* inside the USB driver.
*
* Assumptions
*  NONE
*
* Inputs
*  iface:   we're actually using this as our device handle
*  address: combined direction and endpoint number (as in endpoint descriptors)
*  flags:   we've used this as the index into our arrays of pipe blocks and maxpacketsize
*
* Outputs
*  pipe:    our handle for this pipe
*
* Returns
*  BSD-style status code
*****************************************************************************/
usbd_status usbd_open_pipe(usbd_interface_handle iface, u_int8_t address, u_int8_t flags, usbd_pipe_handle *pipe)
{
  my_usb_device_t *device = (my_usb_device_t *) iface;
  char filename[sizeof "USBxxxxxxxxxxxxxxxx#interfacexxx;alternatexxx;endpointxxx;bulk;sizexxxxxx:" + 1];
  if (pipe) *pipe = 0; /* in case of error */
  
  sprintf(filename, "%s#endpoint%d;interface%d;alternate%d;bulk;size%d:",
         device->devicefs_name,
         address & 0x7F,
         device->interface,
         device->alternate,
         BUFFER_SIZE);
  DEBUGf("\n usbd_open_pipe %s\n",filename);
  _swix(OS_Claim, _INR(0,2),
        UpCallV,
        asm_UpCallHandler,
        &device->pipe[flags].devicedriverstreamhandle);
  _kernel_oserror *e = _swix(OS_Find, _INR(0,1)|_OUT(0),
                             address & 0x80 ? 0x4C : 0x8C,
                             filename,
                             &device->pipe[flags].handle);
  _swix(OS_Release, _INR(0,2),
        UpCallV,
        asm_UpCallHandler,
        &device->pipe[flags].devicedriverstreamhandle);
  if (e)
  {
  DEBUGf("\n usbd_open_pipe error %s\n",e->errmess);
    switch (e->errnum)
    {
      case ErrorBase_USBDriver + 4: return USBD_IN_USE;
      case ErrorBase_USBDriver + 5: return USBD_BAD_ADDRESS; /* probably */
      default: return USBD_INVAL; /* don't really know the cause */
    }
  }
  
  e = _swix(DeviceFS_CallDevice, _INR(0,2)|_OUT(3),
            DeviceCall_ExternalBase + 3, /* return handles */
            device->devicefs_name,
            device->pipe[flags].handle,
            &device->pipe[flags].buffer_handle);
  if (!e) e = _swix(Buffer_InternalInfo, _IN(0)|_OUTR(0,2),
                    device->pipe[flags].buffer_handle,
                    &device->pipe[flags].buffer,
                    &static_BufManRout,
                    &static_BufManWS);
  /* Set threshold so that we get told when the buffer becomes empty/non-empty */
  if (!e) e = _swix(Buffer_Threshold,_INR(0,1),device->pipe[flags].buffer_handle,BUFFER_SIZE-1);
  
  if (e)
  {
    usbd_close_pipe((usbd_pipe_handle)(device->pipe + flags));
    return USBD_INVAL;
  }
  
  device->pipe[flags].write = !(address & 0x80);
  device->pipe[flags].device = device;
  device->pipe[flags].maxpacket = ((struct umass_softc *)device->softc)->sc_maxpacket[flags];
  if (pipe) *pipe = (usbd_pipe_handle)(device->pipe + flags);
  
  return USBD_NORMAL_COMPLETION;
}

/*****************************************************************************
* usbd_close_pipe
*
* Closes a pipe previously opened with usbd_open_pipe.
* The BSD code was designed to link directly with the equivalent routine
* inside the USB driver.
*
* Assumptions
*  NONE
*
* Inputs
*  pipeh: our handle for this pipe
*
* Outputs
*  NONE
*
* Returns
*  BSD-style status code
*****************************************************************************/
usbd_status usbd_close_pipe(usbd_pipe_handle pipeh)
{
  pipe_block_t *pipe = (pipe_block_t *)pipeh;
  if (pipe->handle != 0)
  {
    _swix (OS_Find, _INR(0,1),
           0,
           pipe->handle);
  }
  return USBD_NORMAL_COMPLETION;
}

/*****************************************************************************
* umass_setup_transfer
*
* Initialises a background transfer on a bulk pipe.
* This is a replacement for one of the routines in umass.c, but it fits better
* with the other routines in this source file.
*
* Assumptions
*  NONE
*
* Inputs
*  softc:  the BSD-style struct describing the device (not used)
*  pipeh:  our handle for this pipe
*  buffer: pointer to start of buffer to transfer *or* pointer to
*          first item of scatter list describing data transfer
*  buflen: total amount of data to transfer
*  flags:  we're only using this to indicate if we're using a scatter list
*
* Outputs
*  NONE
*
* Returns
*  BSD-style status code
*****************************************************************************/
usbd_status umass_setup_transfer(struct umass_softc *sc, usbd_pipe_handle pipeh, void *buffer, int buflen, int flags)
{
  IGNORE(sc);
  pipe_block_t *pipe = (pipe_block_t *)pipeh;
  my_usb_device_t *device = pipe->device;
  DEBUGf("umass_setup_transfer ");
  
  if (!pipe->write)
  {
    /* USBDriver needs prodding to get it to start reading */
    _swix (DeviceFS_CallDevice, _INR(0,3),
           DeviceCall_WakeUpRX,
           device->devicefs_name,
           pipe->devicedriverstreamhandle,
           buflen);
  }
  
  device->current_pipe = pipe;
  if ((flags & USBD_DATA_IS_SCATTER_LIST) == 0)
  {
    device->fake_list.start = buffer;
    device->fake_list.length = buflen;
    device->orig_scatterlist = &device->fake_list;
    device->curr_padding = 0;
  }
  else
  {
    device->orig_scatterlist = buffer;
    device->curr_padding = device->current_fill;
  }
  device->curr_scatterlist = device->orig_scatterlist;
  device->curr_offset = 0;
  device->orig_transferlength = buflen;
  device->curr_transferlength = buflen;
  device->background_transfer_active = true;

  if(pipe->write)
  {
    /* Prod the RTSupport callback so it wakes up and performs the write immediately */
    ProdRTSupport();
  }
  
  return USBD_NORMAL_COMPLETION;
}

/*****************************************************************************
* umass_clear_endpoint_stall
*
* Performs the necessary actions to remove a stall condition from an endpoint.
* This is a replacement for one of the routines in umass.c, but it fits better
* with the other routines in this source file.
*
* Assumptions
*  NONE
*
* Inputs
*  sc:     the BSD-style struct describing the device
*  endpt:  the endpoint that is stalled (index into our array of pipes)
*
* Outputs
*  NONE
*
* Returns
*  BSD-style status code
*****************************************************************************/
usbd_status umass_clear_endpoint_stall(struct umass_softc *sc, int endpt)
{
  bool irqs_were_off = _kernel_irqs_disabled();
  DEBUGf("umass_clear_endpoint_stall ");
  if (!irqs_were_off) _kernel_irqs_off();
  my_usb_device_t *device = global_DeviceList;
  while (device != NULL)
  {
    if (device->softc == sc) break;
    device = device->next;
  }
  if (!irqs_were_off) _kernel_irqs_on();
  if (device == NULL) return USBD_INVAL;
  
  _kernel_oserror *e = _swix(DeviceFS_CallDevice, _INR(0,2),
                             DeviceCall_ExternalBase + 5,
                             device->devicefs_name,
                             device->pipe[endpt].handle);
  DEBUGf("New device call returned %s\n", e ? e->errmess : "no error");
  if (!e) return USBD_NORMAL_COMPLETION;
  return USBD_IOERROR;
}


#ifdef UMASS_DEBUG
#include <stdarg.h>
#include "DebugLib/DebugLib.h"
Static const char * const usbd_error_strs[] = {
	"NORMAL_COMPLETION",
	"IN_PROGRESS",
	"PENDING_REQUESTS",
	"NOT_STARTED",
	"INVAL",
	"NOMEM",
	"CANCELLED",
	"BAD_ADDRESS",
	"IN_USE",
	"NO_ADDR",
	"SET_ADDR_FAILED",
	"NO_POWER",
	"TOO_DEEP",
	"IOERROR",
	"NOT_CONFIGURED",
	"TIMEOUT",
	"SHORT_XFER",
	"STALLED",
	"INTERRUPTED",
	"XXX",
};

const char *
usbd_errstr(usbd_status err)
{
	static char buffer[5];

	if (err < USBD_ERROR_MAX) {
		return usbd_error_strs[err];
	} else {
		snprintf(buffer, sizeof buffer, "%d", err);
		return buffer;
	}
}

void logprintf (char* format, ...)
{
    va_list p;
    va_start (p, format);
    dvprintf (("", format, p));
}
#endif

/*****************************************************************************
* END OF FILE
*****************************************************************************/
