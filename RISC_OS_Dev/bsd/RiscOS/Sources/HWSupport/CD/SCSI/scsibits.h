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
#ifndef CDFSSOFTSCSI_SCSIBITS_H
#define CDFSSOFTSCSI_SCSIBITS_H

/* Definitions of things relating to the SCSI interface */

#include <stdint.h>

/* SCSI operations */

typedef enum {
	SCSIOp_MODESENSE6 = 0x1a,
	SCSIOp_STARTSTOPUNIT6 = 0x1b,
	SCSIOp_MODESELECT10 = 0x55,
	SCSIOp_MODESENSE10 = 0x5a,
	SCSIOp_PREVENTALLOW6 = 0x1e,
	SCSIOp_TESTUNITREADY6 = 0x00,
	SCSIOp_PLAYAUDIO12 = 0xa5,
	SCSIOp_READSUBCHANNEL10 = 0x42,
	SCSIOp_READCD12 = 0xbe,
	SCSIOp_READHEADER10 = 0x44,
	SCSIOp_READTOC10 = 0x43,
	SCSIOp_PAUSERESUME10 = 0x4b,
	SCSIOp_READTRACKINFORMATION10 = 0x52,
	SCSIOp_READ10 = 0x28,
} SCSIOp;

/* SCSI_Op params */

#define SCSIOP_NODATA		(0<<24)
#define SCSIOP_READ		(1<<24)
#define SCSIOP_WRITE		(2<<24)
#define SCSIOP_SCATTER		(1<<26)
#define SCSIOP_NOESCAPE		(1<<27)
#define SCSIOP_RETRY		(1<<28)
#define SCSIOP_BACKGROUND	(1<<29)

#define SCSI_ACCESSKEY	0xCD

/* Macros to read/write members of SCSI structures */

/* Read a number of bytes from the given block */
static inline uint32_t SCSI_READBYTES1(const uint8_t *block,uint32_t byteoffset)
{
	return block[byteoffset];
}

static inline uint32_t SCSI_READBYTES2(const uint8_t *block,uint32_t byteoffset)
{
	block += byteoffset;
	return (((uint32_t) block[0])<<8) | block[1];
}

static inline uint32_t SCSI_READBYTES3(const uint8_t *block,uint32_t byteoffset)
{
	block += byteoffset;
	return (((uint32_t) block[0])<<16) | (((uint32_t) block[1])<<8) | block[2];
}

static inline uint32_t SCSI_READBYTES4(const uint8_t *block,uint32_t byteoffset)
{
	block += byteoffset;
	return (((uint32_t) block[0])<<24) | (((uint32_t) block[1])<<16) | (((uint32_t) block[2])<<8) | block[3];
}

/* Write a number of bytes to a given block */
static inline void SCSI_WRITEBYTES1(uint8_t *block,uint32_t byteoffset,uint32_t val)
{
	block[byteoffset] = val;
}

static inline void SCSI_WRITEBYTES2(uint8_t *block,uint32_t byteoffset,uint32_t val)
{
	block += byteoffset;
	block[0] = val>>8;
	block[1] = val;
}

static inline void SCSI_WRITEBYTES3(uint8_t *block,uint32_t byteoffset,uint32_t val)
{
	block += byteoffset;
	block[0] = val>>16;
	block[1] = val>>8;
	block[2] = val;
}

static inline void SCSI_WRITEBYTES4(uint8_t *block,uint32_t byteoffset,uint32_t val)
{
	block += byteoffset;
	block[0] = val>>24;
	block[1] = val>>16;
	block[2] = val>>8;
	block[3] = val;
}

/* Read a number of bits from the given block */
static inline uint32_t SCSI_READBITS(const uint8_t *block,uint32_t byteoffset,uint32_t bitoffset,uint32_t count)
{
	uint32_t byte = block[byteoffset];
	byte >>= bitoffset;
	return byte & ((1<<count)-1);
}

/* Write a number of bits to the given block */
static inline void SCSI_WRITEBITS(uint8_t *block,uint32_t byteoffset,uint32_t bitoffset,uint32_t count,uint32_t val)
{
	block += byteoffset;
	uint32_t mask = ((1<<count)-1)<<bitoffset;
	uint32_t byte = *block;
	val <<= bitoffset;
	*block = (byte & ~mask) | (val & mask);
}

/* Macros for definining struct members
   These define _Read and _Write functions */

/* Bit-wide members */
#define SCSI_DEFINEBITS(S,N,BYTE,BIT,C,DT) \
static inline DT S ## _ ## N ## _Read(const uint8_t *block) { return (DT) SCSI_READBITS(block,BYTE,BIT,C); } \
static inline void S ## _ ## N ## _Write(uint8_t *block,DT val) { SCSI_WRITEBITS(block,BYTE,BIT,C,(uint32_t) val); }

/* Byte-wide members */
#define SCSI_DEFINEBYTES(S,N,BYTE,C,DT) \
static inline DT S ## _ ## N ## _Read(const uint8_t *block) { return (DT) SCSI_READBYTES ## C (block,BYTE); } \
static inline void S ## _ ## N ## _Write(uint8_t *block,DT val) { SCSI_WRITEBYTES ## C (block,BYTE,(uint32_t) val); }

/* Byte arrays - Just returns a pointer to the raw data */
#define SCSI_DEFINEARRAY(S,N,BYTE,C) \
static inline const uint8_t * S ## _ ## N ## _Read(const uint8_t *block) { return block+BYTE; } \
static inline uint8_t * S ## _ ## N ## _Write(uint8_t *block) { return block+BYTE; }

/* Macro for creating a command block for the specified Op & LUN */
#if 0
#define SCSI_CREATEBLOCK(B,OP,SIZE) \
uint8_t B[SIZE]; \
memset(B,0,SIZE); \
OP ## SIZE ## _Op_Write(B,SCSIOp_ ## OP ## SIZE); \
OP ## SIZE ## _LUN_Write(B,blk->lun)
#else
/* LUN field is dead, don't write to it */
#define SCSI_CREATEBLOCK(B,OP,SIZE) \
uint8_t B[SIZE]; \
memset(B,0,SIZE); \
OP ## SIZE ## _Op_Write(B,SCSIOp_ ## OP ## SIZE)
#endif

/* MODE SENSE 6 & 10 commands */

typedef enum {
	PageControl_Current=0,
	PageControl_Changeable=1,
	PageControl_Default=2,
	PageControl_Saved=3,
} PageControl;

typedef enum {
	PageCode_ReadWriteErrorRecovery=0x01,
	PageCode_CDDeviceParameters=0x0d,
	PageCode_CDAudioControl=0x0e,
	PageCode_MMCapabilitiesAndMechanicalStatus=0x2a,

	PageCode_All = 0x3f,
} PageCode;

SCSI_DEFINEBYTES(MODESENSE6,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(MODESENSE6,DBD,1,3,1,uint8_t)
SCSI_DEFINEBITS(MODESENSE6,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(MODESENSE6,PageCode,2,0,6,PageCode)
SCSI_DEFINEBITS(MODESENSE6,PC,2,6,2,PageControl)
SCSI_DEFINEBYTES(MODESENSE6,AllocationLength,4,1,uint8_t)
SCSI_DEFINEBYTES(MODESENSE6,Control,5,1,uint8_t)

SCSI_DEFINEBYTES(MODESENSE10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(MODESENSE10,DBD,1,3,1,uint8_t)
SCSI_DEFINEBITS(MODESENSE10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(MODESENSE10,PageCode,2,0,6,PageCode)
SCSI_DEFINEBITS(MODESENSE10,PC,2,6,2,PageControl)
SCSI_DEFINEBYTES(MODESENSE10,AllocationLength,7,2,uint16_t)
SCSI_DEFINEBYTES(MODESENSE10,Control,9,1,uint8_t)

/* MODE SENSE 6 & 10 responses */

SCSI_DEFINEBYTES(MODEPARAMHEADER6,ModeDataLength,0,1,uint8_t)
SCSI_DEFINEBYTES(MODEPARAMHEADER6,MediumType,1,1,uint8_t)
SCSI_DEFINEBYTES(MODEPARAMHEADER6,DevSpecParam,2,1,uint8_t)
SCSI_DEFINEBYTES(MODEPARAMHEADER6,BlockDescLen,3,1,uint8_t)

SCSI_DEFINEBYTES(MODEPARAMHEADER10,ModeDataLength,0,2,uint16_t)
SCSI_DEFINEBYTES(MODEPARAMHEADER10,MediumType,2,1,uint8_t)
SCSI_DEFINEBYTES(MODEPARAMHEADER10,DevSpecParam,3,1,uint8_t)
SCSI_DEFINEBYTES(MODEPARAMHEADER10,BlockDescLen,6,2,uint16_t)

SCSI_DEFINEBYTES(MODEPARAMBLOCKDESC,DensityCode,0,1,uint8_t)
SCSI_DEFINEBYTES(MODEPARAMBLOCKDESC,NumBlocks,1,3,uint32_t)
SCSI_DEFINEBYTES(MODEPARAMBLOCKDESC,BlockLength,5,3,uint32_t)

SCSI_DEFINEBITS(MODEPAGEHDR,PageCode,0,0,6,PageCode)
SCSI_DEFINEBITS(MODEPAGEHDR,PS,0,7,1,uint8_t)
SCSI_DEFINEBYTES(MODEPAGEHDR,PageLength,1,1,uint8_t)

/* PageCode_ReadWriteErrorRecovery */

SCSI_DEFINEBITS(MODEPAGE_RWER,DCR,2,0,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_RWER,DTE,2,1,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_RWER,PER,2,2,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_RWER,RC,2,4,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_RWER,TB,2,5,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_RWER,ARRE,2,6,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_RWER,AWRE,2,7,1,uint8_t)
SCSI_DEFINEBYTES(MODEPAGE_RWER,ReadRetryCount,3,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_RWER,EMCDR,7,0,2,uint8_t)
SCSI_DEFINEBYTES(MODEPAGE_RWER,WriteRetryCount,8,1,uint8_t)

/* PageCode_CDDeviceParameters */

SCSI_DEFINEBITS(MODEPAGE_CDDP,InactivityTimerMultiplier,3,0,4,uint8_t)
SCSI_DEFINEBYTES(MODEPAGE_CDDP,SperM,4,2,uint16_t)
SCSI_DEFINEBYTES(MODEPAGE_CDDP,FperS,6,2,uint16_t)

/* PageCode_CDAudioControl */

SCSI_DEFINEBITS(MODEPAGE_CDAC,SOTC,2,1,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_CDAC,IMMED,2,2,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_CDAC,Port0ChanSel,8,0,4,uint8_t)
SCSI_DEFINEBYTES(MODEPAGE_CDAC,Port0Volume,9,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_CDAC,Port1ChanSel,10,0,4,uint8_t)
SCSI_DEFINEBYTES(MODEPAGE_CDAC,Port1Volume,11,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_CDAC,Port2ChanSel,12,0,4,uint8_t)
SCSI_DEFINEBYTES(MODEPAGE_CDAC,Port2Volume,13,1,uint8_t)
SCSI_DEFINEBITS(MODEPAGE_CDAC,Port3ChanSel,14,0,4,uint8_t)
SCSI_DEFINEBYTES(MODEPAGE_CDAC,Port3Volume,15,1,uint8_t)

/* MODE SELECT 10 */

SCSI_DEFINEBYTES(MODESELECT10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(MODESELECT10,SP,1,0,1,uint8_t)
SCSI_DEFINEBITS(MODESELECT10,PF,1,4,1,uint8_t)
SCSI_DEFINEBITS(MODESELECT10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBYTES(MODESELECT10,ParamListLength,7,2,uint16_t)
SCSI_DEFINEBYTES(MODESELECT10,Control,9,1,uint8_t)

/* PREVENT-ALLOW MEDIUM REMOVAL */

SCSI_DEFINEBYTES(PREVENTALLOW6,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(PREVENTALLOW6,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(PREVENTALLOW6,Prevent,4,0,1,uint8_t)
SCSI_DEFINEBYTES(PREVENTALLOW6,Control,5,1,uint8_t)

/* TEST UNIT READY */

SCSI_DEFINEBYTES(TESTUNITREADY6,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(TESTUNITREADY6,LUN,1,5,3,uint8_t)
SCSI_DEFINEBYTES(TESTUNITREADY6,Control,5,1,uint8_t)

/* PLAY AUDIO */

SCSI_DEFINEBYTES(PLAYAUDIO12,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(PLAYAUDIO12,RelADR,1,0,1,uint8_t)
SCSI_DEFINEBITS(PLAYAUDIO12,LUN,1,5,3,uint8_t)
SCSI_DEFINEBYTES(PLAYAUDIO12,LBA,2,4,uint32_t)
SCSI_DEFINEBYTES(PLAYAUDIO12,PlayLength,6,4,uint32_t)
SCSI_DEFINEBYTES(PLAYAUDIO12,Control,11,1,uint8_t)

/* READ SUB-CHANNEL */

typedef enum {
	SubChannelParam_CDPos=1,
} SubChannelParam;

SCSI_DEFINEBYTES(READSUBCHANNEL10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(READSUBCHANNEL10,TIME,1,1,1,uint8_t)
SCSI_DEFINEBITS(READSUBCHANNEL10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(READSUBCHANNEL10,SUBQ,2,6,1,uint8_t)
SCSI_DEFINEBYTES(READSUBCHANNEL10,ParamList,3,1,SubChannelParam)
SCSI_DEFINEBYTES(READSUBCHANNEL10,TrackNumber,6,1,uint8_t)
SCSI_DEFINEBYTES(READSUBCHANNEL10,AllocationLength,7,2,uint16_t)
SCSI_DEFINEBYTES(READSUBCHANNEL10,Control,9,1,uint8_t)

/* Response header */

typedef enum {
	SubQ_AudioStatus_Invalid=0x00,
	SubQ_AudioStatus_Playing=0x11,
	SubQ_AudioStatus_Paused=0x12,
	SubQ_AudioStatus_Complete=0x13,
	SubQ_AudioStatus_Error=0x14,
	SubQ_AudioStatus_Idle=0x15,
} SubQ_AudioStatus;

SCSI_DEFINEBYTES(SUBQHEADER,AudioStatus,1,1,SubQ_AudioStatus)
SCSI_DEFINEBYTES(SUBQHEADER,DataLength,2,2,uint16_t)

/* CDPos response */

SCSI_DEFINEBYTES(SUBQ_CDPOS,FormatCode,0,1,uint8_t)
SCSI_DEFINEBITS(SUBQ_CDPOS,CONTROL,1,0,4,uint8_t)
SCSI_DEFINEBITS(SUBQ_CDPOS,ADR,1,4,4,uint8_t)
SCSI_DEFINEBYTES(SUBQ_CDPOS,Track,2,1,uint8_t)
SCSI_DEFINEBYTES(SUBQ_CDPOS,Index,3,1,uint8_t)
SCSI_DEFINEBYTES(SUBQ_CDPOS,AbsoluteAddr,4,4,uint32_t)
SCSI_DEFINEBYTES(SUBQ_CDPOS,RelativeAddr,8,4,uint32_t)

/* START STOP UNIT */

typedef enum {
	PowerCondition_NoChange=0x0,
	PowerCondition_GoIdle=0x2,
	PowerCondition_GoStandby=0x3,
	PowerCondition_GoSleep=0x5,
} PowerCondition;

SCSI_DEFINEBYTES(STARTSTOPUNIT6,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(STARTSTOPUNIT6,IMMED,1,0,1,uint8_t)
SCSI_DEFINEBITS(STARTSTOPUNIT6,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(STARTSTOPUNIT6,Start,4,0,1,uint8_t)
SCSI_DEFINEBITS(STARTSTOPUNIT6,LoEj,4,1,1,uint8_t)
SCSI_DEFINEBITS(STARTSTOPUNIT6,PowerCond,4,4,4,PowerCondition)
SCSI_DEFINEBYTES(STARTSTOPUNIT6,Contorl,5,1,uint8_t)

/* READ CD */

SCSI_DEFINEBYTES(READCD12,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(READCD12,RelAdr,1,0,1,uint8_t)
SCSI_DEFINEBITS(READCD12,DAP,1,1,1,uint8_t)
SCSI_DEFINEBITS(READCD12,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(READCD12,ExpSectorType,1,2,3,uint8_t)
SCSI_DEFINEBYTES(READCD12,StartLBA,2,4,uint32_t)
SCSI_DEFINEBYTES(READCD12,Length,6,3,uint32_t)
SCSI_DEFINEBITS(READCD12,C2Error,9,1,2,uint8_t)
SCSI_DEFINEBITS(READCD12,EDC_ECC,9,3,1,uint8_t)
SCSI_DEFINEBITS(READCD12,UserData,9,4,1,uint8_t)
SCSI_DEFINEBITS(READCD12,HeaderCodes,9,5,2,uint8_t)
SCSI_DEFINEBITS(READCD12,SYNC,9,7,1,uint8_t)
SCSI_DEFINEBITS(READCD12,SubChanSel,10,0,3,uint8_t)
SCSI_DEFINEBYTES(READCD12,Control,11,1,uint8_t)

/* READ HEADER */

SCSI_DEFINEBYTES(READHEADER10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(READHEADER10,MSF,1,1,1,uint8_t)
SCSI_DEFINEBITS(READHEADER10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBYTES(READHEADER10,LBA,2,4,uint32_t)
SCSI_DEFINEBYTES(READHEADER10,Length,7,2,uint16_t)
SCSI_DEFINEBYTES(READHEADER10,Control,9,1,uint8_t)

/* READ HEADER response (LBA) */

SCSI_DEFINEBYTES(READHEADERLBA,DataMode,0,1,uint8_t)
SCSI_DEFINEBYTES(READHEADERLBA,LBA,4,4,uint32_t)

/* READ TOC */

SCSI_DEFINEBYTES(READTOC10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(READTOC10,TIME,1,1,1,uint8_t)
SCSI_DEFINEBITS(READTOC10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(READTOC10,Format,2,0,4,uint8_t)
SCSI_DEFINEBYTES(READTOC10,Track,6,1,uint8_t)
SCSI_DEFINEBYTES(READTOC10,AllocationLength,7,2,uint16_t)
SCSI_DEFINEBYTES(READTOC10,Control,9,1,uint8_t)

/* READ TOC response (for track descriptors) */

SCSI_DEFINEBYTES(READTOCRESPONSE,DataLength,0,2,uint16_t)
SCSI_DEFINEBYTES(READTOCRESPONSE,FirstTrack,2,1,uint8_t)
SCSI_DEFINEBYTES(READTOCRESPONSE,LastTrack,3,1,uint8_t)
SCSI_DEFINEBITS(READTOCRESPONSE,Control,5,0,4,uint8_t)
SCSI_DEFINEBITS(READTOCRESPONSE,ADR,5,4,4,uint8_t)
SCSI_DEFINEBYTES(READTOCRESPONSE,TrackNumber,6,1,uint8_t)
SCSI_DEFINEBYTES(READTOCRESPONSE,StartLBA,8,4,uint32_t)

/* PAUSE/RESUME */

SCSI_DEFINEBYTES(PAUSERESUME10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(PAUSERESUME10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBITS(PAUSERESUME10,Resume,8,0,1,uint8_t)

/* READ TRACK INFORMATION */

SCSI_DEFINEBYTES(READTRACKINFORMATION10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(READTRACKINFORMATION10,AddrNumType,1,0,2,uint8_t)
SCSI_DEFINEBITS(READTRACKINFORMATION10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBYTES(READTRACKINFORMATION10,LBA_Track,2,4,uint32_t)
SCSI_DEFINEBYTES(READTRACKINFORMATION10,AllocationLength,7,2,uint16_t)
SCSI_DEFINEBYTES(READTRACKINFORMATION10,Control,9,1,uint8_t)

/* READ TRACK INFORMATION response */

SCSI_DEFINEBYTES(TRACKINFO,DataLength,0,2,uint16_t)
SCSI_DEFINEBYTES(TRACKINFO,TrackNumberLSB,1,1,uint8_t)
SCSI_DEFINEBYTES(TRACKINFO,SessionNumberLSB,2,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,TrackMode,5,0,4,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,Copy,5,4,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,Damage,5,5,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,DataMode,6,0,4,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,FP,6,4,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,PacketInc,6,5,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,Blank,6,6,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,RT,6,7,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,NWA_V,7,0,1,uint8_t)
SCSI_DEFINEBITS(TRACKINFO,LRA_V,7,1,1,uint8_t)
SCSI_DEFINEBYTES(TRACKINFO,StartAddr,8,4,uint32_t)
SCSI_DEFINEBYTES(TRACKINFO,NextWriteableAddr,12,4,uint32_t)
SCSI_DEFINEBYTES(TRACKINFO,FreeBlocks,16,4,uint32_t)
SCSI_DEFINEBYTES(TRACKINFO,FixedPacketSize,20,4,uint32_t)
SCSI_DEFINEBYTES(TRACKINFO,TrackSize,24,4,uint32_t)
SCSI_DEFINEBYTES(TRACKINFO,LastRecordedAddr,28,4,uint32_t)
SCSI_DEFINEBYTES(TRACKINFO,TrackNumberMSB,32,1,uint8_t)
SCSI_DEFINEBYTES(TRACKINFO,SessionNumberMSB,33,1,uint8_t)
SCSI_DEFINEBYTES(TRACKINFO,ReadCompatabilityLBA,36,4,uint32_t)

/* READ 10 */

SCSI_DEFINEBYTES(READ10,Op,0,1,SCSIOp)
SCSI_DEFINEBITS(READ10,RelAdr,1,0,1,uint8_t)
SCSI_DEFINEBITS(READ10,FUA,1,3,1,uint8_t)
SCSI_DEFINEBITS(READ10,DPO,1,4,1,uint8_t)
SCSI_DEFINEBITS(READ10,LUN,1,5,3,uint8_t)
SCSI_DEFINEBYTES(READ10,LBA,2,4,uint32_t)
SCSI_DEFINEBYTES(READ10,TransferLength,7,2,uint16_t)
SCSI_DEFINEBYTES(READ10,Control,9,1,uint8_t)

/* INQUIRY response */

SCSI_DEFINEBITS(INQUIRY,PeripheralDeviceType,0,0,5,uint8_t)
SCSI_DEFINEBITS(INQUIRY,PeripheralQualifier,0,5,3,uint8_t)
SCSI_DEFINEBITS(INQUIRY,DeviceTypeModifier,1,0,7,uint8_t)
SCSI_DEFINEBITS(INQUIRY,RMB,1,7,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,ANSIVersion,2,0,3,uint8_t)
SCSI_DEFINEBITS(INQUIRY,ECMAVersion,2,3,3,uint8_t)
SCSI_DEFINEBITS(INQUIRY,ISOVersion,2,6,2,uint8_t)
SCSI_DEFINEBITS(INQUIRY,ResponseDataFormat,3,0,4,uint8_t)
SCSI_DEFINEBITS(INQUIRY,TrmIOP,3,6,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,AENC,3,7,1,uint8_t)
SCSI_DEFINEBYTES(INQUIRY,AdditonalLength,4,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,SftRe,7,0,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,CmdQue,7,1,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,Linked,7,3,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,Sync,7,4,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,WBus16,7,5,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,WBus32,7,6,1,uint8_t)
SCSI_DEFINEBITS(INQUIRY,RelAdr,7,7,1,uint8_t)
SCSI_DEFINEARRAY(INQUIRY,VendorID,8,8)
SCSI_DEFINEARRAY(INQUIRY,ProductID,16,16)
SCSI_DEFINEBYTES(INQUIRY,ProductRevision,32,4,uint32_t)

#endif
