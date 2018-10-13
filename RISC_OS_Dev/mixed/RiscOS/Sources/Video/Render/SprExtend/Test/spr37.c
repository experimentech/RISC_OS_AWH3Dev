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
#include <stdlib.h>

#include "swis.h"

int main(void)
{
    int *b;
    int size;
    int palette[32];
    int c1, c2;
    int i;

    _swi(OS_File, _IN(0)|_IN(1)|_OUT(4), 5, "sprites", &size);
    size += 4;
    b = malloc(size + 256);
    b[0] = size + 256;
    _swi(OS_File, _IN(0)|_IN(1)|_IN(2)|_IN(3), 255, "sprites", &(b[1]), 0);
    for (i = 0; i < 16; i++) {
        _swi(OS_ReadPalette, _IN(0)|_IN(1)|_OUT(2)|_OUT(3), i, 16, &c1, &c2);
        palette[i * 2] = c1;
        palette[i * 2 + 1] = c2;
    }
    _swi(OS_SpriteOp, _IN(0)|_IN(1)|_IN(2)|_IN(3)|_IN(4)|_IN(5)|_IN(6)|_IN(7),
         37 + 256, b, "switcher", palette);
    _swi(OS_File, _IN(0)|_IN(1)|_IN(2)|_IN(4)|_IN(5),
         10, "sprites2", 0xff9, b + 1, (int)b + b[3]);
}
