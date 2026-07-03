#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define CTILDEBYTES 48
#define SHAKE256_RATE 136

typedef void (*squeeze_fn_t)(uint8_t*, unsigned int, void*);
extern void poly_uniform_gamma1_rvv(int32_t *a, squeeze_fn_t squeeze, void *ctx);

extern void matrix_expand_rvv(int32_t mat[K][L][N], uint8_t rho[SEEDBYTES],
                               void (*shake_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int));

extern unsigned int sign_core_rvv(
    int32_t z_out[L][N], uint32_t h_out[K][N], unsigned int *n_hints_out,
    int32_t mat[K][L][N], int32_t s1hat[L][N], int32_t s2hat[K][N], int32_t t0hat[K][N],
    uint8_t rhoprime[CRHBYTES], uint8_t mu[CRHBYTES],
    void (*gamma1_shake)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*challenge_hash)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*));

extern void ntt_rvv(int32_t *a);

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

static void real_gamma1_shake(uint8_t *seed, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF;
    input[CRHBYTES+1] = (nonce >> 8) & 0xFF;
    keccak_state st;
    shake256_absorb_once(&st, input, sizeof(input));
    unsigned int nblocks = (outlen + SHAKE256_RATE - 1) / SHAKE256_RATE;
    shake256_squeezeblocks(out, nblocks, &st);
}

static void real_challenge_hash(const uint8_t *mu, const uint8_t *sig_w1, unsigned int w1len, uint8_t *ctilde) {
    keccak_state st;
    shake256_init(&st);
    shake256_absorb(&st, mu, CRHBYTES);
    shake256_absorb(&st, sig_w1, w1len);
    shake256_finalize(&st);
    shake256_squeeze(ctilde, CTILDEBYTES, &st);
}

static int load_i32(const char *fn, int32_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) if (fscanf(f, "%d", &arr[i]) != 1) { fclose(f); return 0; }
    fclose(f);
    return 1;
}
static int load_u8(const char *fn, uint8_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) { int v; if (fscanf(f, "%d", &v) != 1) { fclose(f); return 0; } arr[i] = (uint8_t)v; }
    fclose(f);
    return 1;
}

int main(void) {
    uint8_t rho[SEEDBYTES], rhoprime[CRHBYTES], mu[CRHBYTES];
    load_u8("sig_inputs_rho.txt", rho, SEEDBYTES);
    load_u8("sig_inputs_rhoprime.txt", rhoprime, CRHBYTES);
    load_u8("sig_inputs_mu.txt", mu, CRHBYTES);

    static int32_t s1[L][N], s2[K][N], t0[K][N];
    load_i32("sig_inputs_s1.txt", (int32_t*)s1, L*N);
    load_i32("sig_inputs_s2.txt", (int32_t*)s2, K*N);
    load_i32("sig_inputs_t0.txt", (int32_t*)t0, K*N);

    int attempts_exp, n_hints_exp; unsigned int nonce_final_exp;
    FILE *fm = fopen("sig_meta.txt", "r");
    fscanf(fm, "%d %u %d", &attempts_exp, &nonce_final_exp, &n_hints_exp);
    fclose(fm);

    static int32_t exp_z[L][N];
    load_i32("sig_z.txt", (int32_t*)exp_z, L*N);

    static int32_t mat[K][L][N];
    matrix_expand_rvv(mat, rho, real_shake128);

    static int32_t s1hat[L][N], s2hat[K][N], t0hat[K][N];
    for (int i = 0; i < L; i++) { memcpy(s1hat[i], s1[i], sizeof(s1[i])); ntt_rvv(s1hat[i]); }
    for (int i = 0; i < K; i++) { memcpy(s2hat[i], s2[i], sizeof(s2[i])); ntt_rvv(s2hat[i]); }
    for (int i = 0; i < K; i++) { memcpy(t0hat[i], t0[i], sizeof(t0[i])); ntt_rvv(t0hat[i]); }

    static int32_t z[L][N];
    static uint32_t h[K][N];
    unsigned int n_hints;
    unsigned int attempts = sign_core_rvv(z, h, &n_hints, mat, s1hat, s2hat, t0hat, rhoprime, mu,
                                           real_gamma1_shake, real_challenge_hash);

    printf("attempts=%u (odotettu %d), n_hints=%u (odotettu %d)\n", attempts, attempts_exp, n_hints, n_hints_exp);

    int errors = 0;
    if ((int)attempts != attempts_exp) { errors++; printf("[FAIL] attempts eroaa\n"); }
    if ((int)n_hints != n_hints_exp) { errors++; printf("[FAIL] n_hints eroaa\n"); }
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++)
        if (z[i][n] != exp_z[i][n]) { errors++; if(errors<=5) printf("[FAIL] z[%d][%d] got=%d exp=%d\n",i,n,z[i][n],exp_z[i][n]); }

    printf("%s (%d virhetta)\n", errors == 0 ? "PASS" : "FAIL", errors);
    return errors == 0 ? 0 : 1;
}
