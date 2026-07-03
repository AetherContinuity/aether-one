#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <openssl/evp.h>

#define Q 8380417
#define N 256
#define K 6
#define L 5
#define SEEDBYTES 32
#define SHAKE128_RATE 168
#define POLY_UNIFORM_NBLOCKS ((768 + SHAKE128_RATE - 1) / SHAKE128_RATE)

static unsigned int rej_uniform_ref(int32_t *a, unsigned int len, const uint8_t *buf, unsigned int buflen) {
    unsigned int ctr = 0, pos = 0; uint32_t t;
    while (ctr < len && pos + 3 <= buflen) {
        t = buf[pos++]; t |= (uint32_t)buf[pos++] << 8; t |= (uint32_t)buf[pos++] << 16;
        t &= 0x7FFFFF;
        if (t < Q) a[ctr++] = t;
    }
    return ctr;
}

static void poly_uniform_ref(int32_t *a, const uint8_t *seed, uint16_t nonce) {
    unsigned int buflen = POLY_UNIFORM_NBLOCKS * SHAKE128_RATE;
    uint8_t *buf = malloc(buflen);
    uint8_t input[SEEDBYTES + 2];
    memcpy(input, seed, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF;
    input[SEEDBYTES + 1] = (nonce >> 8) & 0xFF;

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake128(), NULL);
    EVP_DigestUpdate(ctx, input, sizeof(input));
    EVP_DigestFinalXOF(ctx, buf, buflen);
    EVP_MD_CTX_free(ctx);

    unsigned int ctr = rej_uniform_ref(a, N, buf, buflen);
    if (ctr < N) { fprintf(stderr, "VAROITUS: nonce=%u ei taydy yhdella eralla (ctr=%u)\n", nonce, ctr); }
    free(buf);
}

int main(void) {
    uint8_t rho[SEEDBYTES];
    for (int i = 0; i < SEEDBYTES; i++) rho[i] = (uint8_t)(i * 11 + 17);

    int32_t mat[K][L][N];
    for (unsigned int i = 0; i < K; i++)
        for (unsigned int j = 0; j < L; j++)
            poly_uniform_ref(mat[i][j], rho, (uint16_t)((i << 8) + j));

    FILE *f = fopen("expand_a_golden.txt", "w");
    for (unsigned int i = 0; i < K; i++)
        for (unsigned int j = 0; j < L; j++)
            for (int n = 0; n < N; n++)
                fprintf(f, "%d\n", mat[i][j][n]);
    fclose(f);

    FILE *fr = fopen("expand_a_rho.txt", "w");
    for (int i = 0; i < SEEDBYTES; i++) fprintf(fr, "%d\n", rho[i]);
    fclose(fr);

    printf("K=%d L=%d, mat[0][0][0..4]: %d %d %d %d %d\n", K, L,
           mat[0][0][0], mat[0][0][1], mat[0][0][2], mat[0][0][3], mat[0][0][4]);
    printf("mat[5][4][0..4] (viimeinen): %d %d %d %d %d\n",
           mat[5][4][0], mat[5][4][1], mat[5][4][2], mat[5][4][3], mat[5][4][4]);
    return 0;
}
