//
// Copyright (c) 2006, James Peacock
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met: 
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of RISC OS Open Ltd nor the names of its contributors
//       may be used to endorse or promote products derived from this software
//       without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
#ifndef MODULE_H_INCLUDED
#define MODULE_H_INCLUDED

// Switches and options
#define MODULE_ERROR_BASE       0x819a40
#define MODULE_MAX_UNITS        16
#define MODULE_DCI_NAME         "ej"
#define MODULE_MBUF_MIN_UBS     0u
#define MODULE_MBUF_MAX_UBS     0u
#define MODULE_MBUF_MIN_CONTIG  0u
#ifndef DEBUG
#define DEBUG                   0
#define syslog(...)             // Empty
#define syslog_flush()          // Empty
#define syslog_data(d, s)       // Empty
#endif
#define CALLBACK_TICKER_FREQ    1u
#define CALLBACK_QUEUE_LENGTH   20u
#define TX_QUEUE_LENGTH         16u
#define TX_MAX_DATA_SIZE        1600u
#define TX_PREFIX_SIZE          8u
#define TX_SUFFIX_SIZE          8u

// Private word for external calls into this module
extern void* g_module_pw;

// Internationalised messages and error enumerations
extern void* Resources(void);
extern const char *msg_translate(const char *);
extern _kernel_oserror* err_translate(int);
#define ERR_REINSTANTIATE         0
#define ERR_NO_MEMORY             1
#define ERR_UNSUPPORTED           2
#define ERR_BAD_DEVICE            3
#define ERR_TOO_MANY_UNITS        4
#define ERR_CONFIG_FAILED         5
#define ERR_BAD_CONFIG            6
#define ERR_BAD_PHY               7
#define ERR_UNIT_IN_USE           8
#define ERR_USB_TOO_OLD           9
#define ERR_TIMEOUT               10
#define ERR_EEPROM_RANGE          11
#define ERR_MII_IN_USE            12
#define ERR_MAX                   13 // Exclusive limit of private errors
#define ERR_BAD_UNIT              (DCI4ERRORBLOCK + ENXIO)
#define ERR_BAD_OPERATION         (DCI4ERRORBLOCK + ENOTTY)
#define ERR_BAD_FILTER_CLAIM      INETERR_FILTERGONE
#define ERR_BAD_FILTER_RELEASE    (DCI4ERRORBLOCK + EINVAL)
#define ERR_OTHERS_FILTER_RELEASE (DCI4ERRORBLOCK + EPERM)
#define ERR_BAD_VALUE             (DCI4ERRORBLOCK + EINVAL)
#define ERR_TX_BLOCKED            INETERR_TXBLOCKED
#define ERR_MESSAGE_TOO_BIG       (DCI4ERRORBLOCK + EMSGSIZE)
#define ERR_BAD_SYNTAX            220

#endif
