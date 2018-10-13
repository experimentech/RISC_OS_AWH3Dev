; This source code in this file is licensed to You by Castle Technology
; Limited ("Castle") and its licensors on contractual terms and conditions
; ("Licence") which entitle you freely to modify and/or to distribute this
; source code subject to Your compliance with the terms of the Licence.
; 
; This source code has been made available to You without any warranties
; whatsoever. Consequently, Your use, modification and distribution of this
; source code is entirely at Your own risk and neither Castle, its licensors
; nor any other person who has contributed to this source code shall be
; liable to You for any loss or damage which You may suffer as a result of
; Your use, modification or distribution of this source code.
; 
; Full details of Your rights and obligations are set out in the Licence.
; You should have received a copy of the Licence with this source code file.
; If You have not received a copy, the text of the Licence is available
; online at www.castle-technology.co.uk/riscosbaselicence.htm
; 

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:APCS.<APCS>
        GET     Hdr:ModHand
        GET     Hdr:MsgTrans
        GET     Hdr:Services
        GET     Hdr:OsWords
        GET     Hdr:ResourceFS
        GET     Hdr:Portable
        GET     Hdr:TaskWindow
        GET     Hdr:Econet

XMbuf_OpenSession               *       &6A580
XMbuf_CloseSession              *       &6A581
XMbuf_Control                   *       &6A584

InternetStatus_AddressChanged   *       0
InternetStatus_InterfaceUpDown  *       2
InternetStatus_DynamicBootStart *       3
InternetStatus_DynamicBootReply *       4
InternetStatus_DynamicBootInform *      7
InternetStatus_DuplicateIPAddress *     8

        EXPORT  econet_inet_rx_direct
        EXPORT  mbufcontrol_version
        EXPORT  mbuf_close_session
        EXPORT  mbuf_open_session
        EXPORT  messagetrans_close_file
        EXPORT  messagetrans_file_info
        EXPORT  messagetrans_lookup
        EXPORT  messagetrans_open_file
        EXPORT  osmodule_claim
        EXPORT  osmodule_free
        EXPORT  osreadsysinfo_hardware0
        EXPORT  osreadsysinfo_machineid
        EXPORT  osword_read_realtime
        EXPORT  os_add_call_back
        EXPORT  os_claim
        EXPORT  os_generate_event
        EXPORT  os_read_escape_state
        EXPORT  os_read_monotonic_time
        EXPORT  os_release
        EXPORT  os_remove_call_back
        EXPORT  os_upcall
        EXPORT  portable_idle
        EXPORT  portable_read_features
        EXPORT  resourcefs_register_files
        EXPORT  resourcefs_deregister_files
        EXPORT  service_dci_protocol_status
        EXPORT  service_enumerate_network_drivers
        EXPORT  service_internetstatus_address_changed
        EXPORT  service_internetstatus_duplicate_ip_address
        EXPORT  service_internetstatus_dynamicboot_inform
        EXPORT  service_internetstatus_dynamicboot_reply
        EXPORT  service_internetstatus_dynamicboot_start
        EXPORT  service_internetstatus_interface_updown
        EXPORT  taskwindow_task_info

        AREA    swiveneers,CODE,READONLY,PIC

; _kernel_oserror *mbuf_open_session(struct mbctl *);
        ROUT
mbuf_open_session
        MOV     ip,lr
        SWI     XMbuf_OpenSession
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *mbufcontrol_version(int *version_out);
        ROUT
mbufcontrol_version
        MOV     ip,lr
        STR     a1,[sp,#-4]!
        MOV     a1,#0
        SWI     XMbuf_Control
        BVS     %F01
        LDR     lr,[sp]
        TEQS    lr,#0
        STRNE   a1,[lr]
        MOV     a1,#0
01      ADD     sp,sp,#4
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *mbuf_close_session(struct mbctl *);
        ROUT
mbuf_close_session
        MOV     ip,lr
        SWI     XMbuf_CloseSession
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *messagetrans_file_info(const char *filename);
        ROUT
messagetrans_file_info
        MOV     ip,lr
        MOV     a2,a1
        SWI     XMessageTrans_FileInfo
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *messagetrans_open_file(u_long *fd, const char *filename, char *buffer);
        ROUT
messagetrans_open_file
        MOVS    ip,lr
        SWI     XMessageTrans_OpenFile
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *messagetrans_lookup(u_long *fd, const char *token, char *buffer, int size, char **result);
        ROUT
messagetrans_lookup
        MOV     ip,sp
        FunctionEntry "v1-v4"
        MOV     v1,#0
        MOV     v2,#0
        MOV     v3,#0
        MOV     v4,#0
        SWI     XMessageTrans_Lookup
        Return  "v1-v4",,VS
        LDR     lr,[ip]
        TEQS    lr,#0
        STRNE   a3,[lr]
        MOV     a1,#0
        Return  "v1-v4"

; void messagetrans_close_file(u_long *fd);
        ROUT
messagetrans_close_file
        MOVS    ip,lr
        SWI     XMessageTrans_CloseFile
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *resourcefs_register_files(void *resarea);
        ROUT
resourcefs_register_files
        MOV     ip,lr
        SWI     XResourceFS_RegisterFiles
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *resourcefs_deregister_files(void *resarea);
        ROUT
resourcefs_deregister_files
        MOV     ip,lr
        SWI     XResourceFS_DeregisterFiles
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; void service_dci_protocol_status(void *wsp, int status, int ver, const char *title)
        ROUT
service_dci_protocol_status
        FunctionEntry "v1"
        MOV     v1,a4
        MOV     a4,a3
        MOV     a3,a2
        MOV     a2,#Service_DCIProtocolStatus
        SWI     XOS_ServiceCall
        Return  "v1"

; void service_internetstatus_address_changed(void)
        ROUT
service_internetstatus_address_changed
        MOV     ip,lr
        MOV     a1,#InternetStatus_AddressChanged
        MOV     a2,#Service_InternetStatus
        SWI     XOS_ServiceCall
        Return  ,LinkNotStacked,,ip

; void service_internetstatus_interface_updown(int state, const char *name, const void *dib)
        ROUT
service_internetstatus_interface_updown
        FunctionEntry "v1"
        MOV     v1,a3
        MOV     a4,a2
        MOV     a3,a1
        MOV     a2,#Service_InternetStatus
        MOV     a1,#InternetStatus_InterfaceUpDown
        SWI     XOS_ServiceCall
        Return  "v1"

; int service_internetstatus_dynamicboot_start(const char *name, const void *dib, char *pkt, int len,
; int eoo, int *error_code)
        ROUT
service_internetstatus_dynamicboot_start
        MOV     ip, sp
        FunctionEntry "a1-a4,v1-v6"
        Pull    "a3-a4,v1,v2"
        Push    "ip"
        LDR     v3, [ip]
        MOV     a2,#Service_InternetStatus
        MOV     a1,#InternetStatus_DynamicBootStart
        SWI     XOS_ServiceCall
        Pull    "ip"
        LDR     a4, [ip, #4]
        STRVC   a3, [a4]
        MOVVS   a1, #0
        STRVS   a1, [a4]
        MOVVC   a1, a2
        Return  "v1-v6"

; int service_internetstatus_dynamicboot_reply(const char *name, const void *dib, char *pkt, int len)
        ROUT
service_internetstatus_dynamicboot_reply
        FunctionEntry "a1-a4,v1-v6"
        Pull    "a3-a4,v1,v2"
        MOV     a2,#Service_InternetStatus
        MOV     a1,#InternetStatus_DynamicBootReply
        SWI     XOS_ServiceCall
        MOVVS   a1, #Service_InternetStatus
        MOVVC   a1, a2
        Return  "v1-v6"

; int service_internetstatus_dynamicboot_inform(char *pkt, int len)
        ROUT
service_internetstatus_dynamicboot_inform
        FunctionEntry "v1-v6"
        MOV     a4, a2
        MOV     a3, a1
        MOV     a2,#Service_InternetStatus
        MOV     a1,#InternetStatus_DynamicBootReply
        SWI     XOS_ServiceCall
        MOVVS   a1, #Service_InternetStatus
        MOVVC   a1, a2
        Return  "v1-v6"

; int service_internetstatus_duplicate_ip_address(const char *name, const void *dib, struct in_addr addr, u_char *hwaddr)
        ROUT
service_internetstatus_duplicate_ip_address
        FunctionEntry "v1-v2"
        MOV     v2,a4
        MOV     v1,a3
        MOV     a4,a2
        MOV     a3,a1
        MOV     a2,#Service_InternetStatus
        MOV     a1,#InternetStatus_DuplicateIPAddress
        SWI     XOS_ServiceCall
        MOVVC   a1, a2
        Return  "v1-v2"

; void service_enumerate_network_drivers(ChDibRef *)
        ROUT
service_enumerate_network_drivers
        MOV     ip,lr
        MOV     a4,a1
        MOV     a1,#0
        MOV     a2,#Service_EnumerateNetworkDrivers
        SWI     XOS_ServiceCall
        STRVC   a1,[a4]
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; void *osmodule_claim(size_t size)
        ROUT
osmodule_claim
        MOV     ip,lr
        MOV     a4,a1
        MOV     a1,#ModHandReason_Claim
        SWI     XOS_Module
        MOVVC   a1,a3
        MOVVS   a1,#0
        Return  ,LinkNotStacked,,ip

; void osmodule_free(void *)
        ROUT
osmodule_free
        MOV     ip,lr
        MOV     a3,a1
        MOV     a1,#ModHandReason_Free
        SWI     XOS_Module
        Return  ,LinkNotStacked,,ip

; u_long os_read_monotonic_time(void)
        ROUT
os_read_monotonic_time
        MOV     ip,lr
        SWI     XOS_ReadMonotonicTime
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *os_generate_event(int, int, int, int)
        ROUT
os_generate_event
        MOV     ip,lr
        SWI     XOS_GenerateEvent
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *os_claim(int, int (*fun)(), void *)
        ROUT
os_claim
        MOV     ip,lr
        SWI     XOS_Claim
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; void os_release(int, int (*fun)(), void *)
        ROUT
os_release
        MOV     ip,lr
        SWI     XOS_Release
        Return  ,LinkNotStacked,,ip

; _kernel_oserror *os_add_call_back(int (*fun)(), void *)
        ROUT
os_add_call_back
        MOV     ip,lr
        SWI     XOS_AddCallBack
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; void os_remove_call_back(int (*fun)(), void *)
        ROUT
os_remove_call_back
        MOV     ip,lr
        SWI     XOS_RemoveCallBack
        Return  ,LinkNotStacked,,ip

; int econet_inet_rx_direct(int, int, int, int, int, int, int)
        ROUT
econet_inet_rx_direct
        MOV     ip,sp
        FunctionEntry "v1-v3"
        LDMIA   ip,{v1-v3}
        SWI     XEconet_InetRxDirect
        MOV     a1,a2
        Return  "v1-v3"

; _kernel_oserror *taskwindow_task_info(int, int *)
        ROUT
taskwindow_task_info
        MOV     ip,lr
        MOV     a4,a2
        SWI     XTaskWindow_TaskInfo
        STRVC   a1,[a4]
        MOVVC   a1,#0
        Return  ,LinkNotStacked,,ip

; int os_upcall(int, volatile void *)
        ROUT
os_upcall
        MOV     ip,lr
        SWI     XOS_UpCall
        Return  ,LinkNotStacked,,ip

; unsigned osreadsysinfo_hardware0(void)
        ROUT
osreadsysinfo_hardware0
        FunctionEntry "v1"
        MOV     a1,#2
        SWI     XOS_ReadSysInfo
        MOVVS   a1,#0
        Return  "v1"

; void osreadsysinfo_machineid(unsigned int *mac)
        ROUT
osreadsysinfo_machineid
        FunctionEntry "v1"
        MOV     ip,a1
        MOV     a1,#2
        SWI     XOS_ReadSysInfo
        STMVCIA ip,{a4,v1}
        Return  "v1"

; void osword_read_realtime(machinetime *mt)
        ROUT
osword_read_realtime
        MOV     ip,lr
        MOV     a2,a1
        MOV     a1,#OsWord_ReadRealTimeClock
        MOV     lr,#OWReadRTC_5ByteInt
        STRB    lr,[a2]
        SWI     XOS_Word
        Return  ,LinkNotStacked,,ip

; unsigned portable_read_features(void)
        ROUT
portable_read_features
        MOV     ip,lr
        SWI     XPortable_ReadFeatures          ; Returns features mask in R1
        BVC     %FT01
        MOV     a1,#0                           ; Not available - may be an A4.
        MVN     a2,#0                           ; See if we have Portable_Speed.
        SWI     XPortable_Speed
        MOVVC   a2,#PortableFeature_Speed
        MOVVS   a2,#0
01      MOV     a1,a2
        Return  ,LinkNotStacked,,ip

; void portable_idle(void)
        ROUT
portable_idle
        MOV     ip,lr
        SWI     XPortable_Idle
        Return  ,LinkNotStacked,,ip

; int os_read_escape_state(void)
        ROUT
os_read_escape_state
        MOV     ip,lr
        SWI     XOS_ReadEscapeState
        MOVCC   a1,#0
        MOVCS   a1,#1
        Return  ,LinkNotStacked,,ip

        END
