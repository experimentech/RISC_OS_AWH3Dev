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
#ifndef AUTH_H
#define AUTH_H

void Auth_LMOWFv2( const char *password, size_t pass_size,
                   const char *username, size_t user_size,
                   const char *userdomain, size_t dom_size,
                   unsigned char digestout[16] );

void Auth_LMv2ChallengeResponse(unsigned char lmowfv2digest[16],
                                unsigned char serverchallenge[8],
                                unsigned char responseout[24]);

#define Auth_NTOWFv2 Auth_LMOWFv2

/* responseoutsize = 0 if response out is not big enough - should never happen */
void Auth_NTv2ChallengeResponse( unsigned char   ntowfv2digest[16],
                                 unsigned char   serverchallenge[8],
                                 const char     *servername,                  /* ASCII */
                                 const char     *domain,                      /* ASCII */
                                 unsigned char   responseout[128],
                                 unsigned short *responseoutsize );

#endif
