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
/************************************************************************
 * � Acorn Computers Ltd, 1994.                                         *
 *                                                                      *
 * It may be freely used to create executable images for saleable       *
 * products but cannot be sold in source form or as an object library   *
 * without the prior written consent of Acorn Computers Ltd.            *
 *                                                                      *
 * If this file is re-distributed (even if modified) it should retain   *
 * this copyright notice.                                               *
 *                                                                      *
 ************************************************************************/


/*
 * Name        : setdaddr.c
 * Purpose     : Veneer for method SaveAs_SetDataAddress
 * Description : Sets the address of the data (and selection) for the saveas object
 */


#include "kernel.h"
#include "toolbox.h"
#include "saveas.h"




/*
 * Name        : saveas_set_data_address
 * Description : Sets the address of the data (and selection) for the saveas object 
 * In          : unsigned int flags
 *               ObjectId saveas
 *               void *data
 *               int data_size
 *               void *selection
 *               int selection_size
 * Out         : None
 * Returns     : pointer to error block
 */

extern _kernel_oserror *saveas_set_data_address ( unsigned int flags,
                                                  ObjectId saveas,
                                                  void *data,
                                                  int data_size,
                                                  void *selection,
                                                  int selection_size
                                                )
{
_kernel_swi_regs r;

  r.r[0] = flags;
  r.r[1] = (int) saveas;
  r.r[2] = SaveAs_SetDataAddress;
  r.r[3] = (int) data;
  r.r[4] = (int) data_size;
  r.r[5] = (int) selection;
  r.r[6] = (int) selection_size;
  return(_kernel_swi(Toolbox_ObjectMiscOp,&r,&r));
}

