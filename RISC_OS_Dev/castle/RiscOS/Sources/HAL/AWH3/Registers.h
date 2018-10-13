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
#ifndef H_REGISTERS_H
#define H_REGISTERS_H

#pragma force_top_level
#pragma include_only_once

#define CPUS_RST_CTRL_REG                        (0x0)
#define CPU0_RST_CTRL                            (0x40)
#define CPU0_CTRL_REG                            (0x44)
#define CPU0_STATUS_REG                          (0x48)
#define CPU1_RST_CTRL                            (0x80)
#define CPU1_CTRL_REG                            (0x84)
#define CPU1_STATUS_REG                          (0x88)
#define CPU2_RST_CTRL                            (0xc0)
#define CPU2_CTRL_REG                            (0xc4)
#define CPU2_STATUS_REG                          (0xc8)
#define CPU3_RST_CTRL                            (0x100)
#define CPU3_CTRL_REG                            (0x104)
#define CPU3_STATUS_REG                          (0x108)
#define CPU_SYS_RST_REG                          (0x140)
#define CPU_CLK_GATING_REG                       (0x144)
#define GENER_CTRL_REG                           (0x184)
#define SUP_STAN_FLAG_REG                        (0x1a0)
#define CNT64_CTRL_REG                           (0x280)
#define CNT64_LOW_REG                            (0x284)
#define CNT64_HIGH_REG                           (0x288)
#define CPUS_RESET                               (1)
#define CPU_CORE_REST                            (2)
#define CPU_RESET                                (1)
#define CPU_CP15_WRITE_DISABLE                   (1)
#define STANDBYWFI                               (4)
#define STANDBYWFE                               (2)
#define SMP_AMP                                  (1)
#define CPU_SYS_RST                              (1)
#define L2_CLK_GATING                            (256)
#define CPU_CLK_GATING                           (8)
#define CFGDISABLE                               (256)
#define ACINACTM                                 (64)
#define L2_RST                                   (32)
#define L2_RST_DISABLE                           (16)
#define L1_RST_DISABLE                           (15)
#define SUP_STANDBY_FLAG                         (0xffff0000)
#define SUP_STANDBY_FLAG_DATA                    (0xffff)
#define O_HCREVISION                             (0x400)
#define O_HCCONTROL                              (0x404)
#define O_HCCOMMANDSTATUS                        (0x408)
#define O_HCINTERRUPTSTATUS                      (0x40c)
#define O_HCINTERRUPTENABLE                      (0x410)
#define O_HCINTERRUPTDISABLE                     (0x414)
#define O_HCHCCA                                 (0x418)
#define O_HCPERIODCURRENTED                      (0x41c)
#define O_HCCONTROLHEADED                        (0x420)
#define O_HCCONTROLCURRENTED                     (0x424)
#define O_HCBULKHEADED                           (0x428)
#define O_HCBULKCURRENTED                        (0x42c)
#define O_HCDONEHEAD                             (0x430)
#define O_HCFMINTERVAL                           (0x434)
#define O_HCFMREMAINING                          (0x438)
#define O_HCFMNUMBER                             (0x43c)
#define O_HCLSTHRESHOLD                          (0x444)
#define O_HCRHDESCRIPTORA                        (0x448)
#define O_HCRHDESCRIPTORB                        (0x44c)
#define O_HCRHSTATUS                             (0x450)
#define O_HCRHPORTSTATUS                         (0x454)
#define USBPHY_CFG_REG                           (0xcc)
#define AHB2_CLK_CFG                             (0x5c)
#define BUS_CLK_GATING_REG0                      (0x60)
#define BUS_SOFT_RST_REG0                        (0x2c0)
#endif
