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
 * Simple terminal program demonstrating serial library.
 *
 * Modification History
 *---------------------
 * 15-May-96 RWB Created
 */
#include <stdio.h>
#include <stdlib.h>
#include "serial_ven.h"
#include "console.h"

#define BUFFER_SIZE (512)                /* input/output buffer size */

/*
 * These need to be global for atexit function to tidy up
 */
int iInputStream = 0;
int iOutputStream = 0;

/*
 * clean up on exit
 */
void
doexit(void)
{
  if (iInputStream)  serial_close_stream(iInputStream);
  if (iOutputStream) serial_close_stream(iOutputStream);
}

/*
 * main loop
 */
int main(void)
{
  char *pchStreamName = NULL;
  char *pchBuffer = NULL;
  int iDataSize = 0;
  int iKey;


  atexit(doexit);

  pchStreamName = getenv("SerialTerminal$Port");
  if (pchStreamName == NULL)
  {
    printf("Error: environment variable SerialTerminal$Port not set.\n");
    return (0);
  }

  printf("\nSerial terminal on port %s\n\n",pchStreamName);

  pchBuffer = malloc(BUFFER_SIZE);
  if (pchBuffer == 0)
  {
    printf("Error: cannot allocate memory for buffer.\n");
    return (0);
  }

  iInputStream = serial_open_stream(pchStreamName,SERIAL_INPUT);
  iOutputStream = serial_open_stream(pchStreamName,SERIAL_OUTPUT);
  if (iInputStream==0 || iOutputStream==0)
  {
    printf("Error: cannot open serial streams.\n");
    return (0);
  }

  while(1)
  {
    do
    {
      iDataSize = serial_read_stream(iInputStream,pchBuffer,BUFFER_SIZE);
      if (iDataSize) console_put_text(pchBuffer, iDataSize);
    }
    while (iDataSize);

    /* Read keyboard and send to serial port */
    iKey = console_get_key(0);
    if (iKey !=-1) serial_write_byte(iOutputStream,(char)iKey);
  }

  return (0);
}
