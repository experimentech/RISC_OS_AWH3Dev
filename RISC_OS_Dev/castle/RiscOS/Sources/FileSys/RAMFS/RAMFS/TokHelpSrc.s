     TTL ==> s.TokHelpSrc

;>HelpText

 [ International_Help=0
HelpRam
  ;= "*"
     =  "*",TokenEscapeChar,Token0," selects",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token0," ",TokenEscapeChar,Token4," as"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token5," "
     =  TokenEscapeChar,Token4,".", 13
  ;= TokenEscapeChar,Token0
  ;= " selects the "
  ;= TokenEscapeChar,Token0
  ;= " filing system as the current filing system.",13
SynRam
  ;= "Syntax: *"
     =  TokenEscapeChar,Token1,  0
  ;= TokenEscapeChar,Token0
  ;= 0
 |
HelpRam DCB     "HRFSRAM", 0
SynRam  DCB     "SRFSRAM", 0
 ]
        ALIGN

        END
