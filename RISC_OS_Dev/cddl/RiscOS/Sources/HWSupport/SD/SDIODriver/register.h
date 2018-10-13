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

#ifndef REGISTER_H
#define REGISTER_H

#include <stdint.h>
#include "globals.h"

/* Reads and writes are permitted of 8, 16 and 32 bits, at an alignment matching the access width */
/* No effort is made to snoop the write buffer when doing reads - insert an flush between writes and reads if you want to do this */

typedef PACKED(volatile struct)
{                                                  // offset ver OMAP-equiv  notes
  uint32_t sdma_system_address;                    // +0x00  v1  not-impl    unused by OpenBSD       not on OMAP
  uint16_t block_size;                             // +0x04  v1  BLK
  uint16_t block_count;                            // +0x06  v1  "
  uint32_t argument1;                              // +0x08  v1  ARG
  uint16_t transfer_mode;                          // +0x0C  v1  CMD
  uint16_t command;                                // +0x0E  v1  "
  union
  {
    uint8_t  byte[16];
    uint32_t word;
  } response;                                      // +0x10  v1  RSP10-RSP76
  uint32_t data;                                   // +0x20  v1  DATA
  uint32_t present_state;                          // +0x24  v1  PSTATE
  uint8_t  host_control1;                          // +0x28  v1  HCTL
  uint8_t  power_control;                          // +0x29  v1  "
  uint8_t  block_gap_control;                      // +0x2A  v1  "           unused by OpenBSD
  uint8_t  wakeup_control;                         // +0x2B  v1  "           unused by OpenBSD
  uint16_t clock_control;                          // +0x2C  v1  SYSCTL
  uint8_t  timeout_control;                        // +0x2E  v1  "
  uint8_t  software_reset;                         // +0x2F  v1  "
  uint16_t normal_interrupt_status;                // +0x30  v1  STAT
  uint16_t error_interrupt_status;                 // +0x32  v1  "
  uint16_t normal_interrupt_status_enable;         // +0x34  v1  IE
  uint16_t error_interrupt_status_enable;          // +0x36  v1  "
  uint16_t normal_interrupt_signal_enable;         // +0x38  v1  ISE
  uint16_t error_interrupt_signal_enable;          // +0x3A  v1  "
  uint16_t auto_cmd12_error_status;                // +0x3C  v1  AC12        unused by OpenBSD
  uint16_t host_control2;                          // +0x3E  v3  "           undefined by OpenBSD
  uint32_t capabilities[2];                        // +0x40  v1  CAPA                                1 word on OMAP, none on BCM2835
  uint32_t maximum_current_capabilities[2];        // +0x48  v1  CUR_CAPA    unused by OpenBSD       not on BCM2835
  uint16_t force_event_for_auto_cmd_error_status;  // +0x50  v2  not-impl    undefined by OpenBSD    not on OMAP
  uint16_t force_event_for_error_interrupt_status; // +0x52  v2  not-impl    undefined by OpenBSD    not on OMAP
  uint8_t  adma_status;                            // +0x54  v2  not-impl    undefined by OpenBSD    not on OMAP or BCM2835
  uint8_t  reserved1[3];
  uint32_t adma_system_address_lo;                 // +0x58  v2  not-impl    undefined by OpenBSD    not on OMAP or BCM2835
  uint32_t adma_system_address_hi;                 // +0x5C  v2  not-impl    undefined by OpenBSD    not on OMAP or BCM2835
  uint16_t preset_value[8];                        // +0x60  v3  not-impl    undefined by OpenBSD    not on OMAP or BCM2835
  uint16_t reserved2[56];
  uint32_t shared_bus_control;                     // +0xE0  v3  not-impl    undefined by OpenBSD    not on OMAP or BCM2835
  uint16_t reserved3[12];
  uint16_t slot_interrupt_status;                  // +0xFC  v1  REV         unused by OpenBSD
  uint16_t host_controller_version;                // +0xFE  v1  "           unused by OpenBSD
} sdhci_regset_t;

typedef enum
{
  NORMAL_LOCKING, /**< the write buffer struct is locked on entry and unlocked on exit */
  LEAVE_LOCKED,   /**< use on the first write to a write-sensitive word, to prevent flushes due to reentrancy */
  ALREADY_LOCKED, /**< use on the last write to a write-sensitive word */
  NO_LOCKING,     /**< use on any middle writes to a write-sensitive word, equivalent to ALEADY_LOCKED + LEAVE_LOCKED */
}
buffer_lock_override_t;

/** Generic register write macro.
 *  \param reg   Name of register to write, from the list of members of sdhci_regset_t
 *  \param value Number to write to register
 *  Assumes the following variables exist:
 *  \a regs,     pointer to the SDHCI standard register set in logical memory
 *  \a wrbuf,    pointer to the corresponding sdhci_writebuffer_t
 *  \a force32,  a boolean indicating that the write buffer is required for this controller
 */
#define REGISTER_WRITE(reg, value)                                       \
  do                                                                     \
  {                                                                      \
    if (sizeof regs->reg == 1)                                           \
      REGISTER_WRITE8(force32, (uintptr_t)&regs->reg, (value), wrbuf);   \
    else if (sizeof regs->reg == 2)                                      \
      REGISTER_WRITE16(force32, (uintptr_t)&regs->reg, (value), wrbuf);  \
    else                                                                 \
      REGISTER_WRITE32(force32, (uintptr_t)&regs->reg, (value), wrbuf);  \
  } while (0)

#define REGISTER_WRITE8(force32, reg, value, buf)  do { if (force32) register_write_buffer_8 (dev, sloti, (reg), (value), (buf));                 else if (dev->WriteRegister) dev->WriteRegister(dev, sloti, (void *)(reg), (value), 1); else *(volatile uint8_t  *)(reg) = (value); } while(0)
#define REGISTER_WRITE16(force32, reg, value, buf) do { if (force32) register_write_buffer_16(dev, sloti, (reg), (value), (buf), NORMAL_LOCKING); else if (dev->WriteRegister) dev->WriteRegister(dev, sloti, (void *)(reg), (value), 2); else *(volatile uint16_t *)(reg) = (value); } while(0)
#define REGISTER_WRITE32(force32, reg, value, buf) do { if (force32) register_write_buffer_32(dev, sloti, (reg), (value), (buf));                 else if (dev->WriteRegister) dev->WriteRegister(dev, sloti, (void *)(reg), (value), 4); else *(volatile uint32_t *)(reg) = (value); } while(0)

#define REGISTER_WRITE16_LEAVE_LOCKED(force32, reg, value, buf)   do { if (force32) register_write_buffer_16(dev, sloti, (reg), (value), (buf), LEAVE_LOCKED);   else if (dev->WriteRegister) dev->WriteRegister(dev, sloti, (void *)(reg), (value), 2); else *(volatile uint16_t *)(reg) = (value); } while(0)
#define REGISTER_WRITE16_ALREADY_LOCKED(force32, reg, value, buf) do { if (force32) register_write_buffer_16(dev, sloti, (reg), (value), (buf), ALREADY_LOCKED); else if (dev->WriteRegister) dev->WriteRegister(dev, sloti, (void *)(reg), (value), 2); else *(volatile uint16_t *)(reg) = (value); } while(0)

/** Generic register read macro.
 *  \param reg   Name of register to write, from the list of members of sdhci_regset_t
 *  \return      Number that was read from register
 *  Assumes the following variables exist:
 *  \a regs,     pointer to the SDHCI standard register set in logical memory
 *  \a force32,  a boolean indicating that the write buffer is required for this controller
 */
#define REGISTER_READ(reg)                                                      \
  ((sizeof regs->reg == 1) ? REGISTER_READ8(force32, (uintptr_t)&regs->reg) :   \
   (sizeof regs->reg == 2) ? REGISTER_READ16(force32, (uintptr_t)&regs->reg) :  \
                             REGISTER_READ32(force32, (uintptr_t)&regs->reg))

#define REGISTER_READ8(force32, reg)  ((force32) ? (*(volatile uint32_t *)((uintptr_t)(reg) &~ 3) >> (((uintptr_t)(reg) & 3) * 8)) & 0xFFu   : *(volatile uint8_t  *)(reg))
#define REGISTER_READ16(force32, reg) ((force32) ? (*(volatile uint32_t *)((uintptr_t)(reg) &~ 3) >> (((uintptr_t)(reg) & 3) * 8)) & 0xFFFFu : *(volatile uint16_t *)(reg))
#define REGISTER_READ32(force32, reg) (*(volatile uint32_t *)(reg))

/* Register bit definitions */

/* block_size bits */
#define BS_HSBB_SHIFT   (12)                  /* (not on OMAP) */
#define BS_HSBB_MASK    (7u << BS_HSBB_SHIFT) /* (not on OMAP) */
#define BS_TBS_SHIFT    (0)
#define BS_TBS_MASK     (0xFFFu << BS_TBS_SHIFT)

/* transfer_mode bits */
#define TM_MSBS         (1u<<5)  /* Multi / single block select */
#define TM_DDIR         (1u<<4)  /* Data transfer direction select */
#define TM_ACEN_SHIFT   (2)
#define TM_ACEN_NONE    (0u << TM_ACEN_SHIFT) /* Auto command disabled */
#define TM_ACEN_CMD12   (1u << TM_ACEN_SHIFT) /* Auto CMD12 enable */
#define TM_ACEN_CMD23   (2u << TM_ACEN_SHIFT) /* Auto CMD23 enable      (not on OMAP) */
#define TM_ACEN_MASK    (3u << TM_ACEN_SHIFT)
#define TM_BCE          (1u<<1)  /* Block count enable */
#define TM_DE           (1u<<0)  /* DMA enable                          (not on BCM2835) */

/* command bits */
#define CMD_INDEX_SHIFT  (8)
#define CMD_INDEX_MASK   (0x3Fu << CMD_INDEX_SHIFT)
#define CMD_TYPE_SHIFT   (6)
#define CMD_TYPE_NORMAL  (0u << CMD_TYPE_SHIFT)
#define CMD_TYPE_SUSPEND (1u << CMD_TYPE_SHIFT)
#define CMD_TYPE_RESUME  (2u << CMD_TYPE_SHIFT)
#define CMD_TYPE_ABORT   (3u << CMD_TYPE_SHIFT)
#define CMD_TYPE_MASK    (3u << CMD_TYPE_SHIFT)
#define CMD_DP           (1u<<5)  /* Data present */
#define CMD_CICE         (1u<<4)  /* Command index check enable */
#define CMD_CCCE         (1u<<3)  /* Command CRC check enable */
#define CMD_RSP_SHIFT    (0)
#define CMD_RSP_NONE     (0u << CMD_RSP_SHIFT) /* No response */
#define CMD_RSP_136      (1u << CMD_RSP_SHIFT) /* 136-bit response */
#define CMD_RSP_48       (2u << CMD_RSP_SHIFT) /* 48-bit response */
#define CMD_RSP_48_BUSY  (3u << CMD_RSP_SHIFT) /* 48-bit response, check for busy after response */
#define CMD_RSP_MASK     (3u << CMD_RSP_SHIFT)

/* present_state bits */
#define PS_CLEV         (1u<<24) /* CMD line level */
#define PS_DLEV_SHIFT   (20)
#define PS_DLEV_MASK    (0xF << PS_DLEVL_SHIFT)
#define PS_WP           (1u<<19) /* Write protect pin level (not on OMAP or BCM2835) */
#define PS_CD           (1u<<18) /* Card detect pin level   (not on OMAP or BCM2835) */
#define PS_CSS          (1u<<17) /* Card state stable       (not on OMAP or BCM2835) */
#define PS_CI           (1u<<16) /* Card inserted           (not on OMAP or BCM2835) */
#define PS_BRE          (1u<<11) /* Buffer read enable */
#define PS_BWE          (1u<<10) /* Buffer write enable */
#define PS_RTA          (1u<<9)  /* Read transfer active */
#define PS_WTA          (1u<<8)  /* Write transfer active */
#define PS_RTRQ         (1u<<3)  /* Re-tuning request       (not on OMAP or BCM2835) */
#define PS_DLA          (1u<<2)  /* DAT line active */
#define PS_DATI         (1u<<1)  /* Command inhibit (DAT) */
#define PS_CMDI         (1u<<0)  /* Command inhibit (CMD) */

/* host_control1 bits */
#define HC1_CDSS        (1u<<7)  /* Card detect signal selection        (not on OMAP or BCM2835) */
#define HC1_CDTL        (1u<<6)  /* Card detect test level              (not on OMAP or BCM2835) */
#define HC1_EDTW        (1u<<5)  /* Extended data transfer width        (not on OMAP) */
#define HC1_DMAS_SHIFT  (3)
#define HC1_DMAS_SDMA   (0u << HC1_DMAS_SHIFT) /* SDMA is selected      (not on OMAP or BCM2835) */
#define HC1_DMAS_32ADMA (2u << HC1_DMAS_SHIFT) /* 32-bit ADMA2 selected (not on OMAP or BCM2835) */
#define HC1_DMAS_MASK   (3u << HC1_DMAS_SHIFT)
#define HC1_HSE         (1u<<2)  /* High speed enable                   (not on OMAP) */
#define HC1_DTW         (1u<<1)  /* Data transfer width */
#define HC1_LEDC        (1u<<0)  /* LED control                         (not on OMAP or BCM2835) */

/* power_control bits */
#define PC_SDVS_SHIFT (1)
#define PC_SDVS_1_8V  (0x5u << PC_SDVS_SHIFT) /* SD bus voltage select 1.8V (not on BCM2835) */
#define PC_SDVS_3_0V  (0x6u << PC_SDVS_SHIFT) /* SD bus voltage select 3.0V (not on BCM2835) */
#define PC_SDVS_3_3V  (0x7u << PC_SDVS_SHIFT) /* SD bus voltage select 3.3V (not on BCM2835) */
#define PC_SDVS_MASK  (0x7u << PC_SDVS_SHIFT)
#define PC_SDBP       (1u<<0)                 /* SD bus power               (not on BCM2835) */

/* block_gap_control bits */
#define BGC_IBP  (1u<<3) /* Interrupt at block gap */
#define BGC_RWC  (1u<<2) /* Read wait control */
#define BGC_CR   (1u<<1) /* Continue request */
#define BGC_SBGR (1u<<0) /* Stop at block gap request */

/* wakeup_control bits */
#define WC_REM (1u<<2) /* Wakeup event enable on card removal */
#define WC_INS (1u<<1) /* Wakeup event enable on card insertion */
#define WC_IWE (1u<<0) /* Wakeup event enable on card interrupt */

/* clock_control bits */
#define CC_SFS_SHIFT   (8)
#define CC_SFS_MASK    (0xFFu << CC_SFS_SHIFT)  /* SDCLK frequency select               (not on OMAP) */
#define CC_UBSFS_SHIFT (6)
#define CC_UBSFS_MASK  (0x3u << CC_UBSFS_SHIFT) /* Upper bits of SDCLK frequency select (not on OMAP) */
#define CC_CGS         (1u<<5)                  /* Clock generator select               (not on OMAP) */
#define CC_SCE         (1u<<2)                  /* SD clock enable */
#define CC_ICS         (1u<<1)                  /* Internal clock stable */
#define CC_ICE         (1u<<0)                  /* Internal clock enable */

/* timeout_control bits */
#define TC_DTCV_SHIFT (0)
#define TC_DTCV_MASK  (0xF << TC_DTCV_SHIFT) /* Data timeout counter value */

/* software_reset bits */
#define SR_SRD (1u<<2) /* Software reset for DAT line */
#define SR_SRC (1u<<1) /* Software reset for CMD line */
#define SR_SRA (1u<<0) /* Software reset for all */

/* interrupt bits */
#define IRQ_ERRI (1u<<15) /* Error interrupt */
#define IRQ_RTE  (1u<<12) /* Re-tuning event     (not on OMAP) */
#define IRQ_C    (1u<<11) /* INT_C line asserted (not on OMAP or BCM2835) */
#define IRQ_B    (1u<<10) /* INT_B line asserted (not on OMAP or BCM2835) */
#define IRQ_A    (1u<<9)  /* INT_A line asserted (not on OMAP or BCM2835) */
#define IRQ_CIRQ (1u<<8)  /* Card interrupt */
#define IRQ_CREM (1u<<7)  /* Card removal        (not on OMAP or BCM2835) */
#define IRQ_CINS (1u<<6)  /* Card insertion      (not on OMAP or BCM2835) */
#define IRQ_BRR  (1u<<5)  /* Buffer read ready */
#define IRQ_BWR  (1u<<4)  /* Buffer write ready */
#define IRQ_SDMA (1u<<3)  /* DMA interrupt       (not on BCM2835) */
#define IRQ_BGE  (1u<<2)  /* Block gap event */
#define IRQ_TC   (1u<<1)  /* Transfer complete */
#define IRQ_CC   (1u<<0)  /* Command complete */

/* error interrupt bits */
#define EIRQ_TUNE (1u<<10) /* Tuning error  (not on OMAP or BCM2835) */
#define EIRQ_ADMA (1u<<9)  /* ADMA error    (not on OMAP or BCM2835) */
#define EIRQ_ACE  (1u<<8)  /* Auto CMD12 error */
#define EIRQ_CURL (1u<<7)  /* Current limit (not on OMAP or BCM2835) */
#define EIRQ_DEB  (1u<<6)  /* Data end bit error */
#define EIRQ_DCRC (1u<<5)  /* Data CRC error */
#define EIRQ_DTO  (1u<<4)  /* Data timeout error */
#define EIRQ_CIE  (1u<<3)  /* Command index error */
#define EIRQ_CEB  (1u<<2)  /* Command end bit error */
#define EIRQ_CCRC (1u<<1)  /* Command CRC error */
#define EIRQ_CTO  (1u<<0)  /* Command timeout error */

/* capabilities[0] bits (not on BCM2835) */
#define CAP0_ST_SHIFT   (30)
#define CAP0_ST_REMOV   (0u << CAP0_ST_SHIFT)  /* Removable card slot          (not on OMAP) */
#define CAP0_ST_EMBED   (1u << CAP0_ST_SHIFT)  /* Embedded slot for one device (not on OMAP) */
#define CAP0_ST_SHARED  (2u << CAP0_ST_SHIFT)  /* Shared bus slot              (not on OMAP) */
#define CAP0_ST_MASK    (3u << CAP0_ST_SHIFT)
#define CAP0_AI         (1u<<29)  /* Asynchronous interrupt    (not on OMAP) */
#define CAP0_64SB       (1u<<28)  /* 64-bit system bus support (not on OMAP) */
#define CAP0_VS18       (1u<<26)  /* Voltage support 1.8V */
#define CAP0_VS30       (1u<<25)  /* Voltage support 3.0V */
#define CAP0_VS33       (1u<<24)  /* Voltage support 3.3V */
#define CAP0_SRS        (1u<<23)  /* Suspend/resume support */
#define CAP0_DS         (1u<<22)  /* DMA support */
#define CAP0_HSS        (1u<<21)  /* High speed (52MHz) support */
#define CAP0_ADMA1      (1u<<20)  /* ADMA1 support             (not on OMAP) */
#define CAP0_ADMA2      (1u<<19)  /* ADMA2 support             (not on OMAP) */
#define CAP0_8BIT       (1u<<18)  /* 8-bit embedded device     (not on OMAP) */
#define CAP0_MBL_SHIFT  (16)
#define CAP0_MBL_512    (0u << CAP0_MBL_SHIFT)  /* 512-byte blocks */
#define CAP0_MBL_1024   (1u << CAP0_MBL_SHIFT)  /* 1024-byte blocks */
#define CAP0_MBL_2048   (2u << CAP0_MBL_SHIFT)  /* 2048-byte blocks */
#define CAP0_MBL_MASK   (3u << CAP0_MBL_SHIFT)
#define CAP0_BCF_SHIFT  (8)
#define CAP0_BCF_MASK   (0xFFu << CAP0_BCF_SHIFT)
#define CAP0_TCU        (1u<<7)  /* Timeout clock unit */
#define CAP0_TCF_SHIFT  (0)
#define CAP0_TCF_MASK   (0x3Fu << CAP0_TCF_SHIFT)

/* capabilities[1] bits (not on OMAP or BCM2835) */
#define CAP1_CM_SHIFT   (16)
#define CAP1_CM_MASK    (0xFFu << CAP1_CM_SHIFT)
#define CAP1_RTM_SHIFT  (14)
#define CAP1_RTM_MODE1  (0u << CAP1_RTM_SHIFT)
#define CAP1_RTM_MODE2  (1u << CAP1_RTM_SHIFT)
#define CAP1_RTM_MODE3  (2u << CAP1_RTM_SHIFT)
#define CAP1_RTM_MASK   (3u << CAP1_RTM_SHIFT)
#define CAP1_UTSDR50    (1u<<13)
#define CAP1_TCR_SHIFT  (8)
#define CAP1_TCR_MASK   (0xF << CAP1_TCR_SHIFT)
#define CAP1_DTDS       (1u<<6)
#define CAP1_DTCS       (1u<<5)
#define CAP1_DTAS       (1u<<4)
#define CAP1_DDR50S     (1u<<2)
#define CAP1_SDR104S    (1u<<1)
#define CAP1_SDR50S     (1u<<0)

/* maximum_current_capabilities[0] bits (not on BCM2835) */
#define MCC_1_8V_SHIFT  (16)
#define MCC_1_8V_MASK   (0xFFu << MCC_1_8V_SHIFT)
#define MCC_3_0V_SHIFT  (8)
#define MCC_3_0V_MASK   (0xFFu << MCC_1_8V_SHIFT)
#define MCC_3_3V_SHIFT  (0)
#define MCC_3_3V_MASK   (0xFFu << MCC_1_8V_SHIFT)

/* host_controller_version bits */
#define HCV_VREV_SHIFT  (8)
#define HCV_VREV_MASK   (0xFFu << HCV_VREV_SHIFT)  /* Vendor version number (not on OMAP) */
#define HCV_SREV_SHIFT  (0)
#define HCV_SREV_1_00   (0x00u << HCV_SREV_SHIFT)  /* SD Host Specification Version 1.00 */
#define HCV_SREV_2_00   (0x01u << HCV_SREV_SHIFT)  /* SD Host Specification Version 2.00 */
#define HCV_SREV_3_00   (0x02u << HCV_SREV_SHIFT)  /* SD Host Specification Version 3.00 */
#define HCV_SREV_MASK   (0xFFu << HCV_SREV_SHIFT)  /* Specification version number */

void register_init_buffer(sdhci_writebuffer_t * restrict buf);
void register_flush_buffer(sdhcidevice_t *dev, uint32_t sloti, sdhci_writebuffer_t * restrict buf);
void register_write_buffer_8(sdhcidevice_t *dev, uint32_t sloti, uintptr_t reg, uint8_t value, sdhci_writebuffer_t * restrict buf);
void register_write_buffer_16(sdhcidevice_t *dev, uint32_t sloti, uintptr_t reg, uint16_t value, sdhci_writebuffer_t * restrict buf, buffer_lock_override_t override);
void register_write_buffer_32(sdhcidevice_t *dev, uint32_t sloti, uintptr_t reg, uint32_t value, sdhci_writebuffer_t * restrict buf);

#endif
