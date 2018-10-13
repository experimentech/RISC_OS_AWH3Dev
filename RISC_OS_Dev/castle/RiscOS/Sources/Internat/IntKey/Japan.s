LLKS    SETA    0
LLK     SETS    "DCB"
KeyStructPC32
        &       KeyTranPC32-KeyStructPC32
        &       ((KeyTranPC32End-KeyTranPC32) :SHR: (LLKS+2))
        &       InkeyTranPC-KeyStructPC32
        &       ShiftingKeyList-KeyStructPC32
        &       SpecialListPC32-KeyStructPC32
        &       SpecialCodeTablePC32-KeyStructPC32
        &       KeyStructInit-KeyStructPC32
        &       PendingAltCode-KeyStructPC32
        &       &00000000
        &       PadKNumTran-KeyStructPC32-((SpecialListPC32Pad-SpecialListPC32):SHR:LLKS)
        &       PadKCurTran-KeyStructPC32-((SpecialListPC32Pad-SpecialListPC32):SHR:LLKS)
        &       0
        &       UCSTablePC32_0-KeyStructPC32-((SpecialListPC32UCS-SpecialListPC32):SHR:LLKS)*36
        &       UCSTablePC32_1-KeyStructPC32-((SpecialListPC32UCS-SpecialListPC32):SHR:LLKS)*36

KeyTranPC32
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
        $LLK    &C5, &D5, &E5, &F5
KeyTranPC32End


SpecialListPC32
        $LLK    ((SpecialListPC32End - SpecialListPC32) :SHR: LLKS) - 1
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
SpecialListPC32Pad
        $LLK    KeyNo_NumPadSlash, KeyNo_NumPadStar, KeyNo_NumPadHash
        $LLK    KeyNo_NumPad7, KeyNo_NumPad8, KeyNo_NumPad9, KeyNo_NumPadMinus
        $LLK    KeyNo_NumPad4, KeyNo_NumPad5, KeyNo_NumPad6, KeyNo_NumPadPlus
        $LLK    KeyNo_NumPad1, KeyNo_NumPad2, KeyNo_NumPad3
        $LLK    KeyNo_NumPad0, KeyNo_NumPadDot, KeyNo_NumPadEnter
        $LLK    KeyNo_ScrollLock
        $LLK    KeyNo_Tab
SpecialListPC32UCS
        $LLK    &01, &02, &0C, &10, &11, &12, &13, &14
        $LLK    &15, &16, &17, &18, &19, &1A, &1B, &1C
        $LLK    &1D, &22, &27, &28, &29, &2A, &2B, &2C
        $LLK    &2D, &2E, &2F, &30, &31, &32, &33, &34
        $LLK    &3C, &3D, &3E, &3F, &40, &41, &42, &43
        $LLK    &44, &45, &46, &4E, &4F, &50, &51, &52
        $LLK    &53, &54, &55, &56, &57, &5D, &5F, &6C
        $LLK    &6D, &6E
SpecialListPC32End
        ALIGN

SpecialCodeTablePC32
        &       ProcessKShift - SpecialCodeTablePC32
        &       ProcessKShift - SpecialCodeTablePC32
        &       ProcessKCtrl - SpecialCodeTablePC32
        &       ProcessKCtrl - SpecialCodeTablePC32
        &       ProcessKAlt - SpecialCodeTablePC32
        &       ProcessKAlt - SpecialCodeTablePC32
        &       ProcessKFN - SpecialCodeTablePC32
        &       ProcessKLeft - SpecialCodeTablePC32
        &       ProcessKCentre - SpecialCodeTablePC32
        &       ProcessKRight - SpecialCodeTablePC32
        &       ProcessKBreak - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessK1Pad - SpecialCodeTablePC32
        &       ProcessKScroll - SpecialCodeTablePC32
        &       ProcessKTab - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32
        &       ProcessUCS - SpecialCodeTablePC32

UCSTablePC32_0
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &800000C2,&800000D2,&800000E2,&800000F2 ; &10
        &       &800000C3,&800000D3,&800000E3,&800000F3, &76543210
        &       &00000031,&00000021,&00000001,&00000001 ; &11
        &       &0000FF87,&0000FF87,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000032,&00000022,&00000002,&00000002 ; &12
        &       &0000FF8C,&0000FF8C,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&00000023,&00000003,&00000003 ; &13
        &       &0000FF71,&0000FF67,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000034,&00000024,&00000004,&00000004 ; &14
        &       &0000FF73,&0000FF69,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000035,&00000025,&00000005,&00000005 ; &15
        &       &0000FF74,&0000FF6A,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000036,&00000026,&00000006,&00000006 ; &16
        &       &0000FF75,&0000FF6B,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000037,&00000027,&00000007,&00000007 ; &17
        &       &0000FF94,&0000FF6C,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000038,&00000028,&00000008,&00000008 ; &18
        &       &0000FF95,&0000FF6D,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000039,&00000029,&00000009,&00000009 ; &19
        &       &0000FF96,&0000FF6E,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000030,&0000007E,&00000000,&00000000 ; &1A
        &       &0000FF9C,&0000FF66,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002D,&0000003D,&FFFFFFFF,&FFFFFFFF ; &1B
        &       &0000FF8E,&000000A3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005E,&0000203E,&0000001E,&0000001E ; &1C
        &       &0000FF8D,&00003005,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000A5,&0000007C,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &0000FF70,&000000AC,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010001,&80010001,&80010001,&80010001 ; &22
        &       &80010004,&80010004,&80010004,&80010004, &76543210
        &       &00000071,&00000051,&00000011,&00000011 ; &27
        &       &0000FF80,&0000FF80,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000077,&00000057,&00000017,&00000017 ; &28
        &       &0000FF83,&0000FF83,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000065,&00000045,&00000005,&00000005 ; &29
        &       &0000FF72,&0000FF68,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000072,&00000052,&00000012,&00000012 ; &2A
        &       &0000FF7D,&0000FF7D,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000074,&00000054,&00000014,&00000014 ; &2B
        &       &0000FF76,&0000FF76,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000079,&00000059,&00000019,&00000019 ; &2C
        &       &0000FF9D,&0000FF9D,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000075,&00000055,&00000015,&00000015 ; &2D
        &       &0000FF85,&0000FF85,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000069,&00000049,&00000009,&00000009 ; &2E
        &       &0000FF86,&0000FF86,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006F,&0000004F,&0000000F,&0000000F ; &2F
        &       &0000FF97,&0000FF97,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000070,&00000050,&00000010,&00000010 ; &30
        &       &0000FF7E,&0000300E,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000040,&00000060,&00000000,&00000000 ; &31
        &       &0000FF9E,&000000A2,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005B,&0000007B,&0000001B,&0000001B ; &32
        &       &0000FF9F,&0000FF62,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005D,&0000007D,&0000001D,&0000001D ; &33
        &       &0000FF91,&0000FF63,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000061,&00000041,&00000001,&00000001 ; &3C
        &       &0000FF81,&0000FF81,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000073,&00000053,&00000013,&00000013 ; &3D
        &       &0000FF84,&0000FF84,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000064,&00000044,&00000004,&00000004 ; &3E
        &       &0000FF7C,&0000FF7C,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000066,&00000046,&00000006,&00000006 ; &3F
        &       &0000FF8A,&0000FF8A,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000067,&00000047,&00000007,&00000007 ; &40
        &       &0000FF77,&0000FF77,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000068,&00000048,&00000008,&00000008 ; &41
        &       &0000FF78,&0000FF78,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006A,&0000004A,&0000000A,&0000000A ; &42
        &       &0000FF8F,&0000FF8F,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006B,&0000004B,&0000000B,&0000000B ; &43
        &       &0000FF89,&0000FF89,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006C,&0000004C,&0000000C,&0000000C ; &44
        &       &0000FF98,&0000FF98,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000003B,&0000002B,&FFFFFFFF,&FFFFFFFF ; &45
        &       &0000FF9A,&0000300F,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000003A,&0000002A,&FFFFFFFF,&FFFFFFFF ; &46
        &       &0000FF79,&000030F6,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000007A,&0000005A,&0000001A,&0000001A ; &4E
        &       &0000FF82,&0000FF6F,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000078,&00000058,&00000018,&00000018 ; &4F
        &       &0000FF7B,&0000FF7B,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000063,&00000043,&00000003,&00000003 ; &50
        &       &0000FF7F,&0000FF7F,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000076,&00000056,&00000016,&00000016 ; &51
        &       &0000FF8B,&0000FF8B,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000062,&00000042,&00000002,&00000002 ; &52
        &       &0000FF7A,&0000FF7A,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006E,&0000004E,&0000000E,&0000000E ; &53
        &       &0000FF90,&0000FF90,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006D,&0000004D,&0000000D,&0000000D ; &54
        &       &0000FF93,&0000FF93,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000002C,&0000003C,&FFFFFFFF,&FFFFFFFF ; &55
        &       &0000FF88,&0000FF64,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002E,&0000003E,&FFFFFFFF,&FFFFFFFF ; &56
        &       &0000FF99,&0000FF61,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002F,&0000003F,&FFFFFFFF,&FFFFFFFF ; &57
        &       &0000FF92,&0000FF65,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &800000C4,&80010005,&800000E4,&800000F4 ; &5D
        &       &800000C9,&800000D9,&800000E9,&800000F9, &76543210
        &       &00000020,&00000020,&00000020,&00000020 ; &5F
        &       &000000A0,&000000A0,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &800000C6,&800000D6,&800000E6,&800000F6 ; &6C
        &       &800000C8,&800000D8,&800000E8,&800000F8, &76543210
        &       &800000C7,&800000D7,&800000E7,&800000F7 ; &6D
        &       &80010004,&80010004,&80010004,&80010004, &76543210
        &       &0000005C,&0000005F,&0000001C,&0000001F ; &6E
        &       &0000FF9B,&000000A6,&FFFFFFFF,&FFFFFFFF, &76543210

UCSTablePC32_1
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &800000C2,&800000D2,&800000E2,&800000F2 ; &10
        &       &800000C3,&800000D3,&800000E3,&800000F3, &76543210
        &       &0000306C,&0000306C,&FFFFFFFF,&FFFFFFFF ; &11
        &       &000030CC,&000030CC,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003075,&00003075,&FFFFFFFF,&FFFFFFFF ; &12
        &       &000030D5,&000030D5,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003042,&00003041,&FFFFFFFF,&FFFFFFFF ; &13
        &       &000030A2,&000030A1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003046,&00003045,&FFFFFFFF,&FFFFFFFF ; &14
        &       &000030A6,&000030A5,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003048,&00003047,&FFFFFFFF,&FFFFFFFF ; &15
        &       &000030A8,&000030A7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000304A,&00003049,&FFFFFFFF,&FFFFFFFF ; &16
        &       &000030AA,&000030A9,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003084,&00003083,&FFFFFFFF,&FFFFFFFF ; &17
        &       &000030E4,&000030E3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003086,&00003085,&FFFFFFFF,&FFFFFFFF ; &18
        &       &000030E6,&000030E5,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003088,&00003087,&FFFFFFFF,&FFFFFFFF ; &19
        &       &000030E8,&000030E7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000308F,&00003092,&FFFFFFFF,&FFFFFFFF ; &1A
        &       &000030EF,&000030F2,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000307B,&000000A3,&FFFFFFFF,&FFFFFFFF ; &1B
        &       &000030DB,&000000A3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003078,&00003005,&0000001E,&0000001E ; &1C
        &       &000030D8,&00003005,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000030FC,&000000AC,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &000030FC,&000000AC,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010001,&80010001,&80010001,&80010001 ; &22
        &       &80010004,&80010004,&80010004,&80010004, &76543210
        &       &0000305F,&0000305F,&00000011,&00000011 ; &27
        &       &000030BF,&000030BF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003066,&00003066,&00000017,&00000017 ; &28
        &       &000030C6,&000030C6,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003044,&00003043,&00000005,&00000005 ; &29
        &       &000030A4,&000030A3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003059,&00003059,&00000012,&00000012 ; &2A
        &       &000030B9,&000030B9,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000304B,&0000304B,&00000014,&00000014 ; &2B
        &       &000030AB,&000030AB,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003093,&00003093,&00000019,&00000019 ; &2C
        &       &000030F3,&000030F3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000306A,&0000306A,&00000015,&00000015 ; &2D
        &       &000030CA,&000030CA,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000306B,&0000306B,&00000009,&00000009 ; &2E
        &       &000030CB,&000030CB,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003089,&00003089,&0000000F,&0000000F ; &2F
        &       &000030E9,&000030E9,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000305B,&0000300E,&00000010,&00000010 ; &30
        &       &000030BB,&0000300E,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003099,&000000A2,&00000000,&00000000 ; &31
        &       &00003099,&000000A2,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000309A,&0000300C,&0000001B,&0000001B ; &32
        &       &0000309A,&0000300C,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003080,&0000300D,&0000001D,&0000001D ; &33
        &       &000030E0,&0000300D,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003061,&00003061,&00000001,&00000001 ; &3C
        &       &000030C1,&000030C1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003068,&00003068,&00000013,&00000013 ; &3D
        &       &000030C8,&000030C8,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003057,&00003057,&00000004,&00000004 ; &3E
        &       &000030B7,&000030B7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000306F,&0000306F,&00000006,&00000006 ; &3F
        &       &000030CF,&000030CF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000304D,&0000304D,&00000007,&00000007 ; &40
        &       &000030AD,&000030AD,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000304F,&0000304F,&00000008,&00000008 ; &41
        &       &000030AF,&000030AF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000307E,&0000307E,&0000000A,&0000000A ; &42
        &       &000030DE,&000030DE,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000306E,&0000306E,&0000000B,&0000000B ; &43
        &       &000030CE,&000030CE,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000308A,&0000308A,&0000000C,&0000000C ; &44
        &       &000030EA,&000030EA,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000308C,&0000300F,&FFFFFFFF,&FFFFFFFF ; &45
        &       &000030EC,&0000300F,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003051,&000030F6,&FFFFFFFF,&FFFFFFFF ; &46
        &       &000030B1,&000030F6,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003064,&00003063,&0000001A,&0000001A ; &4E
        &       &000030C4,&000030C3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003055,&00003055,&00000018,&00000018 ; &4F
        &       &000030B5,&000030B5,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000305D,&0000305D,&00000003,&00000003 ; &50
        &       &000030BD,&000030BD,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003072,&00003072,&00000016,&00000016 ; &51
        &       &000030D2,&000030D2,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003053,&00003053,&00000002,&00000002 ; &52
        &       &000030B3,&000030B3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000307F,&0000307F,&0000000E,&0000000E ; &53
        &       &000030DF,&000030DF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003082,&00003082,&0000000D,&0000000D ; &54
        &       &000030E2,&000030E2,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000306D,&00003001,&FFFFFFFF,&FFFFFFFF ; &55
        &       &000030CD,&00003001,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000308B,&00003002,&FFFFFFFF,&FFFFFFFF ; &56
        &       &000030EB,&00003002,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00003081,&000030FB,&FFFFFFFF,&FFFFFFFF ; &57
        &       &000030E1,&000030FB,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &800000C4,&800000D4,&800000E4,&800000F4 ; &5D
        &       &800000C9,&800000D9,&800000E9,&800000F9, &76543210
        &       &00003000,&00003000,&00003000,&00003000 ; &5F
        &       &00003000,&00003000,&00003000,&00003000, &76543210
        &       &800000C6,&800000D6,&800000E6,&800000F6 ; &6C
        &       &800000C8,&800000D8,&800000E8,&800000F8, &76543210
        &       &800000C7,&800000D7,&800000E7,&800000F7 ; &6D
        &       &80010004,&80010004,&80010004,&80010004, &76543210
        &       &0000308D,&000000A6,&0000001C,&0000001F ; &6E
        &       &000030ED,&000000A6,&FFFFFFFF,&FFFFFFFF, &76543210

        ALIGN

        END
