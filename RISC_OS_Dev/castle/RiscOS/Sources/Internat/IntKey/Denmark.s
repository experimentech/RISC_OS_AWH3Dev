LLKS    SETA    0
LLK     SETS    "DCB"
KeyStructPC14
        &       KeyTranPC14-KeyStructPC14
        &       ((KeyTranPC14End-KeyTranPC14) :SHR: (LLKS+2))
        &       InkeyTranPC-KeyStructPC14
        &       ShiftingKeyList-KeyStructPC14
        &       SpecialListPC14-KeyStructPC14
        &       SpecialCodeTable-KeyStructPC14
        &       KeyStructInit-KeyStructPC14
        &       PendingAltCode-KeyStructPC14
        &       &00000000
        &       PadKPC14NumTran-KeyStructPC14-((SpecialListPC14Pad-SpecialListPC14):SHR:LLKS)
        &       PadKPC14CurTran-KeyStructPC14-((SpecialListPC14Pad-SpecialListPC14):SHR:LLKS)
        &       0
        &       UCSTablePC14_0-KeyStructPC14-((SpecialListPC14UCS-SpecialListPC14):SHR:LLKS)*36
        &       UCSTablePC14_0-KeyStructPC14-((SpecialListPC14UCS-SpecialListPC14):SHR:LLKS)*36

KeyTranPC14
        $LLK    &1B, &1B, &1B, &1B
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &83, &93, &A3, &B3
        $LLK    &84, &94, &A4, &B4
        $LLK    &85, &95, &A5, &B5
        $LLK    &86, &96, &A6, &B6
        $LLK    &87, &97, &A7, &B7
        $LLK    &88, &98, &A8, &B8
        $LLK    &89, &99, &A9, &B9
        $LLK    &CA, &DA, &EA, &FA
        $LLK    &CB, &DB, &EB, &FB
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &80, &90, &A0, &B0
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &35, &25, &05, &05
        $LLK    &36, &26, &06, &06
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &08, &08, &08, &08
        $LLK    &CD, &DD, &ED, &FD
        $LLK    &1E, &1E, &1E, &1E
        $LLK    &9F, &8F, &BF, &AF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &77, &57, &17, &17
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &75, &55, &15, &15
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &6F, &4F, &0F, &0F
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &8B, &9B, &AB, &BB
        $LLK    &9E, &8E, &BE, &AE
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &61, &41, &01, &01
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &67, &47, &07, &07
        $LLK    &68, &48, &08, &08
        $LLK    &6A, &4A, &0A, &0A
        $LLK    &6B, &4B, &0B, &0B
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &0D, &0D, &0D, &0D
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &8F, &9F, &AF, &BF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &8C, &9C, &AC, &BC
        $LLK    &8E, &9E, &AE, &BE
        $LLK    &8D, &9D, &AD, &BD
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &C0, &D0, &E0, &F0
        $LLK    &D0, &C0, &F0, &E0
        $LLK    &C1, &D1, &E1, &F1
KeyTranPC14End


SpecialListPC14
        $LLK    ((SpecialListPC14End - SpecialListPC14) :SHR: LLKS) - 1
        $LLK    KeyNo_ShiftLeft
        $LLK    KeyNo_ShiftRight
        $LLK    KeyNo_CtrlLeft
        $LLK    KeyNo_CtrlRight
        $LLK    KeyNo_AltLeft
        $LLK    KeyNo_AltRight
        $LLK    KeyNo_FN
        $LLK    KeyNo_LeftMouse
        $LLK    KeyNo_CentreMouse
        $LLK    KeyNo_RightMouse
        $LLK    KeyNo_Break
SpecialListPC14Pad
        $LLK    KeyNo_NumPadSlash, KeyNo_NumPadStar, KeyNo_NumPadHash
        $LLK    KeyNo_NumPad7, KeyNo_NumPad8, KeyNo_NumPad9, KeyNo_NumPadMinus
        $LLK    KeyNo_NumPad4, KeyNo_NumPad5, KeyNo_NumPad6, KeyNo_NumPadPlus
        $LLK    KeyNo_NumPad1, KeyNo_NumPad2, KeyNo_NumPad3
        $LLK    KeyNo_NumPad0, KeyNo_NumPadDot, KeyNo_NumPadEnter
        $LLK    KeyNo_ScrollLock
        $LLK    KeyNo_NumLock
        $LLK    KeyNo_Tab
        $LLK    KeyNo_CapsLock
SpecialListPC14UCS
        $LLK    &01, &02, &0C, &10, &11, &12, &13, &14
        $LLK    &17, &18, &19, &1A, &1B, &1C, &27, &29
        $LLK    &2A, &2B, &2C, &2E, &30, &31, &32, &33
        $LLK    &34, &3D, &3E, &3F, &44, &45, &46, &4D
        $LLK    &4E, &4F, &50, &51, &52, &53, &54, &55
        $LLK    &56, &57, &5F
SpecialListPC14End
        ALIGN
        ASSERT ((SpecialListPC14End-SpecialListPC14):SHR:LLKS)-1 <= (SpecialCodeTableEnd-SpecialCodeTable):SHR:2

UCSTablePC14_0
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &000000BD,&000000A7,&FFFFFFFF,&FFFFFFFF ; &10
        &       &000000AC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000031,&00000021,&00000001,&00000001 ; &11
        &       &000000B9,&000000A1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000032,&00000022,&00000000,&00000000 ; &12
        &       &00000040,&000000B2,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&00000023,&00000003,&00000003 ; &13
        &       &000000A3,&000000B3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000034,&000000A4,&00000004,&00000004 ; &14
        &       &00000024,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000037,&0000002F,&00000007,&00000007 ; &17
        &       &0000007B,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000038,&00000028,&0000001B,&0000001B ; &18
        &       &0000005B,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000039,&00000029,&0000001D,&0000001D ; &19
        &       &0000005D,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000030,&0000003D,&00000000,&00000000 ; &1A
        &       &0000007D,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002B,&0000003F,&FFFFFFFF,&FFFFFFFF ; &1B
        &       &FFFFFFFF,&000000BF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80020002,&80020001,&FFFFFFFF,&FFFFFFFF ; &1C
        &       &0000007C,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000071,&00000051,&00000011,&00000011 ; &27
        &       &00000153,&00000152,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000065,&00000045,&00000005,&00000005 ; &29
        &       &000020AC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000072,&00000052,&00000012,&00000012 ; &2A
        &       &000000B6,&000000AE,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000074,&00000054,&00000014,&00000014 ; &2B
        &       &00002122,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000079,&00000059,&00000019,&00000019 ; &2C
        &       &FFFFFFFF,&000000A5,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000069,&00000049,&00000009,&00000009 ; &2E
        &       &0000FB01,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000070,&00000050,&00000010,&00000010 ; &30
        &       &000000FE,&000000DE,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000000E5,&000000C5,&FFFFFFFF,&FFFFFFFF ; &31
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &80020008,&80020003,&0000001E,&0000001E ; &32
        &       &80020004,&000021D1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000027,&0000002A,&FFFFFFFF,&FFFFFFFF ; &33
        &       &FFFFFFFF,&00002022,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000073,&00000053,&00000013,&00000013 ; &3D
        &       &000000DF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000064,&00000044,&00000004,&00000004 ; &3E
        &       &000000F0,&000000D0,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000066,&00000046,&00000006,&00000006 ; &3F
        &       &FFFFFFFF,&000000AA,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006C,&0000004C,&0000000C,&0000000C ; &44
        &       &0000FB02,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &000000E6,&000000C6,&FFFFFFFF,&FFFFFFFF ; &45
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &000000F8,&000000D8,&FFFFFFFF,&FFFFFFFF ; &46
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000003C,&0000003E,&0000001C,&0000001C ; &4D
        &       &0000005C,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000007A,&0000005A,&0000001A,&0000001A ; &4E
        &       &000000AB,&00002039,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000078,&00000058,&00000018,&00000018 ; &4F
        &       &000000BB,&0000203A,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000063,&00000043,&00000003,&00000003 ; &50
        &       &000000A2,&000000A9,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000076,&00000056,&00000016,&00000016 ; &51
        &       &00002018,&0000201C,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000062,&00000042,&00000002,&00000002 ; &52
        &       &00002019,&0000201D,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006E,&0000004E,&0000000E,&0000000E ; &53
        &       &FFFFFFFF,&0000201E,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006D,&0000004D,&0000000D,&0000000D ; &54
        &       &000000B5,&000000BA,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000002C,&0000003B,&FFFFFFFF,&FFFFFFFF ; &55
        &       &FFFFFFFF,&000000D7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002E,&0000003A,&FFFFFFFF,&FFFFFFFF ; &56
        &       &FFFFFFFF,&000000F7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002D,&0000005F,&0000001F,&0000001F ; &57
        &       &000000AD,&00002212,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000020,&00000020,&00000020,&00000020 ; &5F
        &       &000000A0,&000000A0,&FFFFFFFF,&FFFFFFFF, &76543210

PadKPC14NumTran
        =       &2F, &2A, &23, &37, &38, &39, &2D, &34
        =       &35, &36, &2B, &31, &32, &33, &30, &2C
        =       &0D
PadKPC14CurTran
        =       &2F, &2A, &23, &1E, &8F, &9F, &2D, &8C
        =       &FF, &8D, &2B, &8B, &8E, &9E, &CD, &7F
        =       &0D

        ALIGN

        END
