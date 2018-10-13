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
/************************************************************************/
/* 	        Copyright 1996 Acorn Network Computers		        */
/*									*/
/*  This material is the confidential trade secret and proprietary	*/
/*  information of Acorn Network Computers. It may not be reproduced,   */
/*  used sold, or transferred to any third party without the prior      */
/*  written consent of Acorn Network Computers. All rights reserved.	*/
/* 									*/
/************************************************************************/

/*
 * Test harness for new serial driver
 *
 * Modification History
 *---------------------
 * 14-May-96 RWB Created
 */
#include "kernel.h"
#include "swis.h"
#include "serial.h"

/*
 * open a stream on the given filename
 */
int
serial_open_stream(char *strFilename, int iRights)
{
  _kernel_oserror *err;
  _kernel_swi_regs reg;

  reg.r[0] = iRights;
  reg.r[1] = (int)strFilename;
  err = _kernel_swi(OS_Find,&reg,&reg);
  if (err) return (0);

  return (reg.r[0]);
}

/*
 * close stream specified by handle
 */
void
serial_close_stream(int iHandle)
{
  _kernel_oserror *err;
  _kernel_swi_regs reg;

  reg.r[0] = 0;
  reg.r[1] = iHandle;
  err = _kernel_swi(OS_Find,&reg,&reg);
}

/*
 * execute an ioctl and return the data
 */
unsigned int
serial_ioctl(int iHandle, ioctl_t *pIOCtlBlock)
{
  _kernel_swi_regs reg;

  reg.r[0] = 9;                    /* ioctl */
  reg.r[1] = iHandle;
  reg.r[2] = (int)pIOCtlBlock;
  _kernel_swi(OS_Args,&reg,&reg);

  return (pIOCtlBlock->data);
}

/*
 * Fill buffer with as much data as will fit, or as much as is in the rx stream.
 * Return amount of data read.
 */
int
serial_read_stream(int iHandle, char *pchDataBlock, int iSize)
{
  _kernel_swi_regs reg;
  _kernel_oserror *err;
  int iRxDataSize;

  reg.r[0] = 2;                         /* get amount of data in buffer */
  reg.r[1] = iHandle;
  err = _kernel_swi(OS_Args,&reg,&reg);
  if (err) return (-1);

  iRxDataSize = reg.r[2];
  if (!iRxDataSize) return (0);         /* no data */

  if (iRxDataSize>iSize) iRxDataSize = iSize;

  reg.r[0] = 4;	      	                /* read data */
  reg.r[1] = iHandle;
  reg.r[2] = (int)pchDataBlock;
  reg.r[3] = iRxDataSize;
  err = _kernel_swi(OS_GBPB,&reg,&reg);
  if (err) return (-1);

  return (iRxDataSize);
}

/*
 * Get a single byte from the serial stream. Will return -1 for failure.
 */
int
serial_read_byte(int iHandle)
{
  _kernel_swi_regs reg;
  _kernel_oserror *err;
  int iCarry;

  reg.r[0] = 5;                    /* read eof */
  reg.r[1] = iHandle;
  err = _kernel_swi(OS_Args,&reg,&reg);
  if (err || reg.r[2]) return (-1);

  err = _kernel_swi_c(OS_BGet,&reg,&reg,&iCarry);
  if (err || iCarry) return (-1);

  return (reg.r[0]);
}

/*
 * Write to tx stream as much data as given or as much as will fit in the
 * stream. Return amount of data written.
 */
int
serial_write_stream(int iHandle, char *pchDataBlock, int iSize)
{
  _kernel_swi_regs reg;
  _kernel_oserror *err;
  int iTxFreeSize;

  reg.r[0] = 2;                         /* get amount of free space in buffer */
  reg.r[1] = iHandle;
  err = _kernel_swi(OS_Args,&reg,&reg);
  if (err) return (-1);

  iTxFreeSize = reg.r[2];
  if (!iTxFreeSize) return (0);         /* no free space */

  if (iSize>iTxFreeSize) iSize = iTxFreeSize;

  reg.r[0] = 2;	      	                /* write data */
  reg.r[1] = iHandle;
  reg.r[2] = (int)pchDataBlock;
  reg.r[3] = iSize;
  err = _kernel_swi(OS_GBPB,&reg,&reg);
  if (err) return (-1);

  return (iSize);
}

/*
 * Send a single byte to the serial stream. Will return 1 for success
 */
int
serial_write_byte(int iHandle, char chData)
{
  _kernel_swi_regs reg;
  _kernel_oserror *err;

  reg.r[0] = (int)chData;
  reg.r[1] = iHandle;
  err = _kernel_swi(OS_BPut,&reg,&reg);
  if (err) return (-1);

  return (1);
}

/*
 * Return free space/amount of data
 */
int serial_size(int iHandle)
{
  _kernel_swi_regs reg;
  _kernel_oserror *err;

  reg.r[0] = 2;
  reg.r[1] = iHandle;
  err = _kernel_swi(OS_Args,&reg,&reg);
  if (err) return (-1);

  return (reg.r[2]);
}

