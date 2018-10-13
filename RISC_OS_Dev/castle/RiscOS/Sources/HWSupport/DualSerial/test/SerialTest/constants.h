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

#ifndef __constants_h
#define __constants_h

#define BUFF_SIZE (2000)               /* input/output buffer size */
#define TIMEOUT   (50)		 /* rx timeout (cs) */


typedef enum {
	_CONT,
	_SYNTAX,
	_QUIT
} cmd_ret;

typedef struct {
	cmd_ret	(*call)(int, char**);
	char	*name;
	char	*syntax;
	char	*help;
} cmd_t;


#endif
