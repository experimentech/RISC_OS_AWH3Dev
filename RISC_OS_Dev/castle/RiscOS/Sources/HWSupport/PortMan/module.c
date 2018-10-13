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
/*                  Copyright 1997 Acorn Computers Ltd                  */
/*                                                                      */
/*  This material is the confidential trade secret and proprietary      */
/*  information of Acorn Computers. It may not be reproduced, used      */
/*  sold, or transferred to any third party without the prior written   */
/*  consent of Acorn Computers. All rights reserved.                    */
/*                                                                      */
/************************************************************************/
#include <stdlib.h>
#include <stdbool.h>
#include "swis.h"
#include "Global/Services.h"
#include "Interface/HighFSI.h"
#include "Interface/PCI.h"

#ifdef STANDALONE
#include "saheader.h"
#else
#include "header.h"
#endif

#include "resfiles.h"
#include "module.h"
#include "msgfile.h"
#include "tags.h"
#include "PortMan.h"

#if CMHG_VERSION < 516
#define CMHG_CONST
#else
#define CMHG_CONST const
#endif

#define UNUSED(x) ((x)=(x))

#define IOMD_CLINES (*(unsigned int*)0x0320000c)  /* ARM 7500FE */
#define GPIO_REG_BASE 0x30470000                  /* CX24430 */
#define PLL_REG_BASE  0x30440000                  /* CX24430 */

#define GPIO_READ       (0x04/4)
#define GPIO_DRIVE_HIGH (0x08/4)
#define GPIO_DRIVE_LOW  (0x10/4)
#define GPIO_DRIVE_OFF  (0x14/4)
#define GPIO_BANK       (0x30/4)

#define PLL_CONFIG0     (0x20/4)

#define CXPIOREG(b,a) (CXGPIO_Base[GPIO_BANK*(b)+GPIO_##a])
#define CXPLLREG(a)   (CXPLL_Base[PLL_##a])

static volatile unsigned int *CXGPIO_Base, *CXPLL_Base;
static int clines_softcopy=0xff;
static int messages_handle = 0;
static int tags_handle = 0;
struct msgfile messages = MSGFILE_INIT;

static _kernel_oserror *modify_bit(int flags, const char *name, int *result);

static enum
{
    ARM7500FE,
    CX24430
} platform = ARM7500FE;

/**** Utility function **********************************************/
/* this allows us to find out if the actual data has changed by reading
   the underlying handle for the file */
int resourcefs_handle (const char* file)
{
  int fh, h;
  _kernel_oserror* e;

  e = _swix (OS_Find, _INR(0,1)|_OUT(0),
    0x4f,
    Module_MessagesFile,
    &fh);

  e = _swix (OS_FSControl, _INR(0,1)|_OUT(1),
    21,
    fh,
    &h);

  e = _swix (OS_Find, _INR(0,1),
    0,
    fh);

  return h;
}

/**** Port access functions **********************************************/

static unsigned int modify_clines(unsigned int mask, unsigned int toggle)
{
  int res;
  int irq_state=_kernel_irqs_disabled();

  /* Turn interrupts off round the atomic bit. */
  _kernel_irqs_off();
  res=clines_softcopy;
  /* Update the soft copy */
  clines_softcopy = ( res & mask ) ^ toggle;
  /* Write to the hardware */
  IOMD_CLINES=clines_softcopy;
  if(!irq_state)
    _kernel_irqs_on();

  /* Return the old value. */
  return res;
}

static _kernel_oserror *arm7500fe_modify(struct bitdef bit, int flags, int *result)
{
  if(bit.port == 0)
  {
    unsigned int mask=0, toggle=0;
    unsigned int value;
    if(bit.flags & TAG_FLAGS_OUTPUT)
    {
      mask=flags&PORTMAN_FLAG_CLEAR?1:0;
      toggle=flags&PORTMAN_FLAG_TOGGLE?1:0;
      if((flags & PORTMAN_FLAG_CLEAR) && (bit.flags & TAG_FLAGS_INVERTED))
        toggle^=1;
    }
    value=modify_clines(~(mask<<bit.num), toggle<<bit.num) >> bit.num;
    *result=(value&1) | (((value&!mask)^toggle)<<1);
  }
  else
    *result=0;
  return NULL;
}

static _kernel_oserror *cx24430_modify_pio(struct bitdef bit, int flags, int *result)
{
  bool clear=0, toggle=0, old, new, newphys;
  unsigned int bank = bit.num / 32;
  unsigned int pinbit = 1u << bit.num%32;

  if(bit.flags & TAG_FLAGS_OUTPUT)
  {
    old = CXPIOREG(bank,DRIVE_HIGH) & pinbit;
    if (bit.flags & TAG_FLAGS_INVERTED) old = !old;
    clear = flags&PORTMAN_FLAG_CLEAR;
    toggle = flags&PORTMAN_FLAG_TOGGLE;
    new = (old &~ clear) ^ toggle;
    newphys = bit.flags & TAG_FLAGS_INVERTED ? !new : new;
    if (newphys)
      CXPIOREG(bank,DRIVE_HIGH) = pinbit;
    else
      CXPIOREG(bank,DRIVE_LOW) = pinbit;
  }
  else
  {
    CXPIOREG(bank,DRIVE_OFF) = pinbit;
    old = CXPIOREG(bank,READ) & pinbit;
    if (bit.flags & TAG_FLAGS_INVERTED) old = !old;
    new = old;
  }
  *result = old | new<<1;
  return NULL;
}

static _kernel_oserror *cx24430_modify_config(struct bitdef bit, int flags, int *result)
{
  bool old, new;
  unsigned int pinbit = 1u << bit.num;

  old = CXPLLREG(CONFIG0) & pinbit;
  if (bit.flags & TAG_FLAGS_INVERTED) old = !old;
  new = old;
  *result = old | new<<1;
  return NULL;
}

#define BUTTON_SET_SIZE 8
int button_set[BUTTON_SET_SIZE+1] = { -1 };

static void cx24430_note_button(const char *name, struct bitdef bit)
{
  if (bit.port != 2 && bit.port != 3) return;
  int n;
  for (n = 0; button_set[n] != -1; n++)
      if (button_set[n] == bit.num) return;
  if (n < BUTTON_SET_SIZE)
  {
    button_set[n] = bit.num;
    button_set[n+1] = -1;
  }
}

static void cx24430_buttons_init(void)
{
    /* Make a list of all lines associated with port 2/3 tags. These are
     * the button scan lines, and all need to be manipulated to read a
     * button.
     */
    tag_foreach(cx24430_note_button);
}

static _kernel_oserror *cx24430_read_button(struct bitdef bit, int flags, int *result)
{
  _kernel_oserror *e;
  int res;
  bool old_state[BUTTON_SET_SIZE];
  int irq_state=_kernel_irqs_disabled();

  _kernel_irqs_off();
  /* This case is used for buttons on the STB55. Given the tag definition
   * <n>:<2|3>:0, we drive <n>:0:2 high, all the other scan lines low, then
   * read either Panel_SW1 or Panel_SW2, then put all scan lines back to their
   * old output state.
   * Polarity of read is determined by tag definition of Panel_SW1/2 -
   * flags are effectively ignored for port 2/3 tags, and should be zero.
   */
  for (int n = 0; button_set[n] != -1; n++)
  {
    cx24430_modify_pio((struct bitdef) { .num = button_set[n], .port = 0,
                                         .flags = TAG_FLAGS_OUTPUT },
                       button_set[n] == bit.num ? PORTMAN_FLAG_SET
                                                : PORTMAN_FLAG_CLEAR,
                       &res);
    old_state[n] = res & 1;
  }
  e = modify_bit(0, bit.port == 2 ? "Panel_SW1" : "Panel_SW2", result);
  for (int n = 0; button_set[n] != -1; n++)
  {
    cx24430_modify_pio((struct bitdef) { .num = button_set[n], .port = 0,
                                         .flags = TAG_FLAGS_OUTPUT },
                       old_state[n] ? PORTMAN_FLAG_SET
                                    : PORTMAN_FLAG_CLEAR,
                       &res);
  }
  if(!irq_state)
    _kernel_irqs_on();

  return e;
}

static _kernel_oserror *cx24430_modify(struct bitdef bit, int flags, int *result)
{
  switch (bit.port)
  {
    case 0: return cx24430_modify_pio(bit, flags, result);
    case 1: return cx24430_modify_config(bit, flags, result);
    case 2:
    case 3: return cx24430_read_button(bit, flags, result);
    default: *result = 0; return NULL;
  }
}

static _kernel_oserror *modify_bit(int flags, const char *name, int *result)
{
  _kernel_oserror *err;
  struct bitdef bit;

  err=tag_get(&bit, name);
  if(err)
    return err;

  if (platform == CX24430)
      return cx24430_modify(bit, flags, result);
  else
      return arm7500fe_modify(bit, flags, result);

}

/**** Callback function **************************************************/

_kernel_oserror *callback_handler(_kernel_swi_regs *r, void *pw)
{
  _kernel_swi_regs regs;

  /* Tell everyone we've started */
  regs.r[0]=PORTMAN_SERVICE_STARTING;
  regs.r[1]=Service_PortMan;
  _kernel_swi(OS_ServiceCall, &regs, &regs);

  return NULL;
}


/**** General module functions *******************************************/

_kernel_oserror *
module_finalise(int fatal, int podule, void *pw)
{
  _kernel_swi_regs regs;
  msgfile_close( &messages );
  tag_close();

  /* Before we finish.  Remove the callback. */
  regs.r[0]=(int)callback_entry;
  regs.r[1]=(int)pw;
  _kernel_swi(OS_RemoveCallBack, &regs, &regs);

  /* Tell everyone we're dying */
  regs.r[0]=PORTMAN_SERVICE_DYING;
  regs.r[1]=Service_PortMan;
  _kernel_swi(OS_ServiceCall, &regs, &regs);

#ifdef STANDALONE
  resfiles_final();
#endif

  return NULL;
}

_kernel_oserror *
module_initialise(CMHG_CONST char *cmd_tail, int podule_base, void *pw)
{
  _kernel_swi_regs regs;
  _kernel_oserror* e = 0;

  if (!_swix(PCI_FindByID, _INR(0,4), 0x14F1, 0x4430, -1, 0, -1))
  {
    platform = CX24430;
    e = _swix(OS_Memory, _INR(0,2)|_OUT(3), 13, GPIO_REG_BASE, 0x10000,
                                            &CXGPIO_Base);
    if (e) return e;
    e = _swix(OS_Memory, _INR(0,2)|_OUT(3), 13, PLL_REG_BASE, 0x10000,
                                            &CXPLL_Base);
    if (e) return e;
  }

  if (platform == ARM7500FE)
   IOMD_CLINES=clines_softcopy;

#ifdef STANDALONE
  resfiles_init();
#endif

  msgfile_open( &messages, Module_MessagesFile );
  messages_handle = resourcefs_handle (Module_MessagesFile);
  tags_handle = resourcefs_handle (TAGS_FILE);

  e = tag_init();
  if (e) return e;

  if (platform == CX24430)
    cx24430_buttons_init();

  /* We're ready to go.  Set up the callback. */
  regs.r[0]=(int)callback_entry;
  regs.r[1]=(int)pw;
  _kernel_swi(OS_AddCallBack, &regs, &regs);

  return (NULL);
}

_kernel_oserror *
module_swi(int swi_offset, _kernel_swi_regs *r, void *pw)
{
  UNUSED(pw);

  switch(swi_offset+PortMan_00)
  {
  case PortMan_AccessBit:
    return modify_bit(r->r[0], (const char *)(r->r[1]), r->r+0);

  default:
    return error_BAD_SWI;
  }
}

void module_service(int service_number, _kernel_swi_regs *r, void *pw)
{
  UNUSED(pw);

  switch(service_number)
  {
#ifdef STANDALONE
  case Service_ResourceFSStarting:
    resfiles_service(r->r[3], r->r[2]);
    return;
#endif

  /* only reopen our files if their handle has changed */
  case Service_ResourceFSStarted: {
    int h = resourcefs_handle (Module_MessagesFile);
    if (messages_handle != h) {
      messages_handle = h;
      msgfile_close( &messages );
      msgfile_open( &messages, Module_MessagesFile );
    }

    h = resourcefs_handle (TAGS_FILE);
    if (tags_handle != h) {
      tags_handle = h;
      tag_close();
      tag_init ();
    }}
    return;
  }
}

