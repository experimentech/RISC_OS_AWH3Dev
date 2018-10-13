;KbdScan.s Stub file
        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:HALEntries
        GET     Hdr:OSEntries


        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  HAL_KbdScanDependencies

HAL_KbdScanDependencies
;	mov a1, #-1
;	mov pc, lr
        ADR     a1, %FT10
        MOV     pc, lr
10
        DCB     "SharedCLibrary,BufferManager,DeviceFS,USBDriver,"
        DCB     "EHCIDriver,InternationalKeyboard", 0
        

	END
