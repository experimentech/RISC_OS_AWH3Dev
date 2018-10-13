/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "Licence").
 * You may not use this file except in compliance with the Licence.
 *
 * You can obtain a copy of the licence at
 * cddl/RiscOS/Sources/FileSys/SDFS/SDFS/LICENCE.
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

#include <stdint.h>
#include "kernel.h"
#include "swis.h"

#include "SyncLib/spin.h"
#include "SyncLib/spinrw.h"

/* Defines */

#ifdef DEBUG_ENABLED
#include <stdio.h>
#define dprintf printf
#else
#define dprintf(...) do; while(0)
#endif

#ifdef __GNUC__
#define PACKED(x) x __attribute__((packed))
#else
#define PACKED(x) __packed x
#endif

/** Build switch, whether to do background ops */
#undef ENABLE_BACKGROUND_TRANSFERS

/** Base address of the module as a byte pointer */
#define MODULE_BASE_ADDRESS (*(const char **)&base)

/** Filing system title, as passed to FileCore */
#define FILING_SYSTEM_TITLE "SDFS"

/** Filing system author */
#define FILING_SYSTEM_AUTHOR "Piccolo Systems"

/** CMOS byte containing default drive */
#define DEFAULT_DRIVE_BYTE (NetFilerCMOS)

/** CMOS bit position of default drive */
#define DEFAULT_DRIVE_SHIFT (4)

/** CMOS bit mask of default drive */
#define DEFAULT_DRIVE_MASK  (0x7 << DEFAULT_DRIVE_SHIFT)

/** Number of "floppy" drives to declare to FileCore */
#define NUM_FLOPPIES (4)

/** Number of "hard" drives to declare to FileCore */
#define NUM_WINNIES  (1)

/** Buffer size for media type name */
#define MEDIA_TYPE_NAME_LEN (20)

/** Number of retries to use on reads and writes */
#define RETRIES (16) /* same as ADFS uses for hard discs */

/** Number of retries to use on verifies */
//#define VERIFY_RETRIES (1) /* same as ADFS uses for hard discs */
#define VERIFY_RETRIES (4)

/** Timeout for transition to disc-maybe-changed state, in cs */
#define FAITH (100)

/** Bit shift to convert between bytes and sectors */
#define LOG2_SECTOR_SIZE (9)

/** Sector size in bytes */
#define SECTOR_SIZE ((1u<<LOG2_SECTOR_SIZE))

/** Test for sector alignment */
#define IS_SECTOR_ALIGNED(x) (((x) & (SECTOR_SIZE - 1)) == 0)

/** A quick macro to silence compiler warnings about unused parameters */
#define IGNORE(x) do { (void)(x); } while(0)

#define MAX(a,b) ((a)>(b)?(a):(b))
#define MIN(a,b) ((a)<(b)?(a):(b))

/** Simple concatenation macro */
#define CONCAT(a,b) a##b

/** Concatenation macro that expands the result of the concatenation. */
#define CONCAT_AND_EXPAND(a,b) CONCAT(a,b)

/** Simple 3-way concatenation macro */
#define CONCAT3(a,b,c) a##b##c

/** 3-way concatenation macro that expands the result of the concatenation. */
#define CONCAT3_AND_EXPAND(a,b,c) CONCAT(a,b,c)

/** Issue a foreground command with no data transfer by calling the SDIO_Op SWI handler.
 *  \param bus       Bus index.
 *  \param slot      Slot index.
 *  \param cmd       Command to issue, including application-command bit and flags if appropriate.
 *  \param arg       Command argument.
 *  \param res_type  Response type, e.g. R0
 *  \param crblock   Name of command-response block to declare. Data type is derived from \a res_type, and block remains in scope after the macro.
 *  \param error     Name of variable to hold error returned.
 */
#define COMMAND_NO_DATA(bus, slot, escape_flag, cmd, arg, res_type, crblock, error) \
  CONCAT3(sdioop_cmdres_,res_type,_t) crblock;                                \
  crblock.command = (cmd);                                                    \
  crblock.argument = (arg);                                                   \
  (error) = sdio_op_fg_nodata(((slot) << SDIOOp_SlotShift) |                  \
                              ((bus) << SDIOOp_BusShift) |                    \
                              CONCAT_AND_EXPAND(SDIOOp_,res_type) |           \
                              SDIOOp_TransNone |                              \
                              (escape_flag),                                  \
                              8 + CONCAT_AND_EXPAND(SDIOOp_ResLen_,res_type), \
                              &crblock,                                       \
                              OP_TIMEOUT);


/* Types */

/** Command-response blocks for R0 commands */
typedef struct
{
  uint32_t command;
  uint32_t argument;
}
sdioop_cmdres_R0_t;

/** Command-response blocks for R1 commands */
typedef struct
{
  uint32_t command;
  uint32_t argument;
  uint32_t response;
}
sdioop_cmdres_R1b_t,
sdioop_cmdres_R1_t;

/** Old-style desc error word */
typedef struct
{
  unsigned byte_div_256: 21;
  unsigned drive:         3;
  unsigned disc_error:    6;
} old_disc_error_word_t;

/** Old-style disc error block (RISC OS 3.6) */
typedef struct
{
  unsigned disc_error:  6;
  unsigned unused_MBZ: 26;
  unsigned sector:     29;
  unsigned drive:       3;
} old_disc_error_t;

/** New-style disc error block (RISC OS 5) */
typedef struct
{
  unsigned drive:       8;
  unsigned disc_error:  6;
  unsigned unused_MBZ: 18;
  uint64_t byte;
} new_disc_error_t;

/** Return type for low-level DiscOp/MiscOp calls */
typedef union
{
  struct
  {
    unsigned new_disc_error:  1;
    unsigned not_a_flag:     29;
    unsigned old_pointer:     1;
    unsigned old_disc_error:  1;
  }                     flag;
  uint32_t              number;
  old_disc_error_word_t old_disc_error_word;
  _kernel_oserror      *oserror;
  old_disc_error_t     *old_disc_error;
  new_disc_error_t     *new_disc_error;
} low_level_error_t;

/** FileCore disc record structure */
typedef PACKED(struct)
{
  uint8_t  log2secsize;    /* +0 */
  uint8_t  secspertrack;   /* +1 */
  uint8_t  heads;          /* +2 */
  uint8_t  density;        /* +3 */
  uint8_t  idlen;          /* +4 */
  uint8_t  log2bpmb;       /* +5 */
  uint8_t  skew;           /* +6 */
  uint8_t  bootoption;     /* +7 */
  uint8_t  lowsector;      /* +8 */
  uint8_t  nzones;         /* +9 */
  uint16_t zone_spare;     /* +10 */
  uint32_t root;           /* +12 */
  uint32_t disc_size;      /* +16 */
  uint16_t disc_id;        /* +20 */
  char     disc_name[10];  /* +22 */
  uint32_t disctype;       /* +32 */
  uint32_t disc_size_2;    /* +36 RISC OS 3.6 */
  uint8_t  share_size;     /* +40 RISC OS 3.6 */
  uint8_t  big_flag;       /* +41 RISC OS 3.6 */
  uint8_t  nzones_2;       /* +42 RISC OS 4 */
  uint8_t  reserved;
  uint32_t format_version; /* +44 RISC OS 4 */
  uint32_t root_size;      /* +48 RISC OS 4 */
  uint32_t reserved_2[2];
} disc_record_t;

/** Drive state */
typedef struct
{
  bool              slot_attached;     /**< Do we have an SDIODriver slot associated with this drive? */
  bool              no_card_detect;    /**< Does the attached SDIODriver slot have a broken card detect? */
  volatile bool     card_inserted;     /**< Is a memory card present? */
  bool              write_protected;   /**< Is the write-protect tab engaged? */
  bool              memory_card;       /**< Is is a memory card? */
  bool              io_card;           /**< Is it an IO card? (Can't do anything with it if IO-only) */
  bool              mmc;               /**< Is is an MMC rather than SD card? */
  bool              cmd23_supported;   /**< Card supports predeclaring transfer size */
  bool              sector_addressed;  /**< Use sector addressing in SDIO_Op? */
  bool              single_blocks;     /**< It's an older MMC card that doesn't support multi-block operations */
  bool              slot_claimed;      /**< Part of the mechanism for detecting other users of this drive's slot */
  bool              needs_reselect;    /**< Card state is unknown, needs to be set up (again) */
  bool              needs_wait;        /**< Card's last operation was or might be a write operation, so wait for it to return to tran state */
  uint8_t           bus;               /**< SDIODriver bus number */
  uint8_t           slot;              /**< SDIODriver slot number */
  uint16_t          rca;               /**< Card RCA */
  new_disc_error_t  disc_error;        /**< Most recent disc error */
  size_t            read_block_size;   /**< log2 of read block boundaries on this card */
  size_t            write_block_size;  /**< log2 of write block boundaries on this card */
  uint8_t          *block_buffer;      /**< buffer to handle verifies and misaligned reads/writes, allocated from RMA */
  size_t            block_buffer_size; /**< log2 size of above buffer */
  uint64_t          capacity;          /**< Card size, in sectors */
  volatile uint32_t sequence_number;   /**< FileCore disc detection sequence number */
  spinlock_t        sequence_lock;     /**< Ensures updates to card_inserted and sequence_number are consistent */
  volatile uint32_t certainty;         /**< Countdown until we lose confidence in what's in the drive (for drives with faulty card detect) */
  spinlock_t        certainty_lock;    /**< Ensures atomic updates of certainty */
} drive_t;


/* Global variables */

/** Symbol at whose address is a pointer to the module base address */
extern void base(void);

/** MessageTrans descriptor for our Messages file */
extern uint32_t g_message_fd[4];

/** Module private word pointer */
extern void *g_module_pw;

/** FileCore private word pointer */
extern void *g_filecore_pw;

/** FileCore callback routine to call once background op on drives 0-3 are completed */
extern void (*g_filecore_callback_floppy_op_completed)(void);

/** FileCore callback routine to call once background op on drives 4-7 are completed */
extern void (*g_filecore_callback_winnie_op_completed)(void);

/** Media type name to return from MiscOp 4 */
extern char g_media_type_name[MEDIA_TYPE_NAME_LEN];

/** Array of drive states */
extern drive_t g_drive[NUM_FLOPPIES + NUM_WINNIES];

/** Lock for drive state array */
extern spinrwlock_t g_drive_lock;

/** Bitmask to invert in default drive number in CMOS */
extern uint8_t g_default_drive_toggle;


#endif
