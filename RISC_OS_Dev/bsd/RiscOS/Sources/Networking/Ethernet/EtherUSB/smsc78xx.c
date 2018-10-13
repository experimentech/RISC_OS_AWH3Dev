/*
 * Copyright (c) 2014, Willi Theiss St. Wendel, Germany
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
 
/*
 * Based on smsc75xx driver
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "swis.h"

#include "backends.h"
#include "module.h"
#include "utils.h"
#include "USB/USBDevFS.h"
#include "usb.h"
#include "net.h"
#include "mii.h"
#include "products.h"

/* USB Vendor Requests */
#define USB_VENDOR_REQUEST_WRITE_REGISTER       0xA0
#define USB_VENDOR_REQUEST_READ_REGISTER        0xA1
#define USB_VENDOR_REQUEST_GET_STATS            0xA2

/* Register definitions for SMSC78xx (taken from LAN7800 datasheet DS00001992F) */
/* Register offsets in IO space */
#define SMSC78XX_ID_REV                         (0x0000)        /* Device ID and Revision */
#define SMSC78XX_INT_STS                        (0x000C)        /* Interrupt Status */
#define SMSC78XX_HW_CFG                         (0x0010)        /* Hardware Configuration */
#define SMSC78XX_PMT_CTL                        (0x0014)        /* Power Management Control */
#define SMSC78XX_LED_GPIO_CFG0                  (0x0018)        /* LED General Purpose IO Configuration 0 */
#define SMSC78XX_LED_GPIO_CFG1                  (0x001C)        /* LED General Purpose IO Configuration 1 */
#define SMSC78XX_GPIO_WAKE                      (0x0020)        /* GPIO Wake Enable + Polarity */
#define SMSC78XX_DP_SEL                         (0x0024)        /* Data Port Select */
#define SMSC78XX_DP_CMD                         (0x0028)        /* Data Port Command */
#define SMSC78XX_DP_ADDR                        (0x002C)        /* Data Port Address */
#define SMSC78XX_DP_DATA                        (0x0030)        /* Data Port Data */
#define SMSC78XX_E2P_CMD                        (0x0040)        /* EEPROM Command */
#define SMSC78XX_E2P_DATA                       (0x0044)        /* EEPROM Data */
#define SMSC78XX_HS_ATTR                        (0x0054)        /* HS Descriptor Attributes */
#define SMSC78XX_FS_ATTR                        (0x005C)        /* FS Descriptor Attributes */
#define SMSC78XX_STRNG_ATTR0                    (0x0060)        /* String Descriptor Attributes 0 */
#define SMSC78XX_STRNG_ATTR1                    (0x0064)        /* String Descriptor Attributes 1 */
#define SMSC78XX_FLAG_ATTR                      (0x0068)        /* Flag Attributes */
#define SMSC78XX_USB_CFG0                       (0x0080)        /* USB Configuration Register 0 */
#define SMSC78XX_BURST_CAP                      (0x0090)        /* Burst Capabilities */
#define SMSC78XX_BULK_IN_DLY                    (0x0094)        /* Bulk-in Delay */
#define SMSC78XX_INT_EP_CTL                     (0x0098)        /* Interrupt Endpoint Control */

#define SMSC78XX_RFE_CTL                        (0x00B0)        /* Receive Filtering Engine Control */
#define SMSC78XX_VLAN_TYPE                      (0x00B4)        /* VLAN Type */
#define SMSC78XX_FCT_RX_CTL                     (0x00C0)        /* FIFO Controller RX FIFO Control */
#define SMSC78XX_FCT_TX_CTL                     (0x00C4)        /* FIFO Controller TX FIFO Control */
#define SMSC78XX_FCT_RX_FIFO_END                (0x00C8)        /* RX FIFO End (?) */
#define SMSC78XX_FCT_TX_FIFO_END                (0x00CC)        /* TX FIFO End (?) */
#define SMSC78XX_FCT_FLOW                       (0x00D0)        /* FIFO Controller  Flow Control */

/* MAC Control and Status Registers */
#define SMSC78XX_MAC_CR                         (0x0100)        /* MAC Control */
#define SMSC78XX_MAC_RX                         (0x0104)        /* MAC Receive */
#define SMSC78XX_MAC_TX                         (0x0108)        /* MAC Transmit */
#define SMSC78XX_FLOW                           (0x010C)        /* Flow Control */
#define SMSC78XX_RAND_SEED                      (0x0110)        /* Random Number Seed Value */
#define SMSC78XX_ERR_STS                        (0x0114)        /* Error Status */
#define SMSC78XX_RX_ADDRH                       (0x0118)        /* MAC Receive Address High */
#define SMSC78XX_RX_ADDRL                       (0x011C)        /* MAC Receive Address Low */
#define SMSC78XX_MII_ACCESS                     (0x0120)        /* MII Access Register */
#define SMSC78XX_MII_DATA                       (0x0124)        /* MII Data Register */
#define SMSC78XX_WUCSR                          (0x0140)        /* Wakeup Control and Status */
#define SMSC78XX_WUF_CFGX                       (0x0150)        /* Wakeup Filter Configuration 0 - 31 */
#define SMSC78XX_WUF_MASKX                      (0x0300)        /* Wakeup Filter Mask 0 - 31 */
#define SMSC78XX_ADDR_FILTX                     (0x0400)        /* RFE Perfect MAC Address Filters */
#define SMSC78XX_WUCSR2                         (0x0600)        /* Wakeup Control and Status 2 */
#define SMSC78XX_IPV6_ADDRX                     (0x0610)        /* IPv6 Addresses */
#define SMSC78XX_IPV4_ADDRX                     (0x0690)        /* IPv4 Addresses */

/* TX Command definitions */
#define SMSC78XX_TX_CMD_A_LEN                   (0xFFFFF << 0)  /* Frame Length */
#define SMSC78XX_TX_CMD_A_FCS                   (1 << 22)       /* Insert FCS and Pad */
#define SMSC78XX_TX_CMD_A_RVTG                  (1 << 23)       /* Replace VLAN Tag */
#define SMSC78XX_TX_CMD_A_IVTG                  (1 << 24)       /* Insert VLAN Tag */
#define SMSC78XX_TX_CMD_A_TPE                   (1 << 25)       /* TCP/UDP Checksum Offload Enable */
#define SMSC78XX_TX_CMD_A_IPE                   (1 << 26)       /* IP Checksum Offload Enable */
#define SMSC78XX_TX_CMD_A_LSO                   (1 << 27)       /* Large Send Offload Enable */

#define SMSC78XX_TX_CMD_B_VTAG                  (0xFFFF << 0)   /* VLAN Tag */
#define SMSC78XX_TX_CMD_B_MSS                   (0x3FFF << 16)  /* Maximum Segment Size */
#define SMSC78XX_TX_CMD_B_MSS_SHIFT             (16)
#define SMSC78XX_TX_MSS_MIN                     (8)             /* min MSS value */
#define SMSC78XX_TX_MSS_MAX                     (9 * 1024)      /* max MSS value */

/* RX Command definitions */
#define SMSC78XX_RX_CMD_A_LEN                   (0x3FFF << 0)   /* Frame Length */
#define SMSC78XX_RX_CMD_A_ICSM                  (1 << 14)       /* Ignore TCP/UDP Checksum */
#define SMSC78XX_RX_CMD_A_UAM                   (1 << 15)       /* Unicast Frame */
#define SMSC78XX_RX_CMD_A_FCS                   (1 << 16)       /* FCS Error */
#define SMSC78XX_RX_CMD_A_ALN                   (1 << 17)       /* Alignment Error */
#define SMSC78XX_RX_CMD_A_RXE                   (1 << 18)       /* RX Error */
#define SMSC78XX_RX_CMD_A_LONG                  (1 << 19)       /* Frame Too Long */
#define SMSC78XX_RX_CMD_A_RUNT                  (1 << 20)       /* Runt Frame */
#define SMSC78XX_RX_CMD_A_RWT                   (1 << 21)       /* Receive Watchdog Timer Expired */
#define SMSC78XX_RX_CMD_A_RED                   (1 << 22)       /* Receive Error Detected */
#define SMSC78XX_RX_CMD_A_FVTG                  (1 << 23)       /* Frame is VLAN tagged */
#define SMSC78XX_RX_CMD_A_MAM                   (1 << 24)       /* Multicast Frame */
#define SMSC78XX_RX_CMD_A_BAM                   (1 << 25)       /* Broadcast Frame */
#define SMSC78XX_RX_CMD_A_PFF                   (1 << 26)       /* Perfect Filter Passed */
#define SMSC78XX_RX_CMD_A_PID                   (3 << 27)       /* Protocol ID */
#define SMSC78XX_RX_CMD_A_PID_NIP               (0 << 27)       /*  None IP */
#define SMSC78XX_RX_CMD_A_PID_TCP               (1 << 27)       /*  TCP and IP */
#define SMSC78XX_RX_CMD_A_PID_UDP               (2 << 27)       /*  UDP and IP */
#define SMSC78XX_RX_CMD_A_PID_IP                (3 << 27)       /*  IP */
#define SMSC78XX_RX_CMD_A_IPV                   (1 << 29)       /* IP Version */
#define SMSC78XX_RX_CMD_A_TCE                   (1 << 30)       /* TCP/UDP Checksum Error */
#define SMSC78XX_RX_CMD_A_ICE                   (1u << 31)      /* IP Checksum Error */

#define SMSC78XX_RX_CMD_B_VTAG                  (0xFFFFu << 0)  /* VLAN Tag */
#define SMSC78XX_RX_CMD_B_CSUM                  (0xFFFFu << 16) /* Raw L3 Checksum */
#define SMSC78XX_RX_CMD_B_CSUM_SHIFT            (16)

/* bits in Device ID and Revision Register */
#define SMSC78XX_ID_REV_CHIP_REV                (0xFFFFu << 0)  /* Chip Revision */
#define SMSC78XX_ID_REV_CHIP_ID                 (0xFFFFu << 16) /* Chip ID */
#define SMSC78XX_ID_REV_CHIP_ID_SHIFT           (16)

/* bits in Interrupt Status Register */
#define SMSC78XX_INT_STS_GPIOS                  (0xFFF << 0)    /* GPIO[11:0] interrupts */
#define SMSC78XX_INT_STS_MAC_ERR                (1 << 15)       /* MAC Error */
#define SMSC78XX_INT_STS_PHY                    (1 << 17)       /* PHY event */
#define SMSC78XX_INT_STS_RX_DIS                 (1 << 18)       /* RX Disabled */
#define SMSC78XX_INT_STS_TX_DIS                 (1 << 19)       /* TX Disabled */
#define SMSC78XX_INT_STS_TXE                    (1 << 21)       /* TX Error */
#define SMSC78XX_INT_STS_RDFO                   (1 << 22)       /* RX Data FIFO Overrun */

/* bits in Hardware Configuration Register */
#define SMSC78XX_HW_CFG_SRST                    (1 << 0)        /* Soft Reset */
#define SMSC78XX_HW_CFG_LRST                    (1 << 1)        /* Soft Lite Reset */
#define SMSC78XX_HW_CFG_ETC                     (1 << 3)        /* EEPROM Time-out Control */
#define SMSC78XX_HW_CFG_MEF                     (1 << 4)        /* Multiple Ethernet Frames per USB Packet */
#define SMSC78XX_HW_CFG_RST_PROTECT             (1 << 12)       /* Reset Protection */
#define SMSC78XX_HW_CFG_EEM                     (1 << 13)       /* EEPROM Emulation Enable */
#define SMSC78XX_HW_CFG_NETDET_EN               (1 << 14)       /* NetDetach Enable */
#define SMSC78XX_HW_CFG_NETDET_STS              (1 << 15)       /* NetDetach Status */
#define SMSC78XX_HW_CFG_LED0_EN                 (1 << 20)       /* LED0 Enable */
#define SMSC78XX_HW_CFG_LED1_EN                 (1 << 21)       /* LED1 Enable */
#define SMSC78XX_HW_CFG_LED2_EN                 (1 << 22)       /* LED2 Enable */
#define SMSC78XX_HW_CFG_LED3_EN                 (1 << 23)       /* LED3 Enable */

/* bits in Power Management Control Register */
#define SMSC78XX_PMT_CTL_WUPS                   (3 << 0)        /* Wake-UP Status */
#define SMSC78XX_PMT_CTL_WUPS_NO                (0 << 0)        /* No wake-up event detected */
#define SMSC78XX_PMT_CTL_WUPS_ED                (1 << 0)        /* Energy detected */
#define SMSC78XX_PMT_CTL_WUPS_WOL               (2 << 0)        /* Wake-On-LAN */
#define SMSC78XX_PMT_CTL_WUPS_ME                (3 << 0)        /* Multiple Events */
#define SMSC78XX_PMT_CTL_WOL_EN                 (1 << 3)        /* Wake-On-LAN Enable */
#define SMSC78XX_PMT_CTL_PHY_RST                (1 << 4)        /* PHY Reset */
#define SMSC78XX_PMT_CTL_SUS_MODE               (3 << 5)        /* Suspend Mode */
#define SMSC78XX_PMT_CTL_SUS_MODE_0             (0 << 5)        /* GPIO, WOL, Magic Packet, PHY Link Up */
#define SMSC78XX_PMT_CTL_SUS_MODE_1             (1 << 5)        /* GPIO, Link Status Change */
#define SMSC78XX_PMT_CTL_SUS_MODE_2             (2 << 5)        /* GPIO */
#define SMSC78XX_PMT_CTL_SUS_MODE_3             (3 << 5)        /* GPIO, Good Packet, PHY Link Up */
#define SMSC78XX_PMT_CTL_DEV_RDY                (1 << 7)        /* Device Ready */
#define SMSC78XX_PMT_CTL_RES_CLR_WKP_EN         (1 << 8)        /* Resume Clear Remote Wakeup Enable */
#define SMSC78XX_PMT_CTL_RES_CLR_WKP_STS        (1 << 9)        /* Resume Clear Remote Wakeup Status */
#define SMSC78XX_PMT_CTL_MAC_SRST               (1 << 11)       /* MAC Soft Reset */

/* bits in LED General Purpose IO Configuration Register 0 */
#define SMSC78XX_LED_GPIO_CFG0_GPDATA_0         (1 << 0)        /* GPIO Data */
#define SMSC78XX_LED_GPIO_CFG0_GPDATA_1         (1 << 1)
#define SMSC78XX_LED_GPIO_CFG0_GPDATA_2         (1 << 2)
#define SMSC78XX_LED_GPIO_CFG0_GPDATA_3         (1 << 3)
#define SMSC78XX_LED_GPIO_CFG0_GPDIR_0          (1 << 4)        /* GPIO Direction */
#define SMSC78XX_LED_GPIO_CFG0_GPDIR_1          (1 << 5)
#define SMSC78XX_LED_GPIO_CFG0_GPDIR_2          (1 << 6)
#define SMSC78XX_LED_GPIO_CFG0_GPDIR_3          (1 << 7)
#define SMSC78XX_LED_GPIO_CFG0_GPBUF_0          (1 << 8)        /* GPIO Buffer Type */
#define SMSC78XX_LED_GPIO_CFG0_GPBUF_1          (1 << 9)
#define SMSC78XX_LED_GPIO_CFG0_GPBUF_2          (1 << 10)
#define SMSC78XX_LED_GPIO_CFG0_GPBUF_3          (1 << 11)
#define SMSC78XX_LED_GPIO_CFG0_GPIO_EN_0        (1 << 12)       /* GPIO Enable */
#define SMSC78XX_LED_GPIO_CFG0_GPIO_EN_1        (1 << 13)
#define SMSC78XX_LED_GPIO_CFG0_GPIO_EN_2        (1 << 14)
#define SMSC78XX_LED_GPIO_CFG0_GPIO_EN_3        (1 << 15)

/* bits in LED General Purpose IO Configuration Register 1 */
#define SMSC78XX_LED_GPIO_CFG1_GPDATA           (0xF << 0)
#define SMSC78XX_LED_GPIO_CFG1_GPDIR            (0xF << 8)
#define SMSC78XX_LED_GPIO_CFG1_GPDIR_SHIFT      (8)
#define SMSC78XX_LED_GPIO_CFG1_GPBUF            (0xF << 16)
#define SMSC78XX_LED_GPIO_CFG1_GPBUF_SHIFT      (16)
#define SMSC78XX_LED_GPIO_CFG1_GPEN             (0xFu << 24)
#define SMSC78XX_LED_GPIO_CFG1_GPEN_SHIFT       (24)

/* bits in GPIO WakeUp Configuration Register */
#define SMSC78XX_GPIO_WAKE_WK                   (0xFF << 0)
#define SMSC78XX_GPIO_WAKE_POL                  (0xFF << 16)
#define SMSC78XX_GPIO_WAKE_POL_SHIFT            (16)
#define SMSC78XX_GPIO_WAKE_PHY_LINKUP_EN        (1u << 31)              /* PHY Link Up Enable */

/* bits in Data Port Selection Register */
#define SMSC78XX_DP_SEL_RSEL                    (15 << 0)       /* RAM Test Select */
#define SMSC78XX_DP_SEL_URX                     ( 0 << 0)       /* URX Buffer RAM */
#define SMSC78XX_DP_SEL_VHF                     ( 1 << 0)       /* RFE VLAN + DA Hash Table (VHF RAM) */
#define SMSC78XX_DP_SEL_LSO_HEAD                ( 2 << 0)       /* LSO Header RAM */
#define SMSC78XX_DP_SEL_FCT_RX                  ( 3 << 0)       /* FCT RX RAM */
#define SMSC78XX_DP_SEL_FCT_TX                  ( 4 << 0)       /* FCT TX RAM */
#define SMSC78XX_DP_SEL_DESCRIPTOR              ( 5 << 0)       /* Descriptor RAM */
#define SMSC78XX_DP_SEL_DPRDY                   (1u << 31)      /* Data Port Ready */

/* bits in Data Port Command Register */
#define SMSC78XX_DP_CMD_READ                    (0 << 0)
#define SMSC78XX_DP_CMD_WRITE                   (1 << 0)

/* bits in USB Configuration Register 0 */
#define SMSC78XX_USB_CFG0_SBP                   (1 << 0)        /* Stall Bulk-Out Pipe Disable */
#define SMSC78XX_USB_CFG0_PORT_SWAP             (1 << 4)        /* Port Swap (USBDP - USBDM) */
#define SMSC78XX_USB_CFG0_BCE                   (1 << 5)        /* Burst Cap Enable */
#define SMSC78XX_USB_CFG0_BIR                   (1 << 6)        /* Bulk-In Empty Response */

/* bits in Burst Capabilities Register */
#define SMSC78XX_BURST_CAP_MASK                 (0xFF << 0)

/* bits in Interrupt Endpoint Control Register */
#define SMSC78XX_INT_EP_CTL_GPIOX_EN            (0xFF << 0)
#define SMSC78XX_INT_EP_CTL_MAC_ERR_EN          (1 << 15)       /* MAC Error Enable */
#define SMSC78XX_INT_EP_CTL_PHY_EN              (1 << 17)       /* PHY interrupt Enable */
#define SMSC78XX_INT_EP_CTL_RX_DIS_EN           (1 << 18)       /* RX Disabled Enable */
#define SMSC78XX_INT_EP_CTL_TX_DIS_EN           (1 << 19)       /* TX Disabled Enable */
#define SMSC78XX_INT_EP_CTL_TXE_EN              (1 << 21)       /* TX Error Enable */
#define SMSC78XX_INT_EP_CTL_RDFO_EN             (1 << 22)       /* RX Data FIFO Overrun Enable */
#define SMSC78XX_INT_EP_CTL_INTEP_ON            (1u << 31)      /* Interrupt Endpoint Always On */

/* bits in Bulk In Delay Register */
#define SMSC78XX_BULK_IN_DLY_MASK               (0xFFFF << 0)

/* bits in EEPROM Command Register */
#define SMSC78XX_E2P_CMD_ADDRESS                (0x1FF << 0)    /* EPC Address */
#define SMSC78XX_E2P_CMD_EPC_DL                 (1 << 9)        /* EPC Data Loaded */
#define SMSC78XX_E2P_CMD_EPC_TO                 (1 << 10)       /* EPC Time-out */
#define SMSC78XX_E2P_CMD_CMDMASK                (7 << 28)       /* Command field */
#define SMSC78XX_E2P_CMD_READ                   (0 << 28)       /* Read Location */
#define SMSC78XX_E2P_CMD_EWDS                   (1 << 28)       /* Erase/Write Disable */
#define SMSC78XX_E2P_CMD_EWEN                   (2 << 28)       /* Erase/Write Enable */
#define SMSC78XX_E2P_CMD_WRITE                  (3 << 28)       /* Write Location */
#define SMSC78XX_E2P_CMD_WRAL                   (4 << 28)       /* Write All */
#define SMSC78XX_E2P_CMD_ERASE                  (5 << 28)       /* Erase Location */
#define SMSC78XX_E2P_CMD_ERAL                   (6 << 28)       /* Erase All */
#define SMSC78XX_E2P_CMD_RELOAD                 (7 << 28)       /* Data Reload */
#define SMSC78XX_E2P_CMD_EPC_BSY                (1u << 31)      /* EPC Busy */

/* bits in EEPROM Data Register */
#define SMSC78XX_E2P_DATA_MASK                  (0xFF << 0)

/* bits in Receive Filtering Engine Control Register */
#define SMSC78XX_RFE_CTL_RST_RF                 (1 << 0)        /* Reset Receive Filtering Engine */
#define SMSC78XX_RFE_CTL_DPF                    (1 << 1)        /* Enable Destination Address Perfect Filtering */
#define SMSC78XX_RFE_CTL_DHF                    (1 << 2)        /* Enable Destination Address Hash Filtering */
#define SMSC78XX_RFE_CTL_MHF                    (1 << 3)        /* Enable Multicast Address Only Hash Filtering */
#define SMSC78XX_RFE_CTL_SPF                    (1 << 4)        /* Enable Source Address Perfect Filtering */
#define SMSC78XX_RFE_CTL_VF                     (1 << 5)        /* Enable VLAN Filtering */
#define SMSC78XX_RFE_CTL_UF                     (1 << 6)        /* Untagged Frame Filtering */
#define SMSC78XX_RFE_CTL_VS                     (1 << 7)        /* Enable VLAN Stripping */
#define SMSC78XX_RFE_CTL_AU                     (1 << 8)        /* Accept Unicast Frames */
#define SMSC78XX_RFE_CTL_AM                     (1 << 9)        /* Accept Multicast Frames */
#define SMSC78XX_RFE_CTL_AB                     (1 << 10)       /* Accept Broadcast Frames */
#define SMSC78XX_RFE_CTL_IP_CKM                 (1 << 11)       /* Enable IP Checksum Validation */
#define SMSC78XX_RFE_CTL_TCPUDP_CKM             (1 << 12)       /* Enable TCP/UDP Checksum Validation */

/* bits in FIFO Controller RX FIFO Control Register */
#define SMSC78XX_FCT_RX_CTL_RXUSED              (0xFFFF << 0)   /* RX Data FIFO Used Space */
#define SMSC78XX_FCT_RX_CTL_RX_DISABLED         (1 << 20)       /* FCT RX Disabled */
#define SMSC78XX_FCT_RX_CTL_FRM_DROP            (1 << 23)       /* Frame Dropped */
#define SMSC78XX_FCT_RX_CTL_OVERFLOW            (1 << 24)       /* FCT RX Overflow */
#define SMSC78XX_FCT_RX_CTL_SBF                 (1 << 25)       /* Store Bad Frames */
#define SMSC78XX_FCT_RX_CTL_RST                 (1 << 30)       /* FCT RX Reset */
#define SMSC78XX_FCT_RX_CTL_EN                  (1u << 31)      /* FCT RX Enable */

/* bits in FIFO Controller TX FIFO Control Register */
#define SMSC78XX_FCT_TX_CTL_TXUSED              (0xFFFF << 0)   /* TX Data FIFO Used Space */
#define SMSC78XX_FCT_TX_CTL_TX_DISABLED         (1 << 20)       /* FCT TX Disabled */
#define SMSC78XX_FCT_TX_CTL_RST                 (1 << 30)       /* FCT TX Reset */
#define SMSC78XX_FCT_TX_CTL_EN                  (1u << 31)      /* FCT TX Enable */

/* bits in FIFO Controller Flow Control Register */
#define SMSC78XX_FCT_FLOW_THRESHOLD_ON          (0x7F << 0)     /* Flow Control On Threshold */
#define SMSC78XX_FCT_FLOW_THRESHOLD_OFF         (0x7F << 8)     /* Flow Control Off Threshold */
#define SMSC78XX_FCT_FLOW_THRESHOLD_OFF_SHIFT   (8)

/* bits in MAC Control Register */
#define SMSC78XX_MAC_CR_MRST                    (1 << 0)        /* MAC Reset */
#define SMSC78XX_MAC_CR_CFG_MASK                (3 << 1)        /* MAC Configuration */
#define SMSC78XX_MAC_CR_CFG_10                  (0 << 1)        /*   10 Mbps */
#define SMSC78XX_MAC_CR_CFG_100                 (1 << 1)        /*  100 Mbps */
#define SMSC78XX_MAC_CR_CFG_1000                (2 << 1)        /* 1000 Mbps */
#define SMSC78XX_MAC_CR_CFG_1000_2              (3 << 1)        /* 1000 Mbps */
#define SMSC78XX_MAC_CR_FDPX                    (1 << 3)        /* Duplex Mode (1=Full,0=Half) */
#define SMSC78XX_MAC_CR_BOLMT                   (3 << 6)        /* BackOff Limit */
#define SMSC78XX_MAC_CR_INT_LOOP                (1 << 10)       /* Internal Loopback Operation Mode */
#define SMSC78XX_MAC_CR_ASD                     (1 << 11)       /* Automatic Speed Detection */
#define SMSC78XX_MAC_CR_ADD                     (1 << 12)       /* Automatic Duplex Detection */
#define SMSC78XX_MAC_CR_ADP                     (1 << 13)       /* Automatic Duplex Polarity */

/* bits in MAC Receive Register */
#define SMSC78XX_MAC_RX_RXEN                    (1 << 0)        /* Receiver Enable */
#define SMSC78XX_MAC_RX_RXD                     (1 << 1)        /* Receiver Disabled */
#define SMSC78XX_MAC_RX_FSE                     (1 << 2)        /* VLAN Frame Size Enforcement */
#define SMSC78XX_MAC_RX_FCS_STRIP               (1 << 4)        /* FCS Stripping */
#define SMSC78XX_MAC_RX_MAX_SIZE                (0x3FFF << 16)  /* Maximum Frame Size */
#define SMSC78XX_MAC_RX_MAX_SIZE_SHIFT          (16)

/* bits in MAC Transmit Register */
#define SMSC78XX_MAC_TX_TXEN                    (1 << 0)        /* Transmitter Enable */
#define SMSC78XX_MAC_TX_TXD                     (1 << 1)        /* Transmitter Disabled */
#define SMSC78XX_MAC_TX_BFCS                    (1 << 2)        /* Bad FCS */

/* bits in Flow Control Register */
#define SMSC78XX_FLOW_FCPT                      (0xFFFF << 0)   /* Pause Time */
#define SMSC78XX_FLOW_FPF                       (1 << 28)       /* Filter Pause Frames */
#define SMSC78XX_FLOW_RX_FCEN                   (1 << 29)       /* RX Flow Control Enable */
#define SMSC78XX_FLOW_TX_FCEN                   (1 << 30)       /* TX Flow Control Enable */
#define SMSC78XX_FLOW_FORCE_FC                  (1u << 31)      /* Force Transmission of TX Flow Control Frame */

/* bits in Error Status Register */
#define SMSC78XX_ERR_STS_URERR                  (1 << 2)        /* Under Run Error */
#define SMSC78XX_ERR_STS_ALERR                  (1 << 3)        /* Alignment Error */
#define SMSC78XX_ERR_STS_ECERR                  (1 << 4)        /* Excessive Collison Error */
#define SMSC78XX_ERR_STS_RFERR                  (1 << 6)        /* Runt Frame Error */
#define SMSC78XX_ERR_STS_LRERR                  (1 << 7)        /* Large Frame Error */
#define SMSC78XX_ERR_STS_FERR                   (1 << 8)        /* FCS Error */

/* bits in MII Access Register */
#define SMSC78XX_MII_ACCESS_BUSY                (1 << 0)
#define SMSC78XX_MII_ACCESS_WRITE               (1 << 1)
#define SMSC78XX_MII_ACCESS_READ                (0 << 1)
#define SMSC78XX_MII_ACCESS_REG_ADDR            (0x1F << 6)
#define SMSC78XX_MII_ACCESS_REG_ADDR_SHIFT      (6)
#define SMSC78XX_MII_ACCESS_PHY_ADDR            (0x1F << 11)
#define SMSC78XX_MII_ACCESS_PHY_ADDR_SHIFT      (11)

/* bits in Wakeup Control and Status Register */
#define SMSC78XX_WUCSR_BCST_EN                  (1 << 0)        /* Broadcast Wakeup Enable*/
#define SMSC78XX_WUCSR_MPEN                     (1 << 1)        /* Magic Packet Enable */
#define SMSC78XX_WUCSR_WUEN                     (1 << 2)        /* Wakeup Frame Enable */
#define SMSC78XX_WUCSR_PFDA_EN                  (1 << 3)        /* Perfect DA Wakeup Enable */
#define SMSC78XX_WUCSR_BCAST_FR                 (1 << 4)        /* Broadcast Frame Received */
#define SMSC78XX_WUCSR_MPR                      (1 << 5)        /* Magic Packet Received */
#define SMSC78XX_WUCSR_WUFR                     (1 << 6)        /* Remote Wakeup Frame Received */
#define SMSC78XX_WUCSR_PFDA_FR                  (1 << 7)        /* Perfect DA Frame Received */

/* bits in Wakeup Control and Status Register 2 */
#define SMSC78XX_WUCSR2_IPV4_TCPSYN_WAKE_EN     (1 << 0)        /* IPv4 TCP SYN Wakeup Enable */
#define SMSC78XX_WUCSR2_IPV6_TCPSYN_WAKE_EN     (1 << 1)        /* IPv6 TCP SYN Wakeup Enable */
#define SMSC78XX_WUCSR2_ARP_OFFLOAD_EN          (1 << 2)        /* ARP Offload Enable */
#define SMSC78XX_WUCSR2_NS_OFFLOAD_EN           (1 << 3)        /* NS Offload Enable */
#define SMSC78XX_WUCSR2_IPV4_TCPSYN_RCD         (1 << 4)        /* IPv4 TCP SYN Packet Received */
#define SMSC78XX_WUCSR2_IPV6_TCPSYN_RCD         (1 << 5)        /* IPv6 TCP SYN Packet Received */
#define SMSC78XX_WUCSR2_ARP_RCD                 (1 << 6)        /* ARP Packet Received */
#define SMSC78XX_WUCSR2_NS_RCD                  (1 << 6)        /* NS Packet Received */
#define SMSC78XX_WUCSR2_CSUM_DISABLE            (1u << 31)      /* Checksum Disable */

/* bits in Filter Address registers */
#define SMSC78XX_ADDR_FILTX_ADDR_TYPE           (1  << 30)      /* Address Type */
#define SMSC78XX_ADDR_FILTX_ADDR_TYPE_DEST      (0  << 30)      /* Destination Address */
#define SMSC78XX_ADDR_FILTX_ADDR_TYPE_SRC       (1  << 30)      /* Source Address */
#define SMSC78XX_ADDR_FILTX_ADDR_VALID          (1u << 31)      /* Address Valid */



#define SMSC78XX_MAX_EEPROM_SIZE                (512)   /* Max. EEPROM Size supported */


/* FIFO sizes */
#define MAX_RX_FIFO_SIZE                        12288 /* 12k */
#define MAX_TX_FIFO_SIZE                        12288 /* 12k */
#define BULK_IN_SIZE                            MAX_RX_FIFO_SIZE

//---------------------------------------------------------------------------
// Workspace
//---------------------------------------------------------------------------
typedef struct
{
  usb_pipe_t      pipe_rx;
  usb_pipe_t      pipe_tx;
  net_device_t*   dev;
  mii_t           mii;
  uint32_t        phy_address;
  uint32_t        chip_id;
  uint32_t        eeprom_size;
  uint32_t        rx_buf[BULK_IN_SIZE/sizeof(uint32_t)];
} ws_t;

//---------------------------------------------------------------------------
// Put arbitrary MAC address in an array so that we may have a chance to re-
// configure it. Reason: BeagleBoard(xM) comes without a default one.
// Idea is to set <EtherUSB$MAC_Configured> to a "recyled" MAC address to
// avoid clashes between all the BBxMs with the same MAC. R.S.
//
// (Above reasoning is obsolete now that we'll use the machine ID, but let's
//  keep this logic around for compatibility - JL)
//---------------------------------------------------------------------------

static void fill_arbitraryMAC(net_device_t* dev)
{
  char *p;
  uint32_t var_mac[ETHER_ADDR_LEN];
  int i;

  if ((p = getenv("EtherUSB$MAC_Configured")) != (char *)NULL)
  {
    if (sscanf(p,"%x:%x:%x:%x:%x:%x",
               &var_mac[0],
               &var_mac[1],
               &var_mac[2],
               &var_mac[3],
               &var_mac[4],
               &var_mac[5]) == ETHER_ADDR_LEN)
    {
      for (i = 0; i < ETHER_ADDR_LEN; i++)
      {
        dev->status.mac[i] = (uint8_t)var_mac[i];
      }
    }
    else
    {
      syslog("MAC address %s is invalid\n", p);
    }
  }
}

//---------------------------------------------------------------------------
// Read/write device registers
//---------------------------------------------------------------------------
/* Little Endian 32 Bit on ARM and device so leave data unchanged */
static _kernel_oserror* reg_read(const ws_t*     ws,
                                 uint16_t        reg,
                                 const uint32_t* data)
{
  _kernel_oserror* e;

  if ((e = usb_control(ws->dev->name,
                       USB_REQ_VENDOR_READ,
                       USB_VENDOR_REQUEST_READ_REGISTER,
                       0x0000,
                       reg,
                       sizeof(uint32_t),
                       (void *)data)) != NULL)
  {
    syslog("smsc78xx reg read %s %x: %x %s", ws->dev->name, reg, e->errnum, e->errmess);
    return e;
  }
  syslog("smsc78xx reg read %s %x: %lx", ws->dev->name, reg, *data);
  return NULL;
}

static _kernel_oserror* reg_write(const ws_t* ws,
                                  uint16_t    reg,
                                  uint32_t    data)
{
  _kernel_oserror *e;
  if ((e=usb_control(ws->dev->name,
                     USB_REQ_VENDOR_WRITE,
                     USB_VENDOR_REQUEST_WRITE_REGISTER,
                     0x0000,
                     reg,
                     sizeof(uint32_t),
                     (void *)&data)) != NULL) {
    syslog("smsc78xx reg write %s %x %lx: %x %s", ws->dev->name, reg, data, e->errnum, e->errmess);
    return e;
    }
  syslog("smsc78xx reg write %s %x %lx", ws->dev->name, reg, data);
  return NULL;
}

static _kernel_oserror* reg_modify(const ws_t*   ws,
                                   uint16_t      reg,
                                   uint32_t      bic,
                                   uint32_t      eor)
{
  uint32_t     data;

  _kernel_oserror* e = reg_read(ws, reg, &data);

  if (e == NULL) e = reg_write(ws, reg, ((data & ~bic) ^ eor));

  return e;
}

static _kernel_oserror* phy_write(void*       handle,
                                  unsigned    reg,
                                  uint16_t    data);

static _kernel_oserror* phy_read(void*       handle,
                                 unsigned    reg,
                                 uint16_t*   data)

{
  const ws_t* ws = (const ws_t *) handle;
  uint32_t reg_data;
  uint32_t start_time, actual_time;
  _kernel_swi_regs regs;
  _kernel_oserror* e;

  syslog("smsc78xx phy read %s %d", ws->dev->name, reg);
  /* Access to PHY indirects through MII registers. */
  /* Check that MII is not busy (MII_ADDR) */
  if ((e = reg_read(ws, SMSC78XX_MII_ACCESS, &reg_data)) != NULL)
  {
    return e;
  }
  if ((reg_data & SMSC78XX_MII_ACCESS_BUSY) != 0)
  {
    return err_translate(ERR_MII_IN_USE);
  }

  /* Set the address, index & direction (read from PHY) by writing
     to MII_ADDR. */
  reg_data = ((ws->phy_address & 31) << SMSC78XX_MII_ACCESS_PHY_ADDR_SHIFT)
           | (((uint32_t)reg & 31) << SMSC78XX_MII_ACCESS_REG_ADDR_SHIFT)
           | SMSC78XX_MII_ACCESS_READ
           | SMSC78XX_MII_ACCESS_BUSY;
  if ((e = reg_write(ws, SMSC78XX_MII_ACCESS, reg_data)) != NULL)
  {
    return e;
  }
  /* Wait for completing by checking BUSY state */
  start_time = (uint32_t)regs.r[0];
  do
  {
    /* Get Busy info from MII (MII_ADRR). */
    if ((e = reg_read(ws, SMSC78XX_MII_ACCESS, &reg_data)) != NULL)
    {
      return e;
    }
    if ((reg_data & SMSC78XX_MII_ACCESS_BUSY) == 0)
    {
      /* Now obtain value from MII_DATA */
      if ((e = reg_read(ws, SMSC78XX_MII_DATA, &reg_data)) != NULL)
      {
        return e;
      }
      syslog("smsc78xx phy read value %x", reg_data);
      uint32_t orig_data = reg_data;
      /* The MAC doesn't support 1000-half operation. Override EXTENDED_STATUS to make sure that we don't advertise it (the common MII code doesn't really allow us to state restrictions like this in any other way) */
      if (reg == MII_EXTENDED_STATUS)
      {
        reg_data &= ~MII_EXTD_STATUS_1000BaseT_Half;
      }
      /* Yuck - we also need to patch MASTER_SLAVE_CTRL, since that's what the MII code uses for autonegotiation configuration. For safety, write back the patched value as well. */
      if ((reg == MII_MASTER_SLAVE_CONTROL) && (reg_data & MII_MS_CTRL_1000BaseT_Half))
      {
        reg_data &= ~MII_MS_CTRL_1000BaseT_Half;
        phy_write(handle, reg, reg_data);
      }
      *data = reg_data;
      if (orig_data != reg_data)
      {
        syslog("smsc78xx phy patched value %x", *data);
      }
      return NULL;
    }
    if ((e =_kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL)
    {
      return e;
    }
    actual_time = (uint32_t)regs.r[0];
  } while (actual_time - start_time < 10);
  return err_translate(ERR_TIMEOUT);
}

static _kernel_oserror* phy_write(void*       handle,
                                  unsigned    reg,
                                  uint16_t    data)
{
  const ws_t* ws = (const ws_t *) handle;
  uint32_t reg_data;
  uint32_t start_time, actual_time;
  _kernel_swi_regs regs;
  _kernel_oserror* e;

  syslog("smsc78xx phy write %s %d %x", ws->dev->name, reg, data);
  /* Check that MII is not busy */
  if ((e = reg_read(ws, SMSC78XX_MII_ACCESS, &reg_data)) != NULL)
  {
    return e;
  }
  if ((reg_data & SMSC78XX_MII_ACCESS_BUSY) != 0)
  {
    return err_translate(ERR_MII_IN_USE);
  }

  /* Prepare data */
  if ((e = reg_write(ws, SMSC78XX_MII_DATA, data)) != NULL)
  {
    return e;
  }

  /* Set the address, index & direction (write to PHY) */
  reg_data = ((ws->phy_address & 31) << SMSC78XX_MII_ACCESS_PHY_ADDR_SHIFT)
           | (((uint32_t)reg & 31) << SMSC78XX_MII_ACCESS_REG_ADDR_SHIFT)
           | SMSC78XX_MII_ACCESS_WRITE
           | SMSC78XX_MII_ACCESS_BUSY;
  if ((e = reg_write(ws, SMSC78XX_MII_ACCESS, reg_data)) != NULL)
  {
    return e;
  }
  /* Wait for completing by checking BUSY state */
  start_time = (uint32_t)regs.r[0];
  do
  {
    /* Get Busy info from MII */
    if ((e = reg_read(ws, SMSC78XX_MII_ACCESS, &reg_data)) != NULL)
    {
      return e;
    }
    if ((reg_data & SMSC78XX_MII_ACCESS_BUSY) == 0)
    {
      return NULL;
    }
    if ((e = _kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL)
    {
      return e;
    }
    actual_time = (uint32_t)regs.r[0];
  } while (actual_time - start_time < 10);
  return err_translate(ERR_TIMEOUT);
}

static _kernel_oserror* read_eeprom_byte(const ws_t* ws, int offset, uint8_t* byteout)
{
  uint32_t reg_data;
  _kernel_oserror* e;
 
  if (byteout == NULL) return NULL;
  if (e = reg_read(ws, SMSC78XX_E2P_CMD, &reg_data), e) return e;
  if (reg_data & SMSC78XX_E2P_CMD_EPC_BSY) return err_translate(ERR_TIMEOUT);
  
  if (e = reg_write(ws, SMSC78XX_E2P_CMD, (SMSC78XX_E2P_CMD_EPC_BSY | SMSC78XX_E2P_CMD_READ | offset)), e) return e;
  do
  {
     if (e = reg_read(ws, SMSC78XX_E2P_CMD, &reg_data), e) return e;
  } while (reg_data & SMSC78XX_E2P_CMD_EPC_BSY);
  
  if ((reg_data & SMSC78XX_E2P_CMD_EPC_DL) == 0) return err_translate(ERR_TIMEOUT);
  
  if (reg_read(ws, SMSC78XX_E2P_DATA, &reg_data), e) return e;
  *byteout = reg_data & SMSC78XX_E2P_DATA_MASK;
  return NULL;
}

static _kernel_oserror* read_eeprom(const ws_t* ws, uint32_t offset, uint32_t length, uint8_t *data)
{
  uint8_t reg_data;
  _kernel_oserror* e;

  if (offset + length > ws->eeprom_size)  return err_translate(ERR_EEPROM_RANGE);
  
  /* If eeprom byte 0 isn't 0xA5 then the eeprom is invalid */
  if (e = read_eeprom_byte(ws, 0, &reg_data), e) return e;
  if (reg_data != 0xA5) return err_translate(ERR_TIMEOUT);
  
  for (uint32_t i = 0; i < length; i++)
  {
    if (e = read_eeprom_byte(ws, offset + i, data + i), e) return e;
  }
  
  return NULL;
}

static bool check_mac(uint8_t *mac)
{
  int i;
  bool match = true;

  /* 00 00 00 00 00 00 */
  i = 0;
  while (i < ETHER_ADDR_LEN)
  {
    if (mac[i] != 0x00)
    {
      match = false;
      break;
    }
    i++;
  }
  if (match) return false;

  match = true;
  /* FF FF FF FF FF FF */
  i = 0;
  while (i < ETHER_ADDR_LEN)
  {
    if (mac[i] != 0xFF)
    {
      match = false;
      break;
    }
    i++;
  }
  if (match) return false;
  return true;
}

#if 0
static _kernel_oserror* obtain_autoneg_status(net_device_t* dev)
{
  ws_t* ws = dev->private;
  uint32_t reg_data, partner_abilities;
  _kernel_oserror* e;

  if ((e = reg_read(ws,SMSC78XX_MAC_CR, &reg_data)) != NULL)
  {
    return e;
  }

  switch (reg_data & SMSC78XX_MAC_CR_CFG_MASK)
  {
    case SMSC78XX_MAC_CR_CFG_1000_2:
    case SMSC78XX_MAC_CR_CFG_1000: dev->status.speed  = net_speed_1000Mb; break;
    case SMSC78XX_MAC_CR_CFG_100: dev->status.speed  = net_speed_100Mb; break;
    case SMSC78XX_MAC_CR_CFG_10: dev->status.speed  = net_speed_10Mb; break;
    default: dev->status.speed  = net_speed_unknown; break;
  }

  dev->status.duplex = (reg_data & SMSC78XX_MAC_CR_FDPX) ? net_duplex_full : net_duplex_half;

  /* In to accordance to LAN9100 description.
     Fetch link abilities (PHY_ANEG_ADV) and that of the
     bus (PHY_ANEG_LPA) */
  if ((e = phy_read(ws, MII_NWAY_ADVERT, &reg_data)) != NULL)
  {
    return e;
  }
  if ((e = phy_read(ws, MII_NWAY_PARTNER, &partner_abilities)) != NULL)
  {
    return e;
  }
  /* only that which is supported by both sides is valid */
  reg_data &= partner_abilities;
  /* Check for pause handling */
  if (dev->status.duplex == net_duplex_full)
  {
    if ((reg_data & MII_ADVERT_SYM_PAUSE) != 0)
    {
      /* Symmetric */
      ws->pause_mode = PAUSE_MODE_IN_OUT;
    }
    else if ((reg_data & MII_ADVERT_ASYM_PAUSE) != 0)
    {
      /* Asymmetric */
      ws->pause_mode = PAUSE_MODE_IN;
    }
    else
    {
      ws->pause_mode = PAUSE_MODE_NO;
    }
  }
  else
  {
    ws->pause_mode = PAUSE_MODE_BACKPRESS;
  }
  return NULL;
}
#endif

static _kernel_oserror* update_medium(net_device_t *dev)
{
  ws_t* ws = dev->private;
  _kernel_oserror *e;
  uint32_t reg_data;

  /* Cope with pause handling */
  /* Set flow (FLOW) */
  const uint32_t AFC_LO = 4*1024/512; /* 3KB low threshold (in units of 512 bytes) */
  const uint32_t AFC_HI = (MAX_RX_FIFO_SIZE/512)-1; /* 11.5KB high threshold (should really be MAX_RX_FIFO_SIZE minus max fragment length?) */
  const uint32_t PAUSE_TIME = (AFC_HI-AFC_LO)*8; /* Pause time in units of 512 bits */
  reg_data = PAUSE_TIME;
  if (dev->status.tx_pause) {
    if (e = reg_write(ws, SMSC78XX_FCT_FLOW, AFC_HI | (AFC_LO<<SMSC78XX_FCT_FLOW_THRESHOLD_OFF_SHIFT)), e) return e;
    reg_data |= SMSC78XX_FLOW_TX_FCEN;
  }
  if(dev->status.rx_pause) {
    reg_data |= SMSC78XX_FLOW_RX_FCEN;
  }
  if (e = reg_write(ws, SMSC78XX_FLOW, reg_data), e) return e;

  return NULL;
}

static _kernel_oserror* configure_link(net_device_t* dev,
                                       const net_config_t* cfg)
{
  ws_t* ws = dev->private;
  _kernel_oserror* e;
  
  /* 1000-half not supported by MAC */
  if ((cfg->speed == net_speed_1000Mb) && (cfg->duplex == net_duplex_half))
  {
    return err_translate(ERR_UNSUPPORTED);
  }

  e = mii_configure(&ws->mii, &dev->status, cfg);
  if (e)
  {
    return e;
  }
  
  /* Update medium now if autonegotiation disabled. Else, wait for the status callback. */
  if (dev->status.autoneg == net_autoneg_none)
  {
    e = update_medium(dev);
  }
  return e;
}

//---------------------------------------------------------------------------
// USB pipe handlers
//---------------------------------------------------------------------------

static void read_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;

  uint32_t* buf = ws->rx_buf;

  for (;;)
  {
    size_t size = sizeof(ws->rx_buf);

    _kernel_oserror* e = usb_read(ws->pipe_rx, buf, &size);
    if (e || size == 0) break;
    usb_start_read(ws->pipe_rx);

    if (size > 10)
    {

      int off = 0;
      size = (size+3)/4;                                /* round up to whole words */
      size_t packet_size;
      size_t next;
      for  (off = 0; off < size-2; off = next)          /* stop when only the header is left */
      {
        packet_size = buf[off] & 0x3fff;
        next = off + ((packet_size + 4 + 4 + 2 + 3)/4);   /* round up to whole words */
   //   packet_size -= 2;                             /* remove 2 bytes of padding */
        if ((buf[off] & SMSC78XX_RX_CMD_A_RED) == 0 && packet_size > 0 && packet_size <= ETHER_MAX_LEN && next <= size)
          net_receive(ws->dev, ((unsigned char*)&buf[off]) + 10, packet_size, 0);
      }
    }
  }

  UNUSED(pipe);
  usb_start_read(ws->pipe_rx);
}

static void write_packet(usb_pipe_t pipe, void* dev_pw)
{
  ws_t* ws = dev_pw;
  net_attempt_transmit(ws->dev);
  UNUSED(pipe);
}

//---------------------------------------------------------------------------
// Backend functions.
//---------------------------------------------------------------------------
static _kernel_oserror* device_configure(net_device_t* dev,
                                         const net_config_t* cfg)
{
  return configure_link(dev, (net_config_t*)cfg);
}

static _kernel_oserror* device_status(net_device_t* dev)
{
  ws_t* ws = dev->private;
  _kernel_oserror *e = mii_link_status(&ws->mii, &dev->status);

  if (!e && dev->status.autoneg == net_autoneg_reconfigure)
  {
    e = update_medium(dev);
    if (!e) dev->status.autoneg = net_autoneg_complete;
  }
  return e;
}

static _kernel_oserror* device_transmit(net_device_t*   dev,
                                        const net_tx_t* pkt)
{
  ws_t* ws = dev->private;

  /* Requires two Words at beginning TX_CMD_A and TX_CMD_B */
  size_t to_write = 2 * sizeof(uint32_t) + pkt->size;
  to_write = (to_write + 3) & ~3;

  uint32_t* prefix  = (uint32_t *)&pkt->header;
  prefix -= 2;
  /* SMSC78XX_TX_CMD_A (FCS is needed for padding) */
  prefix[0] = (pkt->size & SMSC78XX_TX_CMD_A_LEN) | SMSC78XX_TX_CMD_A_FCS;
  /* SMSC78XX_TX_CMD_B is empty */
  prefix[1] = 0;

  usb_write(ws->pipe_tx, (void*)prefix, &to_write);
  return (to_write == 0) ? err_translate(ERR_TX_BLOCKED) : NULL;
}

static _kernel_oserror* device_open(const USBServiceCall* dev,
                                    const char*           options,
                                    void**                private)
{
  syslog("smsc78xx open");
  if (!options) return err_translate(ERR_UNSUPPORTED);

  ws_t* ws = xalloc(sizeof(ws_t));
  if (!ws) return err_translate(ERR_NO_MEMORY);

  ws->pipe_rx = 0;
  ws->pipe_tx = 0;
  ws->dev     = NULL;
  /* other values initialized during device_start */

  mii_initialise(&ws->mii, phy_read, phy_write, ws);

  *private = ws;
  UNUSED(dev);
  return NULL;
}

static _kernel_oserror* device_start(net_device_t* dev, const char* options)
{
  ws_t* ws = dev->private;
  uint32_t reg_data;
  int i;
  uint32_t start_time, actual_time;
  _kernel_swi_regs regs;
  _kernel_oserror* e;

  ws->dev = dev;
  syslog("smsc78xx start");

  /* Reset */
  /* Set according Bit inside HW_CFG */
  if ((e = reg_read(ws, SMSC78XX_HW_CFG, &reg_data)) != NULL)
  {
    return e;
  }
  reg_data |= SMSC78XX_HW_CFG_LRST;
  if ((e = reg_write(ws, SMSC78XX_HW_CFG, reg_data)) != NULL)
  {
    return e;
  }
  /* Wait for reset finished. */
  if ((e = _kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL)
  {
    return e;
  }
  start_time = (uint32_t)regs.r[0];
  do
  {
    /* Check whether Reset Bit still set */
    if ((e = reg_read(ws, SMSC78XX_HW_CFG, &reg_data)) != NULL)
    {
      return e;
    }
    if ((e = _kernel_swi(OS_ReadMonotonicTime, &regs, &regs)) != NULL)
    {
      return e;
    }
    actual_time = (uint32_t)regs.r[0];
  } while (((reg_data & SMSC78XX_HW_CFG_LRST) != 0) && (actual_time - start_time < 100));
  if ((reg_data & SMSC78XX_HW_CFG_LRST) != 0)
  {
    return err_translate(ERR_TIMEOUT);
  }

  /* Determine chip type (ID_REV) to cope with certain special properties */
  syslog("Chip type");
  if ((e = reg_read(ws, SMSC78XX_ID_REV, &reg_data)) != NULL)
  {
    return e;
  }
  ws->chip_id = reg_data >> SMSC78XX_ID_REV_CHIP_ID_SHIFT;
  /* ??? EEPROM existence check still missing */
  ws->eeprom_size = SMSC78XX_MAX_EEPROM_SIZE;

  dev->status.broadcast   = 1;
  dev->status.multicast   = 1;
  dev->status.promiscuous = 0;

  /* MAC handling */
  syslog("mac handling");
  /* Obtain address from EEPROM */
  if (e = read_eeprom(ws, 1,  /* Starts at Position 1 (base 0) */
                       ETHER_ADDR_LEN,
                       dev->status.mac), e)
  {
    /* Default */
    for (i = 0; i < ETHER_ADDR_LEN; i++) dev->status.mac[i] = 0xFF;
    
    /* If MAC has been set by system variable, prefer that over the last-used
       MAC. This allows machines with EtherUSB in ROM to use a custom MAC by
       setting the variable and then reiniting the module. */
    fill_arbitraryMAC(dev);
  }
  /* Flush log */
  syslog_flush();
  
  if (!check_mac(dev->status.mac))
  {
    /* If not given try to keep last MAC set
       Only valid if there was no reset. */
    /* Low (ADRRL) 4 Bytes */
    if ((e = reg_read(ws, SMSC78XX_RX_ADDRL, &reg_data)) != NULL)
    {
      return e;
    }
    dev->status.mac[0] = (uint8_t)(reg_data >> 0);
    dev->status.mac[1] = (uint8_t)(reg_data >> 8);
    dev->status.mac[2] = (uint8_t)(reg_data >> 16);
    dev->status.mac[3] = (uint8_t)(reg_data >> 24);
    /* High (ADRRH) 2 Bytes */
    if ((e = reg_read(ws, SMSC78XX_RX_ADDRH, &reg_data)) != NULL)
    {
      return e;
    }
    dev->status.mac[4] = (uint8_t)(reg_data >> 0);
    dev->status.mac[5] = (uint8_t)(reg_data >> 8);
  }
  if (!check_mac(dev->status.mac))
  {
    /* Try the machines configured MAC (e.g. for builtin SMSC on Raspberry Pi) */
    net_machine_mac(dev->status.mac);
  }
  if (!check_mac(dev->status.mac))
  {
    /* Try to construct a MAC from machine ID, or failing that, a hardcoded
       default */
    net_default_mac(dev->dib.dib_unit, dev->status.mac);
  }
  /* Set MAC */
  /* Low (ADRRL) 4 Bytes */
  reg_data = ((uint32_t)(dev->status.mac[3]) << 24)
           | ((uint32_t)(dev->status.mac[2]) << 16)
           | ((uint32_t)(dev->status.mac[1]) <<  8)
           | ((uint32_t)(dev->status.mac[0]) <<  0);

  if ((e = reg_write(ws, SMSC78XX_RX_ADDRL, reg_data)) != NULL)
  {
    return e;
  }
  /* Also write it into first filter slot (reserved for own MAC) */
  if ((e = reg_write(ws, SMSC78XX_ADDR_FILTX + 4, reg_data)) != NULL)
  {
    return e;
  }
  /* High (ADRRH) 2 Bytes */
  reg_data = ((uint32_t)(dev->status.mac[5]) << 8)
           | ((uint32_t)(dev->status.mac[4]) << 0);

  if ((e = reg_write(ws, SMSC78XX_RX_ADDRH, reg_data)) != NULL)
  {
    return e;
  }
  /* Also write it into first filter slot (and activate filter) */
  reg_data |= SMSC78XX_ADDR_FILTX_ADDR_VALID;
  if ((e = reg_write(ws, SMSC78XX_ADDR_FILTX, reg_data)) != NULL)
  {
    return e;
  }
  /* Flush log */
  syslog_flush();

  /* Various setups */
  syslog("set up");
  /* Set to operational mode. */


  /* Flush log */
  syslog_flush();
  syslog("burst");

  /* Set Burst cap (BURST_CAP) */
  if (dev->speed == USB_SPEED_HI)
  {
    if (e = reg_write(ws, SMSC78XX_BURST_CAP, (BULK_IN_SIZE - 4096)/512), e != NULL) return e;
  }
  else
  {
    if (e = reg_write(ws, SMSC78XX_BURST_CAP, (BULK_IN_SIZE - 4096)/64), e != NULL) return e;
  }

  /* burst delay */
  if (e = reg_write(ws,SMSC78XX_BULK_IN_DLY, 0x800), e != NULL)  return e;

  /* Set multiple packets per frame, NAK empty input buffer, Burst cap enable */
  #define HW_CFG_BITS (SMSC78XX_HW_CFG_MEF)
  if (e = reg_modify(ws, SMSC78XX_HW_CFG, HW_CFG_BITS, HW_CFG_BITS ), e != NULL) return e;
  #define USB_CFG0_BITS (SMSC78XX_USB_CFG0_BIR | SMSC78XX_USB_CFG0_BCE)
  if (e = reg_modify(ws, SMSC78XX_USB_CFG0, USB_CFG0_BITS, USB_CFG0_BITS ), e != NULL) return e;

  syslog("set up 2");
  /* Clear all Information inside Interrupt Status (INT_STS) */
  if ((e = reg_write(ws, SMSC78XX_INT_STS, 0xFFFFFFFF)) != NULL)
  {
    return e;
  }
  /* We don't use the Interrupt Endpoint inside EtherUSB.
     So no need to set Interrupt Endpoint Control */
  /* Flush log */
  syslog_flush();
  
  /* Enable auto speed & duplex detection in MAC */
  #define MAC_CR_BITS (SMSC78XX_MAC_CR_ASD | SMSC78XX_MAC_CR_ADD)
  if (e = reg_modify(ws, SMSC78XX_MAC_CR, MAC_CR_BITS, MAC_CR_BITS), e != NULL) return e;

  /* Enable TX */
  syslog("enable TX");
  /* Now enable TX. */
  if ((e = reg_read(ws, SMSC78XX_MAC_TX, &reg_data)) != NULL)
  {
    return e;
  }
  reg_data |= SMSC78XX_MAC_TX_TXEN;
  if ((e = reg_write(ws, SMSC78XX_MAC_TX, reg_data)) != NULL)
  {
    return e;
  }
  /* enable TX FIFO Control */
  if ((e = reg_read(ws, SMSC78XX_FCT_TX_CTL, &reg_data)) != NULL)
  {
    return e;
  }
  reg_data |= SMSC78XX_FCT_TX_CTL_EN;
  if ((e = reg_write(ws, SMSC78XX_FCT_TX_CTL, reg_data)) != NULL)
  {
    return e;
  }
  /* Flush log */
  syslog_flush();

  /* Enable RX */
  syslog("enable RX");
  /* Now enable RX. */
  if ((e = reg_read(ws, SMSC78XX_MAC_RX, &reg_data)) != NULL)
  {
    return e;
  }
  reg_data |= SMSC78XX_MAC_RX_RXEN;
  if ((e = reg_write(ws, SMSC78XX_MAC_RX, reg_data)) != NULL)
  {
    return e;
  }
  /* enable RX FIFO Control */
  if ((e = reg_read(ws, SMSC78XX_FCT_RX_CTL, &reg_data)) != NULL)
  {
    return e;
  }
  reg_data |= SMSC78XX_FCT_RX_CTL_EN;
  if ((e = reg_write(ws, SMSC78XX_FCT_RX_CTL, reg_data)) != NULL)
  {
    return e;
  }
  /* Flush log */
  syslog_flush();

  /* Enable LEDs */
  syslog("LEDs");
  if ((e = reg_modify(ws, SMSC78XX_HW_CFG, SMSC78XX_HW_CFG_LED0_EN | SMSC78XX_HW_CFG_LED1_EN, SMSC78XX_HW_CFG_LED0_EN | SMSC78XX_HW_CFG_LED1_EN)) != NULL)
  {
    return e;
  }

  /* Multicast and Broadcast and Destination address Perfect Filter pass */
  reg_data = SMSC78XX_RFE_CTL_AM | SMSC78XX_RFE_CTL_AB | SMSC78XX_RFE_CTL_DPF;
  if ((e = reg_write(ws, SMSC78XX_RFE_CTL, reg_data)) != NULL)
  {
    return e;
  }
  /* Flush log */
  syslog_flush();
  /* Initialise PHY (HW_CFG) */
  syslog("set up PHY");
  /* internal PHY only */
  ws->phy_address = 1;

  /* The chip default configuration appears to be wrong (for the Pi 3B+, at least)
     Reconfigure so that LED0 (amber) is 10/100 activity and LED1 (green) is 1000 activity
   */
  uint16_t phy_data;
  if ((e = phy_read(ws, 29, &phy_data)) != NULL)
  {
    return e;
  }
  if (phy_data == 0x8021) /* Defaults? */
  {
    phy_data = 0x8016;
    if ((e = phy_write(ws, 29, phy_data)) != NULL)
    {
      return e;
    }
  } 

  /* Link setup and Status determined by EtherUSB after this procedure */

  /* Flush log */
  syslog_flush();

  /* RISC OS USB part */
  syslog("RISC OS USB");

  if (!e) e = usb_open(dev->name,
                       &ws->pipe_rx,
                       USBRead,
                       &read_packet,
                       ws,
                       "Devices#bulk;size" STR(BULK_IN_SIZE) ":$.%s",
                       dev->name);

  if (!e) e = usb_open(dev->name,
                       &ws->pipe_tx,
                       USBWrite,
                       &write_packet,
                       ws,
                       "Devices#bulk;size" STR(MAX_TX_FIFO_SIZE) ":$.%s",
                       dev->name);

  /* Reset PHY and update abilities structure */
  if (!e) e = mii_reset(&ws->mii);
  if (!e) e = mii_abilities(&ws->mii, &dev->abilities);
  dev->abilities.multicast   = 1;
  dev->abilities.promiscuous = 0; /* ??? still to be implemented */
  dev->abilities.tx_rx_loopback = 0; /* ??? SMSC chips can. But where to configure. */
  dev->abilities.rx_pause = dev->abilities.tx_pause = dev->abilities.symmetric_pause = 1;

  if (e)
  {
    usb_close(&ws->pipe_tx);
    usb_close(&ws->pipe_rx);
    return e;
  }

  /* Request initial packet. */
  read_packet(ws->pipe_rx, ws);

  dev->status.ok = true;
  UNUSED(options);
  return NULL;
}

static _kernel_oserror* device_stop(net_device_t* dev)
{
  ws_t* ws = dev->private;
  uint32_t reg_data;
  _kernel_oserror* e;

  syslog("smsc78xx stop");

  if (!dev->gone)
  {
    /* Stop TX */
    if ((e = reg_read(ws, SMSC78XX_MAC_TX, &reg_data)) != NULL)
    {
      return e;
    }
    reg_data &= ~SMSC78XX_MAC_TX_TXEN;
    if ((e = reg_write(ws, SMSC78XX_MAC_TX, reg_data)) != NULL)
    {
      return e;
    }
    /* Stop RX */
    if ((e = reg_read(ws, SMSC78XX_MAC_RX, &reg_data)) != NULL)
    {
      return e;
    }
    reg_data &= ~SMSC78XX_MAC_RX_RXEN;
    if ((e = reg_write(ws, SMSC78XX_MAC_RX, reg_data)) != NULL)
    {
      return e;
    }
  }
  /* RISC OS USB part */
  usb_close(&ws->pipe_tx);
  usb_close(&ws->pipe_rx);
  return NULL;
}

static _kernel_oserror* device_close(void** private)
{
  syslog("smsc78xx close");
  xfree(*private);
  return NULL;
}

static void device_info(const net_device_t* dev, bool verbose)
{
  ws_t* ws = dev->private;
  uint32_t info[0xbc/4];
  _kernel_oserror *e;
  
  /* Follow the lead of EtherK and only output non-zero stats, and only in verbose mode */
  if (!verbose)
  {
    return;
  }

  if ((e=usb_control(ws->dev->name,
                     USB_REQ_VENDOR_READ,
                     USB_VENDOR_REQUEST_GET_STATS,
                     0,
                     0,
                     sizeof(info),
                     (void*)info)) != NULL)
  {
    puts(e->errmess);
    putchar('\n');
    return;
  }
  
  char token[8];
  char fmt[20];
  sprintf(fmt, "%%-%us : %%d\n", strlen(msg_translate("S78Len")));
  for(int i=0;i<47;i++)
  {
    if (info[i])
    {
      sprintf(token,"S78I%02d",i);
      printf(fmt,msg_translate(token),info[i]);
    }
  }
}

/* Provides the driver functions for this kind of device.
   Must be declared here because all functions are known at here. */
static const net_backend_t s_backend = {
  .name        = N_SMSC78XX,
  .description = "DescSMC78",
  .open        = device_open,
  .start       = device_start,
  .stop        = device_stop,
  .close       = device_close,
  .transmit    = device_transmit,
  .info        = device_info,
  .config      = device_configure,
  .status      = device_status
};

/* Registers device driver to general driver */
_kernel_oserror* smsc78xx_register(void)
{
  syslog("smsc78xx register");
  return net_register_backend(&s_backend);
}
