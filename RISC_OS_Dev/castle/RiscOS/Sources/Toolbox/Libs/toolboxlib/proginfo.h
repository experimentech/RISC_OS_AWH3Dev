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
/****************************************************************************
 * This source file was written by Acorn Computers Limited. It is part of   *
 * the toolbox library for writing desktop applications in C. It may be     *
 * used freely in the creation of programs for Archimedes or Risc PC. It    *
 * should be used with Acorn's C Compiler Release 5 or later.               *
 *                                                                          *
 *                                                                          *
 * Copyright � Acorn Computers Ltd, 1994                                    *
 *                                                                          *
 ***************************************************************************/



/*
 * Name        : proginfo.h
 * Description : C veneers to the Methods provided by the proginfo class
 */



#ifndef __proginfo_h
#define __proginfo_h


#ifndef __kernel_h
#include "kernel.h"
#endif

#ifndef __toolbox_h
#include "toolbox.h"
#endif

#ifndef __window_h
#include "window.h"
#endif


/****************************************************************************
 * ProgInfo Templates                                                       *
 ****************************************************************************/

/*-- flags --*/

#define ProgInfo_GenerateShowEvent    0x00000001
#define ProgInfo_GenerateHideEvent    0x00000002
#define ProgInfo_IncludeLicenceType   0x00000004
#define ProgInfo_IncludeWebPageButton 0x00000008
#define ProgInfo_GenerateLaunchEvent  0x00000010


/*-- templates --*/

typedef struct
{
  unsigned int  flags;
  char          *title;
  int           max_title;
  char          *purpose;
  char          *author;
  int           licence_type;
  char          *version;
  char          *window;
  char          *uri;
  int           event;
} ProgInfoTemplate;


/****************************************************************************
 * ProgInfo SWI Calls                                                       *
 ****************************************************************************/

#define ProgInfo_SWIChunkBase    0x82b40
#define ProgInfo_ObjectClass     ProgInfo_SWIChunkBase
#define ProgInfo_ClassSWI        (ProgInfo_SWIChunkBase + 0)
#define ProgInfo_PostFilter      (ProgInfo_SWIChunkBase + 1)
#define ProgInfo_PreFilter       (ProgInfo_SWIChunkBase + 2)


/****************************************************************************
 * ProgInfo Methods                                                         *
 ****************************************************************************/

#define ProgInfo_GetWindowId           0
#define ProgInfo_SetVersion            1
#define ProgInfo_GetVersion            2
#define ProgInfo_SetLicenceType        3
#define ProgInfo_GetLicenceType        4
#define ProgInfo_SetTitle              5
#define ProgInfo_GetTitle              6
#define ProgInfo_SetUri                7
#define ProgInfo_GetUri                8
#define ProgInfo_SetWebEvent           9
#define ProgInfo_GetWebEvent           10

/****************************************************************************
 * ProgInfo License types                                                   *
 ****************************************************************************/

#define ProgInfo_LicenseType_PublicDomain       0
#define ProgInfo_LicenseType_SingleUser         1
#define ProgInfo_LicenseType_SingleMachine      2
#define ProgInfo_LicenseType_Site               3
#define ProgInfo_LicenseType_Network            4
#define ProgInfo_LicenseType_Authority          5

/****************************************************************************
 * ProgInfo Toolbox Events                                                  *
 ****************************************************************************/

#define ProgInfo_AboutToBeShown     ProgInfo_SWIChunkBase
#define ProgInfo_DialogueCompleted  (ProgInfo_SWIChunkBase + 1)
#define ProgInfo_LaunchWebPage      (ProgInfo_SWIChunkBase + 2)


typedef struct
{
  ToolboxEventHeader hdr;
  int                show_type;
  union
  {
    TopLeft               pos;
    WindowShowObjectBlock full;
  } info;
} ProgInfoAboutToBeShownEvent;


typedef struct
{
  ToolboxEventHeader hdr;
} ProgInfoDialogueCompletedEvent;


typedef struct
{
  ToolboxEventHeader hdr;
} ProgInfoLaunchWebPageEvent;




/****************************************************************************
 * The following functions provide veneers to the methods that are          *
 * associated with this particular class.  Please read the User Interface   *
 * Toolbox manual for more detailed information on their functionality.     *
 ****************************************************************************/


#ifdef __cplusplus
  extern "C" {
#endif


/*
 * Name        : proginfo_get_web_event
 * Description : Gets the event generated by a click on the web page button 
 * In          : unsigned int flags
 *               ObjectId proginfo
 * Out         : int *event
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_get_web_event ( unsigned int flags,
                                                 ObjectId proginfo,
                                                 int *event
                                               );


/*
 * Name        : proginfo_set_web_event
 * Description : Sets the event generated by a click on the web page button 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               int event
 * Out         : None
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_set_web_event ( unsigned int flags,
                                                 ObjectId proginfo,
                                                 int event
                                               );


/*
 * Name        : proginfo_get_uri
 * Description : Gets the URI launched by the web page button 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               char *buffer
 *               int buff_size
 * Out         : int *nbytes
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_get_uri ( unsigned int flags,
                                           ObjectId proginfo,
                                           char *buffer,
                                           int buff_size,
                                           int *nbytes
                                         );


/*
 * Name        : proginfo_set_uri
 * Description : Sets the URI launched by the web page button 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               const char *uri
 * Out         : None
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_set_uri ( unsigned int flags,
                                           ObjectId proginfo,
                                           const char *uri
                                         );


/*
 * Name        : proginfo_get_title
 * Description : Gets the title for the specified prog info object 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               char *buffer
 *               int buff_size
 * Out         : int *nbytes
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_get_title ( unsigned int flags,
                                             ObjectId proginfo,
                                             char *buffer,
                                             int buff_size,
                                             int *nbytes
                                           );


/*
 * Name        : proginfo_set_title
 * Description : Sets the title for the specified prog info object 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               char *title
 * Out         : None
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_set_title ( unsigned int flags,
                                             ObjectId proginfo,
                                             char *title
                                           );


/*
 * Name        : proginfo_get_licence_type
 * Description : Gets the licence type for the specified prog info object 
 * In          : unsigned int flags
 *               ObjectId proginfo
 * Out         : int *licence_type
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_get_licence_type ( unsigned int flags,
                                                    ObjectId proginfo,
                                                    int *licence_type
                                                  );


/*
 * Name        : proginfo_set_licence_type
 * Description : Sets the licence type for the specified prog info object 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               int licence_type
 * Out         : None
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_set_licence_type ( unsigned int flags,
                                                    ObjectId proginfo,
                                                    int licence_type
                                                  );


/*
 * Name        : proginfo_get_version
 * Description : Gets the version string for the specified prog info object 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               char *buffer
 *               int buff_size
 * Out         : int *nbytes
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_get_version ( unsigned int flags,
                                               ObjectId proginfo,
                                               char *buffer,
                                               int buff_size,
                                               int *nbytes
                                             );


/*
 * Name        : proginfo_set_version
 * Description : Sets the version string for the prog info object 
 * In          : unsigned int flags
 *               ObjectId proginfo
 *               char *version_string
 * Out         : None
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_set_version ( unsigned int flags,
                                               ObjectId proginfo,
                                               char *version_string
                                             );


/*
 * Name        : proginfo_get_window_id
 * Description : Gets the id of the underlying window object for the prog info object 
 * In          : unsigned int flags
 *               ObjectId proginfo
 * Out         : ObjectId *window
 * Returns     : pointer to error block
 */

extern _kernel_oserror *proginfo_get_window_id ( unsigned int flags,
                                                 ObjectId proginfo,
                                                 ObjectId *window
                                               );


#ifdef __cplusplus
  }
#endif


#endif
