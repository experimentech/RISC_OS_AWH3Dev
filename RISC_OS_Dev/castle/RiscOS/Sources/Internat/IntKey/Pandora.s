LLKS    SETA    1
LLK     SETS    "DCW"
KeyStructPandora1
        &       KeyTranPandora1-KeyStructPandora1
        &       ((KeyTranPandora1End-KeyTranPandora1) :SHR: (LLKS+2))+ KeyHandler_HasFlags
        &       InkeyTranPandoraW-KeyStructPandora1
        &       ShiftingKeyListW-KeyStructPandora1
        &       SpecialListPandora1-KeyStructPandora1
        &       SpecialCodeTable-KeyStructPandora1
        &       KeyStructInit-KeyStructPandora1
        &       PendingAltCode-KeyStructPandora1
        &       &00000001
        &       PadKNumTran-KeyStructPandora1-((SpecialListPandora1Pad-SpecialListPandora1):SHR:LLKS)
        &       PadKCurTran-KeyStructPandora1-((SpecialListPandora1Pad-SpecialListPandora1):SHR:LLKS)
        &       0
        &       UCSTablePandora1_0-KeyStructPandora1-((SpecialListPandora1UCS-SpecialListPandora1):SHR:LLKS)*36
        &       UCSTablePandora1_0-KeyStructPandora1-((SpecialListPandora1UCS-SpecialListPandora1):SHR:LLKS)*36

KeyTranPandora1
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
        $LLK    &30, &5D, &00, &00
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
        $LLK    &65, &45, &05, &05
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
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &0D, &0D, &0D, &0D
KeyTranPandora1End


SpecialListPandora1
        $LLK    ((SpecialListPandora1End - SpecialListPandora1) :SHR: LLKS) - 1
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
SpecialListPandora1Pad
        $LLK    KeyNo_NumPadSlash, KeyNo_NumPadStar, KeyNo_NumPadHash
        $LLK    KeyNo_NumPad7, KeyNo_NumPad8, KeyNo_NumPad9, KeyNo_NumPadMinus
        $LLK    KeyNo_NumPad4, KeyNo_NumPad5, KeyNo_NumPad6, KeyNo_NumPadPlus
        $LLK    KeyNo_NumPad1, KeyNo_NumPad2, KeyNo_NumPad3
        $LLK    KeyNo_NumPad0, KeyNo_NumPadDot, KeyNo_NumPadEnter
        $LLK    KeyNo_ScrollLock
        $LLK    KeyNo_NumLock
        $LLK    KeyNo_Tab
        $LLK    KeyNo_CapsLock
SpecialListPandora1UCS
        $LLK    &01, &02, &0C, &10, &11, &12, &13, &14
        $LLK    &15, &16, &17, &18, &19, &1B, &1C, &1D
        $LLK    &27, &2A, &2B, &2C, &2E, &2F, &30, &33
        $LLK    &34, &3C, &3D, &3E, &3F, &44, &45, &46
        $LLK    &4D, &4E, &4F, &50, &51, &52, &53, &54
        $LLK    &55, &56, &57, &59, &5F, &62, &63, &64
        $LLK    &68, &69, &6A, &200, &201, &202, &203, &204
        $LLK    &207, &208, &209, &20A, &20B, &20C, &20D, &20E
        $LLK    &20F
SpecialListPandora1End
        ALIGN
        ASSERT ((SpecialListPandora1End-SpecialListPandora1):SHR:LLKS)-1 <= (SpecialCodeTableEnd-SpecialCodeTable):SHR:2

UCSTablePandora1_0
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &00000060,&000000AC,&FFFFFFFF,&FFFFFFFF ; &10
        &       &000000A6,&000000B0,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000031,&000000A7,&00000001,&00000001 ; &11
        &       &000000B9,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000032,&0000007B,&00000002,&00000002 ; &12
        &       &000000B2,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&0000007D,&00000003,&00000003 ; &13
        &       &000000B3,&000000A4,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000034,&0000007E,&00000004,&00000004 ; &14
        &       &000020AC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000035,&00000025,&00000005,&00000005 ; &15
        &       &FFFFFFFF,&00002030,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000036,&0000005E,&0000001E,&0000001E ; &16
        &       &FFFFFFFF,&000021D1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000037,&00000026,&00000007,&00000007 ; &17
        &       &000000BC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000038,&0000002A,&00000008,&00000008 ; &18
        &       &000000BD,&00002022,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000039,&0000005B,&00000009,&00000009 ; &19
        &       &000000BE,&000000B1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002D,&0000005F,&0000001F,&0000001F ; &1B
        &       &000000AD,&00002212,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000003D,&0000002B,&FFFFFFFF,&FFFFFFFF ; &1C
        &       &00002013,&00002014,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000A3,&000000A3,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000071,&00000051,&00000011,&00000011 ; &27
        &       &00000153,&00000152,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000072,&00000052,&00000012,&00000012 ; &2A
        &       &000000B6,&000000AE,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000074,&00000054,&00000014,&00000014 ; &2B
        &       &00002122,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000079,&00000059,&00000019,&00000019 ; &2C
        &       &FFFFFFFF,&000000A5,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &00000069,&00000049,&00000009,&00000009 ; &2E
        &       &0000FB01,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000006F,&0000004F,&0000000F,&0000000F ; &2F
        &       &000000F8,&000000D8,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000070,&00000050,&00000010,&00000010 ; &30
        &       &000000FE,&000000DE,&FFFFFFFF,&FFFFFFFF, &76C53281
        &       &00000023,&0000007E,&FFFFFFFF,&FFFFFFFF ; &33
        &       &00002020,&00002021,&FFFFFFFF,&FFFFFFFF, &76543210
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
        &       &0000006C,&0000004C,&0000000C,&0000000C ; &44
        &       &0000FB02,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543281
        &       &0000003B,&0000003A,&FFFFFFFF,&FFFFFFFF ; &45
        &       &80020008,&00002026,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000027,&00000040,&00000000,&00000000 ; &46
        &       &80020003,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005C,&0000007C,&0000001C,&0000001C ; &4D
        &       &000000B7,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
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
        &       &80020009,&000000F7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002F,&0000003F,&FFFFFFFF,&FFFFFFFF ; &57
        &       &8002000D,&000000BF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &8000008F,&8000009F,&800000AF,&800000BF ; &59
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000020,&00000020,&00000020,&00000020 ; &5F
        &       &000000A0,&000000A0,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &8000008C,&8000009C,&800000AC,&800000BC ; &62
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &8000008E,&8000009E,&800000AE,&800000BE ; &63
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &8000008D,&8000009D,&800000AD,&800000BD ; &64
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &800000C0,&800000D0,&800000E0,&800000F0 ; &68
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &800000D0,&800000C0,&800000F0,&800000E0 ; &69
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &800000C1,&800000D1,&800000E1,&800000F1 ; &6A
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000040,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &200
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000028,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &201
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000029,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &202
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000021,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &203
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000005F,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &204
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000022,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &207
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002B,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &208
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000B4,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &209
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000A5,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &20A
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000003A,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &20B
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000003F,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &20C
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000007C,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &20D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000024,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &20E
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000020AC,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF ; &20F
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210

        ALIGN

        END
