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
/*
*  Lan Manager client
*
*  Omni.H -- OmniFiler interface header
*
*  Versions
*  14-10-94 INH Original
*
*/

extern err_t Omni_MountServer ( char *servname, char *userID, char *passwd,
         char *mountname, char *mountpath, int *mount_id_out );

extern err_t Omni_DismountServer ( int mount_id );

extern err_t Omni_GetMountInfo ( int mount_id, const char **pServName,
  const char **pUserName, const char **pMountName, const char **pMountPath, int *pServerID );

extern err_t Omni_GetDefaultType ( char *leafname, int *ptype_out );

extern int Omni_GetMountID ( char *name );

extern char Omni_GetDrvLetter ( char *name );

extern void Omni_StartUp ( void );
extern void Omni_Shutdown ( void );
extern void Omni_ClearLists ( void );

extern void Omni_ServiceCall ( _kernel_swi_regs *R );

extern void Omni_RecheckInfo ( int flags );
#define RI_SERVERS   0
#define RI_MOUNTS    1
#define RI_PRINTERS  2

extern _kernel_oserror *OmniOp_SWI ( _kernel_swi_regs *R );
extern _kernel_oserror *Omni_FreeOp_SWI ( _kernel_swi_regs *R );


extern void Omni_Debug(void);
extern _kernel_oserror *Omni_DumpShares(char *server_name);
extern _kernel_oserror *Omni_DumpServers(void);

extern void Omni_AddInfo ( int flags, const char *server, const char *descr, const char *comment );
#define OAI_SERVER     0
#define OAI_DISK       1
#define OAI_PRINTER    2
#define OAI_DEVICE     3
#define OAI_IPC        4

/* These routines are actually in S.Interface */
extern void OmniS_Suicide (char *modname);
extern void OmniS_ResourceInit (void);
extern void OmniS_ResourceShutdown (void);
extern void OmniS_ResFSStarting(int R2, int R3);

/* OmniClient SWI definitions --------------- */
#define Omni_base 0x4A200

#define SWI_Omni_EnumerateMounts      (Omni_base+0)
#define SWI_Omni_RegisterClient       (Omni_base+1)
#define RC_DOES_FILES      (1<<0)
#define RC_NEEDS_USERID    (1<<1)
#define RC_NEEDS_PASSWD    (1<<2)
#define RC_NEEDS_MOUNTPATH (1<<3)
#define RC_NEEDS_AUTHSERV  (1<<4)
#define RC_LOGON_TYPE      (1<<6)
#define RC_DOES_PRINT      (1<<8)
#define RC_NEEDS_PRINTPWD  (1<<9)
#define RC_NEEDS_PRINTLEN  (1<<10)
#define RC_EXTN_CHAR(a) ((a) << 16)
#define SWI_Omni_DeregisterClient     (Omni_base+2)
#define SWI_Omni_ConvertClientToAcorn (Omni_base+4)
