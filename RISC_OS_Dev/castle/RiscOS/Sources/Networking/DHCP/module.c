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
 *  DHCP (module.c)
 *
 * Copyright (C) Element 14 Ltd. 1999
 *
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"

#include "Global/Services.h"
#include "Global/NewErrors.h"
#include "Global/RISCOS.h"

#include "VersionNum"
#include "DHCPhdr.h"

#include "sys/types.h"
#include "sys/socket.h"
#include "sys/dcistructs.h"
#include "net/if.h"
#include "protocols/dhcp.h"
#include "netinet/in.h"
#include "arpa/inet.h"

#include "dhcpintern.h"
#include "interfaces.h"
#include "sockets.h"
#include "module.h"
#include "packets.h"
#include "dhcpinform.h"
#include "iparp.h"

extern void usermode_donothing(void);

/* ========== Callback code ========== */

/* Callback management.  We need to arrange to be called back in the foreground when
 * our timer fires.
 */
static volatile int callbackflag = 0;
static volatile int callafterflag = 0;

_kernel_oserror *callback_handler(_kernel_swi_regs *r, void *private_word)
{
	(void) r;

	if (callbackflag != 0) {
		callbackflag = 0;
		interfaces_timer_fired(private_word);
	}
	return 0;
}

static void setcallback(void *private_word)
{
	if (callbackflag == 0) {
		if (_swix(OS_AddCallBack, _INR(0,1), callback, private_word) == NULL) {
			callbackflag = 1;
		}
	}
}

_kernel_oserror *callafter_handler(_kernel_swi_regs *r, void *private_word)
{
	(void) r;
	setcallback(private_word);
	callafterflag = 0;
	return NULL;
}

void module_reschedule(int delay, void *private_word)
{
	if (callafterflag != 0) {
		/* Delete existing timeout in favour of a new one */
		_swix(OS_RemoveTickerEvent, _INR(0,1), callafter, private_word);
	}
	callafterflag = 1;
	if (_swix(OS_CallAfter, _INR(0,2), delay, callafter, private_word)) {
		callafterflag = 0;
	}
}

#define SOCKET_ASYNC_EVENT  1
int dhcp_event_handler(_kernel_swi_regs *r, void *private_word)
{
	if (r->r[1] == SOCKET_ASYNC_EVENT) {
		/* sockets module will decide whether to swallow the event or not */
		return sockets_data_arrived(r->r[2], private_word);
	}
	return 1; /* Pass event on */
}

static void module_disable_internet_event(void)
{
	(void) _swix(OS_Byte, _INR(0,1), 13, Event_Internet); /* disable event */
}

static void module_enable_internet_event(void)
{
	(void) _swix(OS_Byte, _INR(0,1), 14, Event_Internet); /* enable event */
}

static void module_clearsystemhooks(void *private_word)
{
	if (callafterflag != 0) {
		(void) _swix(OS_RemoveTickerEvent, _INR(0,1), callafter, private_word);
		callafterflag = 0;
	}
	if (callbackflag != 0) {
		(void) _swix(OS_RemoveCallBack, _INR(0,1), callback, private_word);
		callbackflag = 0;
	}

	module_disable_internet_event();
	(void) _swix(OS_Release, _INR(0,2), EventV, dhcp_event, private_word);
}

static _kernel_oserror *module_initsystemhooks(void *private_word)
{
	_kernel_oserror *e;

	callafterflag = 0;
	callbackflag = 0;

	e = _swix(OS_Claim, _INR(0,2), EventV, dhcp_event, private_word);
	if (e == NULL) {
		module_enable_internet_event();
	}

	/* CallAfter and CallBack will be set as and when required, no need to set anything
	 * up right here right now.
	 */

	return e;
}

/* End callafter/callback management */

static int msg_struct[4];
static _kernel_oserror msg_buff;

_kernel_oserror *dhcp_swi(int swi_number, _kernel_swi_regs *r, void *private_word)
{
	_kernel_oserror *e = NULL;

	sockets_ensure_init();

	switch (swi_number) {
		case DHCP_Version - DHCP_00:
			r->r[0] = Module_VersionNumber;
			break;
		case DHCP_GetState - DHCP_00:
			e = dhcp_swi_getstate(r);
			break;
		case DHCP_GetOption - DHCP_00:
			e = dhcp_swi_getoption(r);
			break;
		case DHCP_Execute - DHCP_00:
			e = dhcp_swi_execute(r, private_word);
			break;
		case DHCP_SetOption - DHCP_00:
			e = dhcp_swi_setoption(r);
			break;
		case DHCP_Inform - DHCP_00:
			e = dhcp_swi_inform(r);
			break;
		default:
			return error_BAD_SWI;
	}

	return e;
}

_kernel_oserror *dhcp_finalise(int fatal, int podule, void *private_word)
{
	(void) fatal;
	(void) podule;

	dhcpinform_discard();
	interfaces_discard();
	sockets_discard();
	module_clearsystemhooks(private_word);

	/* Tidy up the messages (and deregister from ResourceFS if not in ROM) */
	_swix(MessageTrans_CloseFile, _IN(0), msg_struct);
#ifndef ROM
	_swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
#endif
	return NULL;
}

_kernel_oserror *dhcp_initialise(const char *cmd_tail, int podule_base, void *private_word)
{
	_kernel_oserror *e;

	(void) cmd_tail;
	(void) podule_base;

	srand(interfaces_current_time());

#ifndef ROM
	e = _swix(ResourceFS_RegisterFiles, _IN(0), Resources());
	if (e != NULL) goto failinit;
#endif
	e = _swix(MessageTrans_OpenFile, _INR(0,2), msg_struct, Module_MessagesFile, 0);
	if (e != NULL) goto faildereg;

	e = module_initsystemhooks(private_word);
	if (e != NULL) goto failclose;

	interfaces_init();
	sockets_init();
	dhcpinform_init();
	return NULL;

failclose:
	_swix(MessageTrans_CloseFile, _IN(0), msg_struct);
faildereg:
#ifndef ROM
	_swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
failinit:
#endif
	return e;
}

void dhcp_service(int service_number, _kernel_swi_regs *r, void *private_word)
{
        if (service_number == Service_DCIProtocolStatus) {
                const char *protocol_module = (char *) r->r[4];
                if (strcmp("Internet", protocol_module) != 0) return;
                if (r->r[2] == DCIPROTOCOL_DYING) {
                        dhcp_finalise(0, 0, private_word);
                }
                else if (r->r[2] == DCIPROTOCOL_STARTING) {
                        if (sockets_init_ok()) {
                                dhcp_finalise(0, 0, private_word);
                        }
                        dhcp_initialise(0, 0, private_word);
                }

                return;
        }
        if (service_number == Service_DCIDriverStatus) {
                if (r->r[2] == DCIDRIVER_STARTING) {
                        Dib *dib = (Dib *) r->r[0];
                        dhcp_interface *di;
                        char name[100];
                        sprintf(name, "%s%u", dib->dib_name, dib->dib_unit);
                        trace(("Interface %s starting (dib=%p)\n", name, (void *) dib));
                        di = interfaces_find(name);
                        if (di) di->dib = dib;
                }
                return;
        }
        if (service_number == Service_ResourceFSStarting) {
#ifndef ROM
                (*(void (*)(void *, void *, void *, void *))r->r[2])(Resources(), 0, 0, (void *)r->r[3]);
#endif
                return;
        }
	/* Only Service_InternetStatus will arrive here */
	switch (r->r[0]) {
		case InternetStatus_DynamicBootStart:
			sockets_ensure_init();
			if (dhcp_prepare_request((dhcp_start_params *) r, private_word)) {
				r->r[1] = Service_Serviced;
			}
			break;

		case InternetStatus_AddressChanged:
			interfaces_address_changed();
			break;

		case InternetStatus_DuplicateIPAddress:
			if (interfaces_address_clash((Dib *) r->r[3], (u_long) r->r[4])) {
				r->r[1] = Service_Serviced;
				interfaces_reschedule(private_word);
			}
			break;

		default:
			break;
	}

}

static _kernel_oserror *dhcp_command_args_parse(const char *arg_string, char *iname, int *flags)
{
	union {
		const char *args[5];
		char buffer[36];
	} ra_buf;
	const char *const ra_pattern = "e/s,b=block/s,w/s,p/s,/a";
	_kernel_oserror *e;

	e = _swix(OS_ReadArgs, _INR(0,3), ra_pattern, arg_string, &ra_buf, sizeof(ra_buf));
	if (e == NULL) {
		if (ra_buf.args[0]) *flags |= decf_SET_ERROR;
		if (ra_buf.args[1]) *flags |= decf_BLOCK;
		if (ra_buf.args[2]) *flags |= decf_WAIT;
		if (ra_buf.args[3]) *flags |= decf_PRIVATE;
		(void) strncpy(iname, ra_buf.args[4], IFNAMSIZ);
		iname[IFNAMSIZ] = '\0';
		iname[strcspn(iname, "\r\n\t ")] = '\0';
	}
	return e;
}

static _kernel_oserror *dhcp_check_escape_key(void)
{
	int esc_flags;
	_swix(OS_ReadEscapeState, _OUT(_FLAGS), &esc_flags);
	if (esc_flags & _C) {
		trace(("DHCP:Escape pressed\n"));
		_swix(OS_Byte, _IN(0), 126);

		return module_make_error(ErrorNumber_Escape);
	}
	return NULL;
}

static _kernel_oserror *dhcp_cmd_execute(const char *arg_string, void *private_word)
{
	_kernel_oserror *e;
	char ifname[IFNAMSIZ + 1];
	int flags = 0;
	int oldescapestate;

	e = dhcp_command_args_parse(arg_string, ifname, &flags);
	if (e != NULL) {
	  trace(("dhcp_command_args_parse: %s\n", e->errmess));
	  return e;
	}

        /* Polling escape will only work if escape is enabled */
        _swix(OS_Byte, _INR(0,2) | _OUT(1), 229, 0, 0, &oldescapestate);

	while (e == NULL) {
		dhcp_swi_execute_regs exec_args;

		exec_args.flags = dse_IMMEDIATE_START;
		if (flags & decf_BLOCK) exec_args.flags |= dse_BLOCKING_MODE;
		if (flags & decf_PRIVATE) exec_args.flags |= dse_ASSIGN_PRIVATE_IP;
		exec_args.if_name = ifname;

		e = dhcp_swi_execute((_kernel_swi_regs *) &exec_args, private_word);
		if (e == NULL) {
		        flags &= ~decf_WAIT;
		}
		if (e != NULL) {
		        if ((flags & decf_WAIT) == 0) break;
		        if (e->errnum != ErrorNumber_DHCP_NoSuchInterface) break;
		        /* The interface wasn't there.  Hmm.  We'll *try* a nasty nasty hack */
		        usermode_donothing();
		}
		else if (exec_args.out_status == dhcpstate_BOUND) {
			trace(("DHCP: %s is now bound - *DHCPExecute exiting\n", ifname));
			break;
		} else if (exec_args.out_status == dhcpstate_ABANDON) {
		  trace(("DHCP: abandon\n"));
		  break;
		}

		e = dhcp_check_escape_key();
		if (e == NULL && (flags & (decf_BLOCK|decf_WAIT))) {
			usermode_donothing();
			continue;
		}
		break;
	}

        /* Restore escape state */
        _swix(OS_Byte, _INR(0,2), 229, oldescapestate, 0);

	if (e != NULL) {
		if (flags & decf_SET_ERROR) {
			_kernel_setenv(SYSVAR_ERROR, e->errmess);
			return NULL;
		}
	}

	return e;
}

_kernel_oserror *dhcp_command(const char *arg_string, int argc, int cmd_no, void *private_word)
{
        (void) argc;

	switch (cmd_no) {
		case CMD_DHCPInfo:
			_swix(OS_Write0, _IN(0),
				Module_Title " " Module_MajorVersion " "
				Module_MinorVersion " (" Module_Date ")");
			_swix(OS_NewLine, 0);
			interfaces_print_information(NULL);
			break;

		case CMD_DHCPExecute:
			return dhcp_cmd_execute(arg_string, private_word);

		default:
			break;
	}

	return NULL;
}

const char *module_lookup_msg(const char *token)
{
	if (_swix(MessageTrans_Lookup, _INR(0,7),
	          msg_struct, token,  &msg_buff, sizeof(msg_buff),
	          0, 0, 0, 0) != NULL) {
		return "";
	}

	return (const char *)&msg_buff;
}

_kernel_oserror *module_make_error(int error)
{
	struct {
		int errnum;
		char errmess[8];
	} token;

	token.errnum = error;
	sprintf(token.errmess, "E%02u", error & 0xFF);
	return _swix(MessageTrans_ErrorLookup, _INR(0,3),
	          &token, msg_struct, &msg_buff, sizeof(msg_buff));
}

void module_notify_dynamic_boot_start(dhcp_interface *di)
{
	(void) _swix(OS_ServiceCall, _INR(0,6), InternetStatus_DynamicBootStart,
		Service_InternetStatus, di->di_name, di->dib, &di->di_dhcp, sizeof(di->di_dhcp),
		dhcp_find_option(&di->di_dhcp, OPTION_END) - &di->di_dhcp.op);
}

/* Send around a service call announcing the arrival of the offer.
 * Returns zero if the service call was claimed, indicating that something
 * didn't like the offer and that we should not accept it.
 */
int module_notify_dhcp_offer(dhcp_interface *di, DHCP *d)
{
	int claimed;
	(void) _swix(OS_ServiceCall, _INR(0,5)|_OUT(1), InternetStatus_DynamicBootOffer,
		Service_InternetStatus, di->di_name, di->dib, d, sizeof(*d), &claimed);
	return claimed;
}

/* Send around a service call announcing the intention to send a
 * DHCPREQUEST message.
 */
void module_notify_dhcp_request(dhcp_interface *di)
{
	(void) _swix(OS_ServiceCall, _INR(0,7), InternetStatus_DynamicBootRequest,
		Service_InternetStatus, di->di_name, di->dib, &di->di_dhcp, sizeof(di->di_dhcp),
		&di->offer, sizeof(di->offer));
}

/* This routine is used to cause the SIOCGWHOIAMB ioctl to idle */
void module_idle(enum moduleidle_reason mir)
{
	/* This is the blocking semaphore */
	static volatile int semaphore = 0;

	/* This is set if we are currently threaded */
	static volatile int threaded = 0;

	if (mir == mir_IDLE) {
		if (!threaded) {
			semaphore = 1;
			while (semaphore != 0) usermode_donothing();
		}
	}
	else if (mir == mir_THREAD) {
		threaded = 1;
	}
	else if (mir == mir_UNTHREAD) {
		threaded = 0;
	}
	else if (mir == mir_WAKEUP) {
		semaphore = 0;
	}
}


/*
 * A private IP is of the form 169.254.a.b where we get a and b from the
 * last two octets of the MAC address (from the Driver Information Block).
 * interface_delete() must have been called before calling this function,
 * otherwise we get a nasty reentrancy situation due to a service call from
 * the internet module telling us about the new IP address.
*/
void module_apply_private_ip(Dib *dib) {
  unsigned long a, b;
  struct in_addr addr, mask, broad;
  char ifname[IFNAMSIZ];

  a = dib->dib_address[4];
  b = dib->dib_address[5];

  /*
   * All this casting is just to avoid compiler warnings - under RISC OS
   * 'long', 'int'�and 'uint32_t' are all 32 bits.
   */

  addr.s_addr = (uint32_t) htonl(0xa9fe0000u | (a << 8) | b);
  mask.s_addr = (uint32_t) htonl(0xffff0000);
  broad.s_addr = addr.s_addr | ~mask.s_addr;

  trace(("trying private ip %s\n", inet_ntoa(addr)));

  /*
   * Check the resolver cache to check this address doesn't exist
   * (although this is highly unlikely given how we produce it)
   */
  if (arp_for_ip(dib, addr.s_addr) != 0) {
    trace(("address already in ARP cache, duplicate MAC address?"));
    return;
  }

  snprintf(ifname, IFNAMSIZ, "%s%d", dib->dib_name, dib->dib_unit);

  if (sockets_set_if_address(ifname, &addr, &broad, &mask) == 0) {
    trace(("address %s\n", inet_ntoa(addr)));
    trace(("netmask %s\n", inet_ntoa(mask)));
    trace(("broadcast %s\n", inet_ntoa(broad)));
    trace(("ok\n"));
  }

}


#ifdef TRACE
#include <stdarg.h>

void tracef(char *format, ...) {
  va_list ap;
  char date[32];
  FILE *f = fopen("dhcplog", "a+");
  if (f == NULL) return;

  time_t t = time(NULL);
  strftime(date, 32, "%H:%M:%S", localtime(&t));
  fprintf(f, "%s : ", date);

  va_start(ap, format);
  vfprintf(f, format, ap);
  va_end(ap);

  fclose(f);
}
#endif
