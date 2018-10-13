LLKS    SETA    0
LLK     SETS    "DCB"
KeyStructPC10
        &       KeyTranPC10-KeyStructPC10
        &       ((KeyTranPC10End-KeyTranPC10) :SHR: (LLKS+2))
        &       InkeyTranPC-KeyStructPC10
        &       ShiftingKeyList-KeyStructPC10
        &       SpecialListPC10-KeyStructPC10
        &       SpecialCodeTable-KeyStructPC10
        &       KeyStructInit-KeyStructPC10
        &       PendingAltCode-KeyStructPC10
        &       &00000000
        &       PadKNumTran-KeyStructPC10-((SpecialListPC10Pad-SpecialListPC10):SHR:LLKS)
        &       PadKCurTran-KeyStructPC10-((SpecialListPC10Pad-SpecialListPC10):SHR:LLKS)
        &       0
        &       UCSTablePC10_0-KeyStructPC10-((SpecialListPC10UCS-SpecialListPC10):SHR:LLKS)*36
        &       UCSTablePC10_0-KeyStructPC10-((SpecialListPC10UCS-SpecialListPC10):SHR:LLKS)*36

KeyTranPC10
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
        $LLK    &31, &21, &01, &01
        $LLK    &32, &22, &00, &00
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &34, &24, &04, &04
        $LLK    &35, &25, &05, &05
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &37, &2F, &07, &07
        $LLK    &38, &28, &08, &08
        $LLK    &39, &29, &09, &09
        $LLK    &30, &3D, &00, &00
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &2B, &2A, &FF, &FF
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
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &27, &22, &FF, &FF
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
        $LLK    &2C, &3B, &FF, &FF
        $LLK    &2E, &3A, &FF, &FF
        $LLK    &2D, &5F, &1F, &1F
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
KeyTranPC10End


SpecialListPC10
        $LLK    ((SpecialListPC10End - SpecialListPC10) :SHR: LLKS) - 1
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
SpecialListPC10Pad
        $LLK    KeyNo_NumPadSlash, KeyNo_NumPadStar, KeyNo_NumPadHash
        $LLK    KeyNo_NumPad7, KeyNo_NumPad8, KeyNo_NumPad9, KeyNo_NumPadMinus
        $LLK    KeyNo_NumPad4, KeyNo_NumPad5, KeyNo_NumPad6, KeyNo_NumPadPlus
        $LLK    KeyNo_NumPad1, KeyNo_NumPad2, KeyNo_NumPad3
        $LLK    KeyNo_NumPad0, KeyNo_NumPadDot, KeyNo_NumPadEnter
        $LLK    KeyNo_ScrollLock
        $LLK    KeyNo_NumLock
        $LLK    KeyNo_Tab
        $LLK    KeyNo_CapsLock
SpecialListPC10UCS
        $LLK    &01, &02, &0C, &10, &13, &16, &1B, &1D
        $LLK    &27, &28, &29, &2A, &2B, &2C, &2D, &2E
        $LLK    &2F, &30, &31, &32, &33, &34, &3C, &3D
        $LLK    &3E, &3F, &40, &41, &42, &43, &44, &45
        $LLK    &4D, &4E, &4F, &50, &51, &52, &53, &54
        $LLK    &5F
SpecialListPC10End
        ALIGN
        ASSERT ((SpecialListPC10End-SpecialListPC10):SHR:LLKS)-1 <= (SpecialCodeTableEnd-SpecialCodeTable):SHR:2

UCSTablePC10_0
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &000000BD,&000000B1,&0000001C,&0000001C ; &10
        &       &0000005C,&0000007C,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&000000A3,&00000003,&00000003 ; &13
        &       &FFFFFFFF,&00000023,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000036,&000000AC,&00000006,&00000006 ; &16
        &       &FFFFFFFF,&00000026,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000007C,&000000B0,&FFFFFFFF,&FFFFFFFF ; &1B
        &       &FFFFFFFF,&0000003F,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000A3,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002E,&0000002D,&00000011,&00000011 ; &27
        &       &00000071,&00000051,&FFFFFFFF,&FFFFFFFF, &76C53210
        &       &000003C2,&0000007C,&00000017,&00000017 ; &28
        &       &00000077,&00000057,&FFFFFFFF,&FFFFFFFF, &76C53210
        &       &000003B5,&00000395,&00000005,&00000005 ; &29
        &       &00000065,&00000045,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C1,&000003A1,&00000012,&00000012 ; &2A
        &       &00000072,&00000052,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C4,&000003A4,&00000014,&00000014 ; &2B
        &       &00000074,&00000054,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C5,&000003A5,&00000019,&00000019 ; &2C
        &       &00000079,&00000059,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003B8,&00000398,&00000015,&00000015 ; &2D
        &       &00000075,&00000055,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003B9,&00000399,&00000009,&00000009 ; &2E
        &       &00000069,&00000049,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003BF,&0000039F,&0000000F,&0000000F ; &2F
        &       &0000006F,&0000004F,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C0,&000003A0,&00000010,&00000010 ; &30
        &       &00000070,&00000050,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &0000005B,&000000AB,&0000001B,&0000001B ; &31
        &       &FFFFFFFF,&0000007B,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005D,&000000BB,&0000001D,&0000001D ; &32
        &       &FFFFFFFF,&0000007D,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000B2,&000000B3,&0000001E,&0000001E ; &33
        &       &0000005E,&00000040,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000003B1,&00000391,&00000001,&00000001 ; &3C
        &       &00000061,&00000041,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C3,&000003A3,&00000013,&00000013 ; &3D
        &       &00000073,&00000053,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003B4,&00000394,&00000004,&00000004 ; &3E
        &       &00000064,&00000044,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C6,&000003A6,&00000006,&00000006 ; &3F
        &       &00000066,&00000046,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003B3,&00000393,&00000007,&00000007 ; &40
        &       &00000067,&00000047,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003B7,&00000397,&00000008,&00000008 ; &41
        &       &00000068,&00000048,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003BE,&0000039E,&0000000A,&0000000A ; &42
        &       &0000006A,&0000004A,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003BA,&0000039A,&0000000B,&0000000B ; &43
        &       &0000006B,&0000004B,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003BB,&0000039B,&0000000C,&0000000C ; &44
        &       &0000006C,&0000004C,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &8002000C,&80020008,&FFFFFFFF,&FFFFFFFF ; &45
        &       &8002000F,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000003B6,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &4D
        &       &0000003C,&0000003E,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000003B6,&00000396,&0000001A,&0000001A ; &4E
        &       &0000007A,&0000005A,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C7,&000003A7,&00000018,&00000018 ; &4F
        &       &00000078,&00000058,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C8,&000003A8,&00000003,&00000003 ; &50
        &       &00000063,&00000043,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003C9,&000003A9,&00000016,&00000016 ; &51
        &       &00000076,&00000056,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003B2,&00000392,&00000002,&00000002 ; &52
        &       &00000062,&00000042,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003BD,&0000039D,&0000000E,&0000000E ; &53
        &       &0000006E,&0000004E,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &000003BC,&0000039C,&0000000D,&0000000D ; &54
        &       &0000006D,&0000004D,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000020,&00000020,&00000020,&00000020 ; &5F
        &       &000000A0,&000000A0,&FFFFFFFF,&FFFFFFFF, &76543210

        ALIGN

        END
