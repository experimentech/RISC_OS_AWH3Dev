
typedef unsigned long int uint32_t;

void SetPadMode (uint32_t port, uint32_t pad, uint32_t mode);
uint32_t GetPadMode (uint32_t port, uint32_t pad);
void SetPadState (uint32_t port, uint32_t pad, uint32_t state);
uint32_t GetPadState (uint32_t port, uint32_t pad);
void PIOinit(uint32_t* PIO_Base);
