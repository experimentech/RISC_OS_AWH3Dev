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
#if !defined(RTSUPPORT_RESMESS_H) /* file used if not already included */
#define RTSUPPORT_RESMESS_H
/*****************************************************************************
* $Id: resmess,v 1.1.1.1 2005-01-12 19:55:22 bavison Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Rhenium
*
* ----------------------------------------------------------------------------
* Copyright © 2004 Castle Technology Ltd. All rights reserved.
*
* ----------------------------------------------------------------------------
* Purpose: Resource file embedding for RAM builds
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/


/*****************************************************************************
* Macros
*****************************************************************************/


/*****************************************************************************
* New type definitions
*****************************************************************************/


/*****************************************************************************
* Constants
*****************************************************************************/


/*****************************************************************************
* Global variables
*****************************************************************************/


/*****************************************************************************
* Function prototypes
*****************************************************************************/
extern void *resmess_ResourcesFiles(void);
extern void *resmess2_ResourcesFiles(void);
/* These returns a pointer to the resource file data within the image.
 * Whatever you do, DON'T declare this as a variable and use its address -
 * the ResGen documentation is wrong!
 */


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
