        AREA    |Asm$$Code|, CODE, READONLY, PIC

DWCHDMI_Init
        Push   "lr"

        Pull   "lr"
        MOV     pc, lr


;Interrogate the hardware.
DWCHDMI_Probe
        Push   "lr"

        Pull   "lr"
        MOV     pc, lr


        END