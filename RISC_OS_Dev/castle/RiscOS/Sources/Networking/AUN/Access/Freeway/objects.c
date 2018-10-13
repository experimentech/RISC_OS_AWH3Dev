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
 * Freeway (objects.c)
 *
 * Copyright (C) Acorn Computers Ltd. 1992-9
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "kernel.h"
#include "swis.h"

#include "sys/types.h"
#include "sys/uio.h"
#include "sys/socket.h"

#include "netinet/in.h"
#include "net/if.h"
#include "inetlib.h"

#include "module.h"

/**********************************************************************/

static int caseless_strcmp(char *a, char *b)
{
    int d;

    while ( *a || *b )
    {
	d = toupper( *(a++) ) - toupper( *(b++) );
	if ( d )
	    return d;
    }

    return 0;
}

/**********************************************************************/

static void new_object(struct fwtype *f, u_long src, int format,
		       char *title, char *desc, int desclen,
		       int authval, struct object_q **rqp)
{
    struct object_q *rq;

    /* shut the compiler up */
    f = f;
    format = format;

    if( *rqp == 0 )
    {
	rq = (struct object_q *)malloc(sizeof(struct object_q));
	if (rq == 0)
	    return;
	    
	memset((char *)rq, 0, sizeof(struct object_q));
	*rqp = rq;
    }
    else
	rq = *rqp;

    if( title )
    {
	if( rq->r_title && strlen(title) > strlen(rq->r_title) )
	{
	    free(rq->r_title);
	    rq->r_title = 0;
	}

	if( rq->r_title == 0 )
	    rq->r_title = malloc(strlen(title)+1);

	if( rq->r_title )
	    strcpy(rq->r_title, title);
    }

    rq->r_ip.s_addr = src;
    rq->r_desclen = 0;

    if( desclen && desc )
    {
	if( rq->r_desc == 0 )
	    rq->r_desc = malloc(desclen+1);

	if( rq->r_desc )
	{
	    memcpy(rq->r_desc, desc, desclen);
	    rq->r_desclen = desclen;
	}
    }
    rq->r_authval = authval;
    rq->r_validate = REFRESH_INTERVAL + RETRY_INTERVAL;
    rq->r_retries = 0;
    rq->r_inuse = 1;
    rq->r_local=0;
}

/**********************************************************************/

static void send_fw_message(struct fwtype *f, u_long dest, short mtype,
			    int nblocks, char *blocks, int blen, int format)
{
    struct sockaddr_in sin;
    struct rs_msg rs;
    struct msghdr msg;
    struct iovec msgvec[2];
    int i, nvec = 1;


    dprintf(("objects", "SFM> Sending message:"));
    if( format )
	dprintf(("objects", "auth,"));
    else
	dprintf(("objects", "unauth,"));

    if( mtype == REQUEST )
	dprintf(("objects", "request\n"));
    if( mtype == ADD )
	dprintf(("objects", "add\n"));
    if( mtype == REMOVE )
	dprintf(("objects", "remove\n"));
    if( mtype == REFRESH )
	dprintf(("objects", "refresh\n"));

    memset((char *)&rs, 0, sizeof(rs));
    rs.rs_msgid = mtype;
    rs.rs_type = f->fw_number;
    /* cast added 22/7/94 gw */
    rs.rs_format = (short)format;
    rs.rs_nblocks = nblocks;
    msgvec[0].iov_base = (char *)&rs;
    msgvec[0].iov_len  = sizeof(struct rs_msg);
    if( nblocks > 0 )
    {
	msgvec[1].iov_base = blocks;
	msgvec[1].iov_len  = blen;
	nvec = 2;
    }
    sin.sin_family	 = AF_INET;
    sin.sin_port	 = (format == 1) ?
	htons((u_short)FWPORT1) : htons((u_short)FWPORT);
    sin.sin_addr.s_addr	 = dest;
    msg.msg_name	 = (char *)&sin;
    msg.msg_namelen	 = sizeof(sin);
    msg.msg_iov		 = &msgvec[0];
    msg.msg_iovlen	 = nvec;
    msg.msg_accrights	 = 0;
    msg.msg_accrightslen = 0;

    if( dest == INADDR_BROADCAST )
    {
	if( format==0 || !fw.fw_netadrs )
	{
	    for( i = 0; i < fw.fw_ifcnt; i++ )
	    {
		if (fw.fw_ifbcast[i] == INADDR_NONE)
      	        {
         	  dprintf(("objects", "SFM> Called with INADDR_NONE (%s)- skipping\n",fw.fw_ifunit[i]));
		  continue;
		}
		sin.sin_addr.s_addr = fw.fw_ifbcast[i];
		(void) sendmsg(format ? fw.fw_rssock1 : fw.fw_rssock, &msg, 0);
	    }
	}
	else
	{
	    struct address_q *q;
	    for( q = fw.fw_netadrs; q; q = q->q_next )
	    {
		if((q->q_bcast.s_addr) &&  ((q->q_bcast.s_addr) != INADDR_NONE))
		{
		    dprintf(("objects", "SFM> sending message to %s\n",
		        inet_ntoa(q->q_bcast)));
		    sin.sin_addr.s_addr = q->q_bcast.s_addr;
		    (void)sendmsg(format ? fw.fw_rssock1 : fw.fw_rssock,
				  &msg, 0);
		}
	    }
	}
    }
    else
	(void)sendmsg(format ? fw.fw_rssock1 : fw.fw_rssock, &msg, 0);
}

/**********************************************************************/

void do_protocol(struct fwtype *f, u_long dest, struct object_q *rq,
		 int msgid, int format, int rauthval, int skipauth)
{
    int nblocks, mlen;
    char blocks[1024], *b;
    struct object_q *r;
    int titlelen, desclen, authval;

    b = blocks;
    nblocks = 0;
    mlen = 0;
    for( r = f->fw_remobj; r; r = r->r_next )
    {
	if( !r->r_inuse || !r->r_local || (rq && rq != r) ||
	   (rauthval && r->r_authval != rauthval) ||
	   (skipauth && r->r_authval) )
	    continue;

	titlelen = strlen(r->r_title);
	desclen = r->r_desclen;
	authval = r->r_authval;
	if( (mlen + titlelen + desclen + 12) >= sizeof(blocks) )
	{
	    send_fw_message(f, dest, msgid, nblocks, blocks, mlen, format);
	    b = blocks;
	    nblocks = 0;
	    mlen = 0;
	}

	*(short *)b = titlelen;
	*(short *)(b+2) = desclen;
	b += 4;

	/* modified 25/7/94 gw */
	if( format == 1 )
	{
#ifndef AUTH32
	    *(u_short *)b = authval & 0xffff;
	    b += 2;
#else
	    *(u_int *)b = authval;
	    b += 4;
#endif
	}

	memcpy(b, r->r_title, titlelen);
	b += titlelen;
	if( desclen )
	{
	    memcpy(b, r->r_desc, desclen);
	    b += desclen;
	}

        b = (char *) (((unsigned)b + 3) &~ 3);

	nblocks++;
	mlen = b - blocks;
	if (rq)
	    break;
    }

    if( nblocks > 0 )
	send_fw_message(f, dest, msgid, nblocks, blocks, mlen, format);
}

/**********************************************************************/

void process_message(u_long src, struct rs_msg *rsm, int len, int format)
{
    struct object_q **r;
    short mtype = rsm->rs_msgid;
    int n, namelen, desclen, authval, type = rsm->rs_type;
    char name[64], *desc, *b;
    struct fwtype *f;
    int changed = 0;

    /* shut the compiler up */
    (void) len;

    dprintf(("objects", "process message:"));

    if( format )
    {
	dprintf(("objects", "auth,"));
	dprintf(("objects", "val=%d",*(((u_short *)rsm)+4)));
    }
    else
	dprintf(("objects", "unauth,"));

    dprintf(("objects", "type %d,",type));
    if( mtype==REQUEST )
	dprintf(("objects", "request\n"));
    if( mtype==ADD )
	dprintf(("objects", "add\n"));

    if( mtype==REMOVE )
	dprintf(("objects", "remove\n"));

    if( mtype==REFRESH )
	dprintf(("objects", "refresh\n"));

    if( (f = gettype(type)) == 0 || f->fw_refcount < 1 )
	return;

    if( format == 0 && mtype == REQUEST )
    {
	do_protocol(f, src, 0, REFRESH, 0, 0, 1);
	return;
    }

    if( format == 1 )
    {
	if( mtype == REMOVE )
	{
	    struct object_q *rq;
	    for( rq = f->fw_remobj; rq; rq = rq->r_next )
	    {
		if( rq->r_inuse && !rq->r_local &&
		   rq->r_authval &&
		   rq->r_validate > 0 )
		{
		    rq->r_validate = 1;
		    rq->r_retries = 1;	/* set dodgy object flags; validate
					 * on next event */
		}
	    }
	    return;
	}
	else if( mtype == ADD )
	{
	    if (f->fw_authreqtout > 0)
		f->fw_authreqtout = 1; /* refresh all on next timeout */
	    return;
	}
	/* 25/7/94 gw */
	else if( mtype == REQUEST && rsm->rs_nblocks )
	{
#ifndef AUTH32
	    authval = *(((u_short *)rsm) + 4);
#else
	    authval = *(((u_int *)rsm) + 2);
#endif

	    dprintf(("objects", "sending refresh for authval %d\n",authval));
	    do_protocol(f, src, 0, REFRESH, 1, authval, 0);
	    return;
	}
    }

    if( rsm->rs_nblocks == 0 )
	return;

    b = (char *)(&rsm->rs_nblocks);
    b += 2;
    authval = 0;

    for( n = 0; n < rsm->rs_nblocks; n++ )
    {
	namelen = *(short *)b;
	if( namelen <= 0 || namelen >= 64 )
	    return;

	desclen = *(short *)(b + 2);
	if( desclen < 0 || desclen >= 256 )
	    return;

	b += 4;
	if( format == 1 )
	{
#ifndef AUTH32
	    /* move+modify 25/7/94 gw */
	    authval=*(u_short *)b;
	    b += 2;
#else
	    authval=*(u_int *)b;
	    b+=4;
#endif
	}

	memcpy(name, b, namelen);
	name[namelen] = 0;
	b += namelen;
	desc = b;

	/*
	 * first check to see if object is also held locally.
	 * If so, there is a possible name clash; delete the object.
	 */
	r = &(f->fw_remobj);
	while( *r )
	{
	    if( (*r)->r_inuse && (*r)->r_local &&
	       caseless_strcmp((*r)->r_title, name) == 0 )
	    {
		if( mtype != REMOVE )
		{
		    if( format == 0 )
			do_protocol(f, INADDR_BROADCAST, *r, REMOVE, 0, 0, 1);
		    else if( !f->fw_removetout )
			f->fw_removetout = REMOVE_TOUT; /* if not already done,
							 * flag for remove on
							 * next tick */
		}

		(*r)->r_inuse = 0;
		fw_upcall(FW_DELETED, type, (*r));

		if( (*r)->r_desc )
		{
		    /* 22/7/94 moved gw */
		    free((*r)->r_desc);
		    (*r)->r_desc = 0;
		}

		if( mtype==REMOVE )
		    /* 22/7/94 modified gw */
		    goto next;
	    }
	    r = &((*r)->r_next);
	}

	/*
	 * now add, remove, or change the object on the remote list
	 */
	r = &(f->fw_remobj);
	while( *r )
	{
	    if( (*r)->r_inuse &&
	       !(*r)->r_local && caseless_strcmp((*r)->r_title, name) == 0 )
	    {
		if( mtype == REMOVE )
		{
		    (*r)->r_inuse = 0;
		    fw_upcall(FW_REMOVED, type, (*r));
		    if( (*r)->r_desc )
		    {
			free((*r)->r_desc); /* 22/7/94 moved gw */
			(*r)->r_desc = 0;
		    }
		}
		else
		{
		    /* if mtype != REMOVE */
		    (*r)->r_validate = REFRESH_INTERVAL + RETRY_INTERVAL;
		    (*r)->r_retries = 0;
		    if( (*r)->r_desc != 0 &&
		       ((*r)->r_desclen != desclen ||
			memcmp((*r)->r_desc, desc, desclen) != 0) )
		    {
			if( (*r)->r_desclen < desclen )
			{
			    /*
			     * can free here; will call
			     * new_object before upcall
			     */
			    free((*r)->r_desc);
			    (*r)->r_desc = 0;
			}

			changed = 1;
		    }
		    else if( (*r)->r_ip.s_addr != src )
			changed = 1;

		    if( changed )
			new_object(f, src, format, name, desc,
				   desclen, authval, r);

		    if( mtype == REFRESH && changed )
			fw_upcall(FW_CHANGED, type, (*r));

		    if( mtype == ADD )
		    {
			fw_upcall(FW_REMOVED, type, (*r));
			fw_upcall(FW_ADDED, type, (*r));
		    }
		    changed = 0;
		}
		goto next;
	    }
	    r = &((*r)->r_next);
	}

	if( mtype != REMOVE )
	{
	    r = &(f->fw_remobj);
	    while( *r )
	    {
		if( !(*r)->r_inuse )
		    break;

		r = &((*r)->r_next);
	    }

	    if( authval )
	    {
		/*
		 * surely this should be if (format == 1),
		 * though as written above it will work
		 */
		struct authreq_q *a;

		for( a = f->fw_authreq; a; a = a->a_next )
		{
		    if (a->a_authval == authval)
			break;
		}
		if( !a )
		    goto next;
	    }

	    new_object(f, src, format, name, desc, desclen, authval, r);
	    fw_upcall(FW_ADDED, type, (*r));
	}

      next:
	b += desclen;
        b = (char *) (((unsigned)b + 3) &~ 3);
    }
}

/**********************************************************************/

/* performed on tick event for each known type */
void check_objects(struct fwtype *f)
{
    struct object_q *r;
    int callb = 0;

    for (r = f->fw_remobj; r; r = r->r_next)
    {
	if (r->r_inuse && !(r->r_local) &&
	    (r->r_validate > 0 && --r->r_validate == 0))
	{
	    r->r_dovalidate = 1;
	    callb = 1;
	}
    }

    if (f->fw_validate > 0 && --f->fw_validate == 0)
    {
	f->fw_dovalidate = 1;
	callb = 1;
    }

    if (f->fw_authreqtout > 0 && --f->fw_authreqtout == 0)
    {
	f->fw_doauthreq = 1;
	callb = 1;
    }

    if (f->fw_removetout > 0 && --f->fw_removetout == 0)
    {
	f->fw_doremove = 1;
	callb = 1;
    }

    if (f->fw_addtout > 0 && --f->fw_addtout == 0)
    {
	f->fw_doadd = 1;
	callb = 1;
    }

    if (callb)
    {
	doobjects = 1;
	setcallback();
    }
}

/**********************************************************************/

static void send_auth_message(struct fwtype *f, int mtype,
			      u_long dst, int authval)
{
    char *b, block[12];

    b = block;
#ifndef AUTH32
    /* modified 25/7/94 gw */
    *(u_short *)b = authval & 0xffff;
#else
    *(u_int *)b = authval;
#endif
    send_fw_message(f, dst, mtype, 1, block, 4, 1);
}

/**********************************************************************/

void do_objects_on_callback(void)
{
    struct fwtype *f;
    struct object_q *r, *rr;
    struct authreq_q *a;

    for (f = fw.fw_types; f != 0; f = f->fw_next) {
#ifdef DEBUGLIB
        dprintf(("objects", "OOC> Refreshing objects:"));
	switch(f->fw_number) {
	    case DOMAIN_DISC: dprintf(("objects", "Discs...")); break;
	    case DOMAIN_PRINTER: dprintf(("objects", "Printers...")); break;
	    case DOMAIN_HOST: dprintf(("objects", "Hosts...")); break;
	    default: dprintf(("objects", "type %d...",f->fw_number)); break;
	    }
#endif/* DEBUGLIB */

	for (r = f->fw_remobj; r; r = r->r_next)
	{
	    dprintf(("objects", "Object: %s ", r->r_title));

	    if (!r->r_inuse || r->r_local || !r->r_dovalidate)
		continue;

	    dprintf(("objects", "Retries: %d ", r->r_retries));
	    r->r_dovalidate = 0;
	    if (r->r_retries < MAX_RETRIES)
	    {
		if (r->r_authval != 0) {
		    dprintf(("objects", "Sending auth request...\n"));
		    send_auth_message(f, REQUEST, r->r_ip.s_addr,
				      r->r_authval);
		    }
		else {
		    dprintf(("objects", "Sending unauth request...\n"));
		    send_fw_message(f, r->r_ip.s_addr, REQUEST,
				    0, (char *)0, 0, 0);
		    }
		r->r_retries++;
		r->r_validate = RETRY_INTERVAL;

		for (rr = r->r_next; rr; rr = rr->r_next)
		{
		    if (!rr->r_inuse)
			continue;

		    if (rr->r_ip.s_addr != r->r_ip.s_addr ||
			rr->r_authval != r->r_authval)
			continue;

		    dprintf(("objects", "Updating other objects too"));

		    rr->r_retries++;
		    rr->r_validate = RETRY_INTERVAL + 1;
		}
	    }
	    else
	    {
		dprintf(("objects", "Max retries exceeded. Removing!"));
		r->r_inuse = 0;
		r->r_retries = 0;
		fw_upcall(FW_REMOVED, f->fw_number, r);
	    }
	}
	dprintf(("objects", "\n"));

	if (f->fw_dovalidate)
	{
	    dprintf(("objects", "OOC> Periodic revalidation of all.\n"));

	    f->fw_dovalidate = 0;
	    do_protocol(f, INADDR_BROADCAST, 0, REFRESH, 0, 0, 1);
	    f->fw_validate = REFRESH_INTERVAL;
	}

	if (f->fw_doremove)
	{
	    dprintf(("objects", "OOC> Doing send_auth_message, REMOVE, INADDR_BROADCAST\n"));
	    f->fw_doremove = 0;
	    send_auth_message(f, REMOVE, INADDR_BROADCAST, 0);
	}

	if (f->fw_doadd)
	{
	    dprintf(("objects", "OOC> Doing send_auth_message, ADD, INADDR_BROADCAST\n"));
	    f->fw_doadd = 0;
	    send_auth_message(f, ADD, INADDR_BROADCAST, 0);
	}

	if (f->fw_doauthreq)
	{
	    dprintf(("objects", "OOC> Refreshing all authenticated objects:-\n"));

	    f->fw_doauthreq = 0;
	    for (a = f->fw_authreq; a; a = a->a_next)
	    {
		if (!a->a_refcount)
		    continue;

		dprintf(("objects", "OOC> key: %d \n", a->a_authval));

		send_auth_message(f, REQUEST, INADDR_BROADCAST, a->a_authval);
	    }
	    f->fw_authreqtout = REFRESH_INTERVAL;
	}
    }
}

/**********************************************************************/

_kernel_oserror *RegisterType(_kernel_swi_regs *r)
{
    int    type, newinterest, format, authval ;
    const char *name;
    struct fwtype *f;
    struct object_q *rq;
    struct authreq_q *a;
    int    error = 0;

    dprintf(("objects", "registertype flg %x type %x authval %x name@ %p\n",
	r->r[0], r->r[1], r->r[2], r->r[3]));

    newinterest = (r->r[0] & (1<<0)) ? 0 : 1;
    format = (r->r[0] & (1<<1)) ? 1 : 0;   /* format=0 for unauthenticated */
    type = (u_short)r->r[1];
    authval = format==1 ? r->r[2] : 0;
    if (r->r[0] & (1<<2))
    {
      name = (char *)r->r[3];              /* CE - 27/11/96 */
    }
    else
    {
      char token[10];

      sprintf(token, "Type%u", type);
      name = fw_lookup(token);
    }

    dprintf(("objects", "RT>> newinterest=%x format=%x type=%x authval=%x name=%s\n",
	newinterest,format,type,authval,name));

    for (f = fw.fw_types; f != 0; f = f->fw_next)
	if (f->fw_number == type) {
	    dprintf(("objects", "RT>> Found existing objects of same type\n"));
	    break;
	    }


    if (f == 0)
    {
	if (!newinterest)   /* misfeature fix 3/8/94 gw  -- why? PWain */
	    goto out;

	dprintf(("objects", "RT>> No existing objects found - creating a new one\n"));

	f = (struct fwtype *)malloc(sizeof(struct fwtype));

	if (f == 0)
	{
	    error = Err_FWNMem;
	    goto out;
	}

	memset((char *)f, 0, sizeof(struct fwtype));
	f->fw_number = type;
	strncpy(f->fw_name,name,sizeof(f->fw_name));	/* CE - 27/11/96 */
	f->fw_validate = REFRESH_INTERVAL;
	f->fw_next = fw.fw_types;
	fw.fw_types = f;
    }

    if (newinterest)
    {
	dprintf(("objects", "RT>> New interest. No information known.\n"));
	f->fw_refcount++;
	if (f->fw_refcount == 1) {
	    dprintf(("objects", "RT>> Broadcasting request for info\n"));
	    send_fw_message(f, INADDR_BROADCAST, REQUEST, 0, (char *)0, 0, 0);
	    }

	if (format==1)
	{
	    dprintf(("objects", "RT>> Doing Authentication checks\n"));
	    for (a = f->fw_authreq; a; a = a->a_next)
		if (a->a_authval == authval) {
		    dprintf(("objects", "RT>> Matched password. Using found object\n"));
		    break;
		    }

	    if (!a)
	    {
		dprintf(("objects", "RT>> Nothing found. Creating dummy entry.\n"));
		a = (struct authreq_q *) malloc(sizeof(struct authreq_q));
		if (a == 0)
		{
		    error = Err_FWNMem;
		    goto out;
		}

		a->a_refcount = 0;
		a->a_authval = authval;
		a->a_next = f->fw_authreq;
		f->fw_authreq = a;
		f->fw_refcount++;
	    }

	    if (++a->a_refcount == 1) {
		dprintf(("objects", "RT>> Broadcasting authentication request!\n"));
		send_auth_message(f, REQUEST, INADDR_BROADCAST, authval);
		}

	    if (!f->fw_authreqtout && !f->fw_doauthreq)
		f->fw_authreqtout = REFRESH_INTERVAL;
	}
    }
    else
    {
	/* if !newinterest */
	if (f->fw_refcount > 0)
	{
	    f->fw_refcount--;
	    if (f->fw_refcount == 0)
	    {
		for (rq = f->fw_remobj; rq; rq = rq->r_next)
		{
		    if (rq->r_inuse)
			fw_upcall(FW_REMOVED, f->fw_number, rq);
		    rq->r_inuse = 0;
		}

		for (a = f->fw_authreq; a; a = a->a_next)
		    a->a_refcount = 0;

		f->fw_authreqtout = 0;
		f->fw_doauthreq = 0;	/* really should free the memory */
	    }
	}

	if (format==1 && f->fw_refcount>0)
	{
	    for (a = f->fw_authreq; a; a = a->a_next)
	    {
		if (a->a_authval == authval && a->a_refcount > 0)
		{
		    a->a_refcount--;
		    if (a->a_refcount == 0)
		    {
			for (rq = f->fw_remobj; rq; rq = rq->r_next)
			{
			    if (rq->r_inuse && rq->r_authval == authval)
			    {
				rq->r_inuse = 0;
				fw_upcall(FW_REMOVED, f->fw_number, rq);
			    }
			}
		    }
		    break;
		}
	    }
	}
    }

  out:
    return(fw_error(error));
}

/**********************************************************************/

_kernel_oserror *WriteObject(_kernel_swi_regs *r)
{
    struct object_q *rl, *freerl, **rlq;
    int doregister, type, desclen, authval, format, local;
    char *title, *desc;
    struct fwtype *f;
    int error = 0;

    dprintf(("objects", "writeobject flg %x type %x name %s auth %x\n",
	   r->r[0], r->r[1], (char *)r->r[2], r->r[5]));

    type = r->r[1];
    f = gettype(type);
    if (f == 0 || f->fw_refcount < 1)
    {
	/* returns error if not registered */
	error = Err_FWType;
	goto out;
    }

    doregister = (r->r[0] & 01) ? 0 : 1;
    format = (r->r[0] & 02) ? 1 : 0;
    local = (r->r[0] & 04) ? 0 : 1;
    title = (char *)r->r[2];
    desclen = r->r[3];
    desc = (char *)r->r[4];
    authval = format==1 ? r->r[5] : 0;

    if (strlen(title) >= 64 || desclen >= 255)
    {
	/* should generate error */
	error = Err_FWLStr; /* 26/7/94 gw */
	goto out;
    }

    for (rl = f->fw_remobj; rl; rl = rl->r_next)
    {
	if (rl->r_inuse && !rl->r_local &&
	    caseless_strcmp(title, rl->r_title) == 0)
	{
	    error = Err_FWNLoc; /* 26/7/94 gw */
	    goto out;
	}
    }

    rlq = &(f->fw_remobj);  /* why is further indirection needed here? */
    freerl = 0;

    while (*rlq)
    {
	if (!(*rlq)->r_inuse)
	    freerl = *rlq;    /*note unused chain blocks for later use*/

	if ((*rlq)->r_inuse && (*rlq)->r_local &&
	    caseless_strcmp((*rlq)->r_title, title) == 0)
	{
	    if (!doregister)
	    {
		if ((*rlq)->r_authval && (*rlq)->r_authval != authval)
		{
		    error = Err_FWNAut; /* 26/7/94 gw */
		    goto out;
		}

		if (format == 0)
		{
		    fw_upcall(FW_REMOVED, type, *rlq);
		    do_protocol(f, INADDR_BROADCAST, *rlq, REMOVE, 0, 0, 1);
		}
		else if (!f->fw_removetout)
		    f->fw_removetout = REMOVE_TOUT; /* remove on next tick */

		(*rlq)->r_inuse = 0;
	    }
	    else
	    {
		/* if doregister and object name known */
		if ((format == 1) && ((*rlq)->r_authval != authval))
		{
		    /* 25/7/94 gw */
		    send_auth_message(f, REMOVE, INADDR_BROADCAST,
				      (*rlq)->r_authval);
		}

		if (((*rlq)->r_desc &&
		     (desclen != (*rlq)->r_desclen ||
		      memcmp(desc, (*rlq)->r_desc, desclen) != 0)) ||
		    ((format == 1) && ((*rlq)->r_authval != authval)))
		{
		    /* 26/7/94 gw */
		    rl = *rlq;
		    free(rl->r_desc);
		    rl->r_desc = 0;
		    rl->r_desclen = 0;
		    goto newdesc;
		}
	    }
	    goto out;
	}

	rlq = &((*rlq)->r_next);
    }

    /*
     * at this point, we know we have
     * no record of the object
     */
    if (!doregister)
    {
	/* 26/7/94 gw */
	error = Err_FWONex;
	goto out;
    }

    rl = freerl ? freerl : *rlq;
    if (rl == 0)
    {
	rl = (struct object_q *)malloc(sizeof(struct object_q));

	if (rl == 0)
	{
	    error = Err_FWNMem;
	    goto out;
	}

	memset((char *)rl, 0, sizeof(struct object_q));
	*rlq = rl;
    }

    rl->r_ip.s_addr = local_adr;
    rl->r_local=1;
    if (rl->r_title && strlen(title) > strlen(rl->r_title))
    {
	free(rl->r_title);
	rl->r_title = 0;
    }

    if (rl->r_title == 0)
    {
	rl->r_title = malloc(strlen(title)+1);

	if (rl->r_title == 0)
	{
	    error = Err_FWNMem;
	    goto out;
	}
    }
    strcpy(rl->r_title, title);

  newdesc:
    if (desc && desclen)
    {
	rl->r_desc = malloc(desclen + 1);
	if (rl->r_desc == 0)
	{
	    error = Err_FWNMem;
	    goto out;
	}

	memcpy(rl->r_desc, desc, desclen);
	rl->r_desclen = desclen;
    }

    rl->r_authval = authval;
    rl->r_inuse = 1;

    if (format == 0)
    {
	do_protocol(f, INADDR_BROADCAST, rl, ADD, 0, 0, 1);
	fw_upcall(FW_ADDED, type, rl);
    }
    else
	f->fw_addtout = ADD_TOUT; /* ?again, process on tick */

  out:
    return(fw_error(error));
}

/**********************************************************************/

_kernel_oserror *ReadObject(_kernel_swi_regs *r)
{
    struct fwtype *f;
    struct object_q *rq;
    int desclen, auth, authval, error = 0;

    dprintf(("objects", "FRO> Auth=%d PIN=%d\n",(r->r[0] & 01) ? 1 : 0 , r->r[5]));
    f = gettype(r->r[1]);
    if (f == 0 || f->fw_refcount < 1)
    {
	error = Err_FWType;
	goto out;
    }

    auth = (r->r[0] & 01) ? 1 : 0;
    desclen = r->r[3];
    /*
     * Is this correct? I think it should be r->r[1] (see
     * ../ShareFS/ShareFS/internet.c in owner_logon() )
     * PWAIN 060295
     *
     * authval = auth ? r->r[5] : 0;     corrected 22/7/94 gw
     */
    authval = auth ? r->r[5] : 0;

    for (rq = f->fw_remobj; rq; rq = rq->r_next)
    {
	if (!rq->r_inuse || caseless_strcmp((char *)r->r[2], rq->r_title) != 0)
	    continue;

	if (auth && rq->r_authval != authval)
	    continue;

	r->r[3] = rq->r_desclen;
	if (rq->r_desc && r->r[4])
	{
	    if (desclen < rq->r_desclen)
		error = Err_FWDBuf;
	    else
		memcpy((char *)r->r[4], rq->r_desc, rq->r_desclen);
	}

	r->r[5] = (int)rq->r_ip.s_addr;
	break;
    }

    if (!rq)
	error = Err_FWOUnk;

  out:
    return(fw_error(error));
}

/**********************************************************************/

_kernel_oserror *EnumerateObjects(_kernel_swi_regs *r)
{
    struct fwtype *f;
    struct object_q *rq;
    int desclen, namelen, auth, authval, error = 0;

    dprintf(("objects", "FEO> enum flg %x type %x enumref %x authval %x\n",
	   r->r[0], r->r[1], r->r[7], r->r[8]));

    f = gettype(r->r[1]);
    if (f == 0 || f->fw_refcount < 1)
    {
	dprintf(("objects", "FEO> Error: Err_FWType\n"));
	error = Err_FWType;
	goto out;
    }

    auth = (r->r[0] & 01) ? 1 : 0;
    namelen = r->r[2];
    desclen = r->r[4];
    authval = (auth==1) ? r->r[8] : 0;
    rq = (struct object_q *)r->r[7];

    for (rq = rq ? rq->r_next : f->fw_remobj; rq; rq = rq->r_next)
    {
	if (!rq->r_inuse)
	    continue;

	if (auth && rq->r_authval != authval)
	    continue;

	break;
    }

    if (rq == 0)
    {
	r->r[7] = -1;
	goto out;

}
    r->r[2] = strlen(rq->r_title) + 1;
    r->r[4] = rq->r_desclen;

    if (r->r[3])
    {
	if (namelen <= strlen(rq->r_title))
	{
	    dprintf(("objects", "FEO> Error: Err_FWNBuf"));
	    error = Err_FWNBuf;
	    goto out;
	}
	strcpy((char *)r->r[3], rq->r_title);
    }

    if (rq->r_desc && r->r[5])
    {
	if (desclen < rq->r_desclen)
	{
	    dprintf(("objects", "FEO> Error: Err_FWNBuf"));
	    error = Err_FWDBuf;
	    goto out;
	}
	memcpy((char *)r->r[5], rq->r_desc, rq->r_desclen);
    }

    r->r[6] = (int)rq->r_ip.s_addr;
    r->r[7] = (int)rq;

  out:
    dprintf(("objects", "FEO> Returning error code: %d (%x)\n", error, error));
    return(fw_error(error));
}

/**********************************************************************/

/* EOF objects.c */
