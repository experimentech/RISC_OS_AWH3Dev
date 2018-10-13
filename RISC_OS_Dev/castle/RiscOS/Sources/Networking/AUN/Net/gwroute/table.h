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
/* table.h
 *
 * Author: Keith Ruttle (Acorn)
 *
 * Description
 * ===========
 * Header file for routing table
 *
 * Environment
 * ===========
 * Acorn RISC OS 3.11 or later.
 *
 * Compiler
 * ========
 * Acorn Archimedes C release 5.06 or later.
 *
 * Change record
 * =============
 *
 * JPD  Jem Davies (Cambridge Systems Design)
 *
 * 17-Oct-95  10:06  JPD  Version 1.00
 * First version with change record.
 *
 *
 **End of change record*
 */

/******************************************************************************/

#define rtentry ortentry

/*
 * Routing table structure
 */
#ifdef OldCode
struct rthash {
        struct  rt_entry *rt_forw;
        struct  rt_entry *rt_back;
};

struct rt_entry {
        struct  rt_entry *rt_forw;
        struct  rt_entry *rt_back;
        union {
                struct  rtentry rtu_rt;
                struct {
                        u_long  rtu_hash;
                        struct  sockaddr rtu_dst;
                        struct  sockaddr rtu_router;
                        short   rtu_flags;
                        short   rtu_state;
                        int     rtu_timer;
                        int     rtu_metric;
                        int     rtu_ifmetric;
                        struct  interface *rtu_ifp;
                } rtu_entry;
        } rt_rtu;
};
#else

struct rthash
{
   struct rt_entry *rt_forw;
   struct rt_entry *rt_back;
};

struct rt_entry
{
   struct rt_entry *rt_forw;
   struct rt_entry *rt_back;
   union
   {
      struct rtentry rtu_rt;
      struct rtuentry
      {
         u_long rtu_hash;
         struct sockaddr rtu_dst;
         struct sockaddr rtu_router;
         short  rtu_flags;
         short  rtu_state;
         int    rtu_timer;
         int    rtu_metric;
         int    rtu_ifmetric;
         struct interface *rtu_ifp;
      } rtu_entry;
   } rt_rtu;
};

#endif

#define rt_rt           rt_rtu.rtu_rt
#define rt_hash         rt_rtu.rtu_entry.rtu_hash
#define rt_dst          rt_rtu.rtu_entry.rtu_dst
#define rt_router       rt_rtu.rtu_entry.rtu_router
#define rt_flags        rt_rtu.rtu_entry.rtu_flags
#define rt_timer        rt_rtu.rtu_entry.rtu_timer
#define rt_state        rt_rtu.rtu_entry.rtu_state
#define rt_metric       rt_rtu.rtu_entry.rtu_metric
#define rt_ifmetric     rt_rtu.rtu_entry.rtu_ifmetric
#define rt_ifp          rt_rtu.rtu_entry.rtu_ifp

#define ROUTEHASHSIZ    32
#define ROUTEHASHMASK   (ROUTEHASHSIZ - 1)

/*
 * "State" of routing table entry.
 */
#define RTS_CHANGED     0x1
#define RTS_EXTERNAL    0x2
#define RTS_INTERNAL    0x4
#ifdef OldCode
#define RTS_PASSIVE     IFF_PASSIVE    /* appears unused? */
#endif
#define RTS_INTERFACE   IFF_INTERFACE
#define RTS_REMOTE      IFF_REMOTE
#define RTS_SUBNET      IFF_SUBNET


#define RTF_SUBNET      0x8000

#define ADD 1
#define DELETE 2
#define CHANGE 3

#ifdef OldCode
extern struct  rthash nethash[ROUTEHASHSIZ];
extern struct  rthash hosthash[ROUTEHASHSIZ];
#endif

#ifdef OldCode
struct rt_entry *rtlookup();
struct rt_entry *rtfind();
#else
extern struct rt_entry *rtlookup(struct sockaddr *dst);
extern struct rt_entry *rtfind(struct sockaddr *dst);
extern void rtadd(struct sockaddr *dst, struct sockaddr *gate, int metric,
                                                                     int state);
extern void rtchange(struct rt_entry *rt, struct sockaddr *gate, short metric);
extern void rtdelete(struct rt_entry *rt);
extern void rtinit(void);
#endif

/******************************************************************************/

/* EOF table.h */
