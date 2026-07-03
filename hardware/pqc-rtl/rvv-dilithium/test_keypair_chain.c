#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64

extern void matrix_expand_rvv(int32_t mat[K][L][N], uint8_t rho[SEEDBYTES],
                               void (*shake_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int));
extern void expand_s_rvv(int32_t s1[L][N], int32_t s2[K][N], uint8_t seed[CRHBYTES]);
extern void compute_t_rvv(int32_t t1_out[K][N], int32_t t0_out[K][N],
                           int32_t mat[K][L][N], int32_t s1[L][N], int32_t s2[K][N]);

static void real_shake128(uint8_t *rho, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[SEEDBYTES + 2];
    memcpy(input, rho, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF;
    input[SEEDBYTES+1] = (nonce >> 8) & 0xFF;
    keccak_state st;
    shake128_absorb_once(&st, input, sizeof(input));
    unsigned int nblocks = (outlen + 167) / 168;
    shake128_squeezeblocks(out, nblocks, &st);
}

static int load(const char *fn, int32_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) if (fscanf(f, "%d", &arr[i]) != 1) { fclose(f); return 0; }
    fclose(f);
    return 1;
}

int main(void) {
    uint8_t rho[SEEDBYTES], rhoprime[CRHBYTES];
    FILE *fr = fopen("real_rho.txt", "r");
    for (int i = 0; i < SEEDBYTES; i++) { int v; fscanf(fr, "%d", &v); rho[i] = (uint8_t)v; }
    fclose(fr);
    fr = fopen("real_rhoprime.txt", "r");
    for (int i = 0; i < CRHBYTES; i++) { int v; fscanf(fr, "%d", &v); rhoprime[i] = (uint8_t)v; }
    fclose(fr);

    static int32_t exp_t1[K][N], exp_t0[K][N];
    load("real_golden_t1.txt", (int32_t*)exp_t1, K*N);
    load("real_golden_t0.txt", (int32_t*)exp_t0, K*N);

    static int32_t mat[K][L][N], s1[L][N], s2[K][N], t1[K][N], t0[K][N];

    matrix_expand_rvv(mat, rho, real_shake128);
    expand_s_rvv(s1, s2, rhoprime);
    compute_t_rvv(t1, t0, mat, s1, s2);

    int errors = 0;
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) {
        if (t1[i][n] != exp_t1[i][n]) { errors++; if(errors<=5) printf("[FAIL] t1[%d][%d] got=%d exp=%d\n",i,n,t1[i][n],exp_t1[i][n]); }
        if (t0[i][n] != exp_t0[i][n]) { errors++; if(errors<=5) printf("[FAIL] t0[%d][%d] got=%d exp=%d\n",i,n,t0[i][n],exp_t0[i][n]); }
    }
    printf("%s (%d virhetta / %d) -- TAYSI KEYPAIR-KETJU: ExpandA+ExpandS+t=As+e\n",
           errors==0?"PASS":"FAIL", errors, 2*K*N);
    return errors==0?0:1;
}
