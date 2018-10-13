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
/* title: main.c
 *
 * Purpose: This code  has been written as a demonstration of
 * the Toolboxlib library and the eventlib library.
 * It is not therefore a demonstration of how to write a calculator!
 * History:
 *          02-Aug-94  MCC - Created
 */

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "toolbox.h"
#include "window.h"
#include "menu.h"
#include "event.h"
#include "wimp.h"
#include "wimplib.h"
#include "gadgets.h"
#include "main.h"
#include "calc.h"
#include "events.h"

#include "swis.h"

MessagesFD message_block;  /* declare a message block for use with toolbox initialise */
IdBlock    event_id_block; /* declare an event block for use with toolbox initialise  */
int        current_wimp;   /* the current version of the wimp we are using */
int        task_id;        /* and our task handle */
int        quit = 0;       /* declare and initialise a flag to indicate when we should quit */

/* wimp_error is used by E_CHECK and E_CHECK_ABORT */
static void wimp_error(_kernel_oserror *er)
{
   wimp_report_error(er,0,task_name,0,0,0);
}

int finalisation(int event_code, ToolboxEvent *event, IdBlock *id_block, void *handle)
{
  /*
   * to finalise all we have to do is set the flag that indicates when we
   * should quit
   */

  quit = 1;

  /* claim the event */
  return 1;
}

double zero = 0.0;

int decode_operator(int event_code, ToolboxEvent *event, IdBlock *id_block, void *handle)
{
  /*
   * This function is called if we have received an event from the toolbox.
   * We have declared in our Resource file which gadgets deliver what events
   * and we have defined corresponding names for them in main.h.
   * So all we have to do is take appropriate action for the different events
   */

  _kernel_oserror *er;

  extern void foo(void);

  switch(event_code)
  {
    case pressed_equal:
      *(int *)0xf0000000 = 0;
      if(op_flag == 2)
      {
        char result[256];
        result[0]='\0';

        do_calculation(oper, result);
        er = displayfield_set_value(0,id_block->self_id,display,result);
        E_CHECK(er)
        calc_reinit();
      }
      break;

    case pressed_c:
      assert(event_code == 3);
      calc_reinit();
      er = displayfield_set_value(0,id_block->self_id,display,"0");
      E_CHECK(er)
      break;

    case pressed_divide:
      foo();
    case pressed_add:
      return (int) (3.4 / zero);
    case pressed_minus:
      *(double *)0xf0000000 = 2.0;
    case pressed_mult:
      _swix(OS_Write0, _IN(0), (char *) 0xFF000000);
      free((void *) 0x8000);
      if( op_flag == 1)
      {
        oper = event_code;
        op_flag = 2;
        return 0;
      }
      break;
  }
  return 1; /* claim the event */
}

int construct_operand(int event_code, ToolboxEvent *event, IdBlock *id_block, void *handle)
{
  /* This function is called as a result of an event happening upon one
   * of our 'number' gadgets.
   * depending on which operand we are constructing we must call
   * constructors
   */

  _kernel_oserror *er;

  switch(op_flag)
  {
    case 1:
      if(op1_len < CALC_MAX_LEN)
      {
        if( (calc_construct_operand_1(event_code)) == 0)
        /* having changed our operand we must reflect the change in the calculator display */
          er = displayfield_set_value(0,id_block->self_id,display,"0");
        else
          er = displayfield_set_value(0,id_block->self_id,display,operand_1);
        E_CHECK(er)
      }
      break;

    case 2:
      if(op1_len < CALC_MAX_LEN)
      {
        if( (calc_construct_operand_2(event_code)) == 0)
          er = displayfield_set_value(0,id_block->self_id,display,"0");
        else
          er = displayfield_set_value(0,id_block->self_id,display,operand_2);
        E_CHECK(er)
      }
      break;
  }
  return 1;
}

int attach_our_other_handlers(int event_code,ToolboxEvent *event,IdBlock *id_block, void *handle)
{
  /* This function has been called as a result of an object being
   * auto-created. For this example that means our iconbar object
   * so we can now register all our other handlers for the rest
   * of our objects
   */

  _kernel_oserror *er;
  ObjectClass     obj_class;
  int             i = 0;

  er = toolbox_get_object_class(0,id_block->self_id,&obj_class);
  E_CHECK(er)

  switch(obj_class)
  {
    case Window_ObjectClass:
      while(number_event[i] != -1)
      {
        er = event_register_toolbox_handler(id_block->self_id,number_event[i],
                                            construct_operand,NULL);
        E_CHECK(er)
        i++;
      }
      i = 0;
      while(operator_event[i] != -1)
      {
        er = event_register_toolbox_handler(id_block->self_id, operator_event[i],
                                            decode_operator,NULL);
        E_CHECK(er)
        i++;
      }
      break;

    case Menu_ObjectClass:
      er = event_register_toolbox_handler(id_block->self_id,menu_quit_event, finalisation, NULL);
      E_CHECK(er)
      break;
  }

  return 1;
}

int message_control(WimpMessage *message, void *handle)
{
  /*
   * A message handler to deal with wimp messages. As we only registered
   * for quit, there is no need to check the action code, but for demonstration
   * purposes this is included.
   */

  switch(message->hdr.action_code)
  {
    case Wimp_MQuit:
      quit = 1;
    break;
  }
  return 1;
}

void initialise(void)
{
  /*
   * Intialise ourselves with the toolbox
   */

  _kernel_oserror *er;
  unsigned int mask;

  /* Initialise ourselves with the event library */

  er = event_initialise(&event_id_block);
  E_CHECK_ABORT(er)

  /* Mask out Key presses and Null events.
   * Any key presses that we are interested in will be returned via toolbox events
   * as eack keypress has been asigned an event number by us. Look at the keyboard
   * shortcut's defined in the calc_win window object using !ResEd
   */

  mask = Wimp_Poll_KeyPressedMask | Wimp_Poll_NullMask;
  er = event_set_mask(mask);

  /* As we have set the object flags on our iconbar object to be auto-create
   * and auto_show, we are initially only interested in an auto create event
   * when we receive this we can then attach handlers for our window and menu
   */
  er=event_register_toolbox_handler(-1,Toolbox_ObjectAutoCreated,attach_our_other_handlers,NULL);
  E_CHECK_ABORT(er)

  /* We must register our Message handler for the Quit message.
   * in this way we can be told to quit by the task manager
   */

  er = event_register_message_handler(Wimp_MQuit, message_control, NULL);
  E_CHECK_ABORT(er)

  /* Now we have set up our handlers, we must initialise
   * ourselves with the toolbox. Note that a parameter that we are not
   * interested in (eg. in this case the sprite area) can be set to NULL.
   */
  er = toolbox_initialise(0, wimp_version, wimp_messages, toolbox_events, our_directory,
                          &message_block, &event_id_block,
                          &current_wimp, &task_id, NULL);
  E_CHECK_ABORT(er)

  /* Finally we must perform a small amount of initialisation
   * with our calc routines
   */
  calc_initialisation();
}

int main(int argc, char *argv[])
{

  WimpPollBlock block;
  int    code;
  _kernel_oserror  *er;

  /* Perform initialisation of various aspects of ourselves
   */
  initialise();

  /* While we do not have our quit flag set call event poll
   */

  while(!quit)
  {
    er = event_poll(&code, &block, NULL);
    E_CHECK(er)
  }

  /* It is time for us to quit. By simply calling exit
   * the toolbox will be informed of our demise.
   */
  exit(0);
}

