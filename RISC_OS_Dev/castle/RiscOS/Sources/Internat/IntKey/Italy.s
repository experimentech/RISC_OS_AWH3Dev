LLKS    SETA    0
LLK     SETS    "DCB"
KeyStructPC4
        &       KeyTranPC4-KeyStructPC4
        &       ((KeyTranPC4End-KeyTranPC4) :SHR: (LLKS+2))
        &       InkeyTranPC-KeyStructPC4
        &       ShiftingKeyList-KeyStructPC4
        &       SpecialListPC4-KeyStructPC4
        &       SpecialCodeTable-KeyStructPC4
        &       KeyStructInit-KeyStructPC4
        &       PendingAltCode-KeyStructPC4
        &       &00000000
        &       PadKNumTran-KeyStructPC4-((SpecialListPC4Pad-SpecialListPC4):SHR:LLKS)
        &       PadKCurTran-KeyStructPC4-((SpecialListPC4Pad-SpecialListPC4):SHR:LLKS)
        &       0
        &       UCSTablePC4_0-KeyStructPC4-((SpecialListPC4UCS-SpecialListPC4):SHR:LLKS)*36
        &       UCSTablePC4_0-KeyStructPC4-((SpecialListPC4UCS-SpecialListPC4):SHR:LLKS)*36

KeyTranPC4
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
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &37, &2F, &07, &07
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &30, &3D, &00, &00
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
        $LLK    &FF, &FF, &FF, &FF
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
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &67, &47, &07, &07
        $LLK    &68, &48, &08, &08
        $LLK    &6A, &4A, &0A, &0A
        $LLK    &6B, &4B, &0B, &0B
        $LLK    &6C, &4C, &0C, &0C
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
KeyTranPC4End


SpecialListPC4
        $LLK    ((SpecialListPC4End - SpecialListPC4) :SHR: LLKS) - 1
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
SpecialListPC4Pad
        $LLK    KeyNo_NumPadSlash, KeyNo_NumPadStar, KeyNo_NumPadHash
        $LLK    KeyNo_NumPad7, KeyNo_NumPad8, KeyNo_NumPad9, KeyNo_NumPadMinus
        $LLK    KeyNo_NumPad4, KeyNo_NumPad5, KeyNo_NumPad6, KeyNo_NumPadPlus
        $LLK    KeyNo_NumPad1, KeyNo_NumPad2, KeyNo_NumPad3
        $LLK    KeyNo_NumPad0, KeyNo_NumPadDot, KeyNo_NumPadEnter
        $LLK    KeyNo_ScrollLock
        $LLK    KeyNo_NumLock
        $LLK    KeyNo_Tab
        $LLK    KeyNo_CapsLock
SpecialListPC4UCS
        $LLK    &01, &02, &0C, &10, &11, &12, &13, &14
        $LLK    &15, &16, &18, &19, &1B, &1C, &1D, &27
        $LLK    &29, &2A, &2B, &2C, &2E, &2F, &30, &31
        $LLK    &32, &33, &34, &3C, &3D, &3E, &3F, &45
        $LLK    &46, &4D, &4E, &4F, &50, &51, &52, &53
        $LLK    &54, &55, &56, &57, &5F
SpecialListPC4End
        ALIGN
        ASSERT ((SpecialListPC4End-SpecialListPC4):SHR:LLKS)-1 <= (SpecialCodeTableEnd-SpecialCodeTable):SHR:2

UCSTablePC4_0
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &0000005C,&0000007C,&0000001C,&0000001C ; &10
        &       &000000AC,&0000007E,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000031,&00000021,&00000001,&00000001 ; &11
        &       &000000B9,&000000A1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000032,&00000022,&00000002,&00000002 ; &12
        &       &000000B2,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&000000A3,&00000003,&00000003 ; &13
        &       &000000B3,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000034,&00000024,&00000004,&00000004 ; &14
        &       &000000BC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000035,&00000025,&00000005,&00000005 ; &15
        &       &000000BD,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000036,&00000026,&00000006,&00000006 ; &16
        &       &000000BE,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000038,&00000028,&00000008,&00000008 ; &18
        &       &FFFFFFFF,&00002022,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000039,&00000029,&00000009,&00000009 ; &19
        &       &FFFFFFFF,&000000B1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000027,&0000003F,&FFFFFFFF,&FFFFFFFF ; &1B
        &       &FFFFFFFF,&000000BF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000EC,&0000005E,&000000CC,&0000001E ; &1C
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543812
        &       &0000003C,&0000003E,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &FFFFFFFF,&000000A6,&FFFFFFFF,&FFFFFFFF, &76543210
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
        &       &00002020,&00002021,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006F,&0000004F,&0000000F,&0000000F ; &2F
        &       &000000F8,&000000D8,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000070,&00000050,&00000010,&00000010 ; &30
        &       &000000FE,&000000DE,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000000E8,&000000E9,&000000C8,&000000C9 ; &31
        &       &0000005B,&0000007B,&0000001B,&0000001B, &76549832
        &       &0000002B,&0000002A,&0000001D,&0000001D ; &32
        &       &0000005D,&0000007D,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000F9,&000000A7,&000000D9,&FFFFFFFF ; &33
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543812
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000061,&00000041,&00000001,&00000001 ; &3C
        &       &000000E6,&000000C6,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000073,&00000053,&00000013,&00000013 ; &3D
        &       &000000DF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000064,&00000044,&00000004,&00000004 ; &3E
        &       &000000F0,&000000D0,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000066,&00000046,&00000006,&00000006 ; &3F
        &       &FFFFFFFF,&000000AA,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &000000F2,&000000E7,&000000D2,&000000C7 ; &45
        &       &00000040,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76549832
        &       &000000E0,&000000B0,&000000C0,&FFFFFFFF ; &46
        &       &00000023,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543812
        &       &0000003C,&0000003E,&FFFFFFFF,&FFFFFFFF ; &4D
        &       &FFFFFFFF,&000000A6,&FFFFFFFF,&FFFFFFFF, &76543210
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

        ALIGN

        END
