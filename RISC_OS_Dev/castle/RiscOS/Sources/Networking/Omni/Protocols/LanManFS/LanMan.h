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
*   LANMAN.H - Definitions for main LanMan client module
*
*   Versions
*
*   07-03-94 INH Original, from FSinC
*
*
*/

/* Constants ------------- */

#define FilingSystemName                "LanMan"
#define Our_FS_Number                   102
#define Our_Error_Base                  ((0x10000) | (Our_FS_Number << 8))
#define MAX_DRIVES                      8 /* Maximum number of connections */
#define NAME_LIMIT                      16 /* Longest userID/password */
#define DOS_NAME_LEN                    256 /* Path plus leaf limit */

#define INFO_SPECIALFIELD               0x80000000
#define INFO_INTERACTIVE                0x40000000
#define INFO_NULLFILENAMES              0x20000000
#define INFO_OPENNONEXISTENT            0x10000000
#define INFO_ARGS_FLUSH                 0x08000000
#define INFO_FILE_TIME                  0x04000000
#define INFO_FUNC_TEMPFS                0x02000000

#define INFO_SUPPORTS_IMAGE             0x00800000
#define INFO_NO_EXPAND_PATH             0x00400000
#define INFO_NO_STORE_PATHS             0x00200000
#define INFO_AVOID_FILE255              0x00100000
#define INFO_AVOID_FILE0                0x00080000
#define INFO_USE_FUNC9                  0x00040000
#define INFO_EXTRA_INFO                 0x00020000

#define INFO2_SUPPORTS_IOCTL            0x00000008


#define Information_Word                (Our_FS_Number|INFO_FILE_TIME|INFO_EXTRA_INFO)
#define Information2_Word               (INFO2_SUPPORTS_IOCTL)

#define NBNSIPCMOS0			0x50
#define NBNSIPCMOS1			0xe4
#define NBNSIPCMOS2			0xe5
#define NBNSIPCMOS3			0xe6



/* Misc bits ------------- */

extern const int *Image_RO_Base;


/* C.LanMan exports ------------- */
/*
        These routines get used by the cmhg generated header.
*/

extern int LM_pw;

extern void LM_Boot(void);
extern int RdCMOS(int);
extern const char *MsgLookup(const char *);
extern err_t MsgSetOSError(_kernel_oserror *);
extern _kernel_oserror *MsgError(int);

/* S.Interface exports --------------- */

extern void veneer_fsentry_open( void );
extern void veneer_fsentry_getbytes( void );
extern void veneer_fsentry_putbytes( void );
extern void veneer_fsentry_args( void );
extern void veneer_fsentry_close( void );
extern void veneer_fsentry_file( void );
extern void veneer_fsentry_func( void );
extern void veneer_fsentry_gbpb( void );

extern void Free_ServiceRoutine(void);
