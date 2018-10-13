/*
 * Copyright�(c)�2015, Colin Granville
 * All�rights�reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <time.h>
#include <string.h>

#include "DebugLib/DebugLib.h"

#include "Auth.h"
#include "global.h"
#include "md4.h"
#include "md5.h"

/* Based on code from RFC2104 */
typedef struct
{
  MD5_CTX MD5ctx;
  unsigned char k_opad[64];/* outer padding -
                            * key XORd with opad
                            */
} HMAC_MD5_CTX;

static void HMAC_MD5Init( HMAC_MD5_CTX *ctx, unsigned char *key, int key_len )
{
  unsigned char k_ipad[65];    /* inner padding -
                                * key XORd with ipad
                                */
  unsigned char tk[16];
  int i;

  /* if key is longer than 64 bytes reset it to key=MD5(key) */
  if (key_len > 64) {
    MD5_CTX      tctx;

    MD5Init( &tctx );
    MD5Update( &tctx, key, key_len );
    MD5Final( tk, &tctx );

    key = tk;
    key_len = 16;
  }

  /*
   * the HMAC_MD5 transform looks like:
   *
   * MD5(K XOR opad, MD5(K XOR ipad, text))
   *
   * where K is an n byte key
   * ipad is the byte 0x36 repeated 64 times
   * opad is the byte 0x5c repeated 64 times
   * and text is the data being protected
   */

  /* start out by storing key in pads */
  memset( k_ipad, 0, sizeof k_ipad );
  memset( ctx->k_opad, 0, sizeof ctx->k_opad );
  memcpy( k_ipad, key, key_len );
  memcpy( ctx->k_opad, key, key_len );

  /* XOR key with ipad and opad values */
  for (i = 0; i < 64; i++) {
    k_ipad[i] ^= 0x36;
    ctx->k_opad[i] ^= 0x5c;
  }

  /* perform inner MD5 */
  MD5Init( &ctx->MD5ctx );               /* init context for 1st pass */
  MD5Update( &ctx->MD5ctx, k_ipad, 64 ); /* start with inner pad */
}

static void HMAC_MD5Update( HMAC_MD5_CTX *ctx, unsigned char *text, int text_len )
{
  MD5Update( &ctx->MD5ctx, text, text_len ); /* then text of datagram */
}

static void HMAC_MD5Final( unsigned char digest[16], HMAC_MD5_CTX* ctx )
{
  /* finish up 1st pass */
  MD5Final( digest, &ctx->MD5ctx );

  /* perform outer MD5 */
  MD5Init( &ctx->MD5ctx );                     /* init context for 2nd pass */
  MD5Update( &ctx->MD5ctx, ctx->k_opad, 64 );  /* start with outer pad */
  MD5Update( &ctx->MD5ctx, digest, 16 );       /* then results of 1st hash */
  MD5Final( digest, &ctx->MD5ctx );            /* finish up 2nd pass */
}

/*
 * Simplified RISCOS string to UTF16 conversion.
 * sizeof out must be >= size * 2 or (size + 1) * 2 if
 * US_ADD_ZERO flag used.
 */
#define US_UPPERCASE    1
#define US_ADD_ZERO     2
static void UnicodeString( unsigned int flags, const char *s, size_t size, unsigned short *out )
{
  size_t i;

  if (out == 0) return;
  for (i = 0; i < size; i++) {
    out[i] = (flags & US_UPPERCASE) ? toupper( s[i] ) : s[i];
  }
  if (flags & US_ADD_ZERO) out[i] = 0;
}

static void Auth_NTOWFv1( const char *password, size_t pass_size, unsigned char digestout[16] )
{
  unsigned short ustr[pass_size + 1];  /* 1 added because 0 size causes crash */

  MD4_CTX ctx;
  
  MD4Init( &ctx );

  UnicodeString( 0, password, pass_size, ustr );
  if (pass_size)
  {
    MD4Update( &ctx, (void *)ustr, pass_size * sizeof(unsigned short) );
  }

  MD4Final(digestout,&ctx);
}

void Auth_LMOWFv2( const char *password, size_t pass_size,
                   const char *username, size_t user_size,
                   const char *userdomain, size_t dom_size,
                   unsigned char digestout[16] )
{
  size_t max_size = user_size;
  unsigned short ustr[max_size + 1];  /* 1 added because 0 size causes crash */

  Auth_NTOWFv1( password, pass_size, digestout );

  if (dom_size > max_size) max_size = dom_size;

  HMAC_MD5_CTX ctx;
  
  HMAC_MD5Init( &ctx, digestout, 16 );

  UnicodeString( US_UPPERCASE, username, user_size, ustr );
  HMAC_MD5Update( &ctx, (void *)ustr, user_size * sizeof(unsigned short) );

  UnicodeString( 0, userdomain, dom_size, ustr );
  HMAC_MD5Update( &ctx, (void *)ustr, dom_size * sizeof(unsigned short) );

  HMAC_MD5Final( digestout, &ctx );
}

void Auth_LMv2ChallengeResponse( unsigned char lmowfv2digest[16],
                                 unsigned char serverchallenge[8],
                                 unsigned char responseout[24])
{
  size_t i;
  unsigned char *clientchallenge = responseout + 16;
  HMAC_MD5_CTX ctx;

  /* Create random clientchallenge */
  srand( (unsigned int)time( NULL ) );
  for (i = 0; i < 8; i++)
  {
#ifdef AUTHTEST
    clientchallenge[i] = 0xAA;
#else
    clientchallenge[i] = (unsigned char)rand();
#endif
  }

  HMAC_MD5Init( &ctx, lmowfv2digest, 16 );

  HMAC_MD5Update( &ctx, (void *)serverchallenge, 8 );
  HMAC_MD5Update( &ctx, (void *)clientchallenge, 8 );
  HMAC_MD5Final( responseout, &ctx );
}

static unsigned long long SMBTime( void )
{
  unsigned long long tm = time( NULL );

  tm = (tm + 11644473600ull -2*24*3600) * 10000000;
  return tm;
}

void Auth_NTv2ChallengeResponse( unsigned char   ntowfv2digest[16],
                                 unsigned char   serverchallenge[8],
                                 const char     *servername, /* ASCII */
                                 const char     *domain,     /* ASCII */
                                 unsigned char   responseout[128],
                                 unsigned short *responseoutsize )
{
  unsigned char *clientchallenge = responseout + 16;
  unsigned long long tm;
  size_t i, size;
  HMAC_MD5_CTX ctx;

  *responseoutsize = 0;
  *clientchallenge++ = 1;
  *clientchallenge++ = 1;
  memset( clientchallenge, 0, 6 );
  clientchallenge += 6;

  tm = SMBTime();
#ifdef AUTHTEST
  memset( clientchallenge, 0, sizeof(tm) );
#else
  memcpy( clientchallenge, &tm, sizeof(tm) );
#endif
  clientchallenge += sizeof(tm);

  /* Create random clientchallenge */
  srand( (unsigned int)time( NULL ) );
  for (i = 0; i < 8; i++)
  {
#ifdef AUTHTEST
    *clientchallenge++ = 0xaa;
#else
    *clientchallenge++ = (unsigned char)rand();
#endif
  }
  memset( clientchallenge, 0, 4 );
  clientchallenge += 4;

  /* Set domain */
  size = strlen( domain );
  if (clientchallenge + size * 2 + 4 > responseout + 128 - 8) return;
  *clientchallenge++ = 2; 
  *clientchallenge++ = 0;
  *clientchallenge++ = size * 2;
  *clientchallenge++ = 0;
  UnicodeString( 0, domain, size, (unsigned short *)clientchallenge );
  clientchallenge += size * 2;

  /* Set server */
  size = strlen( servername );
  if (clientchallenge + size * 2 + 4 > responseout + 128 - 8) return;
  *clientchallenge++ = 1;
  *clientchallenge++ = 0;
  *clientchallenge++ = size * 2;      
  *clientchallenge++ = 0;
  UnicodeString( 0, servername, size, (unsigned short *)clientchallenge );
  clientchallenge += size * 2;
        
  /* End of list */
  *clientchallenge++ = 0;
  *clientchallenge++ = 0;
  *clientchallenge++ = 0;
  *clientchallenge++ = 0;
  memset( clientchallenge, 0, 4 );
  clientchallenge += 4;
        
  *responseoutsize = clientchallenge - responseout;
        
  HMAC_MD5Init( &ctx, ntowfv2digest, 16 );

  HMAC_MD5Update( &ctx, (void *)serverchallenge, 8 );
  HMAC_MD5Update( &ctx, (void *)(responseout + 16), *responseoutsize - 16 );
  HMAC_MD5Final( responseout, &ctx );
} 
     
#ifdef AUTHTEST
      
#define MDPrint(digest) PrintHex((digest),16)

static void PrintHex( void *d, size_t len )
{
  size_t i;
  unsigned char *data = (unsigned char *)d;

  for (i = 0; i < len; i++) {
    printf( "%02x", data[i] );
  }
  printf( "\n" );
}

int main( void )
{
  unsigned char digest[16];
  MD5_CTX context;
  MD4_CTX context4;
  HMAC_MD5_CTX hctx;
  unsigned char lmv2response[24];
  unsigned long long tm;
  unsigned char ntv2response[128];
  unsigned short ntsize;

  MD5Init( &context );
  MD5Update( &context, (void *)"test", 4 );
  MD5Final( digest, &context );
  MDPrint( digest );

  MD5Init( &context );
  MD5Update( &context, (void *)"te", 2 );
  MD5Update( &context, (void *)"st", 2 );
  MD5Final( digest, &context );
  MDPrint( digest );

  MD4Init( &context4 );
  MD4Update( &context4, (void *)"test", 4 );
  MD4Final( digest, &context4 );
  MDPrint( digest );

  MD4Init( &context4 );
  MD4Update( &context4, (void *)"te", 2 );
  MD4Update( &context4, (void *)"st", 2 );
  MD4Final( digest, &context4 );
  MDPrint( digest );
        
  /* RFC2202 test cases */
  HMAC_MD5Init( &hctx, (void *)"Jefe", 4 );
  HMAC_MD5Update( &hctx, (void *)"what do ya want for nothing?", 28 );
  HMAC_MD5Final( digest, &hctx );
  MDPrint( digest );
  
  HMAC_MD5Init( &hctx, (void *)"Jefe", 4 );
  HMAC_MD5Update( &hctx, (void*)"what", 4 );
  HMAC_MD5Update( &hctx, (void *)" do ya want for nothing?", 24 );
  HMAC_MD5Final( digest, &hctx );
  MDPrint( digest );
  
  /* Value below verified from [MS-NLMP].pdf 4.2.4.1.1 */
  Auth_NTOWFv2( "Password", 8, "User", 4, "Domain", 6, digest );
  MDPrint( digest );
  
  /* Value below verified from [MS-NLMP].pdf 4.2.2.1.2 */
  Auth_NTOWFv1( "Password", 8, digest );
  MDPrint( digest );
  
  /* Value below verified from [MS-NLMP].pdf 4.2.4.1.1 */
  Auth_LMOWFv2( "Password", 8, "User", 4, "Domain", 6, digest );
  MDPrint( digest );
  
  /* Value below verified from [MS-NLMP].pdf 4.2.4.2.1 */
  Auth_LMv2ChallengeResponse( digest, (void *)"\x01\x23\x45\x67\x89\xab\xcd\xef", lmv2response );
  printHex( lmv2response, 24 );
  
  /* Value below verified from [MS-NLMP].pdf 4.2.4.2.2 */
  tm = SMBTime();
  printHex( &tm, 8 );
  
  Auth_NTv2ChallengeResponse( digest, (void *)"\x01\x23\x45\x67\x89\xab\xcd\xef", "Server",
                              "Domain", ntv2response, &ntsize );
  printHex( ntv2response, ntsize );
  printf( "%d\n", ntsize );

  return 0;
}
#endif
