     TTL ==> s.TokHelpSrc

        SUBT    => <wini>arm.Sound0.HelpSrc

 [ International_Help = 0
Audio_Help
         ;=       "*",TokenEscapeChar,Token0
     =  "*",TokenEscapeChar,Token0," controls",TokenEscapeChar,Token2
     =  "sound system.", 13
         ;=       " controls the sound system.", 13
Audio_Syntax
         ;=       "Syntax: *",TokenEscapeChar,Token0
     =  TokenEscapeChar,Token1," On|Off",  0
         ;=       " On|Off",0

Speaker_Help
         ;=       "*",TokenEscapeChar,Token0
     =  "*",TokenEscapeChar,Token0," controls",TokenEscapeChar,Token2
     =  "loudspeaker.", 13
         ;=       " controls the loudspeaker.", 13
Speaker_Syntax
         ;=       "Syntax: *",TokenEscapeChar,Token0
     =  TokenEscapeChar,Token1," On|Off",  0
         ;=       " On|Off",0

Stereo_Help
         ;=       "*",TokenEscapeChar,Token0
     =  "*",TokenEscapeChar,Token0," ",TokenEscapeChar,Token19,"ster"
     =  "eo posi",TokenEscapeChar,Token9," of a sound channel.", 13
         ;=       " sets the stereo position of a sound channel.", 13
Stereo_Syntax
         ;=       "Syntax: *",TokenEscapeChar,Token0
     =  TokenEscapeChar,Token14,"chan> <pos> where <chan>"
     =  TokenEscapeChar,Token41,"1-8, <pos>",TokenEscapeChar,Token41
     =  "-127(L)",TokenEscapeChar,Token40,"127(R) (0 for centre)",  0
         ;=       " <chan> <pos>"
         ;=       " where <chan> is 1-8, <pos> is -127(L) to 127(R) (0 for centre)",0
SoundGain_Help
         ;=       "*",TokenEscapeChar,Token0
     =  "*",TokenEscapeChar,Token0," ",TokenEscapeChar,Token19,"gain"
     =  " for 8-bit mu-law",TokenEscapeChar,Token40,"16-bit linear sou"
     =  "nd conversion.", 13
         ;=       " sets the gain for 8-bit mu-law to 16-bit linear sound conversion.", 13
SoundGain_Syntax
         ;=       "Syntax: *",TokenEscapeChar,Token0
     =  TokenEscapeChar,Token14,"gain> where <gain>"
     =  TokenEscapeChar,Token41,"0-7 for 0dB (default)"
     =  TokenEscapeChar,Token40,"+21dB gain, in 3dB steps",  0
         ;=       " <gain>"
         ;=       " where <gain> is 0-7 for 0dB (default) to +21dB gain, in 3dB steps",0

SoundSystem_Help
         ;=       "*Configure ",TokenEscapeChar,Token0
     =  TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  TokenEscapeChar,Token19,TokenEscapeChar,Token8,"sound syst"
     =  "em.", 13
         ;=       " sets the default sound system.", 13
SoundSystem_Syntax
         ;=       "Syntax: *Configure ",TokenEscapeChar,Token0," 8bit | 16bit [Oversampled] | <0-7>",0
     =  "Syntax: ",TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  "8bit | 16bit [Oversampled] | <0-7>",  0

        ALIGN
 |
Audio_Help      DCB     "HSDMAUD", 0
Audio_Syntax    DCB     "SSDMAUD", 0
Speaker_Help    DCB     "HSDMSPK", 0
Speaker_Syntax  DCB     "SSDMSPK", 0
Stereo_Help     DCB     "HSDMSTR", 0
Stereo_Syntax   DCB     "SSDMSTR", 0
SoundGain_Help  DCB     "HSDMSDG", 0
SoundGain_Syntax DCB    "SSDMSDG", 0
SoundSystem_Help DCB    "HSDMSDS", 0
SoundSystem_Syntax DCB  "SSDMSDS", 0
 ]

        END
