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

#ifndef __serial_ven_h
#define __serial_ven_h

/*
 * open stream on specified device.
 *
 * in: strFilename - filename of device to open stream on
 *     iRights - RiscOS file access rights, SERIAL_INPUT or SERIAL_OUTPUT
 *
 * ret: file handle of stream or 0 for failure
 *
 */
int serial_open_stream(char *strFilename, int iRights);

/*
 * close an open stream.
 *
 * in: iHandle - handle previously returned from serial_open_stram
 *
 */
void serial_close_stream(int iHandle);

/*
 * perform a serial ioctl on an open stream.
 *
 * in: iHandle - handle previously returned from serial_open_stram
 *     pIOCtlBlock - pointer to populated ioctl control block
 *
 * ret: pIOCtlBlock->data
 *
 * contents of ioctl control block will have been modifed depending on the
 * state of the write flag.
 *
 * some ioctls will only perform operations on the stream specified. others
 * will affect the general state of the serial port, ie dtr flag.
 *
 */
unsigned int serial_ioctl(int iHandle, ioctl_t *pIOCtlBlock);

/*
 * read a block of data from an open stream.
 *
 * in: iHandle - handle previously returned from serial_open_stram
 *     pchDataBlock - area to copy data to
 *     iSize - maximum size of pchDataBlock area
 *
 * ret: amount of data copied into pchDataBlock area, -1 for error.
 *
 * if there is more than iSize bytes of data in stream then iSize bytes are
 * copied. otherwise all the data is copied.
 *
 */
int serial_read_stream(int iHandle, char *pchDataBlock, int iSize);

/*
 * reads a single byte from an open stream.
 *
 * in: iHandle - handle previously returned from serial_open_stram
 *
 * ret: byte of data, -1 for error or no data present.
 *
 */
int serial_read_byte(int iHandle);

/*
 * wrties a block of data to an open stream.
 *
 * in: iHandle - handle previously returned from serial_open_stram
 *     pchDataBlock - area to copy data from
 *     iSize - amount of data in pchDataBlock area
 *
 * ret: amount of data copied, -1 for error
 *
 * if there is more than iSize bytes of free space in stream, then iSize bytes
 * are written to the stream. otherwise as much data as will fit will be
 * written.
 *
 */
int serial_write_stream(int iHandle, char *pchDataBlock, int iSize);

/*
 * writes a single byte to an open stream.
 *
 * in: iHandle - handle previously returned from serial_open_stram
 *
 * ret: 1 for success, -1 for error
 */
int serial_write_byte(int iHandle, char chData);

/*
 * returns the number of characters in a input buffer and the amount of free
 * space in an output buffer.
 */
int serial_size(int iHandle);


#endif
