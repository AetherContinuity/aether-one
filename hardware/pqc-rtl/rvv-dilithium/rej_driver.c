#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <openssl/evp.h>

#define Q 8380417
#define N 256
#define SEEDBYTES 32
#define SHAKE128_RATE 168
#define POLY_UNIFORM_NBLOCKS ((768 + SHAKE128_RATE - 1) / SHAKE128_RATE)

static unsigned int rej_uniform_ref(int32_t *a, unsigned int len,
                                     const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr = 0, pos = 0;
    uint32_t t;
    while (ctr < len && pos + 3 <= buflen) {
        t  = buf[pos++];
        t |= (uint32_t)buf[pos++] << 8;
        t |= (uint32_t)buf[pos++] << 16;
        t &= 0x7FFFFF;
        if (t < Q) a[ctr++] = t;
    }
    return ctr;
}

int main(void) {
    uint8_t seed[SEEDBYTES];
    for (int i = 0; i < SEEDBYTES; i++) seed[i] = (uint8_t)(i * 7 + 3);
    uint16_t nonce = 5;

    uint8_t input[SEEDBYTES + 2];
    memcpy(input, seed, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF;
    input[SEEDBYTES + 1] = (nonce >> 8) & 0xFF;

    unsigned int buflen = POLY_UNIFORM_NBLOCKS * SHAKE128_RATE;
    uint8_t *buf = malloc(buflen);

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake128(), NULL);
    EVP_DigestUpdate(ctx, input, sizeof(input));
    EVP_DigestFinalXOF(ctx, buf, buflen);
    EVP_MD_CTX_free(ctx);

    int32_t out[N];
    unsigned int ctr = rej_uniform_ref(out, N, buf, buflen);

    printf("ctr=%u (N=%d)\n", ctr, N);

    FILE *fbuf = fopen("rej_input_buf.txt", "w");
    for (unsigned int i = 0; i < buflen; i++) fprintf(fbuf, "%u\n", buf[i]);
    fclose(fbuf);

    FILE *fgold = fopen("rej_golden.txt", "w");
    fprintf(fgold, "%u\n", ctr);
    for (unsigned int i = 0; i < ctr; i++) fprintf(fgold, "%d\n", out[i]);
    fclose(fgold);

    printf("out[0..7]: ");
    for (int i = 0; i < 8 && i < (int)ctr; i++) printf("%d ", out[i]);
    printf("\n");

    free(buf);
    return 0;
}
