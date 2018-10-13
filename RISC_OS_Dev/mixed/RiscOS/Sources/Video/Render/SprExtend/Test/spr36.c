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
    int factors[4];
    char pixtrans[16];
    int *b;
    int size;

    _swi(OS_File, _IN(0)|_IN(1)|_OUT(4), 5, "sprites", &size);
    size += 4;
    b = malloc(size);
    b[0] = size;
    _swi(OS_File, _IN(0)|_IN(1)|_IN(2)|_IN(3), 255, "sprites", &(b[1]), 0);
    _swi(Wimp_ReadPixTrans, _IN(0)|_IN(1)|_IN(2)|_IN(6)|_IN(7),
         0x100, b, "newpal", factors, pixtrans);
    _swi(OS_SpriteOp, _IN(0)|_IN(1)|_IN(2)|_IN(3)|_IN(4)|_IN(5)|_IN(6)|_IN(7),
         36 + 256, b, "newpal", 1, 0, 0, factors, pixtrans);
    _swi(OS_Byte, _IN(0)|_IN(1), 0x6a, 1);
}
