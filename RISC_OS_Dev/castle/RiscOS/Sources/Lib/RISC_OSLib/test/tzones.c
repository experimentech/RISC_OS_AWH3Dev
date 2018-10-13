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
#include <locale.h>
#include <stdio.h>
#include <time.h>

int main(void)
{
	const char *result;
	time_t      now;
	struct tm  *local;
	struct tm  *utc;
	char        buffer[256];

#ifdef __CC_NORCROFT
	/* Expect 1,1,1,1,1 */
	result = setlocale(LC_ALL, "");
	printf("Set locale to empty string => '%s'\n", result == NULL ? "NULL" : result);
	if (result != NULL) printf("Locale read back %s\n", setlocale(LC_ALL, NULL));

	/* Expect 0,0,0,0,0 */
	result = setlocale(LC_ALL, "C");
	printf("Set locale to 'C' => %s\n", result == NULL ? "NULL" : result);
	if (result != NULL) printf("Locale read back %s\n", setlocale(LC_ALL, NULL));

	/* Expect 17,17,17,17,17 if Canada1 is loaded */
	result = setlocale(LC_ALL, "Canada1");
	printf("Set locale to fr-ca => %s\n", result == NULL ? "NULL" : result);
	if (result != NULL) printf("Locale read back %s\n", setlocale(LC_ALL, NULL));

	/* Expect 17,17,17,17,5137 if Canada1 is loaded */
	result = setlocale(LC_ALL, "Canada1/HNP");
	printf("Set locale to fr-ca Pacific => %s\n", result == NULL ? "NULL" : result);
	if (result != NULL) printf("Locale read back %s\n", setlocale(LC_ALL, NULL));
#else
	/* Probably on a Windows PC then, use rough equivalent tzset() */
	putenv("TZ=PST8PDT");
	tzset();
#endif
	/* Expect the UTC time now and Pacific standard time (UTC-0800)
	 * remembering that if you run this with DST on it'll be UTC-0700
	 */
	now = time(NULL);

	utc = gmtime(&now);
	printf("Time at UTC              %d-%02d-%02d %02d:%02d:%02d\n",
	        utc->tm_year + 1900, utc->tm_mon + 1, utc->tm_mday,
	        utc->tm_hour, utc->tm_min, utc->tm_sec);

	local = localtime(&now);
	strftime(buffer, 256, "%x %X %z %Z", local);
	printf("in this program's locale %s\n", buffer);

	/* Check for reciprocity */
	if (now != mktime(localtime(&now))) printf("Asymmetry in mktime()!\n");

	return 0;
}
