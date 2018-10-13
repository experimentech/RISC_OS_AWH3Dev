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
#ifndef spi_H
#define spi_H

#ifdef DEBUGLIB
#define DEBUG
#endif
#ifdef DEBUG
#undef dprintf
#define dprintf(...) _dprintf("",__VA_ARGS__)  
#else
#undef dprintf
#define dprintf(...) (void) 0
#endif


#include <stdint.h>
#include <stdbool.h>



#define SPI_ErrorBase 0x820600
enum
{
   SPI_NoRoom = 0x00,
   SPI_SWIunkn,
   SPI_RCunkn,
   SPI_BadReset,
   SPI_BadHostID,
   SPI_BadDevID,
   SPI_NoDevice,
   SPI_Established,
   SPI_NotEstablished,
   SPI_NotIdle,
   SPI_Timeout,
   SPI_Timeout2,
   SPI_QueueNotEmpty,
   SPI_QueueFull,
   SPI_DevReserved,
   SPI_InvalidParms,
   SPI_ParmError,
   SPI_NotFromIRQ,
   SPI_AbortOp,
   SPI_Died,
   SPI_WrongMEMC,
   SPI_UnKnCmd,

   SPI_CheckCondition = 0x80,
   SPI_Busy,
   SPI_StatusUnkn,

   SPI_CC_NoSense = 0xC0,
   SPI_RecoveredError,
   SPI_CC_NotReady,
   SPI_CC_MediumError,
   SPI_CC_HardwareError,
   SPI_CC_IllegalRequest,
   SPI_CC_UnitAttention,
   SPI_CC_DataProtect,
   SPI_CC_BlankCheck,
   SPI_CC_VendorUnique,
   SPI_CC_CopyAborted,
   SPI_CC_AbortedCommand,
   SPI_CC_Equal,
   SPI_CC_VolumeOverflow,
   SPI_CC_Miscompare,
   SPI_CC_Reserved,
   SPI_CC_UnKn,
};

typedef _kernel_oserror *swient(_kernel_swi_regs *);

swient spid_version, spid_initialise, spid_control,
       spid_op, spid_status, 
       spid_register, spid_deregister;

void spi_deregister_all(void);


#endif
