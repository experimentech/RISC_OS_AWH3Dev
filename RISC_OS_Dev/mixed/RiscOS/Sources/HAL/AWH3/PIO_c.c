//pio.c
#include "PIO_c.h"


/*
Doesn't work.

ARM Linker: (attribute difference = {NO_SW_STACK_CHECK}).
ARM Linker: (Error) Undefined symbol(s).
ARM Linker:     _Mod$Reloc$Off, referred to from o.PIO_c.
ARM Linker: Errors in link, no output generated.
ARM Linker: finished,  3 informational, 1 warning and 1 error messages.
AMU: *** exit (1) ***

AMU: *** '_debug' not re-made because of errors ***

*/


static uint32_t* PIO = 0x0;//0x01C20800; //pre-mmu. Just a placeholder.

void PIOinit(uint32_t* PIO_Base){
	PIO = PIO_Base; //set base address of PIO ports.
}

void SetPadMode (uint32_t port, uint32_t pad, uint32_t mode){
	//first find the pad offset.
	uint32_t padOffset, regOffset, portOffset, dataTmp;
	volatile uint32_t* IOAddr;
	padOffset = pad << 2; //4 bits per pad.
	padOffset &= 0x1F; //mask all but b0:5

    regOffset = (pad >> 4); //Pn_CFG0-3

    portOffset = (port * 0x24) + regOffset;
    IOAddr = PIO;
//    IOAddr = (volatile uint32_t*) PIO;
//    IOAddr += (volatile uint32_t*) portOffset;
	IOAddr += portOffset;
    //IOAddr now holds absolute address

    mode &= 7; //filter out illegal modes which could overflow.

    dataTmp = *IOAddr; //read

//FIXME! This is only setting bits!!!
//    dataTmp |= (mode << (padOffset);
//FIXME FIXME FIXME FIXME
//    dataTmp ^= (~mode ^ dataTmp ) & (0b111 << regOffset);
    dataTmp ^= (~mode ^ dataTmp ) & (7 << padOffset);
    *IOAddr = dataTmp;                                        //write

}
//--------------------------------------------------------------------//
uint32_t GetPadMode (uint32_t port, uint32_t pad){

	uint32_t padOffset, regOffset, portOffset, dataTmp;
	volatile uint32_t* IOAddr;
	padOffset = pad << 2; //4 bits per pad.
	padOffset &= 0x1F; //mask all but b0:5

    regOffset = (pad >> 4); //Pn_CFG0-3

    portOffset = (port * 0x24) + regOffset;

    IOAddr = PIO;
    //IOAddr = (uint32_t*) PIO;
    IOAddr += portOffset;
//    IOAddr += (uint32_t*) portOffset;
    //IOAddr now holds absolute address


    dataTmp = *IOAddr; //read
    dataTmp = dataTmp >> padOffset; //SHR to put mode at LSB
//    dataTmp &= 0b111;
    dataTmp &= 7;

	return dataTmp;
}
//--------------------------------------------------------------------//
void SetPadState (uint32_t port, uint32_t pad, uint32_t state){
  // (n * 0x24) + 0x10
  uint32_t tmpOffset, tmpData;
  volatile uint32_t* IOAddr;

  IOAddr = PIO;
  //IOAddr += (uint32_t*) PIO;
  tmpOffset = (port * 0x24) + 0x10;
//  IOAddr += (uint32_t*) tmpOffset;
  IOAddr += tmpOffset;
  //read the port
  tmpData = *IOAddr;
  //left shift by pad
  //state &=0b1; //sanitise data to LSB only.
  state &= 1; //sanitise data to LSB only.
  //number ^= (-x ^ number) & (1UL << n);
//  tmpData ^= (~state ^ tmpData ) & (0b1 << pad);
  tmpData ^= (~state ^ tmpData ) & (1 << pad);

  //clear / set bit
  *IOAddr = tmpData;
  //write back to port

}
//--------------------------------------------------------------------//
uint32_t GetPadState (uint32_t port, uint32_t pad){
  // (n * 0x24) + 0x10
  uint32_t tmpOffset, tmpData;
  volatile uint32_t* IOAddr;
//  IOAddr += (uint32_t*) PIO;
  IOAddr = PIO;
  tmpOffset = (port * 0x24) + 0x10;
//  IOAddr += (uint32_t*) tmpOffset;
  IOAddr += tmpOffset;
  //read the port
  tmpData = *IOAddr;
  //left shift by pad
  tmpData = tmpData >> pad;
//  tmpData &=0b1; //sanitise data to LSB only.
  tmpData &= 1; //sanitise data to LSB only.

  return tmpData;

}

