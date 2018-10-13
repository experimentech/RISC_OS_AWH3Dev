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
#ifndef CDFSSOFTSCSI_CDFSBITS_H
#define CDFSSOFTSCSI_CDFSBITS_H

/* Definitions of things relating to the CDFSDriver interface */

#include <stdint.h>

typedef struct {
	uint32_t infoword;
	uint32_t numregistrations;
	uint32_t numdrivetypes;
	uint32_t block_to_msf;
	uint32_t msf_to_block;
} cdfs_driver_info_t;

#define INFOWORD_NUMCOMMANDS_MASK	0x0000003F
#define INFOWORD_USE_SCSI_READDATA	0x00000040
#define INFOWORD_USE_SCSI_SEEK		0x00000080
#define INFOWORD_USE_SCSI_INQUIRY	0x00000100
#define INFOWORD_USE_SCSI_CAPACITY	0x00000200
#define INFOWORD_USE_SCSI_READY		0x00000400
#define INFOWORD_USE_SCSI_STOPOPEN	0x00000800
#define INFOWORD_USE_SCSI_CHECK		0x00001000
#define INFOWORD_USE_SCSI_STATUS	0x00002000
#define INFOWORD_USE_SCSI_CONTROL	0x00004000
#define INFOWORD_USE_SCSI_PREFETCH	0x00008000
#define INFOWORD_USE_SCSI_RESET		0x00010000
#define INFOWORD_USE_PROPRIETARY_RUD	0x00020000
#define INFOWORD_USE_COMPLEX_RUD	0x00040000
#define INFOWORD_USE_PROPRIETARY_SUD	0x00080000
#define INFOWORD_USE_COMPLEX_SUD	0x00100000
#define INFOWORD_USE_SCSI_OP		0x00200000

typedef enum {
	DriveType_Unknown=-1,

	DriveType_MMC=0, /* SCSI drive that follows the MMC spec */

	DriveType_MAX=1,
} DriveType;

typedef struct {
	uint32_t device;
	uint32_t card;
	uint32_t lun;
	DriveType drive_type;
} cdfs_ctl_block_t;

/* Driver operations */

typedef enum {
	CDOp_ReadData,
	CDOp_SeekTo,
	CDOp_DriveStatus,
	CDOp_DriveReady,
	CDOp_GetParameters,
	CDOp_SetParameters,
	CDOp_OpenDrawer,
	CDOp_EjectButton,
	CDOp_EnquireAddress,
	CDOp_EnquireDataMode,
	CDOp_PlayAudio,
	CDOp_PlayTrack,
	CDOp_AudioPause,
	CDOp_EnquireTrack,
	CDOp_ReadSubChannel,
	CDOp_CheckDrive,
	CDOp_DiscChanged,
	CDOp_StopDisc,
	CDOp_DiscUsed,
	CDOp_AudioStatus,
	CDOp_Inquiry,
	CDOp_DiscHasChanged,
	CDOp_Control,
	CDOp_Supported,
	CDOp_Prefetch,
	CDOp_Reset,
	CDOp_CloseDrawer,
	CDOp_IsDrawerLocked,
	CDOp_AudioControl,
	CDOp_AudioLevel,
	CDOp_Identify,
	CDOp_ReadAudio,
	CDOp_ReadUserData,
	CDOp_SeekUserData,
	CDOp_GetAudioParms,
	CDOp_SetAudioParms,
	CDOp_SCSIUserOp,

	CDOp_MAX,
} CDOp;

/* Addressing modes */
typedef enum {
	AddrMode_LBA=0,
	AddrMode_MSF=1,
	AddrMode_PBA=2,

	AddrMode_MAX=3,
} AddrMode;

#define PBA_OFFSET (2*75) /* The difference between physical and logical block addresses */

/* Data modes */
typedef enum {
	DataMode_Audio=0,
	DataMode_Data1=1,
	DataMode_Data2Form2=2,
	DataMode_Data2Form1=3,

	DataMode_MAX=4,
} DataMode;

/* CDOp_GetParmeters/CDOp_SetParameters */
typedef struct {
	uint32_t inactivitytimermultiplier;
	uint32_t readretrycount;
	DataMode datamode;
	uint32_t speed;
} cdfs_parameters_t;

/* CDOp_PlayTrack */

#define PLAY_TO_END_OF_TRACK 254
#define PLAY_TO_END_OF_CD 255

/* CDOp_EnquireTrack */

typedef struct {
	uint8_t first;
	uint8_t last;
} cdfs_trackrange_t;

typedef struct {
	uint32_t startlba;
	uint8_t flags;
} cdfs_trackinfo_t;

/* CDOp_ReadSubChannel */

typedef struct {
	uint32_t trackrelativeaddr;
	uint32_t absoluteaddr;
	uint8_t flags;
	uint8_t track;
	uint8_t index;
} cdfs_readsubchannel_t;

/* cdfs_trackinfo_t.flags, cdfs_readsubchannel_t.flags */

#define TRACKFLAGS_DATA 0x01 /* Else audio */
#define TRACKFLAGS_2CHAN 0x02 /* Else 4 chan */ /* XXX TODO is this correct? READ TOC docs are rather cryptic */

/* CDOp_DiscUsed */

typedef struct {
	uint32_t discsize;
	uint32_t sectorsize;
} cdfs_discused_t;

/* CDOp_AudioStatus */

typedef enum {
	AudioStatus_Playing=0,
	AudioStatus_Paused=1,
	AudioStatus_Complete=3,
	AudioStatus_Error=4,
	AudioStatus_Idle=5,
} AudioStatus;

/* CDOp_Supported */

/* Bits 0-2 = CD_AudioControl support level (0=none)
   Bits 6-13 = Number of drive speeds, -1 */
#define SUPPORTED_PREFETCH		0x0008 /* CDOp_Prefetch */
#define SUPPORTED_CLOSEDRAWER		0x0010 /* CDOp_CloseDrawer */
#define SUPPORTED_AUDIOLEVEL		0x0020 /* CDOp_AudioLevel */
#define SUPPORTED_READAUDIO		0x4000 /* CDOp_ReadAudio */
#define SUPPORTED_GETSETAUDIOPARMS	0x8000 /* CDOp_Get/SetAudioParms */

/* CDOp_Get/SetAudioParms */

typedef enum {
	AudioParm_VolumeLevels=0,
} AudioParm;

typedef struct {
	uint32_t volumes[2];
} cdfs_audioparm_vollevels_t;

#define AUDIOPARM_VOLUMELEVEL_MAX 0xffff

#endif
