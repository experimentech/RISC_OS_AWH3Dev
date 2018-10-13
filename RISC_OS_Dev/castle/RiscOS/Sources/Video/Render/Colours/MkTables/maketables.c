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
/* maketables.c - makes the colourtrans ROM tables */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const uint32_t palette4[16] =
                { 0xffffff00, 0xdddddd00, 0xbbbbbb00, 0x99999900,
                  0x77777700, 0x55555500, 0x33333300, 0x00000000,
                  0x99440000, 0x00eeee00, 0x00cc0000, 0x0000dd00,
                  0xbbeeee00, 0x00885500, 0x00bbff00, 0xffbb0000 };

static const uint32_t palette4g[16] =
                { 0xffffff00, 0xdddddd00, 0xbbbbbb00, 0x99999900,
                  0x77777700, 0x55555500, 0x33333300, 0x00000000,
                  0x11111100, 0xcccccc00, 0x66666600, 0x22222200,
                  0xeeeeee00, 0x44444400, 0xaaaaaa00, 0x88888800 };

static uint8_t *make_32ktable(const uint32_t *palette, uint8_t *table, size_t palsize)
{
  uint32_t element;

  for (element = 0; element < 32768; element++)
  {
    uint32_t shortest, euclid;
    size_t   best = 0, colour;
    uint32_t r,g,b;
    uint32_t rp,gp,bp;

    b = ((element >> 10) & 0x1f) * 255/31;
    g = ((element >>  5) & 0x1f) * 255/31;
    r = ((element >>  0) & 0x1f) * 255/31;
    shortest = UINT32_MAX;

    for (colour = 0; colour < palsize; colour++)
    {
      rp = (uint8_t)(palette[colour] >>  8);
      gp = (uint8_t)(palette[colour] >> 16);
      bp = (uint8_t)(palette[colour] >> 24);
      /* Weight the distances per PRM 3-339 */
      euclid = (2 * (rp - r) * (rp - r)) +
               (4 * (gp - g) * (gp - g)) +
               (1 * (bp - b) * (bp - b));
      if (euclid < shortest)
      {
        shortest = euclid;
        best = colour;
      }
    }
    table[element] = (uint8_t)best;
  }
  return table;
}

int main(int argc, char *argv[])
{
  uint32_t *palette;
  uint8_t  *table;
  FILE     *file;
  size_t    loop;
  uint32_t  r, g, b;
  char      outfile[256];

  palette = (uint32_t *)malloc(256 * sizeof(uint32_t));
  table = (uint8_t *)malloc(32 * 32 * 32 * sizeof(uint8_t));
  (void)argc; /* Unused */
  
  /* 8bpp desktop */
  printf("Constructing 8bpp desktop tables\n");
  for (loop = 0; loop < 256; loop++)
  {
    r = g = b = 0;
    if (loop & 0x80) b |= 0x88; /* top bit blue */
    if (loop & 0x40) g |= 0x88; /* top bit green */
    if (loop & 0x20) g |= 0x44; /* 2nd bit green */
    if (loop & 0x10) r |= 0x88; /* top bit red */
    if (loop & 0x08) b |= 0x44; /* 2nd bit blue */
    if (loop & 0x04) r |= 0x44; /* 2nd bit red */
    if (loop & 0x02)
      { r |= 0x22; g |= 0x22; b |= 0x22; } /* 3rd bit, added white */
    if (loop & 0x01)
      { r |= 0x11; g |= 0x11; b |= 0x11; } /* 4th bit, added white */
    palette[loop] = (b<<24) | (g<<16) | (r<<8);
  }
  sprintf(outfile,"%s.Palettes.8desktop",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(palette, sizeof(uint32_t), 256, file);
  fclose(file);
  printf("  - written palette.\n");

  memset(table,0,32*32*32);
  table = make_32ktable(palette, table, 256);
  sprintf(outfile,"%s.Tables.8desktop",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(table, sizeof(uint8_t), 32 * 32 * 32, file);
  fclose(file);
  printf("  - written table.\n");

  /* 8bpp grey */
  printf("Constructing 8bpp grey tables\n");
  for (loop = 0; loop < 256; loop++)
  {
    palette[loop] = (loop<<24) | (loop<<16) | (loop<<8);
  }
  sprintf(outfile,"%s.Palettes.8greys",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(palette, sizeof(uint32_t), 256, file);
  fclose(file);
  printf("  - written palette.\n");

  memset(table,0,32*32*32);
  table = make_32ktable(palette, table, 256);
  sprintf(outfile,"%s.Tables.8greys",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(table, sizeof(uint8_t), 32 * 32 * 32, file);
  fclose(file);
  printf("  - written table.\n");

  /* 4bpp desktop */
  printf("Constructing 4bpp desktop tables\n");
  sprintf(outfile,"%s.Palettes.4desktop",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(palette4, sizeof(uint32_t), 16, file);
  fclose(file);
  printf("  - written palette.\n");

  memset(table,0,32*32*32);
  table = make_32ktable(palette4, table, 16);
  sprintf(outfile,"%s.Tables.4desktop",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(table, sizeof(uint8_t), 32 * 32 * 32, file);
  fclose(file);
  printf("  - written table.\n");

  /* 4bpp grey */
  printf("Constructing 4bpp grey tables\n");
  sprintf(outfile,"%s.Palettes.4greys",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(palette4g, sizeof(uint32_t), 16, file);
  fclose(file);
  printf("  - written palette.\n");

  memset(table,0,32*32*32);
  table = make_32ktable(palette4g, table, 16);
  sprintf(outfile,"%s.Tables.4greys",argv[1]);
  file = fopen(outfile, "wb");
  fwrite(table, sizeof(uint8_t), 32 * 32 * 32, file);
  fclose(file);
  printf("  - written table.\n");

  free(palette);
  free(table);

  return 0;
}
