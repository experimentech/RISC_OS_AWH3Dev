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
/*
 * Copyright (c) 2010-2012, Freescale Semiconductor, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * o Redistributions of source code must retain the above copyright notice, this list
 *   of conditions and the following disclaimer.
 *
 * o Redistributions in binary form must reproduce the above copyright notice, this
 *   list of conditions and the following disclaimer in the documentation and/or
 *   other materials provided with the distribution.
 *
 * o Neither the name of Freescale Semiconductor, Inc. nor the names of its
 *   contributors may be used to endorse or promote products derived from this
 *   software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "sdk.h"
#include "hdmi_tx.h"
#include "regshdmi.h"
#include "regsiomuxc.h"

////////////////////////////////////////////////////////////////////////////////
// CODE
////////////////////////////////////////////////////////////////////////////////


// defines which channel is HDMI source
// 0,1,2,3=ipu1di0,di1,ipu2di0,di1
void hdmi_config_input_source(uint32_t mux_value)
{
 BITWRITE(IOMUXC_GPR3,HDMI_MUX_CTL,(unsigned) mux_value);
//    HW_IOMUXC_GPR3.B.HDMI_MUX_CTL = (unsigned) mux_value;
 printf("HDMI IPU channel src:%x\n",mux_value);
}

void hdmi_video_sample(hdmi_data_info_s *hdmi_instance)
{
    int color_format = 0;
    if (hdmi_instance->enc_in_format == eRGB) {
        if (hdmi_instance->enc_color_depth == 8) {
            color_format = 0x01;
        } else if (hdmi_instance->enc_color_depth == 10) {
            color_format = 0x03;
        } else if (hdmi_instance->enc_color_depth == 12) {
            color_format = 0x05;
        } else if (hdmi_instance->enc_color_depth == 16) {
            color_format = 0x07;
        } else {
            printf("Invalid color depth %d!!", hdmi_instance->enc_color_depth);
            return;
        }
    } else if (hdmi_instance->enc_in_format == eYCC444) {
        if (hdmi_instance->enc_color_depth == 8) {
            color_format = 0x09;
        } else if (hdmi_instance->enc_color_depth == 10) {
            color_format = 0x0B;
        } else if (hdmi_instance->enc_color_depth == 12) {
            color_format = 0x0D;
        } else if (hdmi_instance->enc_color_depth == 16) {
            color_format = 0x0F;
        } else {
            printf("Invalid color depth %d!!", hdmi_instance->enc_color_depth);
            return;
        }
    } else if (hdmi_instance->enc_in_format == eYCC422) {
        if (hdmi_instance->enc_color_depth == 8) {
            color_format = 0x16;
        } else if (hdmi_instance->enc_color_depth == 10) {
            color_format = 0x14;
        } else if (hdmi_instance->enc_color_depth == 12) {
            color_format = 0x12;
        } else {
            printf("Invalid color depth %d!!", hdmi_instance->enc_color_depth);
            return;
        }
    }
    BITWRITE(HDMI_TX_INVID0,VIDEO_MAPPING,color_format);
//    HW_HDMI_TX_INVID0.B.VIDEO_MAPPING = color_format;
    BITWRITE(HDMI_TX_INVID0,INTERNAL_DE_GENERATOR,0);
//    HW_HDMI_TX_INVID0.B.INTERNAL_DE_GENERATOR = 0;

    /*enable tx stuffing, when DE is inactive, fix the output data to 0 */
    HW_HDMI_TX_INSTUFFING.U = 0x7;
    HW_HDMI_TX_GYDATA0.U = 0x0;
    HW_HDMI_TX_GYDATA1.U = 0x0;
    HW_HDMI_TX_RCRDATA0.U = 0x0;
    HW_HDMI_TX_RCRDATA1.U = 0x0;
    HW_HDMI_TX_BCBDATA0.U = 0x0;
    HW_HDMI_TX_BCBDATA1.U = 0x0;
  printf("*****vid sample setup\n");
}

void update_csc_coeffs(hdmi_data_info_s* hdmi_instance)
{
    uint16_t csc_coeff[3][4];
    uint32_t csc_scale = 1;

    /* default initialization (mainly to workaround
     * uninitialized warning during build) */
    csc_coeff[0][0] = 0x2000;
    csc_coeff[0][1] = 0x0000;
    csc_coeff[0][2] = 0x0000;
    csc_coeff[0][3] = 0x0000;

    csc_coeff[1][0] = 0x0000;
    csc_coeff[1][1] = 0x2000;
    csc_coeff[1][2] = 0x0000;
    csc_coeff[1][3] = 0x0000;

    csc_coeff[2][0] = 0x0000;
    csc_coeff[2][1] = 0x0000;
    csc_coeff[2][2] = 0x2000;
    csc_coeff[2][3] = 0x0000;

    csc_scale = 1;

    if (isColorSpaceConversion(hdmi_instance) == TRUE)  // csc needed
    {
        if (hdmi_instance->enc_out_format == eRGB) {
            if (hdmi_instance->colorimetry == eITU601) {
                csc_coeff[0][0] = 0x2000;
                csc_coeff[0][1] = 0x6926;
                csc_coeff[0][2] = 0x74fd;
                csc_coeff[0][3] = 0x010e;

                csc_coeff[1][0] = 0x2000;
                csc_coeff[1][1] = 0x2cdd;
                csc_coeff[1][2] = 0x0000;
                csc_coeff[1][3] = 0x7e9a;

                csc_coeff[2][0] = 0x2000;
                csc_coeff[2][1] = 0x0000;
                csc_coeff[2][2] = 0x38b4;
                csc_coeff[2][3] = 0x7e3b;

                csc_scale = 1;
            } else if (hdmi_instance->colorimetry == eITU709) {
                csc_coeff[0][0] = 0x2000;
                csc_coeff[0][1] = 0x7106;
                csc_coeff[0][2] = 0x7a02;
                csc_coeff[0][3] = 0x00a7;

                csc_coeff[1][0] = 0x2000;
                csc_coeff[1][1] = 0x3264;
                csc_coeff[1][2] = 0x0000;
                csc_coeff[1][3] = 0x7e6d;

                csc_coeff[2][0] = 0x2000;
                csc_coeff[2][1] = 0x0000;
                csc_coeff[2][2] = 0x3b61;
                csc_coeff[2][3] = 0x7e25;

                csc_scale = 1;
            }
        } else if (hdmi_instance->enc_in_format == eRGB) {
            if (hdmi_instance->colorimetry == eITU601) {
                csc_coeff[0][0] = 0x2591;
                csc_coeff[0][1] = 0x1322;
                csc_coeff[0][2] = 0x074b;
                csc_coeff[0][3] = 0x0000;

                csc_coeff[1][0] = 0x6535;
                csc_coeff[1][1] = 0x2000;
                csc_coeff[1][2] = 0x7acc;
                csc_coeff[1][3] = 0x0200;

                csc_coeff[1][0] = 0x6acd;
                csc_coeff[1][1] = 0x7534;
                csc_coeff[1][2] = 0x2000;
                csc_coeff[1][3] = 0x0200;

                csc_scale = 1;
            } else if (hdmi_instance->colorimetry == eITU709) {
                csc_coeff[0][0] = 0x2dc5;
                csc_coeff[0][1] = 0x0d9b;
                csc_coeff[0][2] = 0x049e;
                csc_coeff[0][3] = 0x0000;

                csc_coeff[1][0] = 0x63f0;
                csc_coeff[1][1] = 0x2000;
                csc_coeff[1][2] = 0x7d11;
                csc_coeff[1][3] = 0x0200;

                csc_coeff[2][0] = 0x6756;
                csc_coeff[2][1] = 0x78ab;
                csc_coeff[2][2] = 0x2000;
                csc_coeff[2][3] = 0x0200;

                csc_scale = 1;
            }
        }
    }

    /*update csc parameters in hdmi csc registers */
    HW_HDMI_CSC_COEF_A1_LSB.U = (uint8_t) (csc_coeff[0][0] & 0xFF);
    HW_HDMI_CSC_COEF_A1_MSB.U = (uint8_t) (csc_coeff[0][0] >> 8);
    HW_HDMI_CSC_COEF_A2_LSB.U = (uint8_t) (csc_coeff[0][1] & 0xFF);
    HW_HDMI_CSC_COEF_A2_MSB.U = (uint8_t) (csc_coeff[0][1] >> 8);
    HW_HDMI_CSC_COEF_A3_LSB.U = (uint8_t) (csc_coeff[0][2] & 0xFF);
    HW_HDMI_CSC_COEF_A3_MSB.U = (uint8_t) (csc_coeff[0][2] >> 8);
    HW_HDMI_CSC_COEF_A4_LSB.U = (uint8_t) (csc_coeff[0][3] & 0xFF);
    HW_HDMI_CSC_COEF_A4_MSB.U = (uint8_t) (csc_coeff[0][3] >> 8);

    HW_HDMI_CSC_COEF_B1_LSB.U = (uint8_t) (csc_coeff[1][0] & 0xFF);
    HW_HDMI_CSC_COEF_B1_MSB.U = (uint8_t) (csc_coeff[1][0] >> 8);
    HW_HDMI_CSC_COEF_B2_LSB.U = (uint8_t) (csc_coeff[1][1] & 0xFF);
    HW_HDMI_CSC_COEF_B2_MSB.U = (uint8_t) (csc_coeff[1][1] >> 8);
    HW_HDMI_CSC_COEF_B3_LSB.U = (uint8_t) (csc_coeff[1][2] & 0xFF);
    HW_HDMI_CSC_COEF_B3_MSB.U = (uint8_t) (csc_coeff[1][2] >> 8);
    HW_HDMI_CSC_COEF_B4_LSB.U = (uint8_t) (csc_coeff[1][3] & 0xFF);
    HW_HDMI_CSC_COEF_B4_MSB.U = (uint8_t) (csc_coeff[1][3] >> 8);

    HW_HDMI_CSC_COEF_C1_LSB.U = (uint8_t) (csc_coeff[2][0] & 0xFF);
    HW_HDMI_CSC_COEF_C1_MSB.U = (uint8_t) (csc_coeff[2][0] >> 8);
    HW_HDMI_CSC_COEF_C2_LSB.U = (uint8_t) (csc_coeff[2][1] & 0xFF);
    HW_HDMI_CSC_COEF_C2_MSB.U = (uint8_t) (csc_coeff[2][1] >> 8);
    HW_HDMI_CSC_COEF_C3_LSB.U = (uint8_t) (csc_coeff[2][2] & 0xFF);
    HW_HDMI_CSC_COEF_C3_MSB.U = (uint8_t) (csc_coeff[2][2] >> 8);
    HW_HDMI_CSC_COEF_C4_LSB.U = (uint8_t) (csc_coeff[2][3] & 0xFF);
    HW_HDMI_CSC_COEF_C4_MSB.U = (uint8_t) (csc_coeff[2][3] >> 8);

    BITWRITE(HDMI_CSC_SCALE,CSC_SCALE,csc_scale);
//    HW_HDMI_CSC_SCALE.B.CSC_SCALE = csc_scale;
 printf("*****CSC coeffs setup\n");
}

void hdmi_video_csc(hdmi_data_info_s *hdmi_instance)
{
    int color_depth = 0;
    int interpolation = 0;
    int decimation = 0;

    /*YCC422 interpolation to 444 mode */
    if (isColorSpaceInterpolation(hdmi_instance) == TRUE) {
        interpolation = 0x01;
    } else if (isColorSpaceDecimation(hdmi_instance) == TRUE) {
        decimation = 0x01;
    }

    if (hdmi_instance->enc_color_depth == 8) {
        color_depth = 4;
    } else if (hdmi_instance->enc_color_depth == 10) {
        color_depth = 5;
    } else if (hdmi_instance->enc_color_depth == 12) {
        color_depth = 6;
    } else if (hdmi_instance->enc_color_depth == 16) {
        color_depth = 7;
    } else {
        printf("Invalid color depth %d!!", hdmi_instance->enc_color_depth);
        return;
    }

    /*configure the CSC registers */
    BITWRITE(HDMI_CSC_CFG,DECMODE,decimation);
//    HW_HDMI_CSC_CFG.B.DECMODE = decimation;
    BITWRITE(HDMI_CSC_CFG,INTMODE,interpolation);
//    HW_HDMI_CSC_CFG.B.INTMODE = interpolation;
    BITWRITE(HDMI_CSC_SCALE,CSC_COLORDEPTH , color_depth);
//    HW_HDMI_CSC_SCALE.B.CSC_COLORDEPTH = color_depth;
//    update_csc_coeffs(hdmi_instance);
}

void hdmi_video_packetize(hdmi_data_info_s* hdmi_instance)
{
    unsigned int color_depth = 0;
    unsigned int remap_size = 0;
    unsigned int output_select = 0;

    if (hdmi_instance->enc_out_format == eRGB || hdmi_instance->enc_out_format == eYCC444) {
        if (hdmi_instance->enc_color_depth == 0) {
            output_select = 3;
        } else if (hdmi_instance->enc_color_depth == 8) {
            color_depth = 4;
            output_select = 3;
        } else if (hdmi_instance->enc_color_depth == 10) {
            color_depth = 5;
        } else if (hdmi_instance->enc_color_depth == 12) {
            color_depth = 6;
        } else if (hdmi_instance->enc_color_depth == 16) {
            color_depth = 7;
        } else {
            printf("Invalid color depth %d!!\n", hdmi_instance->enc_color_depth);
            return;
        }
    } else if (hdmi_instance->enc_out_format == eYCC422) {
        if (hdmi_instance->enc_color_depth == 0 || hdmi_instance->enc_color_depth == 8) {
            remap_size = 0;
        } else if (hdmi_instance->enc_color_depth == 10) {
            remap_size = 1;
        } else if (hdmi_instance->enc_color_depth == 12) {
            remap_size = 2;
        } else {
            printf("Invalid color remap size %d!!\n", hdmi_instance->enc_color_depth);
            return;
        }
        output_select = 1;
    } else {
        printf("Invalid output encoding type %d!!\n", hdmi_instance->enc_out_format);
        return;
    }

    /*set the packetizer registers. */
    BITWRITE(HDMI_VP_PR_CD,COLOR_DEPTH , color_depth);
//    HW_HDMI_VP_PR_CD.B.COLOR_DEPTH = color_depth;
    BITWRITE(HDMI_VP_PR_CD,DESIRED_PR_FACTOR , hdmi_instance->pix_repet_factor);
//    HW_HDMI_VP_PR_CD.B.DESIRED_PR_FACTOR = hdmi_instance->pix_repet_factor;

    BITWRITE(HDMI_VP_STUFF,PR_STUFFING , 0x1);
//    HW_HDMI_VP_STUFF.B.PR_STUFFING = 0x1;
    if (hdmi_instance->pix_repet_factor > 1) // data from repeter block
    {
        BITWRITE(HDMI_VP_CONF,PR_EN , 1);
        BITWRITE(HDMI_VP_CONF,BYPASS_SELECT , 0);
//        HW_HDMI_VP_CONF.B.PR_EN = 1;
//        HW_HDMI_VP_CONF.B.BYPASS_SELECT = 0;
    } else {                    //data from packetizer block
        BITWRITE(HDMI_VP_CONF,PR_EN , 0);
        BITWRITE(HDMI_VP_CONF,BYPASS_SELECT , 1);
//        HW_HDMI_VP_CONF.B.PR_EN = 0;
//        HW_HDMI_VP_CONF.B.BYPASS_SELECT = 1;
    }
    BITWRITE(HDMI_VP_STUFF,IDEFAULT_PHASE , 0x1);
    BITWRITE(HDMI_VP_REMAP,YCC422_SIZE , remap_size);
//    HW_HDMI_VP_STUFF.B.IDEFAULT_PHASE = 0x1;
//    HW_HDMI_VP_REMAP.B.YCC422_SIZE = remap_size;

    if (output_select == 0) {
        BITWRITE(HDMI_VP_CONF,BYPASS_EN , 0);
        BITWRITE(HDMI_VP_CONF,PP_EN , 1);
        BITWRITE(HDMI_VP_CONF,YCC422_EN , 0);
//        HW_HDMI_VP_CONF.B.BYPASS_EN = 0;
//        HW_HDMI_VP_CONF.B.PP_EN = 1;
//        HW_HDMI_VP_CONF.B.YCC422_EN = 0;
    } else if (output_select == 1) {
        BITWRITE(HDMI_VP_CONF,BYPASS_EN , 0);
        BITWRITE(HDMI_VP_CONF,PP_EN , 0);
        BITWRITE(HDMI_VP_CONF,YCC422_EN , 1);
//        HW_HDMI_VP_CONF.B.BYPASS_EN = 0;
    } else if (output_select == 2 || output_select == 3) {
        BITWRITE(HDMI_VP_CONF,BYPASS_EN , 1);
        BITWRITE(HDMI_VP_CONF,PP_EN , 0);
        BITWRITE(HDMI_VP_CONF,YCC422_EN , 0);
//        HW_HDMI_VP_CONF.B.BYPASS_EN = 1;
//        HW_HDMI_VP_CONF.B.PP_EN = 0;
//        HW_HDMI_VP_CONF.B.YCC422_EN = 0;
    } else {
        printf("Invalid output option %d\n", output_select);
        return;
    }

    BITWRITE(HDMI_VP_STUFF,YCC422_STUFFING , 0x1);
    BITWRITE(HDMI_VP_STUFF,PP_STUFFING , 0x1);
    BITWRITE(HDMI_VP_CONF,OUTPUT_SELECTOR , output_select);
//    HW_HDMI_VP_STUFF.B.YCC422_STUFFING = 0x1;
//    HW_HDMI_VP_STUFF.B.PP_STUFFING = 0x1;
//    HW_HDMI_VP_CONF.B.OUTPUT_SELECTOR = output_select;
 printf("*****video packetize setup done\n");
}

void preamble_filter_set(uint8_t value, uint8_t channel)
{
    if (channel == 0) {
        HW_HDMI_FC_CH0PREAM.U= value;
    } else if (channel == 1) {
        HW_HDMI_FC_CH1PREAM.U= value;
    } else if (channel == 2) {
        HW_HDMI_FC_CH2PREAM.U= value;
    } else {
        printf("Invalid channel number %d\n", channel);
    }
    return;
}

void hdmi_av_frame_composer(hdmi_data_info_s * hdmi_instance)
{
    uint8_t i = 0;

//    hdmi_set_video_mode(hdmi_instance->video_mode);

    // configure HDMI_FC_INVIDCONF register
    BITWRITE(HDMI_FC_INVIDCONF,HDCP_KEEPOUT , (hdmi_instance->hdcp_enable == TRUE) ? 1 : 0);
    BITWRITE(HDMI_FC_INVIDCONF,VSYNC_IN_POLARITY ,
        (hdmi_instance->video_mode->mVSyncPolarity == TRUE) ? 1 : 0);
    BITWRITE(HDMI_FC_INVIDCONF,HSYNC_IN_POLARITY ,
        (hdmi_instance->video_mode->mHSyncPolarity == TRUE) ? 1 : 0);
    BITWRITE(HDMI_FC_INVIDCONF,DE_IN_POLARITY ,
        (hdmi_instance->video_mode->mDataEnablePolarity == TRUE) ? 1 : 0);
    BITWRITE(HDMI_FC_INVIDCONF,DVI_MODEZ , (hdmi_instance->video_mode->mHdmiDviSel == TRUE) ? 1 : 0);
    if (hdmi_instance->video_mode->mCode == 39) {
        BITWRITE(HDMI_FC_INVIDCONF,R_V_BLANK_IN_OSC , 0);
    } else {
        BITWRITE(HDMI_FC_INVIDCONF,R_V_BLANK_IN_OSC ,
            (hdmi_instance->video_mode->mInterlaced == TRUE) ? 1 : 0);
    }
    BITWRITE(HDMI_FC_INVIDCONF,IN_I_P , (hdmi_instance->video_mode->mInterlaced == TRUE) ? 1 : 0);

    HW_HDMI_FC_INHACTIV0.U = hdmi_instance->video_mode->mHActive;
    BITWRITE(HDMI_FC_INHACTIV1,H_IN_ACTIV , (hdmi_instance->video_mode->mHActive >> 8));
    HW_HDMI_FC_INHBLANK0.U = hdmi_instance->video_mode->mHBlanking;
    BITWRITE(HDMI_FC_INHBLANK1,H_IN_BLANK , (hdmi_instance->video_mode->mHBlanking >> 8));
    HW_HDMI_FC_INVACTIV0.U = hdmi_instance->video_mode->mVActive;
    BITWRITE(HDMI_FC_INVACTIV1,V_IN_ACTIV , (hdmi_instance->video_mode->mVActive >> 8));
    HW_HDMI_FC_INVBLANK.U = (uint8_t) hdmi_instance->video_mode->mVBlanking;
    HW_HDMI_FC_HSYNCINDELAY0.U = (uint8_t) hdmi_instance->video_mode->mHSyncOffset;
    BITWRITE(HDMI_FC_HSYNCINDELAY1,H_IN_DELAY ,
        (uint8_t) (hdmi_instance->video_mode->mHSyncOffset >> 8));
    HW_HDMI_FC_HSYNCINWIDTH0.U = hdmi_instance->video_mode->mHSyncPulseWidth;
    BITWRITE(HDMI_FC_HSYNCINWIDTH1,H_IN_WIDTH , (hdmi_instance->video_mode->mHSyncPulseWidth >> 8));
    HW_HDMI_FC_VSYNCINDELAY.U = hdmi_instance->video_mode->mVSyncOffset;
    HW_HDMI_FC_VSYNCINWIDTH.U = hdmi_instance->video_mode->mVSyncPulseWidth;

    HW_HDMI_FC_CTRLDUR.U = 12;  //control period minimum duration
    HW_HDMI_FC_EXCTRLDUR.U = 32;
    HW_HDMI_FC_EXCTRLSPAC.U = 1;

    for (i = 0; i < 3; i++) {
        preamble_filter_set((i + 1) * 11, i);
    }

    /*pixel repetition setting. */
    HW_HDMI_FC_PRCONF.U= (hdmi_instance->video_mode->mPixelRepetitionInput + 1)<<4;
 printf("*****Frame composer done\n");
}

void hdmi_tx_hdcp_config(uint32_t de)
{
    BITWRITE(HDMI_A_HDCPCFG0,RXDETECT , 0);
    BITWRITE(HDMI_A_VIDPOLCFG,DATAENPOL , (de == TRUE) ? 1 : 0);
    BITWRITE(HDMI_A_HDCPCFG1,ENCRYPTIONDISABLE , 1);
}

void hdmi_config_force_video(uint8_t force)
{
    if (force) {
        BITWRITE(HDMI_FC_DBGFORCE,FORCEVIDEO , 0x1);
    } else {
        BITWRITE(HDMI_FC_DBGFORCE,FORCEVIDEO , 0x0);
    }
}

void hdmi_config_forced_pixels(uint8_t red, uint8_t green, uint8_t blue)
{
    HW_HDMI_FC_DBGTMDS2.U = red;
    HW_HDMI_FC_DBGTMDS1.U = green;
    HW_HDMI_FC_DBGTMDS0.U = blue;
}

///////////////////////////////////////////////////////////////////////////////
// EOF
///////////////////////////////////////////////////////////////////////////////
