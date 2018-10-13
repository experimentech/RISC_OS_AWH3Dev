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
/* � Acorn Computers Ltd, 1992.                                         */
/*                                                                      */
/* This file forms part of an unsupported source release of RISC_OSLib. */
/*                                                                      */
/* It may be freely used to create executable images for saleable       */
/* products but cannot be sold in source form or as an object library   */
/* without the prior written consent of Acorn Computers Ltd.            */
/*                                                                      */
/* If this file is re-distributed (even if modified) it should retain   */
/* this copyright notice.                                               */
/*                                                                      */
/************************************************************************/

/*
 * Title:   alarm.c
 * Purpose: alarm facilities for wimp programs, using non-busy waiting
 *          for idle events
 * History: IDJ: 05-Feb-92: prepared for source release
 *
 */

#include <stdlib.h>
#include <limits.h>
#include "alarm.h"
#include "werr.h"
#include "os.h"
#include "msgs.h"
#include "swis.h"
#include "VerIntern/messages.h"

#define alarm__laterthan(t1,t2) (t1 > t2)


typedef struct alarm__str
        {
           struct alarm__str *next;
           int at;
           alarm_handler proc;
           void *handle;
        } ALARM;

/* the list of pending alarms */
static ALARM *alarm__pending_list = 0;


void alarm_init(void)
{
  ALARM *p, *save_p;

  if (alarm__pending_list != 0)
  {
    p = alarm__pending_list;
    while (p != 0)
    {
      save_p = p;
      p = p->next;
      free(save_p);
    }
    alarm__pending_list = 0;
  }
}



int alarm_timenow(void)
{
  os_regset r;
  os_error *e;

  if ((e = os_swix(OS_ReadMonotonicTime, &r)) != 0)
  {
       werr (TRUE, msgs_lookup(MSGS_alarm1));
       return 0;   /* compiler likes this !*/
  }
  else
       return (r.r[0]);
}


int alarm_timedifference(int t1, int t2)
{
  /*
   * wrap-round of timer is not really a problem
   * we could just do a subtraction (since large_-ve - large_+ve == small+ve
   * but this kludge makes doubly sure (I think)
   */

   if (t1>0 && t2<0)
   {
     t1 |= 0x80000000;   /* ie. neg distance from 0 */
     t2 &= ~0x80000000;  /* ie. pos distance from 0 */
   }
   return(t2 -t1);
}


void alarm_set(int at, alarm_handler proc, void *handle)
{
  ALARM *p, *save_p, *new;

  p = alarm__pending_list;
  save_p = p;

  /* find where to put the alarm (in time) */
  while (p!=0 && alarm__laterthan(at, p->at))
  {
#ifdef TRACE
  tracef1("at = %d\n", (int)(p->handle));
#endif
    save_p = p;
    p = p->next;
  }

  /* insert new pending alarm */
  if((new = malloc(sizeof(ALARM)))==0)
    werr(TRUE, msgs_lookup(MSGS_alarm2));
  new->next = p;
  new->proc = proc;
  new->handle = handle;
  new->at = at;
  if(save_p == p)
    alarm__pending_list = new;
  else
    save_p->next = new;
}



BOOL alarm_next(int *result)
{
  if (alarm__pending_list != 0)
  {
    /* if there's a pending alarm say when it's for */
    *result = alarm__pending_list->at;
    return TRUE;
  }
  else
    return FALSE;
}



void alarm_callnext(void)
{
  ALARM *next_alarm;
  alarm_handler proc_to_call;
  int called_at;
  void *handle_to_pass;

  if (alarm__pending_list != 0)
  {
    /* save details of next alarm */
    proc_to_call = alarm__pending_list->proc;
    called_at = alarm__pending_list->at;
    handle_to_pass = alarm__pending_list->handle;

    /* farewell and adieu to the next pending alarm */
    next_alarm = alarm__pending_list;
    alarm__pending_list = alarm__pending_list->next;
    free(next_alarm);

    /* call supplied routine last (in case it goes bang!) */
    proc_to_call(called_at, handle_to_pass);
  }
}

#ifndef UROM
void alarm_remove(int at, void *handle)
{
  ALARM *p, *save_p;

  p = alarm__pending_list;
  save_p = p;

  while(p != 0)
  {
    if(p->at == at && p->handle == handle)
      break;
    else
    {
      save_p = p;
      p = p->next;
    }
  }

  if(p != 0)
  {
    if(save_p == p)
      alarm__pending_list = p->next;
    else
      save_p->next = p->next;
    free(p);
  }
}
#endif

void alarm_removeall(void *handle)
{
  ALARM *p, *save_p;

  p = alarm__pending_list;
  save_p = p;

  while(p != 0)
    if(p->handle == handle)
    {
      if(save_p == p)
      {
        alarm__pending_list = p->next;
        p = alarm__pending_list;
        free(save_p);
        save_p = p;
      }
      else
      {
        save_p->next = p->next;
        free(p);
        p = save_p->next;
      }
    }
    else
    {
      save_p = p;
      p = p->next;
    }
}

BOOL alarm_anypending(void *handle)
{
  ALARM *p = alarm__pending_list;

  while(p != 0)
  {
    if(p->handle == handle) return TRUE;
    p = p->next;
  }

  return FALSE;
}
