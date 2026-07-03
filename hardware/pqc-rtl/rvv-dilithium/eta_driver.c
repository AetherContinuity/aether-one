#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <openssl/evp.h>

#define ETA 4
#define N 256
#define CRHBYTES 64
#define SHAKE256_RATE 136
#define POLY_UNIFORM_ETA_NBLOCKS ((227 + SHAKE256_RATE - 1) / SHAKE256_RATE)

static unsigned int rej_eta_ref(int32_t *a, unsigned int len, const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr = 0, pos = 0;
    uint32_t t0, t1;
    while (ctr < len && pos < buflen) {
        t0 = buf[pos] & 0x0F;
        t1 = buf[pos++] >> 4;
        if (t0 < 9) a[ctr++] = 4 - (int32_t)t0;
        if (t1 < 9 && ctr < len) a[ctr++] = 4 - (int32_t)t1;
    }
    return ctr;
}

int main(void) {
    uint8_t seed[CRHBYTES];
    for (int i = 0; i < CRHBYTES; i++) seed[i] = (uint8_t)(i * 19 + 41);
    uint16_t nonce = 3;

    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF;
    input[CRHBYTES + 1] = (nonce >> 8) & 0xFF;

    unsigned int buflen = POLY_UNIFORM_ETA_NBLOCKS * SHAKE256_RATE;
    uint8_t *buf = malloc(buflen);

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake256(), NULL);
    EVP_DigestUpdate(ctx, input, sizeof(input));
    EVP_DigestFinalXOF(ctx, buf, buflen);
    EVP_MD_CTX_free(ctx);

    int32_t out[N];
    unsigned int ctr = rej_eta_ref(out, N, buf, buflen);
    printf("ETA=4, buflen=%u, ctr=%u (N=%d)\n", buflen, ctr, N);

    FILE *fbuf = fopen("eta_input_buf.txt", "w");
    for (unsigned int i = 0; i < buflen; i++) fprintf(fbuf, "%u\n", buf[i]);
    fclose(fbuf);

    FILE *fgold = fopen("eta_golden.txt", "w");
    fprintf(fgold, "%u\n", ctr);
    for (unsigned int i = 0; i < ctr; i++) fprintf(fgold, "%d\n", out[i]);
    fclose(fgold);

    printf("out[0..9]: ");
    for (int i = 0; i < 10; i++) printf("%d ", out[i]);
    printf("\n");
    free(buf);
    return 0;
}
