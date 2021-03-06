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
/******	str.h *************************************************************\

Project:	Ursula (RISC OS for Risc PC II)
Component:	Modular Configure
Purpose:	String routines shared between multiple Configure plug-ins

History:
Date		Who	Change
----------------------------------------------------------------------------
08/12/1997	BJGA	Split from Common
			Renamed functions to str_foo convention
			Added these headers

\**************************************************************************/

#ifndef __str_h
#define __str_h

/* Prototypes */

extern char *str_cpy (char* s1, const char *s2);
extern char *str_ncpy (char* s1, const char *s2, int n);
extern int str_len (const char *s);

#endif
