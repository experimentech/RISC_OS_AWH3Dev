/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "Licence").
 * You may not use this file except in compliance with the Licence.
 *
 * You can obtain a copy of the licence at
 * cddl/RiscOS/Sources/HWSupport/SD/SDIODriver/LICENCE.
 * See the Licence for the specific language governing permissions
 * and limitations under the Licence.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the Licence file. If applicable, add the
 * following below this CDDL HEADER, with the fields enclosed by
 * brackets "[]" replaced with your own identifying information:
 * Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright 2012 Ben Avison.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef GLOBALS_H
#define GLOBALS_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#include "Global/HALDevice.h"
#include "Interface/SDHCIDevice.h"

#include "SyncLib/mutex.h"
#include "SyncLib/spin.h"
#include "SyncLib/spinrw.h"

#include "cardreg.h"

#ifdef DEBUG_ENABLED
#ifdef DEBUGLIB
#include "DebugLib/DebugLib.h"
#undef dprintf
#define dprintf(...)    _dprintf("", __VA_ARGS__)
#else
#include <stdio.h>
#define dprintf printf
#endif
#else
#define dprintf(...) do; while(0)
#endif

#ifdef __GNUC__
#define PACKED(x) x __attribute__((packed))
#else
#define PACKED(x) __packed x
#endif

/* Defines */

/** Length of queue of operations for each slot */
#define QUEUE_LENGTH (4)

/** Limit placed on MMC cards per slot so we can allocate an array rather than a linked list */
#define MAX_CARDS_PER_SLOT (3)

/** Maximum number of functions that an SDIO card can have */
#define MAX_FUNCTIONS (7)

/** Timeout to set on internal commands */
#define INTERNAL_OP_TIMEOUT (100)

/** Simple concatenation macro */
#define CONCAT(a,b) a##b

/** Concatenation macro that expands the result of the concatenation. */
#define CONCAT_AND_EXPAND(a,b) CONCAT(a,b)

/** Simple 3-way concatenation macro */
#define CONCAT3(a,b,c) a##b##c

/** 3-way concatenation macro that expands the result of the concatenation. */
#define CONCAT3_AND_EXPAND(a,b,c) CONCAT(a,b,c)

/* A quick macro to silence compiler warnings about unused parameters */
#define IGNORE(x) do { (void)(x); } while(0)

#define MAX(a,b) ((a)>(b)?(a):(b))
#define MIN(a,b) ((a)<(b)?(a):(b))

/* Types */

/** Scatter list entry */
typedef struct
{
  uint8_t *address;
  size_t   length;
}
scatter_t;

/** Register write buffer */
typedef struct
{
  spinlock_t lock;   /**< ensures atomic updates of the other members */
  uintptr_t  reg;    /**< which register was most recently updated */
  uint32_t   dirty;  /**< mask of bits which have been updated but not yet written back to hardware */
  uint32_t   value;  /**< contents of write buffer */
}
sdhci_writebuffer_t;

/** State variable for an ongoing operation */
enum op_state
{
  CMD_STATE_READY,
  CMD_STATE_WAIT_CMD_INHIBIT,
  CMD_STATE_WAIT_DAT_INHIBIT,
  CMD_STATE_WAIT_COMMAND_COMPLETE,
  CMD_STATE_WAIT_BUFFER_WRITE_READY,
  CMD_STATE_WAIT_BUFFER_READ_READY,
  CMD_STATE_WAIT_TRANSFER_COMPLETE,
  CMD_STATE_ABORT,
  CMD_STATE_WAIT_RESET_CMD,
  CMD_STATE_WAIT_RESET_DAT,
  CMD_STATE_COMPLETED,
  CMD_STATE_NEVER_STARTED
};

/** Details of an ongoing operation */
typedef struct
{
  volatile uint32_t state;           /**< actually holds an enum op_state, forced to uint32 to allow atomic operations */
  bool              chk_r1;          /**< generate errors from R1 (memory) response */
  bool              chk_r5;          /**< generate errors from R5 (IO) response */
  uint32_t          error;           /**< RISC OS error number detected during operation, or 0 if none */
  int32_t           timeout;         /**< monotonic time at which current state times out */
  uint16_t          transfer_mode;   /**< value to program into the transfer_mode register */
  uint16_t          command;         /**< value to program into the command register */
  uint32_t          argument;        /**< value to program into the argument register */
  void             *response;        /**< pointer to response buffer */
  size_t            scatter_offset;  /**< current byte index into current block on scatter list */
  scatter_t        *list;            /**< current block in scatter list for data transfer */
  scatter_t         surrogate;       /**< surrogate scatter list when caller didn't provide one */
  uint16_t          block_size;      /**< number of bytes transferred on data lines between CRCs */
  uint16_t          block_count;     /**< number of blocks remaining in data transfer */
  size_t            total_length;    /**< length of data transfer remaining, bytes */
  void            (*callback)(void); /**< completion callback routine */
  void             *callback_r5;     /**< R5 to pass to completion callback */
  void             *callback_r12;    /**< R12 to pass to completion callback */
}
sdioop_t;

/** Element of an array of cards within the same slot */
typedef struct
{
  bool     in_use;    /**< is this struct in use */
  uint16_t rca;       /**< Relative Card Address */
  reg15_t  cid;       /**< Card IDentification register read from card */
  reg15_t  csd;       /**< Card-Specific Data register read from card */
  uint64_t capacity;  /**< size of card in bytes */
}
sdmmccard_t;

/** Element of array of slots */
typedef struct
{
  bool                insertion_pending;         /**< a callback has been scheduled to handle card insertion for this slot */
  bool                write_protect;             /**< is the write-protect switch engaged? */
  bool                no_card_detect;            /**< slot has broken card detect line, must use command probes instead */
  mutex_t             busy;                      /**< someone has claimed exclusive use of the slot (may also be us internally, e.g. during probe) */
  mutex_t             doing_poll;                /**< ensures only 1 interrupt handler runs at once for this slot TODO: revisit this */
  mutex_t             doing_card_detect;         /**< ensures serialisation of unit attached/removed service calls */
  enum {
    CD_VACANT,
    CD_DEBOUNCING,
    CD_OCCUPIED,
    CD_ANNOUNCED
  }                   card_detect_state;         /**< state variable for card detect */
  int32_t             card_detect_debounce_time; /**< monotonic time at which debounce is complete */
  enum {
    MEMORY_NONE,
    MEMORY_MMC,       /* may also be a group of MMC cards ganged together */
    MEMORY_SD,
    MEMORY_SDHC_SDXC,
    MEMORY_IDENTIFYING
  }                   memory_type;               /**< if card(s) in slot provide memory commands, and which variant if so */
  uint8_t             io_functions;              /**< number of IO functions */
  uint8_t             spec_rev;                  /**< which revision of teh SDHCI spec the controller claims to support */
  uint16_t            controller_maxblklen;      /**< log2 of maximum data block length supported by controller */
  uint32_t            controller_ocr;            /**< controller voltage capabilities in same bitfield format as OCR registers */
  uint32_t            memory_ocr;                /**< wired-AND of OCR for all memory cards in slot (if applicable) */
  uint32_t            io_ocr;                    /**< combined OCR for all functions in the SDIO or combo card in this slot (if applicable) */
  uint32_t            voltage;                   /**< selected Vdd voltage in mV */
  uint8_t             lines;                     /**< maximum number of data lines supported by all cards in this slot */
  uint32_t            freq;                      /**< maximum clock speed supported by all cards in this slot */
  uint32_t            caps[2];                   /**< soft copy of controller's capabilities registers */
  uint32_t            voltage_caps;              /**< which voltages are supported */
  sdhci_writebuffer_t wrbuf;
  volatile size_t     op_used; /* circular buffer pointers into array */
  volatile size_t     op_free;
  sdioop_t            op[QUEUE_LENGTH];
  spinlock_t          op_lock;
  sdmmccard_t         card[MAX_CARDS_PER_SLOT];
  uint8_t             scr[8];                    /**< the SCR register for the (only 1 possible) SD memory card in this slot */
  bool                scr_valid;                 /**< MMC cards don't have this register */
  uint8_t             fic[MAX_FUNCTIONS];        /**< function interface code for each function in the (only 1 possible) SDIO card in this slot */
}
sdmmcslot_t;

/** Node of list of SDHCI controllers */
typedef struct sdhcinode
{
  struct sdhcinode *next;        /**< link to next controller */
  uint32_t          bus;         /**< bus number */
  sdhcidevice_t    *dev;         /**< HAL device for this controller */
  uint32_t         *trampoline;  /**< interrupt handler trampoline */
  sdmmcslot_t       slot[];      /**< array of state data for each slot on this controller */
}
sdhcinode_t;


/** Command-response blocks for R0 commands */
typedef struct
{
  uint32_t command;
  uint32_t argument;
}
sdioop_cmdres_R0_t;

/** Command-response blocks for R2 commands */
typedef struct
{
  uint32_t command;
  uint32_t argument;
  uint8_t  response[15];
}
sdioop_cmdres_R2_t;

/** Command-response blocks for other commands */
typedef struct
{
  uint32_t command;
  uint32_t argument;
  uint32_t response;
}
sdioop_cmdres_R1_t,
sdioop_cmdres_R1b_t,
sdioop_cmdres_R3_t,
sdioop_cmdres_R4mmc_t,
sdioop_cmdres_R4sdio_t,
sdioop_cmdres_R5mmc_t,
sdioop_cmdres_R5sdio_t,
sdioop_cmdres_R6_t,
sdioop_cmdres_R7_t;

/** Issue a foreground command with no data transfer by jumping to the SDIO_Op SWI handler.
 *  \param bus       Bus index.
 *  \param slot      Slot index.
 *  \param cmd       Command to issue, including application-command bit and flags if appropriate.
 *  \param arg       Command argument.
 *  \param res_type  Response type, e.g. R0
 *  \param crblock   Name of command-response block to declare. Data type is derived from \a res_type, and block remains in scope after the macro.
 *  \param error     Name of variable to hold error returned.
 */
#define COMMAND_NO_DATA(bus, slot, cmd, arg, res_type, crblock, error)   \
  CONCAT3(sdioop_cmdres_,res_type,_t) crblock;                           \
  crblock.command = (cmd);                                               \
  crblock.argument = (arg);                                              \
  {                                                                      \
    sdioop_block_t op = {                                                \
        .r0.word = ((slot) << SDIOOp_SlotShift) |                        \
                   ((bus) << SDIOOp_BusShift) |                          \
                   CONCAT_AND_EXPAND(SDIOOp_,res_type) |                 \
                   SDIOOp_TransNone,                                     \
        .r1.cmdres_len = 8 + CONCAT_AND_EXPAND(SDIOOp_ResLen_,res_type), \
        .r5.timeout = INTERNAL_OP_TIMEOUT                                \
    };                                                                   \
    op.cmdres.res_type = &crblock;                                       \
    error = swi_Op(&op);                                                 \
  }

/** Issue a foreground command with single-block data transfer by jumping to the SDIO_Op SWI handler.
 *  \param bus       Bus index.
 *  \param slot      Slot index.
 *  \param cmd       Command to issue, including application-command bit and flags if appropriate.
 *  \param arg       Command argument.
 *  \param res_type  Response type, e.g. R0
 *  \param crblock   Name of command-response block to declare. Data type is derived from \a res_type, and block remains in scope after the macro.
 *  \param type      "Read" or "Write".
 *  \param buffer    Name of (pre-declared) data buffer.
 *  \param buflen    Length of data transfer.
 *  \param error     Name of variable to hold error returned.
 */
#define COMMAND_DATA(bus, slot, cmd, arg, res_type, crblock, type, buffer, buflen, error) \
  CONCAT3(sdioop_cmdres_,res_type,_t) crblock;                           \
  crblock.command = (cmd);                                               \
  crblock.argument = (arg);                                              \
  {                                                                      \
    sdioop_block_t op = {                                                \
        .r0.word = ((slot) << SDIOOp_SlotShift) |                        \
                   ((bus) << SDIOOp_BusShift) |                          \
                   CONCAT_AND_EXPAND(SDIOOp_,res_type) |                 \
                   CONCAT_AND_EXPAND(SDIOOp_Trans,type),                 \
        .r1.cmdres_len = 8 + CONCAT_AND_EXPAND(SDIOOp_ResLen_,res_type), \
        .r5.timeout = INTERNAL_OP_TIMEOUT                                \
    };                                                                   \
    op.cmdres.res_type = &crblock;                                       \
    op.data.block = (buffer);                                            \
    op.data_len = (buflen);                                              \
    error = swi_Op(&op);                                                 \
  }


/* Global variables */

/** List of known SDHCI controllers and their attached SDIO devices */
extern sdhcinode_t *g_sdhci;
/** Lock for the list of SDHCI controllers */
extern spinrwlock_t g_sdhci_lock;

/** MessageTrans descriptor for our Messages file */
extern uint32_t g_message_fd[4];

/** Module private word pointer */
extern void *g_module_pw;

#endif
