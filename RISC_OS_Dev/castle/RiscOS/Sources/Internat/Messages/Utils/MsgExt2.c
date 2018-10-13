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
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#include "swis.h"

int getword(char *b, int i, int size, char *r)
{
     int j;

     while (i < size && isspace(b[i])) i++;
     j = 0;
     while (i < size && (isalnum(b[i]) || b[i] == '/' || b[i] == '@' || b[i] == '$' || b[i] == '_' || b[i] == '?' || b[i] == '-' || b[i] == '.' || b[i] == '<' || b[i] == '>')) r[j++] = b[i++];
     r[j] = 0;
     return i;
}

int main(int argc, char **argv)
{
    int rc, size;
    char ket[256];
    FILE *outfile;
    char *msg_buff;
    int msgi, found, l;
    char *tagb;
    int tagi;
    int msg_size;
    char message_file[256];

    if (argc != 3) {
        fprintf(stderr, "Usage: MsgExt <messages> <tags>\n");
        exit(1);
    }
    outfile = fopen(argv[1], "w");
    if (!outfile) {
        fprintf(stderr, "Error opening %s for output", argv[1]);
        exit(1);
    }
    rc = _swi(OS_File, _IN(0)|_IN(1)|_OUT(4), 17, argv[2], &size);
    if (rc != 1) {
        fprintf(stderr, "File %s not found\n", argv[2]);
        exit(1);
    }
    tagb = malloc(size);
    if (!tagb) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    _swi(OS_File, _IN(0)|_IN(1)|_IN(2)|_IN(3), 16, argv[2], tagb, 0);
    tagi = 0;
    while (1) {
        tagi = getword(tagb, tagi, size, message_file);
        if (tagi >= size) break;
        if (tagb[tagi++] != ':') {
            fprintf(stderr, "Missing ':' for %s\n", message_file);
            exit(1);
        }
        if (tagi >= size) break;
        rc = _swi(OS_File, _IN(0)|_IN(1)|_OUT(4), 17, message_file, &msg_size);
        if (rc != 1) {
            fprintf(stderr, "File %s not found\n", message_file);
            exit(1);
        }
        msg_buff = malloc(msg_size);
        if (!msg_buff) {
            fprintf(stderr, "Out of memory\n");
            exit(1);
        }
        _swi(OS_File, _IN(0)|_IN(1)|_IN(2)|_IN(3), 16, message_file, msg_buff, 0);
        printf("Extracting messages from %s\n", message_file);
        while (1) {
            tagi = getword(tagb, tagi, size, ket);
            if (tagi >= size) break;
            msgi = 0;
            /* printf("Tag: %s", ket); */
            l = strlen(ket);
            found = 0;
            while (1) {
                if (msg_buff[msgi] != '#') {
                    if (strncmp(&msg_buff[msgi], ket, l) == 0 && msg_buff[msgi + l] == ':') {
                        /* putchar('.'); */
                        found = 1;
                        msgi = msgi + l + 1;
                        while (msgi < msg_size && msg_buff[msgi] != '\n') {
                            if (msg_buff[msgi] == 27) {
                                fputc(27, outfile);
                                fputc(msg_buff[++msgi], outfile);
                                ++msgi;
                                continue;
                            }
                            if (msg_buff[msgi] == '%' && msg_buff[msgi + 1] != '\n') {
                                fputc('\n', outfile);
                                msgi += 2;
                                continue;
                            }
                            if (msg_buff[msgi])
                                fputc(msg_buff[msgi], outfile);
                            msgi++;
                        }
                        fputc('\n', outfile);
                        /* Skip token 0 specification if there. */
                        if (tagb[tagi] == ':') tagi = getword(tagb, tagi+1, size, ket);
                    }
                }
                while (msgi < msg_size && msg_buff[msgi++] != '\n');
                if (msgi >= msg_size) break;
            }
            /* putchar('\n'); */
            if (!found) {
                fprintf(stderr, "Warning: Tag not found\n");
            }
            if (tagb[tagi++] != ',') break;
        }
        free(msg_buff);
    }
}
