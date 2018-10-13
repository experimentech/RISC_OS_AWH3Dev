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
#ifndef __kernel_h
#include "kernel.h"
#endif
#ifndef __sys_dcistructs_h
#include "sys/dcistructs.h"
#endif

typedef struct machinetime
{
    unsigned int l,h;
} machinetime;

extern _kernel_oserror *mbuf_open_session(struct mbctl *);
extern _kernel_oserror *mbufcontrol_version(int *);
extern _kernel_oserror *mbuf_close_session(struct mbctl *);
extern _kernel_oserror *messagetrans_file_info(const char *filename);
extern _kernel_oserror *messagetrans_open_file(u_long *fd, const char *filename,
                                               char *buffer);
extern void             messagetrans_close_file(u_long *fd);
extern _kernel_oserror *messagetrans_lookup(u_long *fd, const char *token,
                                            char *buffer, int size,
                                            char **result);
extern _kernel_oserror *resourcefs_register_files(void *resarea);
extern _kernel_oserror *resourcefs_deregister_files(void *resarea);
extern void             service_dci_protocol_status(void *wsp, int status,
                                                    int ver, const u_char *title);
extern void             service_internetstatus_address_changed(void);
extern void             service_internetstatus_interface_updown(int state, const char *name,
                                                                const void *dib);
extern int              service_internetstatus_dynamicboot_start(const char *name, const void *dib,
                                                                 char *pkt, int len, int eoo,
                                                                 unsigned int *error);
extern int              service_internetstatus_dynamicboot_reply(const char *name, const void *dib,
                                                                 char *pkt, int len);
extern int              service_internetstatus_dynamicboot_inform(char *pkt, int len);
extern int              service_internetstatus_duplicate_ip_address(const char *name, const void *dib,
                                                                    struct in_addr ia, u_char *ha);
extern _kernel_oserror *service_enumerate_network_drivers(ChDibRef *);
extern void            *osmodule_claim(size_t);
extern void             osmodule_free(void *);
extern u_long           os_read_monotonic_time(void);
extern _kernel_oserror *os_generate_event(int, int, int, int);
extern _kernel_oserror *os_claim(int, void (*fun)(void), void *);
extern void             os_release(int, void (*fun)(void), void *);
extern _kernel_oserror *os_add_call_back(void (*fun)(void), void *);
extern void             os_remove_call_back(void (*fun)(void), void *);
extern struct mbuf     *econet_inet_rx_direct(int, struct mbuf *,
                                              struct sockaddr *, char *,
                                              int, int, struct mbuf *);
extern _kernel_oserror *taskwindow_task_info(int, int *);
extern int              os_upcall(int, volatile void *);
extern void             osword_read_realtime(machinetime *);
extern u_int            osreadsysinfo_hardware0(void);
extern void             osreadsysinfo_machineid(unsigned int *);
extern void             portable_idle(void);
extern u_int            portable_read_features(void);
extern int              os_read_escape_state(void);
