/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "os.h"
#include "Global/RISCOS.h"

static char *testid(void)
{
	static char name[10];
	static uint16_t test = 0;

	sprintf(name, "Test %03d:", test);
	test++;

	return name;
}

int main(void)
{
	extern int8_t VariformCall(os_regset *);
	os_regset     r;
	int8_t        result;
	uint8_t       power;
	char          out[50], clib[50];
	int           length;
	union
	{
		uint8_t  dcb[16];
		uint16_t dcw[8];
		uint32_t dcd[4];
		uint64_t dcq[2];
	} in;

	/* Length check hex conversion */
	r.r[0] = (int)&in;
	r.r[1] = NULL;
	r.r[2] = -1;
	r.r[3] = 50; /* nybbles => 100 characters */
	r.r[4] = ConvertToHex;
	result = VariformCall(&r);
	if (r.r[2] != ~100)
	{
		printf("%s FAIL length of %d\n", testid(), ~r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	/* Length check binary conversion */
	r.r[0] = (int)&in;
	r.r[1] = NULL;
	r.r[2] = -1;
	r.r[3] = 50; /* bytes => 400 characters */
	r.r[4] = ConvertToBinary;
	result = VariformCall(&r);
	if (r.r[2] != ~400)
	{
		printf("%s FAIL length of %d\n", testid(), ~r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	/* Length check EUI conversion */
	r.r[0] = (int)&in;
	r.r[1] = NULL;
	r.r[2] = -1;
	r.r[3] = 6; /* a MAC address => 17 characters */
	r.r[4] = ConvertToEUI;
	result = VariformCall(&r);
	if (r.r[2] != ~17)
	{
		printf("%s FAIL length of %d\n", testid(), ~r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	/* Length check fixed file size conversion */
	r.r[0] = (int)&in;
	r.r[1] = NULL;
	r.r[2] = -1;
	r.r[3] = sizeof(uint64_t); /* any input => 11 characters */
	r.r[4] = ConvertToFixedFileSize;
	result = VariformCall(&r);
	if (r.r[2] != ~strlen("1234 kbytes"))
	{
		printf("%s FAIL length of %d\n", testid(), ~r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	/* Length check IPv4 address */
	in.dcd[0] = 0xFFFF0000;
	r.r[0] = (int)&in;
	r.r[1] = NULL;
	r.r[2] = -1;
	r.r[3] = sizeof(uint32_t); /* network address */
	r.r[4] = ConvertToIPv4;
	result = VariformCall(&r);
	if (r.r[2] != ~11)
	{
		printf("%s FAIL length of %d\n", testid(), ~r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	/* Length check IPv6 address */
	r.r[0] = (int)&in;
	r.r[1] = NULL;
	r.r[2] = -1;
	r.r[3] = 2 * sizeof(uint16_t); /* insufficient input => error */
	r.r[4] = ConvertToIPv6;
	result = VariformCall(&r);
	if (result != -1)
	{
		printf("%s FAIL without error\n", testid());
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	/* Length check IPv6 address */
	in.dcq[0] = 0x9999999999999999;
	in.dcq[1] = 0x9999999900000000;
	r.r[0] = (int)&in;
	r.r[1] = NULL;
	r.r[2] = -1;
	r.r[3] = 2 * sizeof(uint64_t); /* whopper address and some zeros */
	r.r[4] = ConvertToIPv6;
	result = VariformCall(&r);
	if (r.r[2] != ~33)
	{
		printf("%s FAIL length of %d\n", testid(), ~r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	/* Output check binary conversion */
	in.dcw[0] = 0xAA0F;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 2; /* bytes */
	r.r[4] = ConvertToBinary;
	result = VariformCall(&r);
	if ((strcmp(out, "1010101000001111") != 0) ||
	    (r.r[2] != (sizeof(out) - 16)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check hex conversion */
	in.dcd[0] = 0x12345F78;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 6; /* nybbles */
	r.r[4] = ConvertToHex;
	result = VariformCall(&r);
	if ((strcmp(out, "345F78") != 0) ||
	    (r.r[2] != (sizeof(out) - 6)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check short hex conversion */
	in.dcd[0] = 0x12345678;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 1; /* nybbles */
	r.r[4] = ConvertToHex;
	result = VariformCall(&r);
	if ((strcmp(out, "8") != 0) ||
	    (r.r[2] != (sizeof(out) - 1)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check EUI conversion */
	in.dcd[0] = 0x12345678;
	in.dcd[1] = 0x99AABBCC;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 6; /* bytes */
	r.r[4] = ConvertToEUI;
	result = VariformCall(&r);
	if ((strcmp(out, "BB:CC:12:34:56:78") != 0) ||
	    (r.r[2] != (sizeof(out) - 17)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check IPv6 conversion */
	in.dcq[0] = 0x106633440ABC00DE;
	in.dcq[1] = 0x5566778800000001;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 16; /* bytes */
	r.r[4] = ConvertToIPv6;
	result = VariformCall(&r);
	if ((strcmp(out, "5566:7788:0:1:1066:3344:abc:de") != 0) ||
	    (r.r[2] != (sizeof(out) - 30)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check short IPv6 conversion */
	in.dcq[0] = 0x1066000000000000;
	in.dcq[1] = 0x5566778800000001;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 16; /* bytes */
	r.r[4] = ConvertToShortestIPv6;
	result = VariformCall(&r);
	if ((strcmp(out, "5566:7788:0:1:1066::") != 0) ||
	    (r.r[2] != (sizeof(out) - 20)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check short IPv6 conversion */
	in.dcq[0] = 0x1066000000000000;
	in.dcq[1] = 0x5566000000000000;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 16; /* bytes */
	r.r[4] = ConvertToShortestIPv6;
	result = VariformCall(&r);
	if ((strcmp(out, "5566::1066:0:0:0") != 0) ||
	    (r.r[2] != (sizeof(out) - 16)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check short IPv6 conversion */
	in.dcq[0] = 0x0000000000000000;
	in.dcq[1] = 0x0000000000000000;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 16; /* bytes */
	r.r[4] = ConvertToShortestIPv6;
	result = VariformCall(&r);
	if ((strcmp(out, "::") != 0) ||
	    (r.r[2] != (sizeof(out) - 2)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check short IPv6 conversion */
	in.dcq[0] = 0x0000000000000001;
	in.dcq[1] = 0x0000000000000000;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 16; /* bytes */
	r.r[4] = ConvertToShortestIPv6;
	result = VariformCall(&r);
	if ((strcmp(out, "::1") != 0) ||
	    (r.r[2] != (sizeof(out) - 3)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check short IPv6 conversion */
	in.dcq[0] = 0x1111222200004444;
	in.dcq[1] = 0x5000600070008000;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 16; /* bytes */
	r.r[4] = ConvertToShortestIPv6;
	result = VariformCall(&r);
	if ((strcmp(out, "5000:6000:7000:8000:1111:2222:0:4444") != 0) ||
	    (r.r[2] != (sizeof(out) - 36)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check cardinal and integer */
	for (power = 0; power < 64; power++)
	{
		/* Candidate value */
		in.dcq[0] = 1uLL << power;

		/* Interpret as cardinal */
		r.r[0] = (int)&in;
		r.r[1] = (int)out;
		r.r[2] = sizeof(out);
		r.r[3] = (power < 32) ? 4 : 8; /* bytes */
		r.r[4] = ConvertToCardinal;
		result = VariformCall(&r);
		length = sprintf(clib, "%llu", in.dcq[0]);
		if ((strcmp(out, clib) != 0) ||
		    (r.r[2] != (sizeof(out) - length)))
		{
			printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
			return 1;
		}
		else
		{
			printf("%s PASS generated %s\n", testid(), out);
		}

		/* Candidate value */
		in.dcq[0] = ~((1uLL << (uint64_t)power) - 1uLL);

		/* Interpret as integer */
		r.r[0] = (int)&in;
		r.r[1] = (int)out;
		r.r[2] = sizeof(out);
		r.r[3] = (power < 32) ? 4 : 8; /* bytes */
		r.r[4] = ConvertToInteger;
		result = VariformCall(&r);
		length = sprintf(clib, "%lld", in.dcq[0]);
		if ((strcmp(out, clib) != 0) ||
		    (r.r[2] != (sizeof(out) - length)))
		{
			printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
			return 1;
		}
		else
		{
			printf("%s PASS generated %s\n", testid(), out);
		}

		/* Interpret as integer requiring sign extension */
		r.r[0] = (int)&in;
		r.r[1] = (int)out;
		r.r[2] = sizeof(out);
		r.r[3] = ((power + 8) & ~7) / 8; /* minimum bytes */
		r.r[4] = ConvertToInteger;
		result = VariformCall(&r);
		length = sprintf(clib, "%lld", in.dcq[0]);
		if ((strcmp(out, clib) != 0) ||
		    (r.r[2] != (sizeof(out) - length)))
		{
			printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
			return 1;
		}
		else
		{
			printf("%s PASS generated %s\n", testid(), out);
		}
	}

	/* Output check zero digit */
	in.dcb[0] = 0;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 1; /* bytes */
	r.r[4] = ConvertToCardinal;
	result = VariformCall(&r);
	if ((strcmp(out, "0") != 0) ||
	    (r.r[2] != (sizeof(out) - 1)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check IPv4 conversion */
	in.dcd[0] = 0x0A0B0C0D;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 4; /* bytes */
	r.r[4] = ConvertToIPv4;
	result = VariformCall(&r);
	if ((strcmp(out, "10.11.12.13") != 0) ||
	    (r.r[2] != (sizeof(out) - 11)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check thousands separators (UK territory assumed) */
	in.dcq[0] = 1000000;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 4; /* bytes */
	r.r[4] = ConvertToPunctCardinal;
	result = VariformCall(&r);
	if ((strcmp(out, "1,000,000") != 0) ||
	    (r.r[2] != (sizeof(out) - 9)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check thousands separators (UK territory assumed) */
	in.dcq[0] = 543;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 4; /* bytes */
	r.r[4] = ConvertToPunctCardinal;
	result = VariformCall(&r);
	if ((strcmp(out, "543") != 0) ||
	    (r.r[2] != (sizeof(out) - 3)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check thousands separators (UK territory assumed) */
	in.dcq[0] = 100000;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 4; /* bytes */
	r.r[4] = ConvertToPunctCardinal;
	result = VariformCall(&r);
	if ((strcmp(out, "100,000") != 0) ||
	    (r.r[2] != (sizeof(out) - 7)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check spaced separators */
	in.dcq[0] = -6555444333222111;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 7; /* bytes */
	r.r[4] = ConvertToSpacedInteger;
	result = VariformCall(&r);
	if ((strcmp(out, "-6 555 444 333 222 111") != 0) ||
	    (r.r[2] != (sizeof(out) - 22)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check file size */
	in.dcq[0] = 842uLL * 1024 * 1024 * 1024 * 1024;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 8; /* bytes */
	r.r[4] = ConvertToFileSize;
	result = VariformCall(&r);
	if ((strcmp(out, "842 Tbytes") != 0) ||
	    (r.r[2] != (sizeof(out) - 10)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check file size */
	in.dcq[0] = ~0uLL;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 8; /* bytes */
	r.r[4] = ConvertToFileSize;
	result = VariformCall(&r);
	if ((strcmp(out, "16 Ebytes") != 0) ||
	    (r.r[2] != (sizeof(out) - 9)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check fixed file size */
	in.dcq[0] = (5 * 1024 * 1024) + (512 * 1024);
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 4; /* bytes */
	r.r[4] = ConvertToFixedFileSize;
	result = VariformCall(&r);
	if ((strcmp(out, "   6 Mbytes") != 0) ||
	    (r.r[2] != (sizeof(out) - 11)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check fixed file size */
	in.dcq[0] = 1;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 4; /* bytes */
	r.r[4] = ConvertToFixedFileSize;
	result = VariformCall(&r);
	if ((strcmp(out, "   1  byte ") != 0) ||
	    (r.r[2] != (sizeof(out) - 11)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check fixed file size */
	in.dcq[0] = 0;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = sizeof(out);
	r.r[3] = 6; /* bytes */
	r.r[4] = ConvertToFixedFileSize;
	result = VariformCall(&r);
	if ((strcmp(out, "   0  bytes") != 0) ||
	    (r.r[2] != (sizeof(out) - 11)))
	{
		printf("%s FAIL generated %s rem %d\n", testid(), out, r.r[2]);
		return 1;
	}
	else
	{
		printf("%s PASS generated %s\n", testid(), out);
	}

	/* Output check fixed file size */
	in.dcq[0] = 12345678;
	r.r[0] = (int)&in;
	r.r[1] = (int)out;
	r.r[2] = 10;
	r.r[3] = 8; /* bytes */
	r.r[4] = ConvertToFixedFileSize;
	result = VariformCall(&r);
	if (result != -1)
	{
		printf("%s FAIL without error\n", testid());
		return 1;
	}
	else
	{
		printf("%s PASS\n", testid());
	}

	return 0;
}
