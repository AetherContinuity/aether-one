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
#define RNDBYTES 32
#define CTILDEBYTES 48
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + K*320)
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + TRBYTES + L*128 + K*128 + K*416)
#define CRYPTO_BYTES (CTILDEBYTES + L*640 + 55 + K)

extern int crypto_sign_signature_rvv(uint8_t*, const uint8_t*, unsigned int,
    const uint8_t*, unsigned int, const uint8_t*, uint8_t*,
    void (*)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*)(const uint8_t**, const unsigned int*, int, uint8_t*, unsigned int),
    void (*)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*));

extern int crypto_sign_verify_rvv(const uint8_t*, const uint8_t*, unsigned int,
    const uint8_t*, unsigned int, const uint8_t*,
    void (*)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*)(const uint8_t*, unsigned int, uint8_t*, unsigned int),
    void (*)(const uint8_t**, const unsigned int*, int, uint8_t*, unsigned int),
    void (*)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*));

static void real_shake128(uint8_t *rho, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[SEEDBYTES + 2];
    memcpy(input, rho, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF; input[SEEDBYTES+1] = (nonce >> 8) & 0xFF;
    keccak_state st;
    shake128_absorb_once(&st, input, sizeof(input));
    shake128_squeezeblocks(out, (outlen+167)/168, &st);
}
static void real_shake256_seedlen(const uint8_t *input, unsigned int inlen, uint8_t *out, unsigned int outlen) {
    keccak_state st;
    shake256_absorb_once(&st, input, inlen);
    uint8_t buf[16*136];
    shake256_squeezeblocks(buf, (outlen+135)/136, &st);
    memcpy(out, buf, outlen);
}
static void real_shake256_multi(const uint8_t **parts, const unsigned int *partlens, int nparts,
                                 uint8_t *out, unsigned int outlen) {
    keccak_state st;
    shake256_init(&st);
    for (int i = 0; i < nparts; i++) shake256_absorb(&st, parts[i], partlens[i]);
    shake256_finalize(&st);
    shake256_squeeze(out, outlen, &st);
}
static void real_gamma1_shake(uint8_t *seed, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF; input[CRHBYTES+1] = (nonce >> 8) & 0xFF;
    keccak_state st;
    shake256_absorb_once(&st, input, sizeof(input));
    shake256_squeezeblocks(out, (outlen+135)/136, &st);
}
static void real_challenge_hash(const uint8_t *mu, const uint8_t *sig_w1, unsigned int w1len, uint8_t *ctilde) {
    keccak_state st;
    shake256_init(&st);
    shake256_absorb(&st, mu, CRHBYTES);
    shake256_absorb(&st, sig_w1, w1len);
    shake256_finalize(&st);
    shake256_squeeze(ctilde, CTILDEBYTES, &st);
}

static int load_u8(const char *fn, uint8_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < n; i++) { int v; if(fscanf(f,"%d",&v)!=1) { fclose(f); return 0; } arr[i]=(uint8_t)v; }
    fclose(f); return 1;
}

int main(void) {
    uint8_t sk[CRYPTO_SECRETKEYBYTES], pk[CRYPTO_PUBLICKEYBYTES];
    load_u8("keypair_sk_golden.txt", sk, CRYPTO_SECRETKEYBYTES);
    load_u8("keypair_pk_golden.txt", pk, CRYPTO_PUBLICKEYBYTES);

    char msg[128] = {0};
    FILE *fm = fopen("fullsig_msg.txt","r");
    unsigned int mlen = fread(msg, 1, sizeof(msg)-1, fm);
    fclose(fm);

    uint8_t rnd[RNDBYTES];
    load_u8("fullsig_rnd.txt", rnd, RNDBYTES);

    static uint8_t exp_sig[CRYPTO_BYTES];
    load_u8("fullsig_golden.txt", exp_sig, CRYPTO_BYTES);

    uint8_t ctx[1] = {0};
    static uint8_t sig[CRYPTO_BYTES];
    int rc_sign = crypto_sign_signature_rvv(sig, (uint8_t*)msg, mlen, ctx, 0, sk, rnd,
                                             real_shake128, real_shake256_multi,
                                             real_gamma1_shake, real_challenge_hash);
    printf("sign rc=%d\n", rc_sign);

    int e1 = 0;
    for (int i = 0; i < CRYPTO_BYTES; i++) if (sig[i] != exp_sig[i]) { e1++; if(e1<=5) printf("[FAIL] sig[%d] got=%u exp=%u\n",i,sig[i],exp_sig[i]); }
    printf("sig vs REFERENSSI: %s (%d/%d)\n", e1==0?"PASS":"FAIL", CRYPTO_BYTES-e1, CRYPTO_BYTES);

    int rc_verify = crypto_sign_verify_rvv(sig, (uint8_t*)msg, mlen, ctx, 0, pk,
                                            real_shake128, real_shake256_seedlen,
                                            real_shake256_multi, real_challenge_hash);
    printf("verify (oikea): rc=%d (odotettu 0)\n", rc_verify);

    char bad_msg[128]; memcpy(bad_msg, msg, mlen); bad_msg[0] ^= 1;
    int rc_verify_bad = crypto_sign_verify_rvv(sig, (uint8_t*)bad_msg, mlen, ctx, 0, pk,
                                                real_shake128, real_shake256_seedlen,
                                                real_shake256_multi, real_challenge_hash);
    printf("verify (turmeltu viesti): rc=%d (odotettu -1)\n", rc_verify_bad);

    int ok = (rc_sign==0 && e1==0 && rc_verify==0 && rc_verify_bad==-1);
    printf("%s\n", ok?"PASS":"FAIL");
    return ok?0:1;
}
