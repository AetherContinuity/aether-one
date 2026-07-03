#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define TRBYTES 64
#define POLYT1_PACKEDBYTES 320
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + K*POLYT1_PACKEDBYTES)
#define POLYETA_PACKEDBYTES 128
#define POLYT0_PACKEDBYTES 416
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + TRBYTES + L*POLYETA_PACKEDBYTES + K*POLYETA_PACKEDBYTES + K*POLYT0_PACKEDBYTES)

extern void crypto_sign_keypair_rvv(uint8_t*, uint8_t*, uint8_t[SEEDBYTES],
    void (*)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*)(const uint8_t*, unsigned int, uint8_t*, unsigned int));

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
static void real_shake256(const uint8_t *input, unsigned int inlen, uint8_t *out, unsigned int outlen) {
    keccak_state st;
    shake256_absorb_once(&st, input, inlen);
    unsigned int nblocks = (outlen + 135) / 136;
    uint8_t buf[8*136];
    shake256_squeezeblocks(buf, nblocks, &st);
    memcpy(out, buf, outlen);
}

static int load_u8(const char *fn, uint8_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) { int v; if (fscanf(f, "%d", &v) != 1) { fclose(f); return 0; } arr[i] = (uint8_t)v; }
    fclose(f);
    return 1;
}

int main(void) {
    uint8_t seed[SEEDBYTES];
    load_u8("keypair_seed.txt", seed, SEEDBYTES);

    static uint8_t exp_pk[CRYPTO_PUBLICKEYBYTES], exp_sk[CRYPTO_SECRETKEYBYTES];
    load_u8("keypair_pk_golden.txt", exp_pk, CRYPTO_PUBLICKEYBYTES);
    load_u8("keypair_sk_golden.txt", exp_sk, CRYPTO_SECRETKEYBYTES);

    static uint8_t pk[CRYPTO_PUBLICKEYBYTES], sk[CRYPTO_SECRETKEYBYTES];
    crypto_sign_keypair_rvv(pk, sk, seed, real_shake128, real_shake256);

    int e1 = 0;
    for (int i = 0; i < CRYPTO_PUBLICKEYBYTES; i++) if (pk[i] != exp_pk[i]) { e1++; if(e1<=5) printf("[FAIL] pk[%d] got=%u exp=%u\n",i,pk[i],exp_pk[i]); }
    printf("pk: %s (%d/%d)\n", e1==0?"PASS":"FAIL", CRYPTO_PUBLICKEYBYTES-e1, CRYPTO_PUBLICKEYBYTES);

    int e2 = 0;
    for (int i = 0; i < CRYPTO_SECRETKEYBYTES; i++) if (sk[i] != exp_sk[i]) { e2++; if(e2<=5) printf("[FAIL] sk[%d] got=%u exp=%u\n",i,sk[i],exp_sk[i]); }
    printf("sk: %s (%d/%d)\n", e2==0?"PASS":"FAIL", CRYPTO_SECRETKEYBYTES-e2, CRYPTO_SECRETKEYBYTES);

    printf("%s\n", (e1==0 && e2==0) ? "PASS" : "FAIL");
    return (e1==0 && e2==0) ? 0 : 1;
}
