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
/* Created by Hdr2H.  Do not edit.*/
#ifndef H_USB_H
#define H_USB_H

#pragma force_top_level
#pragma include_only_once

#define USB_HCI1_Offset                          (0x0)
#define USB_HCI2_Offset                          (0x1000)
#define USB_HCI3_Offset                          (0x2000)
#define USB_OTG_HCI_Offset                       (0x1000)
#define OHCI_BASE                                (0x400)
#define EHCI_BASE                                (0x0)
#define OHCI_HCREVISION                          (0x0)
#define OHCI_HCCONTROL                           (0x4)
#define OHCI_HCCOMANDSTATUS                      (0x8)
#define OHCI_HCINTERRUPTSTATUS                   (0xc)
#define OHCI_HCINTERRUPTENABLE                   (0x10)
#define OHCI_HCINTERRUPTDISABLE                  (0x14)
#define OHCI_HCHCCA                              (0x18)
#define OHCI_HCPERIODCURRENTED                   (0x1c)
#define OHCI_HCCONTROLHEADED                     (0x20)
#define OHCI_HCCONTROLCURRENTED                  (0x24)
#define OHCI_HCBULKHEADED                        (0x28)
#define OHCI_HCBULKCURRENTED                     (0x2c)
#define OHCI_HCDONEHEAD                          (0x30)
#define OHCI_HCFMINTERVAL                        (0x34)
#define OHCI_HCFMREMAINING                       (0x38)
#define OHCI_HCFMNUMBER                          (0x3c)
#define OHCI_HCPERIODICSTART                     (0x40)
#define OHCI_HCLSTHRESHOLD                       (0x44)
#define OHCI_HCRHDESCRIPTORA                     (0x48)
#define OHCI_HCRHDESCRIPTORB                     (0x4c)
#define OHCI_HCRHSTATUS                          (0x50)
#define OHCI_HCRHPORTSTATUS                      (0x54)
#define EHCI_HCCAPBASE                           (0x0)
#define EHCI_HCSPARAMS                           (0x4)
#define EHCI_HCCPARAMS                           (0x8)
#define EHCI_HCSPPORTROUTE                       (0xc)
#define EHCI_USBCMD                              (0x10)
#define EHCI_USBSTS                              (0x14)
#define EHCI_USBINTR                             (0x18)
#define EHCI_FRINDEX                             (0x1c)
#define EHCI_CTRLDSSEGMENT                       (0x20)
#define EHCI_PERIODICLISTBASE                    (0x24)
#define EHCI_ASYNCLISTADDR                       (0x28)
#define EHCI_CONFIGFLAG                          (0x50)
#define EHCI_PORTSC_0                            (0x54)
#define OTG_BASE                                 (0x400)
#define OTG_REVISION                             (0x0)
#define OTG_SYSCONFIG                            (0x4)
#define OTG_SYSSTATUS                            (0x8)
#define OTG_INTERFSEL                            (0xc)
#define OTG_SIMENABLE                            (0x10)
#define OTG_FORCESTDBY                           (0x14)
#define OTG_BIGENDIAN                            (0x18)
#define HCI_ICR                                  (0x800)
#define HSIC_STATUS                              (0x804)
#define USB_CONNECT_DETECT                       (1 << 17)
#define USB_CONNECT_INT                          (1 << 16)
#define USB_AHB_INCR16_EN                        (1 << 11)
#define USB_AHB_INCR8_EN                         (1 << 10)
#define USB_AHB_INCR4_BURST_EN                   (1 << 9)
#define USB_AHB_INCRX_ALIGN_EN                   (1 << 8)
#define USB_ULPI_BYPASS_EN                       (1 << 0)
#endif
