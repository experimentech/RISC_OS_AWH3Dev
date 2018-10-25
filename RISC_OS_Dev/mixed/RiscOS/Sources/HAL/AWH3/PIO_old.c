/*
This is not a part of the project. It probably won't even build.
It's just a scratchpad for working out PIO and maybe a GPIO layer.
*/
//Note. These could probably be packed into a single 32 bit word.
//opting for 32 bit because register size.
#include <stdint.h>
#include "GPIO.h"

//These don't apply to all pads.
//Not all pads and ports exist. There is no check in the code.

// set/get pad mode, or alt.
void     SetPadMode (uint32_t port, uint32_t pad, uint32_t mode);
uint32_t GetPadMode (uint32_t port, uint32_t pad);

// read / write pad
void     SetPadData (uint32_t port, uint32_t pad, uint32_t drv);
uint32_t GetPadData (uint32_t port, uint32_t pad);

// set drive level. Pullup/down related.
void     SetPadDrive(uint32_t port, uint32_t pad, uint32_t drv);
uint32_t GetPadDrive(uint32_t port, uint32_t pad);
