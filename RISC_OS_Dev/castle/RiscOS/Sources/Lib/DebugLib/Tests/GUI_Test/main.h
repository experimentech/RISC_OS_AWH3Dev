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
/* File:    main.h                                                      */
/* Purpose: Primary header file for the project. Handles library imports*/
/*          ComponentId #define's                                       */
/*          and project-global variables                                */
/*                                                                      */
/* Author:  Neil Bingham (mailto:NBingham@acorn.com)                    */
/* History: 0.00  - dd                                                  */
/*                  Created.                                            */
/************************************************************************/

#ifndef __main_h
#define __main_h


/* -------------------------------------- LIBRARY IMPORTS --------------------------------------- */
#ifdef MEM_CHECK
  #include "MemCheck:memcheck.h"
#endif // MEM_CHECK

/* ANSI Libraries */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* Toolbox Libraries */
#include "tbox:toolbox.h"
#include "tbox:window.h"
#include "tbox:menu.h"
#include "tbox:event.h"
#include "tbox:wimp.h"
#include "tbox:wimplib.h"
#include "tbox:gadgets.h"
#include "tbox:iconbar.h"
/* CLib 5 Libraries */
#include "kernel.h"
#include "swis.h"

#include "ErrorLib/ErrorLib.h"

/* ------------------------------------ COMPILE-TIME OPTIONS ------------------------------------ */

/* Debug information.  If debug is #define'd then the debug code will be compile-time switched    */
/* in, otherwise nothing will happen when debug calls are made.                                   */

#include "DebugLib/DebugLib.h"		/* Neil Binghams Debug Library */


/* ------------------------------------- GADGET DEFINITIONS ------------------------------------- */

/* Main_Window */

/* IBar_Menu */
#define menu_quit_event         0x99   /* The event returned when quit is selected from the menu  */


/* ------------------------------------- OBJECT DEFINITIONS ------------------------------------- */

extern ObjectId Main_WindowHandle;
extern ObjectId Output_WindowHandle;
extern ObjectId Ibar_MenuHandle;
extern ObjectId Icon_BarHandle;
extern ObjectId ProgInfo_WindowHandle;

/* ------------------------------------ #DEFINE STATEMENTS -------------------------------------- */

#define LEVEL_VAR	"Test$DB"
#define SOCKET_VAR	"Inet$DebugHost"
#define APP_NAME	"DebugLibTst"

#define IGNORE(a) a=a

/* ---------------------------------------- GENERAL STUFF --------------------------------------- */

#define wimp_version            310    /* The current wimp version we know about                  */
#define our_directory "<DebugTest$Dir>"/* The name of our application direcory                    */


int quit_program (int, ToolboxEvent *, IdBlock *, void *);
void startup (void);
int attach_handlers (int, ToolboxEvent *, IdBlock *, void *);
int message_control (WimpMessage *, void *);
int default_key_handler (int, WimpPollBlock *, IdBlock *, void *);
void initialise (void);


/* -------------------------------------- GLOBAL VARIABLES -------------------------------------- */

extern MessagesFD message_block;       /* Messages file id for use in MsgHandle.c                 */

extern IdBlock event_id_block;         /* declare an event block for use with toolbox initialise  */
extern int current_wimp;               /* the current version of the wimp we are using            */
extern int task_id;                    /* and our task handle                                     */
extern int quit;

/* -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ END +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ */

#endif

