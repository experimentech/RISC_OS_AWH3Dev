// This source code in this file is licensed to You by Castle Technology
// Limited ("Castle") and its licensors on contractual terms and conditions
// ("Licence") which entitle you freely to modify and/or to distribute this
// source code subject to Your compliance with the terms of the Licence.
//
// This source code has been made available to You without any warranties
// whatsoever. Consequently, Your use, modification and distribution of this
// source code is entirely at Your own risk and neither Castle, its licensors
// nor any other person who has contributed to this source code shall be
// liable to You for any loss or damage which You may suffer as a result of
// Your use, modification or distribution of this source code.
//
// Full details of Your rights and obligations are set out in the Licence.
// You should have received a copy of the Licence with this source code file.
// If You have not received a copy, the text of the Licence is available
// online at www.castle-technology.co.uk/riscosbaselicence.htm
//

#ifndef __WS_H__
#define __WS_H__
#include "hdmi_tx.h"

#define IPU_IDMAC_INFO_T
typedef struct ipu_idmac_info_t{
    uint32_t channel;
    uint32_t addr0;
    uint32_t addr1;
    uint32_t width;
    uint32_t height;
    uint32_t npb;
    uint32_t pixel_format;
    uint32_t sl;                // sl for interleaved mode, sly for non-interleaved mode
    uint32_t u_offset;          //uoffset
    uint32_t bpp;
    uint32_t so;
    uint32_t ilo;
    uint32_t bm;
    uint32_t rot;
    uint32_t hf;
    uint32_t vf;
} ipu_idmac_info_t;

typedef struct  ips_dev_panel{
    char panel_name[32];
    uint32_t panel_id;
    uint32_t panel_type;
    uint32_t colorimetry;
    uint32_t refresh_rate;
    uint32_t width;
    uint32_t height;
    uint32_t pixel_clock;
    uint32_t hsync_start_width;
    uint32_t hsync_width;
    uint32_t hsync_end_width;
    uint32_t vsync_start_width;
    uint32_t vsync_width;
    uint32_t vsync_end_width;
    uint32_t delay_h2v;
    uint32_t interlaced;
    uint32_t clk_sel;
    uint32_t clk_pol;
    uint32_t hsync_pol;
    uint32_t vsync_pol;
    uint32_t drdy_pol;
    uint32_t data_pol;
     int32_t(*panel_init) (int32_t * arg);
     int32_t(*panel_deinit) (void);
}xx;

// NOTE.. all items at start workspace are duplicated in h.ws in the StaticWS structure  .. KEEP THESE IN SYNC!!
typedef struct StaticWS {
	volatile unsigned  ScrInit;       // Phys addr of screen start
	volatile unsigned* CCM_Base;      // CCM base address
	volatile unsigned* IOMUXC_Base;   // IOMUXC base address
	volatile unsigned* HDMI_Log;      // HDMI base address
	volatile unsigned* SRC_Log;       // System Reset Cntrl logical address
	volatile unsigned* IPU1_Log;      // IPU1 logical address
	volatile unsigned* IPU2_Log;      // IPU2 logical address
	volatile unsigned* CCMAn_Log;     // CCM_Analog logical address
        volatile hdmi_data_info_s  myHDMI_infos;
        volatile hdmi_vmode_s      myHDMI_vmode_infos;
        uint32_t ml2bpp;
        volatile ipu_idmac_info_t idmac_info;
        volatile struct ips_dev_panel myHDMI_dev_panel;
}StaticWS_t;

	__global_reg(6)  StaticWS_t *sb;                 


#endif
