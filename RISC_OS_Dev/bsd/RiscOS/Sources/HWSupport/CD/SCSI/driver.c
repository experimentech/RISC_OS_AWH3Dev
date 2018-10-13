/*
 * Copyright (c) 2011, RISC OS Open Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#include "modhead.h"
#include "swis.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Interface/SCSIErr.h"

#include "DebugLib/DebugLib.h"

#include "globals.h"
#include "scsibits.h"
#include "errors.h"

/* Local vars */

static uint8_t SCSIOp_MiscBuffer[8192];
static uint8_t DiscChangeBits[4*8]; /* Disc change flags */
static uint8_t DrawerStatusBits[4*8]; /* Drawer lock flags */
static uint8_t DriveDataModes[256]; /* Current data mode settings */

static const uint32_t BlockSizes[DataMode_MAX] =
{
	2352, /* Audio */
	2048, /* Mode 1 */
	2340, /* Mode 2 format 2 */
	2048, /* Mode 2 format 1 */
};

#define MAX_READDATA_BLOCKS 32 /* Max number of blocks to read at once */

/* Extra debugging - show all mode sense results */
//#define EXTRADEBUG

/* Utility functions */

#ifdef DEBUGLIB
static void DumpBlock(const uint8_t *block,uint32_t size)
{
	while(size--)
		dprintf((""," %02x",*block++));
	dprintf(("","\n"));
}
#else
#define DumpBlock(A,B) (void) 0
#endif

static uint8_t *FindModePage(uint8_t *pages,uint32_t size,PageCode page)
{
	while(size > 2)
	{
		if(MODEPAGEHDR_PageCode_Read(pages) == page)
			return pages;
		uint32_t len = MODEPAGEHDR_PageLength_Read(pages)+2;
		if(len >= size)
			return NULL;
		pages += len;
	}
	return NULL;
}

static uint32_t HasDiscChanged(const cdfs_ctl_block_t *blk)
{
	uint8_t *byte = DiscChangeBits+blk->device+(blk->card<<3);
	uint32_t result = ((*byte)>>(blk->lun)) & 1;
	if(result)
		*byte -= (1<<blk->lun);
	return result;
}

static void SetDiscChanged(const cdfs_ctl_block_t *blk)
{
	DiscChangeBits[blk->device+(blk->card<<3)] |= (1<<blk->lun);
}

static uint32_t GetDrawerStatus(const cdfs_ctl_block_t *blk)
{
	uint8_t *byte = DrawerStatusBits+blk->device+(blk->card<<3);
	return ((*byte)>>(blk->lun)) & 1;
}

static void SetDrawerStatus(const cdfs_ctl_block_t *blk,uint32_t locked)
{
	uint8_t *byte = DrawerStatusBits+blk->device+(blk->card<<3);
	uint8_t val = *byte;
	uint8_t flag = 1<<blk->lun;
	if(locked)
		val |= flag;
	else
		val &= ~flag;
	*byte = val;
}

static DataMode GetDataMode(const cdfs_ctl_block_t *blk)
{
	return (DataMode) DriveDataModes[blk->device | (blk->card<<3) | (blk->lun<<5)];
}

static void SetDataMode(DataMode mode,const cdfs_ctl_block_t *blk)
{
	DriveDataModes[blk->device | (blk->card<<3) | (blk->lun<<5)] = mode;
}

/* SCSI_Op SWI wrapper
   Not suitable for background transfers or scatter lists
   Assumes we don't care about the extended error info
   Handles retries & disc change detection */

static _kernel_oserror *DoSCSIOp(uint32_t typeandflags,const uint8_t *scb,size_t scblen,uint8_t *buffer,size_t buflen,uint32_t timeout,uint32_t *result,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	_kernel_oserror *e;
#ifdef DEBUGLIB
	dprintf(("","  SCSI_Op: type %02x dev %d:%d.%d scblen %d buffer %p buflen %d timeout %d retries %d\n",typeandflags,blk->card,blk->device,blk->lun,scblen,buffer,buflen,timeout,retries));
	dprintf(("","  SCB:"));
	DumpBlock(scb,scblen);
#endif
	do {
		uint32_t remaining;
		e = _swix(SCSI_Op,_INR(0,5)|_IN(8)|_OUT(4),blk->device | (blk->card<<3) | (blk->lun<<5) | typeandflags,scblen,scb,buffer,buflen,timeout,SCSI_ACCESSKEY,&remaining);
		if(e)
		{
			if((e->errnum == ErrorNumber_SCSI_CC_UnitAttention) || (e->errnum == ErrorNumber_SCSI_CheckCondition))
			{
				if(++retries >= 3)
				{
					dprintf(("","  Reached retry limit with error %x %s\n",e->errnum,e->errmess));
					return e;
				}
				dprintf(("","  Retrying with error %x %s\n",e->errnum,e->errmess));
				SetDiscChanged(blk);
				SetDrawerStatus(blk,0);
			}
			else
			{
				dprintf(("","  Error %x %s\n",e->errnum,e->errmess));
				return e;
			}
		}
		else
		{
			dprintf(("","  OK, %d data bytes\n",buflen-remaining));
			if(result)
				*result = buflen-remaining;
			return NULL;
		}
	} while(1);
}

/* Issue a MODE SENSE command, into the misc buffer */
static _kernel_oserror *ModeSense(PageCode page,uint32_t *result,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	SCSI_CREATEBLOCK(SCB,MODESENSE,10);
	MODESENSE10_DBD_Write(SCB,1); /* Don't return block descriptors */
	MODESENSE10_PageCode_Write(SCB,page);
	MODESENSE10_PC_Write(SCB,PageControl_Current); /* Return current values */
	MODESENSE10_AllocationLength_Write(SCB,sizeof(SCSIOp_MiscBuffer));
	_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,sizeof(SCSIOp_MiscBuffer),0,result,blk,retries);
	if(e)
		return e;
	if(*result < 8)
	{
		dprintf(("", " Only %d bytes returned in response to MODESENSE10!\n",*result));
		return ERROR(BadResponse);
	}
#if defined(DEBUGLIB) && defined(EXTRADEBUG)
	dprintf((""," MODE SENSE response (page %02x):\n",page));
	DumpBlock(SCSIOp_MiscBuffer,*result);
#endif
	if(MODEPARAMHEADER10_BlockDescLen_Read(SCSIOp_MiscBuffer))
	{
		dprintf(("", " Device returned block descriptors, even though we said not to!\n"));
		return ERROR(BadResponse);
	}
#ifdef DEBUGLIB
	/* Ideally we'd return an error for this case, but some drives do return the wrong values. Just spit out a warning instead.
	   TODO - Should we obey the value returned by the drive, or use the number of bytes that were transferred by the SCSI op? */
	if(MODEPARAMHEADER10_ModeDataLength_Read(SCSIOp_MiscBuffer) != 6+*result)
		dprintf(("", " ModeDataLength doesn't add up! Drive reports %d bytes, but should be %d\n",MODEPARAMHEADER10_ModeDataLength_Read(SCSIOp_MiscBuffer),6+*result));
#endif
	return NULL;
}

static _kernel_oserror *ReadSubChannel(const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Issue a ReadSubChannel request */
	SCSI_CREATEBLOCK(SCB,READSUBCHANNEL,10);
	READSUBCHANNEL10_SUBQ_Write(SCB,1);
	READSUBCHANNEL10_ParamList_Write(SCB,SubChannelParam_CDPos);
	READSUBCHANNEL10_AllocationLength_Write(SCB,16);
	uint32_t result;
	_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,16,0,&result,blk,retries);
	if(e)
		return e;
	if(result != 16)
	{
		dprintf((""," Bad number of bytes returned by READ SUB-CHANNEL (%d)\n",result));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	if(SUBQHEADER_DataLength_Read(SCSIOp_MiscBuffer) < 12)
	{
		dprintf((""," Bad data length (%d)\n",SUBQHEADER_DataLength_Read(SCSIOp_MiscBuffer)));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	if(SUBQ_CDPOS_FormatCode_Read(SCSIOp_MiscBuffer+4) != SubChannelParam_CDPos)
	{
		dprintf((""," Returned data isn't for CDPos!\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	return NULL;
}

static _kernel_oserror *ReadData(uint32_t start,uint32_t numblock,uint8_t *dest,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	DataMode mode = GetDataMode(blk);
	uint32_t blocksize = BlockSizes[mode];
	switch(mode)
	{
	default:
		/* Shouldn't happen. Reset to something sensible. */
		dprintf((""," Bad data mode! %d\n",mode));
		SetDataMode(DataMode_Data1,blk);
		mode = DataMode_Data1;
		blocksize = BlockSizes[mode];
		/* Fall through... */

	case DataMode_Data1:
	case DataMode_Data2Form1:
		{
			/* Issue a simple READ 10
			   To cope with dodgy drives/controllers we'll split the transfer into chunks which are multiples of MAX_READDATA_BLOCKS in size */
			SCSI_CREATEBLOCK(SCB,READ,10);
			do {
				uint32_t toread = MIN(numblock,MAX_READDATA_BLOCKS);
				READ10_LBA_Write(SCB,start);
				READ10_TransferLength_Write(SCB,toread);
				uint32_t result;
				_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),dest,toread*blocksize,0,&result,blk,retries);
				if(e)
				{
					/* TODO - Process errors like CDFS? */
					return e;
				}
				if(result != toread*blocksize)
				{
					dprintf(("", " Device didn't read all the data!\n"));
					return ERROR(BadResponse);
				}
				numblock -= toread;
				start += toread;
				dest += toread*blocksize;
			} while(numblock);
			return NULL;
		}

	case DataMode_Audio:
	case DataMode_Data2Form2:
		{
			/* Use READ CD */
			/* TODO - Split into chunks like we do for READ 10? */
			SCSI_CREATEBLOCK(SCB,READCD,12);
			READCD12_StartLBA_Write(SCB,start);
			READCD12_Length_Write(SCB,numblock);
			/* Return all data */
			READCD12_EDC_ECC_Write(SCB,1);
			READCD12_UserData_Write(SCB,1);
			READCD12_HeaderCodes_Write(SCB,3);
			uint32_t result;
			_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),dest,numblock*blocksize,0,&result,blk,retries);
			if(e)
			{
				/* TODO - Process errors like CDFS? */
				return e;
			}
			if(result != numblock*blocksize)
			{
				dprintf(("", " Device didn't read all the data!\n"));
				return ERROR(BadResponse);
			}
			return NULL;
		}
	}
}

static _kernel_oserror *ReadTrackInformation(uint32_t addr,DataMode *datamode,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Use READ TRACK INFORMATION */
	SCSI_CREATEBLOCK(SCB,READTRACKINFORMATION,10);
	READTRACKINFORMATION10_AddrNumType_Write(SCB,0); /* LBA */
	READTRACKINFORMATION10_LBA_Track_Write(SCB,addr);
	READTRACKINFORMATION10_AllocationLength_Write(SCB,sizeof(SCSIOp_MiscBuffer));
	uint32_t result;
	_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,sizeof(SCSIOp_MiscBuffer),0,&result,blk,retries);
	if(e)
		return e;
	dprintf((""," READ TRACK INFORMATION of %08x:\n",addr));
	if(result < 28) /* Size as per MMC1 */
	{
		dprintf((""," READ TRACK INFO only returned %d bytes!\n",result));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	if(TRACKINFO_DataLength_Read(SCSIOp_MiscBuffer) < 26) /* Size as per MMC1 */
	{
		dprintf((""," READ TRACK INFO data length is only %d bytes!\n",TRACKINFO_DataLength_Read(SCSIOp_MiscBuffer)));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	/* Check the data mode and track mode fields */
	if(!(TRACKINFO_TrackMode_Read(SCSIOp_MiscBuffer) & 0x4))
	{
		dprintf((""," Looks like audio\n"));
		*datamode = DataMode_Audio;
		return NULL;
	}
	switch(TRACKINFO_DataMode_Read(SCSIOp_MiscBuffer))
	{
	case 1:
		dprintf((""," Should be data mode 1\n"));
		*datamode = DataMode_Data1;
		return NULL;
	case 2:
		dprintf((""," Should be data mode 2\n"));
		/* Mode 2 needs extra interrogation to work out whether it's format 1 or 2
		   Just return form 1 and let the caller deal with it */
		*datamode = DataMode_Data2Form1;
		return NULL;
	default:
		dprintf((""," Unknown data mode!\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		/* Just claim it's mode 1? */
		*datamode = DataMode_Data1;
		return NULL;
	}
}

static _kernel_oserror *ReadHeader(uint32_t addr,DataMode *datamode,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	SCSI_CREATEBLOCK(SCB,READHEADER,10);
	READHEADER10_LBA_Write(SCB,addr);
	uint32_t result;
	_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,8,0,&result,blk,retries);
	if(e)
	{
		/* Assume any illegal request error is because it's a mode 0 disc (like Sony 561 SCSI driver does) */
		if(e->errnum == ErrorNumber_SCSI_CC_IllegalRequest)
		{
			*datamode = DataMode_Audio;
			return NULL;
		}
		return e;
	}
	if(result != 8)
	{
		dprintf((""," READHEADER only returned %d bytes!\n",result));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	switch(READHEADERLBA_DataMode_Read(SCSIOp_MiscBuffer))
	{
	case 0:
		*datamode = DataMode_Audio;
		return NULL;
	case 1:
		*datamode = DataMode_Data1;
		return NULL;
	case 2:
		/* Mode 2 needs extra interrogation to work out whether it's format 1 or 2
		   Just return form 1 and let the caller deal with it */
		*datamode = DataMode_Data2Form1;
		return NULL;
	default:
		dprintf((""," Unknown data mode!\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
}

/* Driver operations */

static _kernel_oserror *driver_GetParameters(cdfs_parameters_t *params,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!params)
		return ERROR(BadArgs);
	/* Perform MODE SENSE 10 to get list of mode pages */
	uint32_t result;
	_kernel_oserror *e = ModeSense(PageCode_All,&result,blk,retries);
	if(e)
		return e;
	uint8_t *page;
	/* Find page 0x0d for inactivity timer multiplier */
	page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_CDDeviceParameters);
	if(!page)
	{
		dprintf(("", " Couldn't find page 0x0d\n"));
		/* This is a legacy page which may not be implemented
		   TODO - Find an alternative!
		   For now just fudge it */
		params->inactivitytimermultiplier = 0;
	}
	else if(MODEPAGEHDR_PageLength_Read(page) < 0x06)
	{
		dprintf(("", " Unexpected 0x0d page length\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	else
	{
		params->inactivitytimermultiplier = MODEPAGE_CDDP_InactivityTimerMultiplier_Read(page);
	}
	/* Find page 0x01 for read retry count */
	page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_ReadWriteErrorRecovery);
	if(!page)
	{
		dprintf(("", " Couldn't find page 0x01\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	else if(MODEPAGEHDR_PageLength_Read(page) < 0x06)
	{
		dprintf(("", " Page 0x01 is shorter than both 0x06 & 0x0A variants\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	params->readretrycount = MODEPAGE_RWER_ReadRetryCount_Read(page); /* Common offset in both forms */
#if 0
	/* Find page 0x2a for speed setting */
	page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_MMCapabilitiesAndMechanicalStatus);
	if(!page)
	{
		dprintf(("", " Couldn't find page 0x2a\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	else if(MODEPAGEHDR_PageLength_Read(page) < 28)
	{
		dprintf(("", " Unexpected 0x2a page length\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	params->speed = SCSI_READBYTES2(page,14)/176; /* XXX obsolete! */
#else
	/* TODO - The CD speed field in mode page 0x2a seems to be obsolete.
	   Looks like we need to use a combination of GET PERFORMANCE and SET CD SPEED instead.
	   For now, just return a speed of 0. */
	params->speed = 0;
#endif
	/* Get the current data mode */
	params->datamode = GetDataMode(blk);

	return NULL;
}

static _kernel_oserror *driver_SetParameters(const cdfs_parameters_t *params,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!params)
		return ERROR(BadArgs);
	/* Set each page individually, since there's only two of them */
	SCSI_CREATEBLOCK(SCB,MODESELECT,10);
	MODESELECT10_PF_Write(SCB,1);
	uint32_t result;
	uint32_t result2;
	uint8_t *page;
	_kernel_oserror *e;
	/* Inactivity timer multiplier */
	e = ModeSense(PageCode_CDDeviceParameters,&result,blk,retries);
	if(e)
	{
		/* Illegal request will be returned if the page doesn't exist; ignore it */
		if(e->errnum != ErrorNumber_SCSI_CC_IllegalRequest)
			return e;
		dprintf(("", " Couldn't request page 0x0d\n"));
	}
	else
	{
		page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_CDDeviceParameters);
		if(!page)
		{
			dprintf(("", " Couldn't find page 0x0d\n"));
			/* This is a legacy page which may not be implemented
			   TODO - Find an alternative
			   For now, just ignore */
		}
		else if(MODEPAGEHDR_PageLength_Read(page) < 0x06)
		{
			dprintf(("", " Unexpected 0x0d page length\n"));
			DumpBlock(SCSIOp_MiscBuffer,result);
			return ERROR(BadResponse);
		}
		else
		{
			MODEPAGE_CDDP_InactivityTimerMultiplier_Write(page,params->inactivitytimermultiplier);
			/* Update device */
			MODESELECT10_ParamListLength_Write(SCB,result);
			e = DoSCSIOp(SCSIOP_WRITE|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,result,0,&result2,blk,retries);
			if(e)
			{
				/* Illegal request will be returned if the field(s) are read-only. Ignore it. */
				if(e->errnum != ErrorNumber_SCSI_CC_IllegalRequest)
					return e;
				dprintf(("", " Looks like inactivity timer multiplier is read-only\n"));
			}
			else if(result2 != result)
			{
				dprintf(("", " Device didn't accept all the data! (CDDeviceParameters)\n"));
				return ERROR(BadResponse);
			}
		}
	}
	/* Read retry count */
	e = ModeSense(PageCode_ReadWriteErrorRecovery,&result,blk,retries);
	if(e)
		return e;
	page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_ReadWriteErrorRecovery);
	if(!page)
	{
		dprintf(("", " Couldn't find page 0x01\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	else if(MODEPAGEHDR_PageLength_Read(page) < 0x06)
	{
		dprintf(("", " Page 0x01 is shorter than both 0x06 & 0x0A variants\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	MODEPAGE_RWER_ReadRetryCount_Write(page,params->readretrycount); /* Common offset in both forms */
	/* Update device */
	MODESELECT10_ParamListLength_Write(SCB,result);
	e = DoSCSIOp(SCSIOP_WRITE|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,result,0,&result2,blk,retries);
	if(e)
	{
		/* Illegal request will be returned if the field(s) are read-only. Ignore it. */
		if(e->errnum != ErrorNumber_SCSI_CC_IllegalRequest)
			return e;
		dprintf(("", " Looks like read retry count is read-only\n"));
	}
	else if(result2 != result)
	{
		dprintf(("", " Device didn't accept all the data! (ReadWriteErrorRecovery)\n"));
		return ERROR(BadResponse);
	}
	SetDataMode(params->datamode,blk);
	return NULL;
}

static _kernel_oserror *driver_EjectButton(uint32_t prevent,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(prevent > 1)
		return ERROR(BadArgs);
	SCSI_CREATEBLOCK(SCB,PREVENTALLOW,6);
	PREVENTALLOW6_Prevent_Write(SCB,prevent);
	_kernel_oserror *e = DoSCSIOp(SCSIOP_NODATA|SCSIOP_NOESCAPE,SCB,sizeof(SCB),NULL,0,0,NULL,blk,retries);
	if(!e)
		SetDrawerStatus(blk,prevent);
	return e;
}

static _kernel_oserror *driver_EnquireAddress(AddrMode mode,uint32_t *addr,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Use READ SUB CHANNEL to get the current address */
	_kernel_oserror *e = ReadSubChannel(blk,retries);
	if(e)
		return e;
	uint32_t temp = SUBQ_CDPOS_AbsoluteAddr_Read(SCSIOp_MiscBuffer+4);
	switch(mode)
	{
	case AddrMode_LBA:
		*addr = temp;
		return NULL;
	case AddrMode_MSF:
		return _swix(CD_ConvertToMSF,_INR(0,1)|_IN(7)|_OUT(1),AddrMode_LBA,temp+PBA_OFFSET,blk,addr);
	case AddrMode_PBA:
		*addr = temp + PBA_OFFSET;
		return NULL;
	default:
		return ERROR(BadArgs);
	}
}

static _kernel_oserror *driver_EnquireDataMode(AddrMode mode,uint32_t addr,DataMode *datamode,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Convert address to LBA */
	_kernel_oserror *e = _swix(CD_ConvertToLBA,_INR(0,1)|_IN(7)|_OUT(1),mode,addr,blk,&addr);
	if(e)
		return e;
	/* There are two commands for finding the track type - READ HEADER (MMC 1, CD only), and READ TRACK INFORMATION (MMC 2+, or MMC 1 for CD-R/RW)
	   Try using READ TRACK INFORMATION first, then fall back to READ HEADER if it fails (mostly likely due to being an old drive) */
	e = ReadTrackInformation(addr,datamode,blk,retries);
	if(e && (e->errnum == ErrorNumber_SCSI_CC_IllegalRequest))
	{
		/* Try READ HEADER */
		e = ReadHeader(addr,datamode,blk,retries);
	}
	if(e)
		return e;
	/* Mode2Form1 will have been returned if it's a mode 2 sector (any type).
	   So if that's the case, we'll need to do some extra work to determine whether it's form 1 or 2 */
	if(*datamode != DataMode_Data2Form1)
		return NULL;
	SCSI_CREATEBLOCK(SCB,READCD,12);
	READCD12_StartLBA_Write(SCB,addr);
	READCD12_Length_Write(SCB,1);
	/* Return full info */
	READCD12_EDC_ECC_Write(SCB,1);
	READCD12_UserData_Write(SCB,1);
	READCD12_HeaderCodes_Write(SCB,3);
	READCD12_SYNC_Write(SCB,1);
	uint32_t result;
	e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,2352,0,&result,blk,retries);
	if(e)
		return e;
	if(result != 2352)
	{
		dprintf((""," READCD only returned %d bytes!\n",result));
		return ERROR(BadResponse);
	}
	if(SCSIOp_MiscBuffer[12+4+2] & (1<<5)) /* Check submode field of mode 2 sub header */
	{
		dprintf((""," Is data 2 form 2\n"));
		*datamode = DataMode_Data2Form2;
	}
	else
	{
		dprintf((""," Is data 2 form 1\n"));
		*datamode = DataMode_Data2Form1;
	}
	return NULL;
}

static _kernel_oserror *driver_PlayAudio(AddrMode mode,uint32_t start,uint32_t end,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Convert addresses to LBA */
	_kernel_oserror *e = _swix(CD_ConvertToLBA,_INR(0,1)|_IN(7)|_OUT(1),mode,start,blk,&start);
	if(e)
		return e;
	e = _swix(CD_ConvertToLBA,_INR(0,1)|_IN(7)|_OUT(1),mode,end,blk,&end);
	if(e)
		return e;
	if(end < start)
		return ERROR(BadArgs);
	/* Issue PLAY AUDIO 12 */
	SCSI_CREATEBLOCK(SCB,PLAYAUDIO,12);
	PLAYAUDIO12_LBA_Write(SCB,start);
	PLAYAUDIO12_PlayLength_Write(SCB,end-start);
	return DoSCSIOp(SCSIOP_NODATA|SCSIOP_NOESCAPE,SCB,sizeof(SCB),NULL,0,0,NULL,blk,retries);
}

static _kernel_oserror *driver_AudioPause(uint32_t pause,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(pause > 1)
		return ERROR(BadArgs);
	_kernel_oserror *e = ReadSubChannel(blk,retries);
	if(e)
		return e;
	SubQ_AudioStatus status = SUBQHEADER_AudioStatus_Read(SCSIOp_MiscBuffer);
	if((status == SubQ_AudioStatus_Paused) && (pause == 1))
	{
		/* Do nothing */
		return NULL;
	}
	if((status == SubQ_AudioStatus_Playing) && (pause == 0))
	{
		/* Do nothing */
		return NULL;
	}
	if(pause)
	{
		/* Pause playback */
		SCSI_CREATEBLOCK(SCB,PAUSERESUME,10);
		return DoSCSIOp(SCSIOP_NODATA|SCSIOP_NOESCAPE,SCB,sizeof(SCB),NULL,0,0,NULL,blk,retries);
	}
	else
	{
		/* Play to end of disc */
		uint32_t start = SUBQ_CDPOS_AbsoluteAddr_Read(SCSIOp_MiscBuffer+4);
		cdfs_discused_t disc;
		e = _swix(CD_DiscUsed,_INR(0,1)|_IN(7),AddrMode_LBA,&disc,blk);
		if(e)
			return e;
		return driver_PlayAudio(AddrMode_LBA,start,disc.discsize,blk,retries);
	}
}

static _kernel_oserror *driver_EnquireTrackRange(cdfs_trackrange_t *range,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Note: 'range' guaranteed non-null by driver_code() */
	SCSI_CREATEBLOCK(SCB,READTOC,10);
	READTOC10_Track_Write(SCB,1);
	READTOC10_AllocationLength_Write(SCB,12);
	uint32_t result;
	_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,12,0,&result,blk,retries);
	if(e)
		return e;
	if(result != 12)
	{
		dprintf((""," READTOC only returned %d bytes!\n",result));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	range->first = READTOCRESPONSE_FirstTrack_Read(SCSIOp_MiscBuffer);
	range->last = READTOCRESPONSE_LastTrack_Read(SCSIOp_MiscBuffer);
	return NULL;
}

static _kernel_oserror *driver_EnquireTrackInfo(uint32_t track,cdfs_trackinfo_t *info,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Note: 'track' and 'info' guaranteed valid by driver_code() */
	SCSI_CREATEBLOCK(SCB,READTOC,10);
	READTOC10_Track_Write(SCB,track);
	READTOC10_AllocationLength_Write(SCB,12);
	uint32_t result;
	_kernel_oserror *e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,12,0,&result,blk,retries);
	if(e)
	{
		/* Convert IllegalRequest into NotSuchTrack error */
		if(e->errnum == ErrorNumber_SCSI_CC_IllegalRequest)
		{
			return ERROR(NoSuchTrack);
		}
		return e;
	}
	if(result != 12)
	{
		dprintf((""," READTOC only returned %d bytes!\n",result));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	info->startlba = READTOCRESPONSE_StartLBA_Read(SCSIOp_MiscBuffer);
	info->flags = READTOCRESPONSE_Control_Read(SCSIOp_MiscBuffer)>>2;
	return NULL;
}

static _kernel_oserror *driver_PlayTrack(uint32_t start,uint32_t end,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!start || (start > 99) || ((end != PLAY_TO_END_OF_TRACK) && (end != PLAY_TO_END_OF_CD)))
		return ERROR(BadArgs);
	/* TODO - Why does the StrongHelp manual suggest you can play up to a certain track? */

	/* Read the info of the first track */
	cdfs_trackinfo_t first;
	_kernel_oserror *e = driver_EnquireTrackInfo(start,&first,blk,retries);
	if(e)
		return e;
	/* Read the info of the last track */
	if(end == PLAY_TO_END_OF_CD)
		end = 0xaa;
	else if(start > READTOCRESPONSE_LastTrack_Read(SCSIOp_MiscBuffer))
		return ERROR(NoSuchTrack);
	else if(start == READTOCRESPONSE_LastTrack_Read(SCSIOp_MiscBuffer))
		end = 0xaa;
	else
		end = start+1;
	cdfs_trackinfo_t last;
	e = driver_EnquireTrackInfo(end,&last,blk,retries);
	if(e)
		return e;
	/* Now play */
	return driver_PlayAudio(AddrMode_LBA,first.startlba,last.startlba,blk,retries);
}

static _kernel_oserror *driver_ReadSubChannel(uint32_t subchannel,cdfs_readsubchannel_t *info,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Note: subchannel 64 corresponds to the SUBQ bit in the CDB */
	if((subchannel != 64) || !info)
		return ERROR(BadArgs);
	_kernel_oserror *e = ReadSubChannel(blk,retries);
	if(e)
		return e;
	/* Transfer the data to the cdfs_readsubchannel_t */
	info->trackrelativeaddr = SUBQ_CDPOS_RelativeAddr_Read(SCSIOp_MiscBuffer+4);
	info->absoluteaddr = SUBQ_CDPOS_AbsoluteAddr_Read(SCSIOp_MiscBuffer+4);
	info->flags = SUBQ_CDPOS_CONTROL_Read(SCSIOp_MiscBuffer+4);
	info->track = SUBQ_CDPOS_Track_Read(SCSIOp_MiscBuffer+4);
	info->index = SUBQ_CDPOS_Index_Read(SCSIOp_MiscBuffer+4);
	return NULL;
}

static _kernel_oserror *driver_DiscChanged(uint32_t *changed,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!changed)
		return ERROR(BadArgs);
	SCSI_CREATEBLOCK(SCB,TESTUNITREADY,6);
	_kernel_oserror *e = DoSCSIOp(SCSIOP_NODATA|SCSIOP_NOESCAPE,SCB,sizeof(SCB),NULL,0,0,NULL,blk,retries);
	if(!e)
		*changed = HasDiscChanged(blk);
	return e;
}

static _kernel_oserror *driver_AudioStatus(AudioStatus *status,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!status)
		return ERROR(BadArgs);
	_kernel_oserror *e = ReadSubChannel(blk,retries);
	if(e)
		return e;
	/* Process the audio status */
	switch(SUBQHEADER_AudioStatus_Read(SCSIOp_MiscBuffer))
	{
	case SubQ_AudioStatus_Playing:
		*status = AudioStatus_Playing;
		break;
	case SubQ_AudioStatus_Paused:
		*status = AudioStatus_Paused;
		break;
	case SubQ_AudioStatus_Complete:
		*status = AudioStatus_Complete;
		break;
	case SubQ_AudioStatus_Error:
		*status = AudioStatus_Error;
		break;
	default:
		*status = AudioStatus_Idle;
		break;
	}
	return NULL;
}

static _kernel_oserror *driver_DiscHasChanged(const cdfs_ctl_block_t *blk,uint32_t retries)
{
	(void) retries;
	SetDiscChanged(blk);
	return NULL;
}

static _kernel_oserror *driver_Supported(uint32_t *flags,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* TODO - return number of speeds supported by drive? */
	/* TODO - query drive for whether these are actually supported */
	(void)blk;
	(void)retries;
	*flags = SUPPORTED_PREFETCH | SUPPORTED_CLOSEDRAWER | SUPPORTED_AUDIOLEVEL | SUPPORTED_READAUDIO | SUPPORTED_GETSETAUDIOPARMS | (255<<6);
	return NULL;
}

static _kernel_oserror *driver_CloseDrawer(const cdfs_ctl_block_t *blk,uint32_t retries)
{
	SCSI_CREATEBLOCK(SCB,STARTSTOPUNIT,6);
	/* Immediately close drawer & load disc */
	STARTSTOPUNIT6_IMMED_Write(SCB,1);
	STARTSTOPUNIT6_Start_Write(SCB,1);
	STARTSTOPUNIT6_LoEj_Write(SCB,1);
	return DoSCSIOp(SCSIOP_NODATA|SCSIOP_NOESCAPE,SCB,sizeof(SCB),NULL,0,0,NULL,blk,retries);
}

static _kernel_oserror *driver_IsDrawerLocked(uint32_t *locked,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!locked)
		return ERROR(BadArgs);
	/* Perform MODE SENSE 10 to get list of mode pages */
	uint32_t result;
	_kernel_oserror *e = ModeSense(PageCode_All,&result,blk,retries);
	if(e)
		return e;
	uint8_t *page;
	/* Find page 0x2a for lock setting */
	page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_MMCapabilitiesAndMechanicalStatus);
	if(!page)
	{
		dprintf(("", " Couldn't find page 0x2a\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
	}
	else if(MODEPAGEHDR_PageLength_Read(page) < 28)
	{
		dprintf(("", " Unexpected 0x2a page length\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
	}
	else
	{
		/* Page found, use it to update our softcopy of the lock state */
		dprintf(("", " Locking flags: %x\n",page[6] & 3));
		SetDrawerStatus(blk,page[6] & 2);
	}
	/* Return softcopy of the state (which will be the real state, if the drive supports the relevant mode page. Else assume lock state has remained the same as when we last set it) */
	*locked = GetDrawerStatus(blk);
	return e;
}

static _kernel_oserror *driver_Identify(const uint8_t *inquiry,DriveType *type,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	(void)blk;
	(void)retries;
	*type = DriveType_Unknown;
	/* Check the first byte of the inquiry result to see if this is an MMC device */
#if defined(DEBUGLIB)
	if(inquiry)
	{
		dprintf((""," Inquiry response data:\n"));
		DumpBlock(inquiry,36);
	}
#endif
	if(inquiry && (*inquiry == 5)) /* Peripheral device type = MMC, peripheral qualifier = 0 */
	{
		/* TODO - More checks, e.g. conformance to specific standards versions, features/page codes, etc.
		   For now, just accept any MMC device and hope for the best */
		*type = DriveType_MMC;
		dprintf((""," Detected DriveType_MMC\n"));
		return NULL;
	}
	return NULL;
}

static _kernel_oserror *driver_ReadAudio(AddrMode mode,uint32_t start,uint32_t length,void *buffer,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!buffer)
		return ERROR(BadArgs);
	/* Convert start address to LBA */
	_kernel_oserror *e = _swix(CD_ConvertToLBA,_INR(0,1)|_IN(7)|_OUT(1),mode,start,blk,&start);
	if(e)
		return e;
	/* Calculate byte length of data */
	uint64_t bytelength = ((uint64_t)length)*2352;
	if(bytelength >= 0x100000000) /* Too big to fit in RAM! */
		return ERROR(BadArgs);
	SCSI_CREATEBLOCK(SCB,READCD,12);
#if 0
	/* Leave DAP disabled for now - some drives complain about it, and
	   simply retrying the op with DAP disabled can cause problems too
	   (although that might be a SCSISoftUSB bug?) */
	READCD12_DAP_Write(SCB,1); /* Enable DAP */
#endif
	READCD12_ExpSectorType_Write(SCB,1); /* CD-DA */
	READCD12_StartLBA_Write(SCB,start);
	READCD12_Length_Write(SCB,length);
	READCD12_UserData_Write(SCB,1);
	e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),buffer,(uint32_t) bytelength,0,NULL,blk,retries); /* TODO allow escape? */
	/* Convert IllegalRequest into NotAudio error */
	if(e && (e->errnum == ErrorNumber_SCSI_CC_IllegalRequest))
	{
		return ERROR(NotAudio);
	}
	/* TODO error if not enough data returned? */ 
	return e;
}

static _kernel_oserror *driver_GetAudioParms_VolumeLevels(cdfs_audioparm_vollevels_t *levels,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!levels)
		return ERROR(BadArgs);
	/* Get the current parameters */
	uint32_t result;
	_kernel_oserror *e = ModeSense(PageCode_CDAudioControl,&result,blk,retries);
	if(e)
		return e;
	uint8_t *page;
	/* Find the page */
	page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_CDAudioControl);
	if(!page)
	{
		dprintf(("", " Couldn't find page 0x0e\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	else if(MODEPAGEHDR_PageLength_Read(page) < 0x0e)
	{
		dprintf(("", " Unexpected 0x0e page length\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	/* Return the volume levels, scaled up to 16 bit
	   This assumes the channels are mapped sensibly! */
	levels->volumes[0] = MODEPAGE_CDAC_Port0Volume_Read(page)*0x101;
	levels->volumes[1] = MODEPAGE_CDAC_Port1Volume_Read(page)*0x101;
	return NULL;
}

static _kernel_oserror *driver_SetAudioParms_VolumeLevels(const cdfs_audioparm_vollevels_t *levels,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!levels)
		return ERROR(BadArgs);
	if((levels->volumes[0] >= 0x10000) || (levels->volumes[1] >= 0x10000))
		return ERROR(BadArgs);
	/* Read the current parameters */
	uint32_t result;
	_kernel_oserror *e = ModeSense(PageCode_CDAudioControl,&result,blk,retries);
	if(e)
		return e;
	uint8_t *page;
	/* Find the page */
	page = FindModePage(SCSIOp_MiscBuffer+8,result-8,PageCode_CDAudioControl);
	if(!page)
	{
		dprintf(("", " Couldn't find page 0x0e\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	else if(MODEPAGEHDR_PageLength_Read(page) < 0x0e)
	{
		dprintf(("", " Unexpected 0x0e page length\n"));
		DumpBlock(SCSIOp_MiscBuffer,result);
		return ERROR(BadResponse);
	}
	/* Write the new values */
	MODEPAGE_CDAC_Port0Volume_Write(page,levels->volumes[0]>>8);
	MODEPAGE_CDAC_Port1Volume_Write(page,levels->volumes[1]>>8);
	/* Issue MODE SELECT to update the device */
	SCSI_CREATEBLOCK(SCB,MODESELECT,10);
	MODESELECT10_PF_Write(SCB,1);
	MODESELECT10_ParamListLength_Write(SCB,result);
	uint32_t result2;
	e = DoSCSIOp(SCSIOP_WRITE|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,result,0,&result2,blk,retries);
	if(e)
		return e;
	if(result2 != result)
	{
		dprintf(("", " Device didn't accept all the data!\n"));
		return ERROR(BadResponse);
	}
	return NULL;
}

static _kernel_oserror *driver_ReadData(AddrMode mode,uint32_t start,uint32_t numblock,uint8_t *dest,uint32_t blocksize,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	if(!dest)
		return ERROR(BadArgs);
	/* Convert to LBA address */
	_kernel_oserror *e = _swix(CD_ConvertToLBA,_INR(0,1)|_IN(7)|_OUT(1),mode,start,blk,&start);
	if(e)
		return e;
	DataMode datamode = GetDataMode(blk);
	dprintf((""," Reading %d blocks (%d each) from %08x to %08x. Data mode %d\n",numblock,blocksize,start,(uint32_t) dest,datamode));
	/* Multisession PhotoCD fix (from CDFSSoftATAPI):
	   When reading the PVD, adjust the address to be within the last session */
	if(start <= 16)
	{
		dprintf(("","  Performing PhotoCD correction\n"));
		/* TODO - ATAPI code for this is highly suspect. It sets bit 6 of the Control field (i.e. one of the vendor-specific bits) and ends up requesting the address of track 0. Really it should be setting the format field to 1, thus selecting the start address of the last session? */
		SCSI_CREATEBLOCK(SCB,READTOC,10);
		READTOC10_Format_Write(SCB,1);
		READTOC10_AllocationLength_Write(SCB,12);
		uint32_t result;
		e = DoSCSIOp(SCSIOP_READ|SCSIOP_NOESCAPE,SCB,sizeof(SCB),SCSIOp_MiscBuffer,12,0,&result,blk,retries);
		if(e)
			return e;
		if(result != 12)
		{
			dprintf(("","  READTOC only returned %d bytes!\n",result));
			DumpBlock(SCSIOp_MiscBuffer,result);
			return ERROR(BadResponse);
		}
		dprintf(("","  Applying offset of %08x\n",READTOCRESPONSE_StartLBA_Read(SCSIOp_MiscBuffer)));
		start += READTOCRESPONSE_StartLBA_Read(SCSIOp_MiscBuffer);
	}
	if(numblock != 1)
	{
		/* Multiple blocks; read straight to dest buffer */
		if(blocksize != BlockSizes[datamode])
			return ERROR(BadArgs);
		return ReadData(start,numblock,dest,blk,retries);
	}
	else
	{
		/* Read into temp buffer, then copy out */
		e = ReadData(start,1,SCSIOp_MiscBuffer,blk,retries);
		if(e)
			return e;
		memcpy(dest,SCSIOp_MiscBuffer,blocksize);
	}
	return NULL;
}

static _kernel_oserror *driver_Prefetch(AddrMode mode,uint32_t block,const cdfs_ctl_block_t *blk,uint32_t retries)
{
	/* Just do what CD_ReadData does and read to some scratch memory */
	return driver_ReadData(mode,block,1,SCSIOp_MiscBuffer,0,blk,retries);
}

#ifdef DEBUGLIB
static const char *op_names[] = {
	"ReadData",
	"SeekTo",
	"DriveStatus",
	"DriveReady",
	"GetParameters",
	"SetParameters",
	"OpenDrawer",
	"EjectButton",
	"EnquireAddress",
	"EnquireDataMode",
	"PlayAudio",
	"PlayTrack",
	"AudioPause",
	"EnquireTrack",
	"ReadSubChannel",
	"CheckDrive",
	"DiscChanged",
	"StopDisc",
	"DiscUsed",
	"AudioStatus",
	"Inquiry",
	"DiscHasChanged",
	"Control",
	"Supported",
	"Prefetch",
	"Reset",
	"CloseDrawer",
	"IsDrawerLocked",
	"AudioControl",
	"AudioLevel",
	"Identify",
	"ReadAudio",
	"ReadUserData",
	"SeekUserData",
	"GetAudioParms",
	"SetAudioParms",
	"SCSIUserOp",
	"???",
};

/* Wrap driver_code so we can easily report any errors */
static _kernel_oserror *driver_code_int(_kernel_swi_regs *r,void *pw);

_kernel_oserror *driver_code(_kernel_swi_regs *r,void *pw)
{
	_kernel_oserror *e = driver_code_int(r,pw);
	if(e)
		dprintf(("","driver_code: Returning error %x %s\n",e->errnum,e->errmess));
	return e;
}

static _kernel_oserror *driver_code_int(_kernel_swi_regs *r,void *pw)
#else
_kernel_oserror *driver_code(_kernel_swi_regs *r,void *pw)
#endif
{
	(void)pw;
	/* Called with:
	   r0-r6 = CD_ SWI params
	   r7 = CD_ SWI control block
	   r8 = Operation
	   r9 = Retry count
	*/
	const cdfs_ctl_block_t *blk = (const cdfs_ctl_block_t *) r->r[7];
	if(!blk)
		return ERROR(BadArgs);
	dprintf(("","driver_code: Op %s (%d) on %d:%d.%d\n",op_names[((uint32_t)r->r[8]) < CDOp_MAX?r->r[8]:CDOp_MAX],r->r[8],blk->card,blk->device,blk->lun));

	switch(r->r[8])
	{
	case CDOp_GetParameters:
		return driver_GetParameters((cdfs_parameters_t *) r->r[0],blk,r->r[9]);

	case CDOp_SetParameters:
		return driver_SetParameters((const cdfs_parameters_t *) r->r[0],blk,r->r[9]);

	case CDOp_EjectButton:
		return driver_EjectButton(r->r[0],blk,r->r[9]);

	case CDOp_EnquireAddress:
		return driver_EnquireAddress((AddrMode) r->r[0],(uint32_t *) &r->r[0],blk,r->r[9]);

	case CDOp_EnquireDataMode:
		return driver_EnquireDataMode((AddrMode) r->r[0],r->r[1],(DataMode *) &r->r[0],blk,r->r[9]);

	case CDOp_PlayAudio:
		return driver_PlayAudio((AddrMode) r->r[0],r->r[1],r->r[2],blk,r->r[9]);

	case CDOp_PlayTrack:
		return driver_PlayTrack(r->r[0],r->r[1],blk,r->r[9]);

	case CDOp_AudioPause:
		return driver_AudioPause(r->r[0],blk,r->r[9]);

	case CDOp_EnquireTrack:
		if(!r->r[1])
			return ERROR(BadArgs);
		if(!r->r[0])
			return driver_EnquireTrackRange((cdfs_trackrange_t *) r->r[1],blk,r->r[9]);
		else if(((uint32_t)r->r[0]) >= 100)
			return ERROR(BadArgs);
		else
			return driver_EnquireTrackInfo(r->r[0],(cdfs_trackinfo_t *) r->r[1],blk,r->r[9]);

	case CDOp_ReadSubChannel:
		return driver_ReadSubChannel(r->r[0],(cdfs_readsubchannel_t *) r->r[1],blk,r->r[9]);

	case CDOp_DiscChanged:
		return driver_DiscChanged((uint32_t *) &r->r[0],blk,r->r[9]);

	case CDOp_AudioStatus:
		return driver_AudioStatus((AudioStatus *) &r->r[0],blk,r->r[9]);

	case CDOp_DiscHasChanged:
		return driver_DiscHasChanged(blk,r->r[9]);

	case CDOp_Supported:
		return driver_Supported((uint32_t *) &r->r[0],blk,r->r[9]);

	case CDOp_CloseDrawer:
		return driver_CloseDrawer(blk,r->r[9]);

	case CDOp_IsDrawerLocked:
		return driver_IsDrawerLocked((uint32_t *) &r->r[0],blk,r->r[9]);

	case CDOp_Identify:
		return driver_Identify((const uint8_t *) r->r[0],(DriveType *) &r->r[2],blk,r->r[9]);

	case CDOp_ReadAudio:
		return driver_ReadAudio((AddrMode) r->r[0],r->r[1],r->r[2],(void *) r->r[3],blk,r->r[9]);

	case CDOp_GetAudioParms:
		switch((AudioParm) r->r[0])
		{
		case AudioParm_VolumeLevels:
			return driver_GetAudioParms_VolumeLevels((cdfs_audioparm_vollevels_t *) r->r[1],blk,r->r[9]);
		default:
			r->r[0] = -1;
			return NULL;
		}

	case CDOp_SetAudioParms:
		switch((AudioParm) r->r[0])
		{
		case AudioParm_VolumeLevels:
			return driver_SetAudioParms_VolumeLevels((const cdfs_audioparm_vollevels_t *) r->r[1],blk,r->r[9]);
		default:
			r->r[0] = -1;
			return NULL;
		}

	case CDOp_Prefetch:
		return driver_Prefetch((AddrMode) r->r[0],r->r[1],blk,r->r[9]);

	case CDOp_ReadData:
		return driver_ReadData((AddrMode) r->r[0],r->r[1],r->r[2],(uint8_t *) r->r[3],r->r[4],blk,r->r[9]);

	/* These should be handled by the default routines in CDFSDriver */
	case CDOp_SeekTo:
	case CDOp_Inquiry:
	case CDOp_DiscUsed:
	case CDOp_DriveReady:
	case CDOp_StopDisc:
	case CDOp_OpenDrawer:
	case CDOp_DriveStatus:
	case CDOp_Control:
	case CDOp_Reset:
	case CDOp_CheckDrive:
	case CDOp_SCSIUserOp:
	case CDOp_ReadUserData:
	case CDOp_SeekUserData:
		dprintf(("","Unexpected call - should be handled by CDFSDriver\n"));

	default:
	case CDOp_AudioControl: /* ???? */
	case CDOp_AudioLevel: /* ???? */
		dprintf(("","Unsupported call\n"));
		return ERROR(Unsupported);
	}

	return NULL;
}
