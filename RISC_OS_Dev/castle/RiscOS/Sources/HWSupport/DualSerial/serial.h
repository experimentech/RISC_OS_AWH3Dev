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

#ifndef __serial_h
#define __serial_h

/*
 * filenames for serial streams without modification of baud rate, etc, ...
 */
#define SERIAL_STREAM_1 "devices:$.serial1"
#define SERIAL_STREAM_2 "devices:$.serial2"

/*
 * access rights to be passed to serial_open_stream
 */
#define SERIAL_INPUT  (0x4f)
#define SERIAL_OUTPUT (0xcf)

/*
 * ioctl reason codes supported by serial driver
 */
#define IOCTL_BAUD         (1)
#define IOCTL_FORMAT       (2)
#define IOCTL_HANDSHAKE    (3)
#define IOCTL_BUFFER_SIZE  (4)
#define IOCTL_BUFFER_THRES (5)
#define IOCTL_CTRL_LINES   (6)
#define IOCTL_FIFO_TRIG    (7)
#define IOCTL_READ_BAUDS   (8)
#define IOCTL_READ_BAUD	   (9)

/*
 * struct to contain data forming an ioctl, used when calling serial_ioctl
 */
typedef struct {
	unsigned int reason   : 16; /* ioctl reason code */
	unsigned int group    : 8;  /* ioctl group code */
	unsigned int reserved : 6;  /* should be zero */
	unsigned int read     : 1;  /* read flag */
	unsigned int write    : 1;  /* write flag */
	unsigned int data;          /* actual data */
} ioctl_t;

/*
 * integer giving access to bit field values used in ioctl 6. should be used
 * along the lines of :
 *
 *       serial_ctrl.bits.dtr = 1
 *	 pchIOCtlBlock->write = 1
 * 	 pchIOCtlBlock->data = serial_ctrl.data
 */
typedef union {
  	unsigned int data;
  	struct {
   	   unsigned int dtr   : 1;     /* dtr line wr */
	   unsigned int rts   : 1;	    /* rts line wr */
	   unsigned int resv1 : 14;    /* reserved */
	   unsigned int cts   : 1;	    /* cts line ro */
	   unsigned int dsr   : 1;	    /* dsr line ro */
	   unsigned int ri    : 1;	    /* ri line ro */
	   unsigned int dcd   : 1;	    /* dcd line ro */
	   unsigned int fifo  : 1;	    /* fifos enabled */
	   unsigned int resv2 : 11;    /* reserved  */
	} bits;
} serial_ctrl_t;

#endif
