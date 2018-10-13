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
/* h.rojpeg
   Interface between core code and SpriteExtend innards.
   started: 12 Sep 93 WRS
*/

#ifndef rojpeg_h_
#define rojpeg_h_

/* Error diffused dithering */
char *asm_get_table32k(const int *palette_data);
void asm_diffuse_to_8bpp(JSAMPARRAY, int count, JSAMPARRAY, char *table32k, int nlines, int xmin, const int *palette_data);
void asm_diffuse_to_24bpp(JSAMPARRAY, int count, JSAMPARRAY, char *table32k, int nlines, int xmin, const int *palette_data);

/* YUV <-> VIDC colour tables (not really functions!) */
const int *pixel_to_yuv_table(void);
const char *yuv_to_pixel_table(void);

/* Transcoder */
void jpegtrans_make_baseline(j_decompress_ptr, const JOCTET **, size_t *);

/* Used by SpriteExtend assembler code */
typedef struct
{
  int type; /* Bits   0-2: 1=monochrome, 3=YUV or RGB, 4=CMYK or YCCK
             *        3-6: unused
             *          7: image density was a ratio
             *       8-11: SOF type
             *      12-31: unused
             */
  int width;
  int height;
  int density;
} image_dims_info;
_kernel_oserror *jpeg_find_image_dims(const char *jdata, image_dims_info *image, int *ws_size);
#define jfid_OK          (_kernel_oserror *)0
#define jfid_NOT_JPEG    (_kernel_oserror *)1
#define jfid_CANT_RENDER (_kernel_oserror *)2

/* Return a pointer to the fully decompressed scan line of 32-bit pixels at the given y coordinate.
 * This might be in the already-decompressed band buffer, or it might require decompression
 * of a band. Only pixels between xmin and xmax in the original scan-file are assured of being correct.
 * 
 * If ycoord is outside the acceptable range (0..image_height-1) the result may well
 * be trash.
 */
int *jpeg_find_line(j_decompress_ptr cinfo, int ycoord, const int *palette_data);

/* Given a file image and all necessary workspace, scan the file image,
 * build an array of band pointers into it. file_image points to image_length
 * bytes, which should be a JFIF file. Only two forms of file are accepted - a
 * greyscale single-scan file, and an interlaced YUV (YCbCr) file.
 * 
 * A non-zero error code is returned if an error occurred. Reason code in
 *   cinfo->error_code           (same as returned result)
 *   cinfo->error_argument       (any additional argument)
 * Typical reasons include an unacceptable or badly formed JPEG file.
 *
 * cinfo must point to cinfo->workspace_size bytes of available workspace. This
 * should be about 50K for typical JPEG files, if it's not big enough then
 * cinfo->error_argument is set to what it needs to be - you are welcome to
 * allocate more space and call again.
 * 
 * If the file is at the same address as the previous call, and a sample of the
 * data is the same, then jpeg_scan_file guesses that it's the same data - it's hard to
 * do a random update to the data of a JPEG file.
 * 
 * width and height say how big the resulting image should be - complain if not
 * precisely correct. If double size and band buffer is big enough, interpolate
 * upwards If width==-1 the width test is omitted. If height==-1 the height
 * test is omitted.
 * 
 * (It would be wonderful to feed in scale factors too, so that strange combinations of
 * scaling, interpolation etc. made sensible decisions. Unfortunately this requires the
 * calling code to be prepared to accept an output of an unexpected size, say by a factor
 * of 2 or 8. Not this time.)
 * 
 * Interpolate in the X direction takes twice as much store, and will only be done if
 * it will fit. On return, if it was requested, cinfo->error_argument will have
 * jopt_INTERP_X set if the interpolation is enabled. jopt_OUTBPP_8DITHER and
 * jopt_OUTBPP_8YUV and jopt_OUTBPP_16 are similar, they constitute a request which will
 * only happen if the corresponding bits of cinfo->error_argument are set on exit.
 */
int jpeg_scan_file(j_decompress_ptr cinfo, const JOCTET *file_image, size_t image_length,
                   int xmin, int xmax, int width, int height, int options);

/* JFIF file parsing options */
#define jopt_GREY 1            /* Greyscale output is requested, choice of 24bpp/8bpp in OUTBPP_8GREY flag */
#define jopt_DC_ONLY 2         /* Do only the DC values of the tiles - faster, less accurate */
#define jopt_INTERP_X 4        /* Interpolate in the X direction */
#define jopt_DIFFUSE 8         /* Dithered output is requested, choice of 24bpp/8bpp in OUTBPP_8DITHER flag */
#define jopt_OUTBPP_16 16      /* Output 16bit pixels */
#define jopt_OUTBPP_8YUV 32    /* Output 8bit pixels directly using YUV<->VIDC reverse lookup table */
#define jopt_OUTBPP_8DITHER 64 /* Dither to 8bpp when set, else 24bpp */
#define jopt_OUTBPP_8GREY 128  /* Grey pixels at 8bpp when set, else 24bpp (assumes an ascending palette) */

#endif
