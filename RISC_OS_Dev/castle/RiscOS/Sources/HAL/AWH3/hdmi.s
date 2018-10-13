;pseudo-ish code

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>

        GET     Hdr:OSEntries

    GET hdr.Timers
    IMPORT HAL_CounterDelay

    GET hdr.AllWinnerH3
    GET hdr.StaticWS
    GET hdr.HDMI_Regs

    EXPORT  my_video_init

 [ Debug
    GET     Debug
    IMPORT  HAL_DebugTX
    IMPORT  HAL_DebugRX
    IMPORT  DebugHALPrint
    IMPORT  DebugHALPrintReg
    IMPORT  DebugMemDump
    IMPORT  DebugHALPrintByte
    IMPORT  DebugCallstack
    
 ]

    
    AREA    |Asm$$Code|, CODE, READONLY, PIC

my_video_init
    Push "lr"

    bl    phy_init

    ;other layers should get called from here

    Pull "lr"
    MOV   pc, lr



phy_init
    Push "lr"
    ;Let's assume this is post MMU, post logical mapping
    LDR     a2, HDMI_BaseAddr ;from StaticWS
    LDR     a3, =HDMI_PHY
    ADD     a3, a2, a3 ;Now has logical address of HDMI_PHY

    ;Time to do the S40 dance...

    ;stipping straight to read access and un-obfuscation
    B %FT50

    DebugTX "Enabling TDMS Clock"
    ;Enable TDMS Clock
    LDR     a1, =TMDSCLK_EN
    STR     a1, [a3, #ANA_CFG1]

    DebugTX "Enabling common voltage reference bias module"
    ;Enable common voltage reference bias module
    LDR     a1, =ENVBS
    STR     a1, [a3, #ANA_CFG1]

;    MOV     a1, #5
;    BL      HAL_CounterDelay

    DebugTX "Enabling internal LDO"
    ;Enable internal LDO
    LDR     a1, =LDOEN
    STR     a1, [a3, #ANA_CFG1]

    DebugTX "Enabling common clock module"
    ;Enable common clock module
    LDR     a1, =CKEN
    STR     a1, [a3, #ANA_CFG1]

    DebugTX "Enabling resistance calibration analog module"
    ;Enable resistence calibration analog module
    LDR     a1, =ENRCAL
    STR     a1, [a3, #ANA_CFG1]

    DebugTX "Enable resistance calibration digital module"
    ;Enable resistence calibration digital module
    ;Surely this is the analog calibration step???
    LDR     a1, =ENCALOG
    STR     a1, [a3, #ANA_CFG1]

    DebugTX "Enable P2S module for data lane"
    ;P2S module enable for TDMS data lane <2:0>
    LDR     a1, =ENP2S
    STR     a1, [a3, #ANA_CFG1]

    DebugTX "Waiting for resistance calibration to finish..."

;---as expected the code gets stuck in this section.
;next up we need to poll for the end of resistence calibration.
    MOV     a2, #RCALEND2D
20
    LDR     a1, [a3, #ANA_STS]
    AND     a1, a2, a1 ;mask

    CMP     a1, #0
    BEQ     %BT20
    ;poll until b7 = 1
    ;TODO: Add timeout.

    DebugTX "Calibration complete"

    DebugTX "Enabling current and voltage module"
;--9. Enable current and voltage module
    LDR     a1, =BIASEN
    STR     a1, [a3, #ANA_CFG1]

    DebugTX "Enable P2S module for clock lane"
;---10. P2S module enable for TDMS clock lane
    LDR     a1, =ENP2S
    STR     a1, [a3, #ANA_CFG1]

;-----TODO----
;---11. Config PLL module. Table1.1 of manual
;Hardcoding to 74.25MHz for now

    DebugTX "Configuring PLL to 74.25MHz"
    LDR     a1, =&3ddc5040
    STR     a1, [a3, #PLL_CFG1]
    LDR     a1, =&80084343
    STR     a1, [a3, #PLL_CFG2]
    MOV     a1, #1
    STR     a1, [a3, #PLL_CFG3]
;----/TODO----

;--12. Enable PLL
    DebugTX "Enabling PLL"
    LDR     a1, =PLLEN
    STR     a1, [a3, #PLL_CFG1]

;--13.
    DebugTX "Getting HDMI terminator resistance data"
    LDR     a1, [a3, #ANA_STS]
    LDR     a2, =RESDO2D
    AND     a1, a2, a1
    Push   "a1"
    ;---FIXME!--- what do I do with a1 now??? Possibly nothing.
    ;May be used for prototype stage? Table 1.2.5

    DebugTX "Step 14..."
;---14.
    LDR     a1, =REG_OD1
    STR     a1, [a3, #PLL_CFG1]
    LDR     a1, =REG_OD0
    STR     a1, [a3, #PLL_CFG1]

    LDR     a1, [a3, #ANA_STS]
    LDR     a2, =B_OUT
    AND     a1, a2, a1
    MOV     a1, a1, ROR #11 ;syntax?
    STR     a1, [a3, #PLL_CFG1] ;B_IN

;---15 ----TODO----
;Table 1.2.4
;I have no idea.
;There appears to be a correlation between PLL and TMDS config.
    ;todo. some voodoo with tmp value.

    DebugTX "Setting analog calibration"
    LDR     a1, =&11ffff7f
    STR     a1, [a3, #ANA_CFG1]
    ;need to grab the calibration info now.
    Pull   "a1"
    MOV    a1, a1, ROR #2 ;Really???
    LDR    a2, =&80623000
    ORR    a1, a2, a1
    STR    a1, [a3, #ANA_CFG2]
    LDR    a1, =&0f814385
    STR    a1, [a3, #ANA_CFG3]

50
;so I can short circuit the whole thing.
    ;now we need enable read access and un-obfuscate the interface.
    DebugTX "Enabling read, and un-obfuscating interface"
    LDR    a1, =HDMI_READ_ENABLE
    STR    a1, [a3, #PHY_READ_EN]

    LDR    a1, =HDMI_UNSCRAMBLE_ENABLE
    STR    a1, [a3, #PHY_UNSCRAMBLE]

    DebugTX "HDMI PHY config complete."

    Pull "lr"
    MOV   pc, lr

    END
    
    




