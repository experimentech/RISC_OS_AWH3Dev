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
/*****************************************************************************
* $Id: global,v 1.7 2012-06-03 14:25:56 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): 
*
* ----------------------------------------------------------------------------
* Purpose: Global variables
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include "global.h"


/*****************************************************************************
* MACROS
*****************************************************************************/


/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/


/*****************************************************************************
* File scope Global variables
*****************************************************************************/
void *global_PrivateWord; /* so we don't have to worry about passing pw around */
MessagesFD global_MessageFD; /* message file descriptor */
my_usb_device_t *global_DeviceList = NULL; /* list of usb device info */
my_usb_device_t *global_TickerList = NULL; /* list of devices using TickerV */

bool global_UseRTSupport = false; /* Use RTSupport instead of TickerV? */
int global_RTSupportPollword = 0; /* RTSupport pollword */
int global_RTSupportHandle = 0; /* RTSupport handle */
callback_type global_CallbackType = callback_NONE; /* Type of our registered callback, if any */

uint32_t global_PopUpDelay = 400; /* Delay before SCSIFS gets told about new devices */

/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/


/*****************************************************************************
* Functions
*****************************************************************************/


/*****************************************************************************
* END OF FILE
*****************************************************************************/
