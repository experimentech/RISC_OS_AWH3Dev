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
 * The mrouted program is covered by the license in the accompanying file
 * named "LICENSE".  Use of the mrouted program represents acceptance of
 * the terms and conditions listed in that file.
 *
 * The mrouted program is COPYRIGHT 1989 by The Board of Trustees of
 * Leland Stanford Junior University.
 *
 *
 * $Id: route,v 1.1 1999-07-22 16:49:58 kbracey Exp $
 * route.h,v 3.8.4.6 1997/07/01 23:02:35 fenner Exp
 */

/*
 * Routing Table Entry, one per subnet from which a multicast could originate.
 * (Note: all addresses, subnet numbers and masks are kept in NETWORK order.)
 *
 * The Routing Table is stored as a doubly-linked list of these structures,
 * ordered by decreasing value of rt_originmask and, secondarily, by
 * decreasing value of rt_origin within each rt_originmask value.
 * This data structure is efficient for generating route reports, whether
 * full or partial, for processing received full reports, for clearing the
 * CHANGED flags, and for periodically advancing the timers in all routes.
 * It is not so efficient for updating a small number of routes in response
 * to a partial report.  In a stable topology, the latter are rare; if they
 * turn out to be costing a lot, we can add an auxiliary hash table for
 * faster access to arbitrary route entries.
 */
struct rtentry {
    struct rtentry  *rt_next;		/* link to next entry MUST BE FIRST */
    u_int32	     rt_origin;		/* subnet origin of multicasts      */
    u_int32	     rt_originmask;	/* subnet mask for origin           */
    short	     rt_originwidth;	/* # bytes of origin subnet number  */
    u_char	     rt_metric;		/* cost of route back to origin     */
    u_char	     rt_flags;		/* RTF_ flags defined below         */
    u_int32	     rt_gateway;	/* first-hop gateway back to origin */
    vifi_t	     rt_parent;	    	/* incoming vif (ie towards origin) */
    vifbitmap_t	     rt_children;	/* outgoing children vifs           */
    u_int32	    *rt_dominants;      /* per vif dominant gateways        */
    nbrbitmap_t	     rt_subordinates;   /* bitmap of subordinate gateways   */
    nbrbitmap_t	     rt_subordadv;      /* recently advertised subordinates */
    u_int	     rt_timer;		/* for timing out the route entry   */
    struct rtentry  *rt_prev;		/* link to previous entry           */
    struct gtable   *rt_groups;		/* link to active groups 	    */
};

#define	RTF_CHANGED		0x01	/* route changed but not reported   */
#define	RTF_HOLDDOWN		0x04	/* this route is in holddown	    */

#define ALL_ROUTES	0		/* possible arguments to report()   */
#define CHANGED_ROUTES	1		/*  and report_to_all_neighbors()   */

#define	RT_FMT(r, s)	inet_fmts((r)->rt_origin, (r)->rt_originmask, s)
