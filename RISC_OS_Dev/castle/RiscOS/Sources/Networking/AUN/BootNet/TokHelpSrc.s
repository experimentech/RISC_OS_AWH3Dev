     TTL ==> s.TokHelpSrc

        SUBT    Strings for Help messages. => BootNet.HelpTexts

        [ international_help

HelpForConfigureBootNet
        DCB     "HBNTCBN",0
        ALIGN
SyntaxOfConfigureBootNetError
        DCD     ErrorNumber_Syntax
SyntaxOfConfigureBootNet
        DCB     "SBNTCBN",0

        |

HelpForConfigureBootNet
         ;=       "*Configure BootNet enables or disables AUN client "
     =  TokenEscapeChar,Token10,"BootNet enables or disables AUN clie"
     =  "nt sta",TokenEscapeChar,Token9," booting from expansion card"
     =  " ROM", 13,  0
         ;=       "station booting from expansion card ROM", 13, 0
SyntaxOfConfigureBootNetError
        DCD     ErrorNumber_Syntax
SyntaxOfConfigureBootNet
        DCB     "Syntax: *Configure BootNet On|Off", 0

        ]

        ALIGN
EndOfSyntaxOfConfigureBootNet

        END
