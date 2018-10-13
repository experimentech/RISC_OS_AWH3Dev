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

#ifndef CARDREG_H
#define CARDREG_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

/** A type describing the CID and CSD registers in MMC, SD and SDHC cards */
typedef uint8_t reg15_t[15];

/** A type defining the position of a bitfield within a multi-word register.
 *  These are listed as shown in the standards, i.e. (inclusive) msb then lsb.
 */
typedef struct
{
  size_t hi, lo;
  bool crc_omitted;
} bitfield_t;

#define OCR_NOT_BUSY           (1u<<31) // MMC, SD, SDIO (in response)
#define OCR_HCS                (1u<<30) // SD only (in argument)
#define OCR_CCS                (1u<<30) // SD only (in response)
#define OCR_ACCESS_MODE_SHIFT (29)      // MMC only (but effectively the same as CCS) (in response)
#define OCR_ACCESS_MODE_BYTE   (0u << OCR_ACCESS_MODE_SHIFT)
#define OCR_ACCESS_MODE_SECTOR (2u << OCR_ACCESS_MODE_SHIFT)
#define OCR_ACCESS_MODE_MASK   (3u << OCR_ACCESS_MODE_SHIFT)
#define OCR_XPC                (1u<<28) // SD only (in argument)
#define OCR_NFUNCTIONS_SHIFT  (28)      // SDIO only (in response)
#define OCR_NFUNCTIONS_MASK    (7u << OCR_NFUNCTIONS_SHIFT)
#define OCR_MP                 (1u<<27) // SDIO only (in response)
#define OCR_S18R               (1u<<24) // SD/SDIO UHS only (1.8V signalling request; in argument)
#define OCR_S18A               (1u<<24) // SD/SDIO UHS only (1.8V signalling accepted; in response)
#define OCR_3_5V_3_6V          (1u<<23)
#define OCR_3_4V_3_5V          (1u<<22)
#define OCR_3_3V_3_4V          (1u<<21)
#define OCR_3_2V_3_3V          (1u<<20)
#define OCR_3_1V_3_2V          (1u<<19)
#define OCR_3_0V_3_1V          (1u<<18)
#define OCR_2_9V_3_0V          (1u<<17)
#define OCR_2_8V_2_9V          (1u<<16)
#define OCR_2_7V_2_8V          (1u<<15)
#define OCR_2_6V_2_7V          (1u<<14) // MMC, SDIO
#define OCR_2_5V_2_6V          (1u<<13) // MMC, SDIO
#define OCR_2_4V_2_5V          (1u<<12) // MMC, SDIO
#define OCR_2_3V_2_4V          (1u<<11) // MMC, SDIO
#define OCR_2_2V_2_3V          (1u<<10) // MMC, SDIO
#define OCR_2_1V_2_2V          (1u<<9)  // MMC, SDIO
#define OCR_2_0V_2_1V          (1u<<8)  // MMC, SDIO
#define OCR_1_7V_1_95V         (1u<<7)  // MMC, SD
#define OCR_DONTCARE   (0x1FFFF80u) // bits for IO OCR that don't restrict memory OCR and vice versa

#define CID_MID     ((const bitfield_t) { 127,120,true })
#define CID_OID_SD  ((const bitfield_t) { 119,104,true })
#define CID_CBX     ((const bitfield_t) { 113,112,true }) // MMC only
#define CID_OID_MMC ((const bitfield_t) { 111,104,true })
#define CID_PNM_SD  ((const bitfield_t) { 103, 64,true })
#define CID_PNM_MMC ((const bitfield_t) { 103, 56,true })
#define CID_PRV_SD  ((const bitfield_t) {  63, 56,true })
#define CID_PRV_MMC ((const bitfield_t) {  55, 48,true })
#define CID_PSN_SD  ((const bitfield_t) {  55, 24,true })
#define CID_PSN_MMC ((const bitfield_t) {  47, 16,true })
#define CID_MDT_SD  ((const bitfield_t) {  19,  8,true })
#define CID_MDT_MMC ((const bitfield_t) {  15,  8,true })

#define CSD_CSD_STRUCTURE      ((const bitfield_t) { 127,126,true })
#define CSD_SPEC_VERS          ((const bitfield_t) { 125,122,true }) // MMC only
#define CSD_TAAC               ((const bitfield_t) { 119,112,true })
#define CSD_NSAC               ((const bitfield_t) { 111,104,true })
#define CSD_TRAN_SPEED         ((const bitfield_t) { 103, 96,true })
#define CSD_CCC                ((const bitfield_t) {  95, 84,true })
#define CSD_READ_BL_LEN        ((const bitfield_t) {  83, 80,true })
#define CSD_READ_BL_PARTIAL    ((const bitfield_t) {  79, 79,true })
#define CSD_WRITE_BLK_MISALIGN ((const bitfield_t) {  78, 78,true })
#define CSD_READ_BLK_MISALIGN  ((const bitfield_t) {  77, 77,true })
#define CSD_DSR_IMP            ((const bitfield_t) {  76, 76,true })
#define CSD_C_SIZE_MMC_SD      ((const bitfield_t) {  73, 62,true }) // not SDHC
#define CSD_C_SIZE_SDHC        ((const bitfield_t) {  69, 48,true }) // SDHC only
#define CSD_VDD_R_CURR_MIN     ((const bitfield_t) {  61, 59,true }) // not SDHC
#define CSD_VDD_R_CURR_MAX     ((const bitfield_t) {  58, 56,true }) // not SHDC
#define CSD_VDD_W_CURR_MIN     ((const bitfield_t) {  55, 53,true }) // not SHDC
#define CSD_VDD_W_CURR_MAX     ((const bitfield_t) {  52, 50,true }) // not SDHC
#define CSD_C_SIZE_MULT        ((const bitfield_t) {  49, 47,true }) // not SDHC
#define CSD_ERASE_GRP_SIZE     ((const bitfield_t) {  46, 42,true }) // MMC only
#define CSD_ERASE_BLK_EN       ((const bitfield_t) {  46, 46,true }) // not MMC
#define CSD_SECTOR_SIZE        ((const bitfield_t) {  45, 39,true }) // not MMC
#define CSD_ERASE_GRP_MULT     ((const bitfield_t) {  41, 37,true }) // MMC only
#define CSD_WR_GRP_SIZE_SD     ((const bitfield_t) {  38, 32,true }) // not MMC
#define CSD_WR_GRP_SIZE_MMC    ((const bitfield_t) {  36, 32,true }) // MMC only
#define CSD_WR_GRP_ENABLE      ((const bitfield_t) {  31, 31,true })
#define CSD_DEFAULT_ECC        ((const bitfield_t) {  30, 29,true }) // MMC only
#define CSD_R2W_FACTOR         ((const bitfield_t) {  28, 26,true })
#define CSD_WRITE_BL_LEN       ((const bitfield_t) {  25, 22,true })
#define CSD_WRITE_BL_PARTIAL   ((const bitfield_t) {  21, 21,true })
#define CSD_CONTENT_PROT_APP   ((const bitfield_t) {  16, 16,true }) // MMC only
#define CSD_FILE_FORMAT_GRP    ((const bitfield_t) {  15, 15,true })
#define CSD_COPY               ((const bitfield_t) {  14, 14,true })
#define CSD_PERM_WRITE_PROTECT ((const bitfield_t) {  13, 13,true })
#define CSD_TMP_WRITE_PROTECT  ((const bitfield_t) {  12, 12,true })
#define CSD_FILE_FORMAT        ((const bitfield_t) {  11, 10,true })
#define CSD_ECC                ((const bitfield_t) {   9,  8,true }) // MMC only

#define CSD_SPEC_VERS_1_0_1_2 (0)
#define CSD_SPEC_VERS_1_4     (1)
#define CSD_SPEC_VERS_2_0_2_2 (2)
#define CSD_SPEC_VERS_3_1_3_3 (3)
#define CSD_SPEC_VERS_4_1_4_3 (4)

#define EXT_CSD_SEC_COUNT (212) /* least significant of 4 bytes; msb is 215 */

#define EXT_CSD_DEVICE_TYPE (196)

#define EXT_CSD_DEVICE_TYPE_HS200_1_2   (1u<<5)
#define EXT_CSD_DEVICE_TYPE_HS200_1_8   (1u<<4)
#define EXT_CSD_DEVICE_TYPE_HSDDR_1_2   (1u<<3)
#define EXT_CSD_DEVICE_TYPE_HSDDR_1_8_3 (1u<<2)
#define EXT_CSD_DEVICE_TYPE_HS          (1u<<1)
#define EXT_CSD_DEVICE_TYPE_STD         (1u<<0)

#define EXT_CSD_HS_TIMING (185)

#define EXT_CSD_HS_TIMING_DS_SHIFT (4)
#define EXT_CSD_HS_TIMING_DS_50    (0x0u << EXT_CSD_HS_TIMING_DS_SHIFT)
#define EXT_CSD_HS_TIMING_DS_30    (0x1u << EXT_CSD_HS_TIMING_DS_SHIFT)
#define EXT_CSD_HS_TIMING_DS_66    (0x2u << EXT_CSD_HS_TIMING_DS_SHIFT)
#define EXT_CSD_HS_TIMING_DS_100   (0x3u << EXT_CSD_HS_TIMING_DS_SHIFT)
#define EXT_CSD_HS_TIMING_DS_MASK  (0xFu << EXT_CSD_HS_TIMING_DS_SHIFT)
#define EXT_CSD_HS_TIMING_TI_SHIFT (0)
#define EXT_CSD_HS_TIMING_TI_STD   (0x0u << EXT_CSD_HS_TIMING_TI_SHIFT)
#define EXT_CSD_HS_TIMING_TI_HS    (0x1u << EXT_CSD_HS_TIMING_TI_SHIFT)
#define EXT_CSD_HS_TIMING_TI_HS200 (0x2u << EXT_CSD_HS_TIMING_TI_SHIFT)
#define EXT_CSD_HS_TIMING_TI_MASK  (0xFu << EXT_CSD_HS_TIMING_TI_SHIFT)

#define EXT_CSD_BUS_WIDTH (183)

#define EXT_CSD_BUS_WIDTH_1BIT_SDR (0)
#define EXT_CSD_BUS_WIDTH_4BIT_SDR (1)
#define EXT_CSD_BUS_WIDTH_8BIT_SDR (2)
#define EXT_CSD_BUS_WIDTH_4BIT_DDR (5)
#define EXT_CSD_BUS_WIDTH_8BIT_DDR (6)

#define SCR_SCR_STRUCTURE         ((const bitfield_t) { 63,60,false })
#define SCR_SD_SPEC               ((const bitfield_t) { 59,56,false })
#define SCR_DATA_STAT_AFTER_ERASE ((const bitfield_t) { 55,55,false })
#define SCR_SD_SECURITY           ((const bitfield_t) { 54,52,false })
#define SCR_SD_BUS_WIDTHS         ((const bitfield_t) { 51,48,false })
#define SCR_SD_SPEC3              ((const bitfield_t) { 47,47,false })
#define SCR_EX_SECURITY           ((const bitfield_t) { 46,43,false })
#define SCR_CMD_SUPPORT           ((const bitfield_t) { 33,32,false })

#define SCR_SD_BUS_WIDTH_1 (1u<<0)
#define SCR_SD_BUS_WIDTH_4 (1u<<2)

#define R1_CARD_IS_LOCKED        (1u<<25)
#define R1_CARD_ECC_DISABLED     (1u<<14)
#define R1_ERASE_RESET           (1u<<13)
#define R1_CURRENT_STATE_SHIFT   (9)
#define R1_CURRENT_STATE_IDLE  (0x0u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_READY (0x1u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_IDENT (0x2u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_STBY  (0x3u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_TRAN  (0x4u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_DATA  (0x5u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_RCV   (0x6u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_PRG   (0x7u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_DIS   (0x8u << R1_CURRENT_STATE_SHIFT)
#define R1_CURRENT_STATE_MASK  (0xFu << R1_CURRENT_STATE_SHIFT)
#define R1_READY_FOR_DATA        (1u<<8)
#define R1_APP_CMD               (1u<<5)

#define R5_IO_CURRENT_STATE_SHIFT (12)
#define R5_IO_CURRENT_STATE_DIS  (0x0u << R5_IO_CURRENT_STATE_SHIFT)
#define R5_IO_CURRENT_STATE_CMD  (0x1u << R5_IO_CURRENT_STATE_SHIFT)
#define R5_IO_CURRENT_STATE_TRN  (0x2u << R5_IO_CURRENT_STATE_SHIFT)
#define R5_IO_CURRENT_STATE_MASK (0x3u << R5_IO_CURRENT_STATE_SHIFT)
#define R5_DATA_MASK            (0xFFu)

#define SWITCH_ACCESS_SHIFT      (24)
#define SWITCH_ACCESS_COMMAND_SET (0u << SWITCH_ACCESS_SHIFT)
#define SWITCH_ACCESS_SET_BITS    (1u << SWITCH_ACCESS_SHIFT)
#define SWITCH_ACCESS_CLEAR_BITS  (2u << SWITCH_ACCESS_SHIFT)
#define SWITCH_ACCESS_WRITE_BYTE  (3u << SWITCH_ACCESS_SHIFT)
#define SWITCH_ACCESS_MASK        (3u << SWITCH_ACCESS_SHIFT)
#define SWITCH_INDEX_SHIFT       (16)
#define SWITCH_INDEX_MASK      (0xFFu << SWITCH_INDEX_SHIFT)
#define SWITCH_VALUE_SHIFT        (8)
#define SWITCH_VALUE_MASK      (0xFFu << SWITCH_VALUE_SHIFT)
#define SWITCH_CMD_SET_SHIFT      (0)
#define SWITCH_CMD_SET_STD_MMC    (0u << SWITCH_CMD_SET_SHIFT)
#define SWITCH_CMD_SET_MASK       (7u << SWITCH_CMD_SET_SHIFT)

#define SWITCH_FUNC_MODE_SHIFT           (31)
#define SWITCH_FUNC_MODE_CHECK            (0u << SWITCH_FUNC_MODE_SHIFT)
#define SWITCH_FUNC_MODE_SWITCH           (1u << SWITCH_FUNC_MODE_SHIFT)
#define SWITCH_FUNC_MODE_MASK             (1u << SWITCH_FUNC_MODE_SHIFT)
#define SWITCH_FUNC_GROUP6               (20)
#define SWITCH_FUNC_GROUP5               (16)
#define SWITCH_FUNC_CURRENT_LIMIT_SHIFT  (12)
#define SWITCH_FUNC_DRIVE_STRENGTH_SHIFT  (8)
#define SWITCH_FUNC_COMMAND_SYSTEM_SHIFT  (4)
#define SWITCH_FUNC_ACCESS_MODE_SHIFT     (0)

#define SWITCH_FUNC_FG1RESULT      (376)
#define SWITCH_FUNC_FG1RESULT_MASK (0xF)
#define SWITCH_FUNC_FG1INFO0_BYTE  (400)
#define SWITCH_FUNC_FG1INFO1_BYTE  (408)
#define ACCESS_MODE_SDR12          (0x0)
#define ACCESS_MODE_SDR25          (0x1)
#define ACCESS_MODE_SDR50          (0x2)
#define ACCESS_MODE_SDR104         (0x3)
#define ACCESS_MODE_DDR50          (0x4)
#define ACCESS_MODE_NO_CHANGE      (0xF)
#define ACCESS_MODE_BIT_SDR12      (1u << ACCESS_MODE_SDR12)
#define ACCESS_MODE_BIT_SDR25      (1u << ACCESS_MODE_SDR25)
#define ACCESS_MODE_BIT_SDR50      (1u << ACCESS_MODE_SDR50)
#define ACCESS_MODE_BIT_SDR104     (1u << ACCESS_MODE_SDR104)
#define ACCESS_MODE_BIT_DDR50      (1u << ACCESS_MODE_DDR50)
#define ACCESS_MODE_BIT_NO_CHANGE  (1u << ACCESS_MODE_NO_CHANGE)

#define IO_RW_WRITE                  (1u<<31)
#define IO_RW_FUNCTION_SHIFT        (28)
#define IO_RW_FUNCTION_MASK          (7u << IO_RW_FUNCTION_SHIFT)
#define IO_RW_RAW                    (1u<<27) /* CMD52 */
#define IO_RW_BLOCK_MODE             (1u<<27) /* CMD53 */
#define IO_RW_INCREMENTING           (1u<<26) /* CMD53 */
#define IO_RW_REGISTER_SHIFT         (9)
#define IO_RW_REGISTER_MASK    (0x1FFFFu << IO_RW_REGISTER_SHIFT)
#define IO_RW_WRITE_DATA_SHIFT       (0) /* CMD52 */
#define IO_RW_WRITE_DATA_MASK     (0xFFu << IO_RW_WRITE_DATA_SHIFT)
#define IO_RW_COUNT_SHIFT            (0) /* CMD52 */
#define IO_RW_COUNT_MASK         (0x1FFu << IO_RW_COUNT_SHIFT)

/* Layout of the CIA in SDIO cards */
#define CIA_BASE    (0)
#define CCCR_BASE   (CIA_BASE + 0)
#define FBR_BASE(n) (CIA_BASE + (n) * 0x100)
#define CIS_BASE    (CIA_BASE + 0x1000)
#define CIS_LIMIT   (CIA_BASE + 0x18000)

/* Registers within the CCCR in SDIO cards */
#define CCCR_IO_ABORT              (CCCR_BASE + 0x06)
#define CCCR_BUS_INTERFACE_CONTROL (CCCR_BASE + 0x07)
#define CCCR_CARD_CAPABILITY       (CCCR_BASE + 0x08)
#define CCCR_COMMON_CIS0           (CCCR_BASE + 0x09)
#define CCCR_COMMON_CIS1           (CCCR_BASE + 0x0A)
#define CCCR_COMMON_CIS2           (CCCR_BASE + 0x0B)
#define CCCR_BUS_SUSPEND           (CCCR_BASE + 0x0C)
#define CCCR_FUNCTION_SELECT       (CCCR_BASE + 0x0D)
#define CCCR_BUS_SPEED_SELECT      (CCCR_BASE + 0x13)
#define CCCR_UHS_I_SUPPORT         (CCCR_BASE + 0x14)

#define CCCR_SHS        (1u<<0)
#define CCCR_BSS_SHIFT  (1)
#define CCCR_BSS_SDR12  (0u << CCCR_BSS_SHIFT)
#define CCCR_BSS_SDR25  (1u << CCCR_BSS_SHIFT)
#define CCCR_BSS_SDR50  (2u << CCCR_BSS_SHIFT)
#define CCCR_BSS_SDR104 (3u << CCCR_BSS_SHIFT)
#define CCCR_BSS_DDR50  (4u << CCCR_BSS_SHIFT)
#define CCCR_BSS_MASK   (7u << CCCR_BSS_SHIFT)
#define CCCR_SSDR50     (1u<<0)
#define CCCR_SSDR104    (1u<<1)
#define CCCR_SDDR50     (1u<<2)

/* Registers within the FBR in SDIo cards */
#define FBR_STANDARD_FIC(n)           (FBR_BASE(n) + 0x00)
#define FBR_STANDARD_FIC_SHIFT        (0)
#define FBR_STANDARD_FIC_MASK         (0x0F << FBR_STANDARD_FIC_SHIFT)
#define FBR_STANDARD_FIC_USE_EXTENDED (0x0F << FBR_STANDARD_FIC_SHIFT)
#define FBR_EXTENDED_FIC(n)           (FBR_BASE(n) + 0x01)
#define FBR_CIS0(n)                   (FBR_BASE(n) + 0x09)
#define FBR_CIS1(n)                   (FBR_BASE(n) + 0x0A)
#define FBR_CIS2(n)                   (FBR_BASE(n) + 0x0B)

/* CIS tuple codes */
#define CISTPL_NULL   (0x00)
#define CISTPL_FUNCID (0x21)
#define CISTPL_FUNCE  (0x22)
#define CISTPL_END    (0xFF)

uint32_t cardreg_read_int(uint8_t *reg, bitfield_t where);
const char *cardreg_read_string(uint8_t *reg, bitfield_t where, char *buffer);
const char *cardreg_lookup_manufacturer(const char *code);

#endif
