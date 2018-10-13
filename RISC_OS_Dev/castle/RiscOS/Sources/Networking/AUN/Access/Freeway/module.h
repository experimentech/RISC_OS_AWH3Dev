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
 *
 * module.h (Freeway)
 *
 * Copyright (C) Acorn Computers Ltd. 1991
 */

#include "kernel.h"

#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Global/Upcall.h"

#ifdef DEBUG
#  define DEBUGLIB
#endif
#include "DebugLib/DebugLib.h"

#define REFRESH_INTERVAL  3000
#define REMOVE_TOUT       200
#define ADD_TOUT          200
#define DOMAIN_DISC       1
#define DOMAIN_PRINTER    2
#define DOMAIN_HOST       5

struct fwtype
{
    struct fwtype    *fw_next;
    int		      fw_number;
    char	      fw_name[16];	/* CE - 25/11/96 ; added (description) */
    int		      fw_refcount;
    int		      fw_validate;
    int		      fw_dovalidate;
    int		      fw_authreqtout;
    int		      fw_doauthreq;
    int		      fw_removetout;
    int		      fw_doremove;
    int		      fw_addtout;
    int		      fw_doadd;
    struct object_q  *fw_remobj;      /* remote unauthenticated objects */
#if 0
    struct object_q  *fw_locobj;      /* local unauthenticated objects */
#endif
    struct authreq_q *fw_authreq;     /* list of locally registered auth values */
};

struct fw
{
    int		     fw_rssock;
    int		     fw_rssock1;
    int		     fw_ifcnt;
    char	     fw_ifunit[16][16];
    u_long	     fw_ifaddrs[16];
    u_long	     fw_ifbcast[16];
    struct address_q *fw_netadrs;
    struct fwtype    *fw_types;
};

struct serial_if
{
  int		serial_if_request;	/* 1=> bring up interface */
  int		serial_if_action;	/* reason code for interface state change */
  char		serial_if_name[16];	/* name of interface to use */
};

struct rs_msg
{
    char	       rs_msgid;
#define REQUEST	       1
#define ADD	       2
#define REMOVE	       3
#define REFRESH	       4
    short	       rs_type;
    short	       rs_format;
    short	       rs_nblocks;
    /* variable length body follows */
};

#define RETRY_INTERVAL	  500
#define MAX_RETRIES	    3

struct object_q
{
    struct object_q   *r_next;
    short	       r_inuse;
    struct in_addr     r_ip;		     /* owner's IP address */
    short	       r_validate;	     /* type refresh interval countdown */
    int		       r_dovalidate;
    int		       r_retries;
    int		       r_format;	     /* 0=unauthenticated, 1=authenticated */
    char	      *r_title;		     /* object name */
    char	      *r_desc;		     /* descriptor field */
    int		       r_desclen;	     /* length of descriptor field */
    int		       r_authval;	     /* authenticator value */
    int		       r_local;		     /* object is local */
};

struct authreq_q
{
    struct authreq_q  *a_next;
    short	      a_refcount;
    int		      a_authval;
};

struct address_q
{
    struct address_q *q_next;
    struct in_addr    q_bcast;
};

#define SocketIO	   1 /* Subreason to internet event */

#define FWPORT		   0x8002
#define FWPORT1		   0x8003

#define FW_ADDED    0
#define FW_REMOVED  1
#define FW_CHANGED  2
#define FW_DELETED  3

struct eblk
{
    int   err_nbr;
    char *err_token;
};

#define Err_FWType     1
#define Err_FWOExt     2
#define Err_FWONex     3
#define Err_FWDBuf     4
#define Err_FWNBuf     5
#define Err_FWNMem     6
#define Err_FWOUnk     7
#define Err_FWNNet     8
#define Err_FWLStr     9
#define Err_FWNLoc     10
#define Err_FWNAut     11
#define Err_FWNoInet   12
#define Err_FWStatus   13
#define Err_FWInvalSWI 14
#define Err_FWSerNoInt 15
#define Err_FWSerParam 16

/*
 * function declarations
 */
extern const char *fw_lookup(const char *token);
extern _kernel_oserror *fw_error(int error);
extern _kernel_oserror *RegisterType(_kernel_swi_regs *r);
extern _kernel_oserror *WriteObject(_kernel_swi_regs *r);
extern _kernel_oserror *ReadObject(_kernel_swi_regs *r);
extern _kernel_oserror *EnumerateObjects(_kernel_swi_regs *r);

extern struct fwtype *gettype(int type);

extern int type_id(char *str);
extern void *Resources(void); /* From ResGen */

extern void setcallback(void);
extern void fw_upcall(int upc, int type, struct object_q *rq);
extern void do_protocol(struct fwtype *f, u_long dest, struct object_q *rq,
			int msgid, int format, int rauthval, int skipauth);
extern void process_message(u_long src, struct rs_msg *rsm, int len,
			    int format);
extern void check_objects(struct fwtype *f);
extern void do_objects_on_callback(void);

extern u_long local_adr;
extern int doobjects;
extern struct fw fw;
extern struct serial_if serial_if;

			     /* .oOo. */

extern void do_objects_on_callback(void);
extern void check_objects(struct fwtype *f);
extern void do_protocol(struct fwtype *f, u_long dest, struct object_q *rq,
			int msgid, int format, int rauthval, int skipauth);
extern void process_message(u_long src, struct rs_msg *rsm,
			    int len, int format);

/* EOF module.h */
