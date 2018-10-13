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
#if !defined(RESMESS_H) /* file used if not already included */
#define RESMESS_H
/*****************************************************************************
* $Id: resmess,v 1.1.1.1 2003-02-21 20:29:11 bavison Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Ursula (originally)
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
* MACROS
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

/*****************************************************************************
* resmess_ResourcesFiles
*
* Does nothing.
* Whatever you do, DON'T declare this as a variable and use its address -
* the ResGen documentation is wrong!
*
* Assumptions
*  NONE
*
* Inputs
*  NONE
*
* Outputs
*  NONE
*
* Returns
*  pointer to the resource file data within the image
*****************************************************************************/
extern void *resmess_ResourcesFiles(void);


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
