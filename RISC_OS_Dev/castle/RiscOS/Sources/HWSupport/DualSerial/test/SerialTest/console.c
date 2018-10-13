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
#include "kernel.h"
#include "swis.h"

/*
 * Look for a key press, return 0 for none.
 */
int
console_get_key(int time)
{
  _kernel_swi_regs reg;
  int flag = 0;
  int key;

  reg.r[0] = 129;                        /* read keyboard for information */
  reg.r[1] = time & 0xFF;	      	 /* time limit low byte */
  reg.r[2] = (time>>8) & 0x7F;           /* time limit low byte 0x00->0x7F */
  _kernel_swi(OS_Byte, &reg, &reg);

  if (reg.r[1] == 0)      /* received a null, could be a function following */
  {
    flag = 1;             /* set flag to indicate possible function key */
    reg.r[0] = 129;
    reg.r[1] = time & 0xFF;
    reg.r[2] = (time>>8) & 0x7F;
    _kernel_swi(OS_Byte, &reg, &reg);
  }

  if (reg.r[2] == 0)                        /* key has been read */
  {
    key = reg.r[1];
    if (flag) key = key<<8;		    /* add an offset if function key */
  }
  else
  {
    key = 0;                               /* no key read */
  }

  return (key);
}

/*
 * put character on screen
 */
void
console_put_char(char ch)
{
  _kernel_swi_regs reg;

  reg.r[0] = (int)ch;
  _kernel_swi(OS_WriteC, &reg, &reg);
}

/*
 * Print the contents of given buffer to the screen
 */
void
console_put_text(char *pchBuffer, int iLength)
{
  _kernel_swi_regs reg;

  reg.r[0] = (int)pchBuffer;
  reg.r[1] = iLength;
  _kernel_swi(OS_WriteN,&reg,&reg);
}

/*
 * get line of text from keyboard
 */
int
console_get_str(char *pchBuffer, int iLength)
{
  _kernel_swi_regs reg;
  _kernel_oserror *err;

  reg.r[0] = ((int)pchBuffer) | (unsigned int)1<<31;
  reg.r[1] = iLength;
  reg.r[2] = (int)'0';
  reg.r[3] = (int)'9';
  err = _kernel_swi(OS_ReadLine,&reg,&reg);
  if (err) return (-1);

  return (reg.r[1]);
}
