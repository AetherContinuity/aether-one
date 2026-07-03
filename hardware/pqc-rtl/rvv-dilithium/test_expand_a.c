#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <openssl/evp.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32

extern void matrix_expand_rvv(int32_t mat[K][L][N], uint8_t rho[SEEDBYTES],
                               void (*shake_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int));

static void real_shake(uint8_t *rho, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[SEEDBYTES + 2];
    memcpy(input, rho, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF;
    input[SEEDBYTES + 1] = (nonce >> 8) & 0xFF;

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake128(), NULL);
    EVP_DigestUpdate(ctx, input, sizeof(input));
    EVP_DigestFinalXOF(ctx, out, outlen);
    EVP_MD_CTX_free(ctx);
}

int main(void) {
    FILE *fr = fopen("expand_a_rho.txt", "r");
    FILE *fg = fopen("expand_a_golden.txt", "r");
    if (!fr || !fg) { printf("FAIL: tiedostoja ei loydy\n"); return 1; }

    uint8_t rho[SEEDBYTES];
    for (int i = 0; i < SEEDBYTES; i++) { int v; fscanf(fr, "%d", &v); rho[i] = (uint8_t)v; }
    fclose(fr);

    int32_t expected[K][L][N];
    for (int i = 0; i < K; i++)
        for (int j = 0; j < L; j++)
            for (int n = 0; n < N; n++)
                fscanf(fg, "%d", &expected[i][j][n]);
    fclose(fg);

    static int32_t mat[K][L][N];
    matrix_expand_rvv(mat, rho, real_shake);

    int errors = 0;
    for (int i = 0; i < K; i++)
        for (int j = 0; j < L; j++)
            for (int n = 0; n < N; n++)
                if (mat[i][j][n] != expected[i][j][n]) {
                    errors++;
                    if (errors <= 5) printf("[FAIL] i=%d j=%d n=%d got=%d expected=%d\n",
                                             i, j, n, mat[i][j][n], expected[i][j][n]);
                }

    printf("%s (%d virhetta / %d)\n", errors == 0 ? "PASS" : "FAIL", errors, K*L*N);
    return errors == 0 ? 0 : 1;
}
