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
/* RISC OS path seperator */
#define PATH_SEP '.'

/* Need some renamed magic constants from "TCPIPLibs:arpa.h.nameser" */
#define NS_MAXDNAME  MAXDNAME
#define NS_MAXCDNAME MAXCDNAME
#define NS_INT32SZ   INT32SZ
#define NS_INT16SZ   INT16SZ
#define NS_IN6ADDRSZ IN6ADDRSZ
#define NS_INADDRSZ  INADDRSZ

/* Flags & misc functions */
#include "addrinfo.h"
#include "unixlib.h"

/* Stuff implemented elsewhere */
extern int getaddrinfo(char *,int *,void *,void *); //?
extern void freeaddrinfo(void *); //?
extern u_int ns_get16(const u_char *);
extern u_long ns_get32(const u_char *);
extern void ns_put16(u_int,u_char *);
extern int ns_name_unpack(const u_char *,const u_char *,const u_char *, u_char *, size_t);
extern int ns_name_ntol(const u_char *, u_char *, size_t);
extern int ns_samename (const char *, const char *);

extern const struct res_sym __p_default_section_syms[];
extern const struct res_sym __p_update_section_syms[];
extern const struct res_sym __p_key_syms[];
extern const struct res_sym __p_rcode_syms[];
extern const struct res_sym __p_cert_syms[];
extern const struct res_sym __p_type_syms[];
extern const struct res_sym __p_class_syms[];

extern char * __progname;

/* Macro */
#define NOTUSED(k) k=k;

/* Accessor macros - this is part of the public interface. */
#define ns_rr_name(rr)  (((rr).name[0] != '\0') ? (rr).name : ".")
#define ns_rr_type(rr)  ((ns_type)((rr).type + 0))
#define ns_rr_class(rr) ((ns_class)((rr).rr_class + 0))
#define ns_rr_ttl(rr)   ((rr).ttl + 0)
#define ns_rr_rdlen(rr) ((rr).rdlength + 0)
#define ns_rr_rdata(rr) ((rr).rdata + 0)

/* The Algorithm field of the KEY and SIG RR's is an integer, {1..254} */
#define NS_ALG_MD5RSA           1       /* MD5 with RSA */
#define NS_ALG_DH               2       /* Diffie Hellman KEY */
#define NS_ALG_DSA              3       /* DSA KEY */
#define NS_ALG_DSS              NS_ALG_DSA
#define NS_ALG_EXPIRE_ONLY      253     /* No alg, no security */
#define NS_ALG_PRIVATE_OID      254     /* Key begins with OID giving alg */

#define S_ZONE		ns_s_zn
#define S_PREREQ	ns_s_pr
#define S_UPDATE	ns_s_ud
#define S_ADDT		ns_s_ar

#define C_NONE		ns_c_none

/* More magic constants,all stolen from "nameser.h" */
typedef enum __ns_type {
        ns_t_invalid = 0,       /* Cookie. */
        ns_t_a = 1,             /* Host address. */
        ns_t_ns = 2,            /* Authoritative server. */
        ns_t_md = 3,            /* Mail destination. */
        ns_t_mf = 4,            /* Mail forwarder. */
        ns_t_cname = 5,         /* Canonical name. */
        ns_t_soa = 6,           /* Start of authority zone. */
        ns_t_mb = 7,            /* Mailbox domain name. */
        ns_t_mg = 8,            /* Mail group member. */
        ns_t_mr = 9,            /* Mail rename name. */
        ns_t_null = 10,         /* Null resource record. */
        ns_t_wks = 11,          /* Well known service. */
        ns_t_ptr = 12,          /* Domain name pointer. */
        ns_t_hinfo = 13,        /* Host information. */
        ns_t_minfo = 14,        /* Mailbox information. */
        ns_t_mx = 15,           /* Mail routing information. */
        ns_t_txt = 16,          /* Text strings. */
        ns_t_rp = 17,           /* Responsible person. */
        ns_t_afsdb = 18,        /* AFS cell database. */
        ns_t_x25 = 19,          /* X_25 calling address. */
        ns_t_isdn = 20,         /* ISDN calling address. */
        ns_t_rt = 21,           /* Router. */
        ns_t_nsap = 22,         /* NSAP address. */
        ns_t_nsap_ptr = 23,     /* Reverse NSAP lookup (deprecated). */
        ns_t_sig = 24,          /* Security signature. */
        ns_t_key = 25,          /* Security key. */
        ns_t_px = 26,           /* X.400 mail mapping. */
        ns_t_gpos = 27,         /* Geographical position (withdrawn). */
        ns_t_aaaa = 28,         /* Ip6 Address. */
        ns_t_loc = 29,          /* Location Information. */
        ns_t_nxt = 30,          /* Next domain (security). */
        ns_t_eid = 31,          /* Endpoint identifier. */
        ns_t_nimloc = 32,       /* Nimrod Locator. */
        ns_t_srv = 33,          /* Server Selection. */
        ns_t_atma = 34,         /* ATM Address */
        ns_t_naptr = 35,        /* Naming Authority PoinTeR */
        ns_t_kx = 36,           /* Key Exchange */
        ns_t_cert = 37,         /* Certification record */
        ns_t_a6 = 38,           /* IPv6 address (deprecates AAAA) */
        ns_t_dname = 39,        /* Non-terminal DNAME (for IPv6) */
        ns_t_sink = 40,         /* Kitchen sink (experimentatl) */
        ns_t_opt = 41,          /* EDNS0 option (meta-RR) */
        ns_t_tkey = 249,        /* Transaction key */
        ns_t_tsig = 250,        /* Transaction signature. */
        ns_t_ixfr = 251,        /* Incremental zone transfer. */
        ns_t_axfr = 252,        /* Transfer zone of authority. */
        ns_t_mailb = 253,       /* Transfer mailbox records. */
        ns_t_maila = 254,       /* Transfer mail agent records. */
        ns_t_any = 255,         /* Wildcard match. */
        ns_t_zxfr = 256,        /* BIND-specific, nonstandard. */
        ns_t_max = 65536
} ns_type;

typedef enum __ns_class {
        ns_c_invalid = 0,       /* Cookie. */
        ns_c_in = 1,            /* Internet. */
        ns_c_2 = 2,             /* unallocated/unsupported. */
        ns_c_chaos = 3,         /* MIT Chaos-net. */
        ns_c_hs = 4,            /* MIT Hesiod. */
        /* Query class values which do not appear in resource records */
        ns_c_none = 254,        /* for prereq. sections in update requests */
        ns_c_any = 255,         /* Wildcard match. */
        ns_c_max = 65536
} ns_class;

typedef enum __ns_opcode {
        ns_o_query = 0,         /* Standard query. */
        ns_o_iquery = 1,        /* Inverse query (deprecated/unsupported). */
        ns_o_status = 2,        /* Name server status query (unsupported). */
                                /* Opcode 3 is undefined/reserved. */
        ns_o_notify = 4,        /* Zone change notification. */
        ns_o_update = 5,        /* Zone update message. */
        ns_o_max = 6
} ns_opcode;

typedef enum __ns_rcode {
        ns_r_noerror = 0,       /* No error occurred. */
        ns_r_formerr = 1,       /* Format error. */
        ns_r_servfail = 2,      /* Server failure. */
        ns_r_nxdomain = 3,      /* Name error. */
        ns_r_notimpl = 4,       /* Unimplemented. */
        ns_r_refused = 5,       /* Operation refused. */
        /* these are for BIND_UPDATE */
        ns_r_yxdomain = 6,      /* Name exists */
        ns_r_yxrrset = 7,       /* RRset exists */
        ns_r_nxrrset = 8,       /* RRset does not exist */
        ns_r_notauth = 9,       /* Not authoritative for zone */
        ns_r_notzone = 10,      /* Zone of record different from zone section */
        ns_r_max = 11,
        /* The following are EDNS extended rcodes */
        ns_r_badvers = 16,
        /* The following are TSIG errors */
        ns_r_badsig = 16,
        ns_r_badkey = 17,
        ns_r_badtime = 18
} ns_rcode;

typedef enum __ns_cert_types {
        cert_t_pkix = 1,        /* PKIX (X.509v3) */
        cert_t_spki = 2,        /* SPKI */
        cert_t_pgp  = 3,        /* PGP */
        cert_t_url  = 253,      /* URL private type */
        cert_t_oid  = 254       /* OID private type */
} ns_cert_types;

typedef enum __ns_sect {
        ns_s_qd = 0,            /* Query: Question. */
        ns_s_zn = 0,            /* Update: Zone. */
        ns_s_an = 1,            /* Query: Answer. */
        ns_s_pr = 1,            /* Update: Prerequisites. */
        ns_s_ns = 2,            /* Query: Name servers. */
        ns_s_ud = 2,            /* Update: Update. */
        ns_s_ar = 3,            /* Query|Update: Additional records. */
        ns_s_max = 4
} ns_sect;

typedef enum __ns_flag {
        ns_f_qr,                /* Question/Response. */
        ns_f_opcode,            /* Operation code. */
        ns_f_aa,                /* Authoritative Answer. */
        ns_f_tc,                /* Truncation occurred. */
        ns_f_rd,                /* Recursion Desired. */
        ns_f_ra,                /* Recursion Available. */
        ns_f_z,                 /* MBZ. */
        ns_f_ad,                /* Authentic Data (DNSSEC). */
        ns_f_cd,                /* Checking Disabled (DNSSEC). */
        ns_f_rcode,             /* Response code. */
        ns_f_max
} ns_flag;
