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
#include <stddef.h>
#include <stdio.h>

#include "swis.h"
#include "debuglib/debuglib.h"
#include "callx/callx.h"
#include "Global/Services.h"
#include "Global/Variables.h"

#include "header.h"
#include "scsiswitch.h"
#include "module.h"

void *module_wsp;
void (*irqtrigger)(void);
static int msg_struct[4];
static _kernel_oserror msg_buff;

const char *module_lookup(const char *token)
{
    if (_swix(MessageTrans_Lookup, _INR(0,7),
              msg_struct, token, &msg_buff, sizeof(msg_buff), 0, 0, 0, 0) != NULL)
    {
        return "";
    }
    return (const char *)&msg_buff;
}

_kernel_oserror *module_error(unsigned err)
{
    struct {
        int errnum;
        char errmess[8];
    } token;

    if (err > 256) return (_kernel_oserror *) err;

    token.errnum = SCSI_ErrorBase + err;
    sprintf(token.errmess, "E%02x", err);
    return _swix(MessageTrans_ErrorLookup, _INR(0,3),
              &token, msg_struct, &msg_buff, sizeof(msg_buff));
}

_kernel_oserror *module_initialise(const char *cmd_tail, int podule_base, void *pw)
{
    (void) cmd_tail;
    (void) podule_base;
    _kernel_oserror *err = NULL;
    uint32_t flags;

    module_wsp = pw;
    debug_initialise ("SCSIDriver", "", 0);
    debug_set_device(DEBUGIT_OUTPUT);
//    debug_set_device(PRINTF_OUTPUT);
    debug_set_unbuffered_files (TRUE);
    debug_set_stamp_debug (TRUE);

#ifndef ROM
    err = _swix(ResourceFS_RegisterFiles, _IN(0), Resources());
    if (err != NULL) goto failinit;
#endif
    err = _swix(MessageTrans_OpenFile, _INR(0,2), msg_struct, Module_MessagesFile, 0);
    if (err != NULL) goto faildereg;

    /* Transitionary */
    static const char aliasto[] = "%SCSIDevices";
    _swix(OS_SetVarVal, _INR(0,4), "Alias$Devices", aliasto, sizeof(aliasto) - 1,
                                                    0, VarType_LiteralString);
                                   
    callx_init(pw);

    if(!_swix(OS_PlatformFeatures,_IN(0)|_OUTR(0,1),0,&flags,&irqtrigger))
    {
      if(!(flags & 2))
        irqtrigger = NULL;
    }

    _swix(OS_ServiceCall, _IN(1), Service_SCSIStarting);

    return NULL;

faildereg:
#ifndef ROM
    _swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
failinit:
#endif
    return err;
}

_kernel_oserror *module_finalise(int fatal, int podule, void *pw)
{
    (void) fatal;
    (void) podule;
    (void) pw;

    _swix(OS_ServiceCall, _IN(1), Service_SCSIDying);

    scsi_deregister_all();

    callx_remove_all_callbacks();
    callx_remove_all_callafters();
    callx_remove_all_calleverys();

    /* Tidy up the messages (and deregister from ResourceFS if not in ROM) */
    _swix(MessageTrans_CloseFile, _IN(0), msg_struct);
#ifndef ROM
    _swix(ResourceFS_DeregisterFiles, _IN(0), Resources());
#endif

    return NULL;
}

void module_service_handler(int service_number, _kernel_swi_regs *r, void *pw)
{
    (void) pw;
#ifndef ROM
    if (service_number == Service_ResourceFSStarting)
    {
        /* Reregister our resources */
        (*(void (*)(void *, void *, void *, void *))r->r[2])(Resources(), 0, 0, (void *)r->r[3]);
    }
#else
    (void) service_number;
    (void) r;
#endif
}

_kernel_oserror *module_swi_handler(int swi_offset, _kernel_swi_regs *r, void *pw)
{
    (void) pw;

    switch (swi_offset)
    {
        case SCSI_Version - SCSI_00:
            return scsi_version(r);
        case SCSI_Initialise - SCSI_00:
            return scsi_initialise(r);
        case SCSI_Control - SCSI_00:
            return scsi_control(r);
        case SCSI_Op - SCSI_00:
            return scsi_op(r);
        case SCSI_Status - SCSI_00:
            return scsi_status(r);
        case SCSI_Reserve - SCSI_00:
            return scsi_reserve(r);
        case SCSI_Deregister - SCSI_00:
            return scsi_deregister(r);
        case SCSI_Register - SCSI_00:
            return scsi_register(r);
    }
    return module_error(SCSI_SWIunkn);
}

_kernel_oserror *module_cmd_handler(const char *arg_string, int argc, int cmd_no, void *pw)
{
    (void) arg_string;
    (void) argc;
    (void) cmd_no;
    (void) pw;

    /* Only *SCSIDevices */
    return scsi_devices();
}
