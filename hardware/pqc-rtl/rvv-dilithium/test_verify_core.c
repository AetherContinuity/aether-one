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

extern int verify_core_rvv(uint8_t rho[SEEDBYTES], int32_t t1[K][N],
                            uint8_t ctilde[CTILDEBYTES], int32_t z[L][N], uint32_t h[K][N],
                            uint8_t mu[CRHBYTES],
                            void (*shake128_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int),
                            void (*challenge_hash)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*));

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
static int load_u32(const char *fn, uint32_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) { unsigned v; if (fscanf(f, "%u", &v) != 1) { fclose(f); return 0; } arr[i] = v; }
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
    uint8_t rho[SEEDBYTES], mu[CRHBYTES], ctilde[CTILDEBYTES];
    load_u8("sig_inputs_rho.txt", rho, SEEDBYTES);
    load_u8("sig_inputs_mu.txt", mu, CRHBYTES);
    load_u8("ver_ctilde.txt", ctilde, CTILDEBYTES);

    static int32_t t1[K][N], z[L][N];
    static uint32_t h[K][N];
    load_i32("ver_t1.txt", (int32_t*)t1, K*N);
    load_i32("sig_z.txt", (int32_t*)z, L*N);
    load_u32("ver_h.txt", (uint32_t*)h, K*N);

    int result = verify_core_rvv(rho, t1, ctilde, z, h, mu, real_shake128, real_challenge_hash);
    printf("verify (oikea allekirjoitus): %d (odotettu 0)\n", result);
    int ok1 = (result == 0);

    /* Negatiivikontrolli: turmeltu z */
    static int32_t z2[L][N];
    load_i32("sig_z.txt", (int32_t*)z2, L*N);
    z2[0][0] += 12345;
    int result_bad = verify_core_rvv(rho, t1, ctilde, z2, h, mu, real_shake128, real_challenge_hash);
    printf("verify (turmeltu z): %d (odotettu -1)\n", result_bad);
    int ok2 = (result_bad == -1);

    printf("%s\n", (ok1 && ok2) ? "PASS" : "FAIL");
    return (ok1 && ok2) ? 0 : 1;
}
