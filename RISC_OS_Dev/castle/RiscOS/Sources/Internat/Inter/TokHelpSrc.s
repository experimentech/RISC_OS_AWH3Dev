     TTL ==> s.TokHelpSrc

; This source code in this file is licensed to You by Castle Technology
; Limited ("Castle") and its licensors on contractual terms and conditions
; ("Licence") which entitle you freely to modify and/or to distribute this
; source code subject to Your compliance with the terms of the Licence.
; 
; This source code has been made available to You without any warranties
; whatsoever. Consequently, Your use, modification and distribution of this
; source code is entirely at Your own risk and neither Castle, its licensors
; nor any other person who has contributed to this source code shall be
; liable to You for any loss or damage which You may suffer as a result of
; Your use, modification or distribution of this source code.
; 
; Full details of Your rights and obligations are set out in the Licence.
; You should have received a copy of the Licence with this source code file.
; If You have not received a copy, the text of the Licence is available
; online at www.castle-technology.co.uk/riscosbaselicence.htm
; 
        SUBT    Inter.s.HelpSrc

        [ international_help
Alphabet_Help     DCB "HINTALP", 0
Alphabet_Syntax   DCB "SINTALP", 0
Country_Help      DCB "HINTCTY", 0
Country_Syntax    DCB "SINTCTY", 0
Keyboard_Help     DCB "HINTKBD", 0
Keyboard_Syntax   DCB "SINTKBD", 0
ConCountry_Help   DCB "HINTCCT", 0
ConCountry_Syntax DCB "SINTCCT", 0
Alphabets_Help    DCB "HINTALS", 0
Alphabets_Syntax  DCB "SINTALS", 0
Countries_Help    DCB "HINTCTS", 0
Countries_Syntax  DCB "SINTCTS", 0
        |
Alphabet_Help
                   ;= "*Alphabet with no parameter displays the currently selected alphabet.", 13
     =  "*Alphabet with no ",TokenEscapeChar,Token36
     =  TokenEscapeChar,Token32,TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5,"ly selected alphabet.", 13,"Type *Al"
     =  "phabets",TokenEscapeChar,Token40,"list available alphabets.", 13
                   ;= "Type *Alphabets to list available alphabets.", 13
Alphabet_Syntax
                   ;= "Syntax: *Alphabet [<country name> | <alphabet name>]", 0
     =  "Syntax: *Alphabet [<country ",TokenEscapeChar,Token11,"> | <a"
     =  "lphabet ",TokenEscapeChar,Token11,">]",  0
Country_Help
                   ;= "*Country sets the appropriate alphabet and keyboard driver for a particular country.", 13
     =  "*Country ",TokenEscapeChar,Token19,"appropriate alphabet"
     =  TokenEscapeChar,Token16,"keyboard driver for a particular cou"
     =  "ntry.", 13,"*Country with no ",TokenEscapeChar,Token36
     =  TokenEscapeChar,Token32,TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5,"ly selected country.", 13
                   ;= "*Country with no parameter displays the currently selected country.", 13
Country_Syntax
                   ;= "Syntax: *Country [<country name>]", 0
     =  "Syntax: *Country [<country ",TokenEscapeChar,Token11,">]",  0
Keyboard_Help
                   ;= "*Keyboard with no parameter displays the currently selected keyboard.", 13
     =  "*Keyboard with no ",TokenEscapeChar,Token36
     =  TokenEscapeChar,Token32,TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5,"ly selected keyboard.", 13,"Type *Co"
     =  "untries",TokenEscapeChar,Token40,"list available countries.", 13
                   ;= "Type *Countries to list available countries.", 13
Keyboard_Syntax
                   ;= "Syntax: *Keyboard [<country name>]", 0
     =  "Syntax: *Keyboard [<country ",TokenEscapeChar,Token11,">]",  0
ConCountry_Help
                   ;= "*Configure Country controls which country setting the computer will use on a "
     =  TokenEscapeChar,Token10,"Country controls which country setti"
     =  "ng",TokenEscapeChar,Token2,"computer will use on a hard rese"
     =  "t, which in turn determines which alphabet"
     =  TokenEscapeChar,Token16,"keyboard driver",TokenEscapeChar,Token41
     =  "used.", 13,"Type *Countries",TokenEscapeChar,Token40,"list av"
     =  "ailable countries.", 13
                   ;= "hard reset, which in turn determines which alphabet and keyboard driver is used.", 13
                   ;= "Type *Countries to list available countries.", 13
ConCountry_Syntax
                   ;= "Syntax: *Configure Country <country name>", 0
     =  "Syntax: ",TokenEscapeChar,Token10,"Country <country "
     =  TokenEscapeChar,Token11,">",  0
Alphabets_Help
                   ;= "*Alphabets lists the available alphabets.", 13
     =  "*Alphabets lists",TokenEscapeChar,Token2,"available alphabet"
     =  "s.", 13
Alphabets_Syntax
                   ;= "Syntax: *Alphabets", 0 
     =  "Syntax: *Alphabets",  0
Countries_Help
                   ;= "*Countries lists the available countries.", 13
     =  "*Countries lists",TokenEscapeChar,Token2,"available countrie"
     =  "s.", 13
Countries_Syntax
                   ;= "Syntax: *Countries", 0
     =  "Syntax: *Countries",  0
        ]

        END
