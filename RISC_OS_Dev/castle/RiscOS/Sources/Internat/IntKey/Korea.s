LLKS    SETA    0
LLK     SETS    "DCB"
KeyStructPC53
        &       KeyTranPC53-KeyStructPC53
        &       ((KeyTranPC53End-KeyTranPC53) :SHR: (LLKS+2))
        &       InkeyTranPC-KeyStructPC53
        &       ShiftingKeyList-KeyStructPC53
        &       SpecialListPC53-KeyStructPC53
        &       SpecialCodeTablePC53-KeyStructPC53
        &       KeyStructInit-KeyStructPC53
        &       PendingAltCode-KeyStructPC53
        &       &00000000
        &       PadKNumTran-KeyStructPC53-((SpecialListPC53Pad-SpecialListPC53):SHR:LLKS)
        &       PadKCurTran-KeyStructPC53-((SpecialListPC53Pad-SpecialListPC53):SHR:LLKS)
        &       0
        &       UCSTablePC53_0-KeyStructPC53-((SpecialListPC53UCS-SpecialListPC53):SHR:LLKS)*36
        &       UCSTablePC53_1-KeyStructPC53-((SpecialListPC53UCS-SpecialListPC53):SHR:LLKS)*36

KeyTranPC53
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
        $LLK    &37, &26, &07, &07
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
        $LLK    &C6, &D6, &E6, &F6
KeyTranPC53End


SpecialListPC53
        $LLK    ((SpecialListPC53End - SpecialListPC53) :SHR: LLKS) - 1
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
SpecialListPC53Pad
        $LLK    KeyNo_NumPadSlash, KeyNo_NumPadStar, KeyNo_NumPadHash
        $LLK    KeyNo_NumPad7, KeyNo_NumPad8, KeyNo_NumPad9, KeyNo_NumPadMinus
        $LLK    KeyNo_NumPad4, KeyNo_NumPad5, KeyNo_NumPad6, KeyNo_NumPadPlus
        $LLK    KeyNo_NumPad1, KeyNo_NumPad2, KeyNo_NumPad3
        $LLK    KeyNo_NumPad0, KeyNo_NumPadDot, KeyNo_NumPadEnter
        $LLK    KeyNo_ScrollLock
        $LLK    KeyNo_Tab
        $LLK    KeyNo_CapsLock
SpecialListPC53UCS
        $LLK    &01, &02, &0C, &10, &11, &12, &13, &14
        $LLK    &15, &16, &18, &19, &1A, &1B, &1C, &1D
        $LLK    &22, &27, &28, &29, &2A, &2B, &2C, &2D
        $LLK    &2E, &2F, &30, &31, &32, &33, &34, &3C
        $LLK    &3D, &3E, &3F, &40, &41, &42, &43, &44
        $LLK    &45, &46, &4E, &4F, &50, &51, &52, &53
        $LLK    &54, &55, &56, &57, &5F, &6D
SpecialListPC53End
        ALIGN

SpecialCodeTablePC53
        &       ProcessKShift - SpecialCodeTablePC53
        &       ProcessKShift - SpecialCodeTablePC53
        &       ProcessKCtrl - SpecialCodeTablePC53
        &       ProcessKCtrl - SpecialCodeTablePC53
        &       ProcessKAlt - SpecialCodeTablePC53
        &       ProcessKAlt - SpecialCodeTablePC53
        &       ProcessKFN - SpecialCodeTablePC53
        &       ProcessKLeft - SpecialCodeTablePC53
        &       ProcessKCentre - SpecialCodeTablePC53
        &       ProcessKRight - SpecialCodeTablePC53
        &       ProcessKBreak - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessK1Pad - SpecialCodeTablePC53
        &       ProcessKScroll - SpecialCodeTablePC53
        &       ProcessKTab - SpecialCodeTablePC53
        &       ProcessKCaps - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53
        &       ProcessUCS - SpecialCodeTablePC53

UCSTablePC53_0
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &00000060,&0000007E,&FFFFFFFF,&FFFFFFFF ; &10
        &       &000000AC,&000000B0,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000031,&00000021,&00000001,&00000001 ; &11
        &       &000000B9,&000000A1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000032,&00000040,&00000000,&00000000 ; &12
        &       &000000B2,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&00000023,&00000003,&00000003 ; &13
        &       &000000B3,&000000A3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000034,&00000024,&00000004,&00000004 ; &14
        &       &000000BC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000035,&00000025,&00000005,&00000005 ; &15
        &       &000000BD,&00002030,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000036,&0000005E,&0000001E,&0000001E ; &16
        &       &000000BE,&000021D1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000038,&0000002A,&00000008,&00000008 ; &18
        &       &FFFFFFFF,&00002022,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000039,&00000028,&00000009,&00000009 ; &19
        &       &000002BB,&000000B1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000030,&00000029,&00000000,&00000000 ; &1A
        &       &000002BC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002D,&0000005F,&0000001F,&0000001F ; &1B
        &       &000000AD,&00002212,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000003D,&0000002B,&FFFFFFFF,&FFFFFFFF ; &1C
        &       &00002013,&00002014,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000A3,&000000A4,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010001,&80010001,&80010001,&80010001 ; &22
        &       &80010004,&80010004,&80010004,&80010004, &76543210
        &       &00000071,&00000051,&00000011,&00000011 ; &27
        &       &00000153,&00000152,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000077,&00000057,&00000017,&00000017 ; &28
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000065,&00000045,&00000005,&00000005 ; &29
        &       &000020AC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000072,&00000052,&00000012,&00000012 ; &2A
        &       &000000B6,&000000AE,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000074,&00000054,&00000014,&00000014 ; &2B
        &       &00002122,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000079,&00000059,&00000019,&00000019 ; &2C
        &       &FFFFFFFF,&000000A5,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000075,&00000055,&00000015,&00000015 ; &2D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000069,&00000049,&00000009,&00000009 ; &2E
        &       &0000FB01,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006F,&0000004F,&0000000F,&0000000F ; &2F
        &       &000000F8,&000000D8,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000070,&00000050,&00000010,&00000010 ; &30
        &       &000000FE,&000000DE,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &0000005B,&0000007B,&0000001B,&0000001B ; &31
        &       &80020002,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005D,&0000007D,&0000001D,&0000001D ; &32
        &       &80020001,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000020A9,&0000007C,&0000001C,&0000001C ; &33
        &       &0000005C,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000061,&00000041,&00000001,&00000001 ; &3C
        &       &000000E6,&000000C6,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000073,&00000053,&00000013,&00000013 ; &3D
        &       &000000DF,&000000A7,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000064,&00000044,&00000004,&00000004 ; &3E
        &       &000000F0,&000000D0,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000066,&00000046,&00000006,&00000006 ; &3F
        &       &FFFFFFFF,&000000AA,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000067,&00000047,&00000007,&00000007 ; &40
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000068,&00000048,&00000008,&00000008 ; &41
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006A,&0000004A,&0000000A,&0000000A ; &42
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006B,&0000004B,&0000000B,&0000000B ; &43
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006C,&0000004C,&0000000C,&0000000C ; &44
        &       &0000FB02,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000003B,&0000003A,&FFFFFFFF,&FFFFFFFF ; &45
        &       &80020008,&00002026,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000027,&00000022,&FFFFFFFF,&FFFFFFFF ; &46
        &       &80020003,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
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
        &       &0000002C,&0000003C,&FFFFFFFF,&FFFFFFFF ; &55
        &       &80020004,&000000D7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002E,&0000003E,&FFFFFFFF,&FFFFFFFF ; &56
        &       &80020006,&000000F7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002F,&0000003F,&FFFFFFFF,&FFFFFFFF ; &57
        &       &8002000D,&000000BF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000020,&00000020,&00000020,&00000020 ; &5F
        &       &000000A0,&000000A0,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010004,&80010004,&80010004,&80010004 ; &6D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210

UCSTablePC53_1
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &00000060,&0000007E,&FFFFFFFF,&FFFFFFFF ; &10
        &       &000000AC,&000000B0,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000031,&00000021,&00000001,&00000001 ; &11
        &       &000000B9,&000000A1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000032,&00000040,&00000000,&00000000 ; &12
        &       &000000B2,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&00000023,&00000003,&00000003 ; &13
        &       &000000B3,&000000A3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000034,&00000024,&00000004,&00000004 ; &14
        &       &000000BC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000035,&00000025,&00000005,&00000005 ; &15
        &       &000000BD,&00002030,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000036,&0000005E,&0000001E,&0000001E ; &16
        &       &000000BE,&000021D1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000038,&0000002A,&00000008,&00000008 ; &18
        &       &FFFFFFFF,&00002022,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000039,&00000028,&00000009,&00000009 ; &19
        &       &FFFFFFFF,&000000B1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000030,&00000029,&00000000,&00000000 ; &1A
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002D,&0000005F,&0000001F,&0000001F ; &1B
        &       &000000AD,&00002212,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000003D,&0000002B,&FFFFFFFF,&FFFFFFFF ; &1C
        &       &00002013,&00002014,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000A3,&000000A4,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010001,&80010001,&80010001,&80010001 ; &22
        &       &80010004,&80010004,&80010004,&80010004, &76543210
        &       &00003142,&00003143,&00000011,&00000011 ; &27
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003148,&00003149,&00000017,&00000017 ; &28
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003137,&00003138,&00000005,&00000005 ; &29
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003131,&00003132,&00000012,&00000012 ; &2A
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003145,&00003146,&00000014,&00000014 ; &2B
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000315B,&0000315B,&00000019,&00000019 ; &2C
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003155,&00003155,&00000015,&00000015 ; &2D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003151,&00003151,&00000009,&00000009 ; &2E
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003150,&00003152,&0000000F,&0000000F ; &2F
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003154,&00003156,&00000010,&00000010 ; &30
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005B,&0000007B,&0000001B,&0000001B ; &31
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005D,&0000007D,&0000001D,&0000001D ; &32
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000020A9,&0000007C,&0000001C,&0000001C ; &33
        &       &0000005C,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003141,&00003141,&00000001,&00000001 ; &3C
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003134,&00003134,&00000013,&00000013 ; &3D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003147,&00003147,&00000004,&00000004 ; &3E
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003139,&00003139,&00000006,&00000006 ; &3F
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000314E,&0000314E,&00000007,&00000007 ; &40
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003157,&00003157,&00000008,&00000008 ; &41
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003153,&00003153,&0000000A,&0000000A ; &42
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000314F,&0000314F,&0000000B,&0000000B ; &43
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003163,&00003163,&0000000C,&0000000C ; &44
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000003B,&0000003A,&FFFFFFFF,&FFFFFFFF ; &45
        &       &FFFFFFFF,&00002026,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000027,&00000022,&FFFFFFFF,&FFFFFFFF ; &46
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000314B,&0000314B,&0000001A,&0000001A ; &4E
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000314C,&0000314C,&00000018,&00000018 ; &4F
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000314A,&0000314A,&00000003,&00000003 ; &50
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000314D,&0000314D,&00000016,&00000016 ; &51
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003160,&00003160,&00000002,&00000002 ; &52
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000315C,&0000315C,&0000000E,&0000000E ; &53
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003161,&00003161,&0000000D,&0000000D ; &54
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002C,&0000003C,&FFFFFFFF,&FFFFFFFF ; &55
        &       &FFFFFFFF,&000000D7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002E,&0000003E,&FFFFFFFF,&FFFFFFFF ; &56
        &       &FFFFFFFF,&000000F7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002F,&0000003F,&FFFFFFFF,&FFFFFFFF ; &57
        &       &FFFFFFFF,&000000BF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000020,&00000020,&00000020,&00000020 ; &5F
        &       &800000C6,&800000D6,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010004,&80010004,&80010004,&80010004 ; &6D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210

        ALIGN

        END
