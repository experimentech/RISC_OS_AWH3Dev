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
 * Copyright (c) 2011-2012, Freescale Semiconductor, Inc.
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

/*!
 * @file hdmi_test.c
 * @brief Unit test for the HDMI controller driver.
 *
 * @ingroup diag_hdmi
 */

#include "sdk.h"

void PrintInstance  (hdmi_data_info_s *myHDMI_info)
{
//    printf("EncIn fmt :%d\n", myHDMI_info->enc_in_format);
//    printf("EncOut fmt:%d\n", myHDMI_info->enc_out_format);
//    printf("Enc Coldep:%d\n", myHDMI_info->enc_color_depth);
//    printf("Colorim   :%d\n", myHDMI_info->colorimetry);
//    printf("PixRepetF :%d\n", myHDMI_info->pix_repet_factor);
//    printf("hdcp_En   :%d\n", myHDMI_info->hdcp_enable);
//    if (myHDMI_info->video_mode)
//    {
//      printf("Code        :%d\n", myHDMI_info->video_mode->mCode);
//      printf("DVISel      :%d\n", myHDMI_info->video_mode->mHdmiDviSel);
//      printf("RVBinOsc    :%d\n", myHDMI_info->video_mode->mRVBlankInOSC);
//      printf("RefRate     :%d\n", myHDMI_info->video_mode->mRefreshRate);
//      printf("HImSz       :%d\n", myHDMI_info->video_mode->mHImageSize);
//      printf("VImSz       :%d\n", myHDMI_info->video_mode->mVImageSize);
//      printf("HActiv      :%d\n", myHDMI_info->video_mode->mHActive);
//      printf("VActiv      :%d\n", myHDMI_info->video_mode->mVActive);
//      printf("HBlank      :%d\n", myHDMI_info->video_mode->mHBlanking);
//      printf("VBlank      :%d\n", myHDMI_info->video_mode->mVBlanking);
//      printf("HSyncOff    :%d\n", myHDMI_info->video_mode->mHSyncOffset);
//      printf("VSyncOff    :%d\n", myHDMI_info->video_mode->mVSyncOffset);
//      printf("HSyncPW     :%d\n", myHDMI_info->video_mode->mHSyncPulseWidth);
//      printf("VSyncPw     :%d\n", myHDMI_info->video_mode->mVSyncPulseWidth);
//      printf("HSyncPol    :%d\n", myHDMI_info->video_mode->mHSyncPolarity);
//      printf("VSyncPol    :%d\n", myHDMI_info->video_mode->mVSyncPolarity);
//      printf("DatEnPol    :%d\n", myHDMI_info->video_mode->mDataEnablePolarity);
//      printf("Interlaced  :%d\n", myHDMI_info->video_mode->mInterlaced);
//      printf("PixClk      :%d\n", myHDMI_info->video_mode->mPixelClock);
//      printf("HBorder     :%d\n", myHDMI_info->video_mode->mHBorder);
//      printf("VBorder     :%d\n", myHDMI_info->video_mode->mVBorder);
//      printf("PixRepInp   :%d\n", myHDMI_info->video_mode->mPixelRepetitionInput);
//    }
//
//    printf("mpanel_name        :%s\n",sb->myHDMI_dev_panel.panel_name       );//
//    printf("mpanel_id          :%d\n",sb->myHDMI_dev_panel.panel_id         );//
//    printf("mpanel_type        :%d\n",sb->myHDMI_dev_panel.panel_type       );//
//    printf("mcolorimetry       :%d\n",sb->myHDMI_dev_panel.colorimetry      );//
//    printf("mrefresh_rate      :%d\n",sb->myHDMI_dev_panel.refresh_rate     );//
//    printf("mwidth             :%d\n",sb->myHDMI_dev_panel.width            );//ll
//    printf("mheight            :%d\n",sb->myHDMI_dev_panel.height           );//ll
//    printf("mpixel_clock       :%d\n",sb->myHDMI_dev_panel.pixel_clock      );//ll
//    printf("mhsync_start_width :%d\n",sb->myHDMI_dev_panel.hsync_start_width);//ll
//    printf("mhsync_width       :%d\n",sb->myHDMI_dev_panel.hsync_width      );//ll
//    printf("mhsync_end_width   :%d\n",sb->myHDMI_dev_panel.hsync_end_width  );//ll
//    printf("mvsync_start_width :%d\n",sb->myHDMI_dev_panel.vsync_start_width);//ll
//    printf("mvsync_width       :%d\n",sb->myHDMI_dev_panel.vsync_width      );//ll
//    printf("mvsync_end_width   :%d\n",sb->myHDMI_dev_panel.vsync_end_width  );//ll
//    printf("mdelay_h2v         :%d\n",sb->myHDMI_dev_panel.delay_h2v        );//ll
//    printf("mpinterlaced       :%d\n",sb->myHDMI_dev_panel.interlaced       );//
//    printf("mclk_sel           :%d\n",sb->myHDMI_dev_panel.clk_sel          );//ll
//    printf("mclk_pol           :%d\n",sb->myHDMI_dev_panel.clk_pol          );//
//    printf("mhsync_pol         :%d\n",sb->myHDMI_dev_panel.hsync_pol        );//ll
//    printf("mvsync_pol         :%d\n",sb->myHDMI_dev_panel.vsync_pol        );//ll
//    printf("mdrdy_pol          :%d\n",sb->myHDMI_dev_panel.drdy_pol         );//ll
//    printf("mdata_pol          :%d\n",sb->myHDMI_dev_panel.data_pol         );//ll
//    printf("mpanel_init        :%x\n",sb->myHDMI_dev_panel.panel_init       );//
//    printf("mpanel_deinit      :%x\n",sb->myHDMI_dev_panel.panel_deinit     );//
}
/*! ------------------------------------------------------------
 * HDMI TX Video Test (force output of FSL logo)
 *  ------------------------------------------------------------
 */
void HDMI_Setup(void)
{
//    printf("\n---- Settuing up HDMI ----\n");
//
//    hdmi_data_info_s *myHDMI_info = (hdmi_data_info_s *)&sb->myHDMI_infos;
//    hdmi_vmode_s *myHDMI_vmode_info = (hdmi_vmode_s *)&sb->myHDMI_vmode_infos;
//    myHDMI_info->video_mode = myHDMI_vmode_info;
//
//    hdmi_audioparam_s *myHDMI_audio_info = (hdmi_audioparam_s *)&sb->myHDMI_audioparams;
//    printf("ws:%x myHDMI_Info:%x myHDMI_vmode_info:%x myHDMI_audio_info:%x \n",sb,myHDMI_info,myHDMI_vmode_info,myHDMI_audio_info);
//
////    myHDMI_info = { 0 };   // declare new hdmi module object instance
////    hdmi_vmode_s myHDMI_vmode_info = { 0 }; // declare new hdmi module object instance
////    myHDMI_audio_info = { 0 };    // declare new hdmi audio object instance
////    myHDMI_info->enc_in_format = eRGB;
////    myHDMI_info->enc_out_format = eRGB;
////    myHDMI_info->enc_color_depth = 8;
////    myHDMI_info->colorimetry = eITU601;
////    myHDMI_info->pix_repet_factor = 0;
////    myHDMI_info->hdcp_enable = 0;
////    myHDMI_info->video_mode->mCode = 4;  //1280x720p @ 59.94/60Hz 16:9
////    myHDMI_info->video_mode->mCode = 16; //1920x1080p @ 59.94/60Hz 16:9
////    myHDMI_info->video_mode->mHdmiDviSel = TRUE;
////    myHDMI_info->video_mode->mRVBlankInOSC = FALSE;
//////    myHDMI_info->video_mode->mRefreshRate = 60000;
////    myHDMI_info->video_mode->mDataEnablePolarity = TRUE;
////    myHDMI_audio_info->IecCgmsA = 0;
////    myHDMI_audio_info->IecCopyright = TRUE;
////    myHDMI_audio_info->IecCategoryCode = 0;
////    myHDMI_audio_info->IecPcmMode = 0;
////    myHDMI_audio_info->IecSourceNumber = 1;
////    myHDMI_audio_info->IecClockAccuracy = 0;
////    myHDMI_audio_info->OriginalSamplingFrequency = 0;
////    myHDMI_audio_info->ChannelAllocation = 0xf;
////    myHDMI_audio_info->SamplingFrequency = 32000;
////    myHDMI_audio_info->SampleSize = 16;
//
////    hdmi_set_video_mode(myHDMI_info->video_mode);
////extern void LoadDefaultVideoMode(void);
//// PrintInstance  (myHDMI_info);
////            LoadDefaultVideoMode();
// PrintInstance  (myHDMI_info);
//
////extern void ConfigHDMI(hdmi_data_info_s *myHDMI_info);
////    ConfigHDMI(myHDMI_info);
//
////    hdmi_av_frame_composer(myHDMI_info);
////    hdmi_video_packetize(myHDMI_info);
////    hdmi_video_csc(myHDMI_info);
////    hdmi_video_sample(myHDMI_info);
//
////    hdmi_audio_mute(TRUE);
////    hdmi_tx_hdcp_config(myHDMI_info->video_mode->mDataEnablePolarity);
//
////    hdmi_phy_init(TRUE, myHDMI_info->video_mode->mPixelClock);
//
////    hdmi_config_input_source(IPU1_DI0); // configure input source to HDMI block
//
//    // configure IPU to output stream for hdmi input
//    if (ips_hdmi_stream()) {    // set up ipu1 disp0  1080P60 display stream
//        printf("HDMI video initialised\n");
// PrintInstance  (myHDMI_info);
////        printf("Audio will play for 2 more seconds\n");
////        hal_delay_us(2000000);  // play hdmi audio for 3 seconds
////        disable_interrupt(IMX_INT_HDMI_TX, CPU_0);
//    } else {
//        printf("HDMI video didnt initialise\n");
////        disable_interrupt(IMX_INT_HDMI_TX, CPU_0);
//    }
//
}
