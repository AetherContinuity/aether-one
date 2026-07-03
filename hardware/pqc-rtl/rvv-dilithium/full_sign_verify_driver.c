#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define DILITHIUM_MODE 3
#include "params.h"
#include "poly.h"
#include "polyvec.h"
#include "packing.h"
#include "fips202.h"

/* crypto_sign_signature_internal ja crypto_sign_verify_internal
 * kirjoitettu tanne suoraan (ei linkata sign.c:ta, koska se kutsuu
 * randombytes:ia jota ei ole - kaytetaan samaa logiikkaa mutta annettu
 * rnd parametrina, sama periaate kuin koko tama hakemisto). */

static int sign_det(uint8_t *sig, const uint8_t *m, size_t mlen,
                     const uint8_t *pre, size_t prelen,
                     const uint8_t *sk, const uint8_t rnd[RNDBYTES]) {
    unsigned int n;
    uint8_t seedbuf[2*SEEDBYTES + TRBYTES + 2*CRHBYTES];
    uint8_t *rho, *tr, *key, *mu, *rhoprime;
    uint16_t nonce = 0;
    polyvecl mat[K], s1, y, z;
    polyveck t0, s2, w1, w0, h;
    poly cp;
    keccak_state state;

    rho = seedbuf; tr = rho+SEEDBYTES; key = tr+TRBYTES; mu = key+SEEDBYTES; rhoprime = mu+CRHBYTES;
    unpack_sk(rho, tr, key, &t0, &s1, &s2, sk);

    shake256_init(&state);
    shake256_absorb(&state, tr, TRBYTES);
    shake256_absorb(&state, pre, prelen);
    shake256_absorb(&state, m, mlen);
    shake256_finalize(&state);
    shake256_squeeze(mu, CRHBYTES, &state);

    shake256_init(&state);
    shake256_absorb(&state, key, SEEDBYTES);
    shake256_absorb(&state, rnd, RNDBYTES);
    shake256_absorb(&state, mu, CRHBYTES);
    shake256_finalize(&state);
    shake256_squeeze(rhoprime, CRHBYTES, &state);

    polyvec_matrix_expand(mat, rho);
    polyvecl_ntt(&s1);
    polyveck_ntt(&s2);
    polyveck_ntt(&t0);

rej:
    polyvecl_uniform_gamma1(&y, rhoprime, nonce++);
    z = y;
    polyvecl_ntt(&z);
    polyvec_matrix_pointwise_montgomery(&w1, mat, &z);
    polyveck_reduce(&w1);
    polyveck_invntt_tomont(&w1);
    polyveck_caddq(&w1);
    polyveck_decompose(&w1, &w0, &w1);
    polyveck_pack_w1(sig, &w1);

    shake256_init(&state);
    shake256_absorb(&state, mu, CRHBYTES);
    shake256_absorb(&state, sig, K*POLYW1_PACKEDBYTES);
    shake256_finalize(&state);
    shake256_squeeze(sig, CTILDEBYTES, &state);
    poly_challenge(&cp, sig);
    poly_ntt(&cp);

    polyvecl_pointwise_poly_montgomery(&z, &cp, &s1);
    polyvecl_invntt_tomont(&z);
    polyvecl_add(&z, &z, &y);
    polyvecl_reduce(&z);
    if (polyvecl_chknorm(&z, GAMMA1-BETA)) goto rej;

    polyveck_pointwise_poly_montgomery(&h, &cp, &s2);
    polyveck_invntt_tomont(&h);
    polyveck_sub(&w0, &w0, &h);
    polyveck_reduce(&w0);
    if (polyveck_chknorm(&w0, GAMMA2-BETA)) goto rej;

    polyveck_pointwise_poly_montgomery(&h, &cp, &t0);
    polyveck_invntt_tomont(&h);
    polyveck_reduce(&h);
    if (polyveck_chknorm(&h, GAMMA2)) goto rej;

    polyveck_add(&w0, &w0, &h);
    n = polyveck_make_hint(&h, &w0, &w1);
    if (n > OMEGA) goto rej;

    pack_sig(sig, sig, &z, &h);
    return 0;
}

static int verify_det(const uint8_t *sig, const uint8_t *m, size_t mlen,
                       const uint8_t *pre, size_t prelen, const uint8_t *pk) {
    uint8_t buf[K*POLYW1_PACKEDBYTES];
    uint8_t rho[SEEDBYTES], mu[CRHBYTES], c[CTILDEBYTES], c2[CTILDEBYTES];
    poly cp;
    polyvecl mat[K], z;
    polyveck t1, w1, h;
    keccak_state state;

    unpack_pk(rho, &t1, pk);
    if (unpack_sig(c, &z, &h, sig)) return -1;
    if (polyvecl_chknorm(&z, GAMMA1-BETA)) return -1;

    shake256(mu, TRBYTES, pk, CRYPTO_PUBLICKEYBYTES);
    shake256_init(&state);
    shake256_absorb(&state, mu, TRBYTES);
    shake256_absorb(&state, pre, prelen);
    shake256_absorb(&state, m, mlen);
    shake256_finalize(&state);
    shake256_squeeze(mu, CRHBYTES, &state);

    poly_challenge(&cp, c);
    polyvec_matrix_expand(mat, rho);
    polyvecl_ntt(&z);
    polyvec_matrix_pointwise_montgomery(&w1, mat, &z);
    poly_ntt(&cp);
    polyveck_shiftl(&t1);
    polyveck_ntt(&t1);
    polyveck_pointwise_poly_montgomery(&t1, &cp, &t1);
    polyveck_sub(&w1, &w1, &t1);
    polyveck_reduce(&w1);
    polyveck_invntt_tomont(&w1);
    polyveck_caddq(&w1);
    polyveck_use_hint(&w1, &w1, &h);
    polyveck_pack_w1(buf, &w1);

    shake256_init(&state);
    shake256_absorb(&state, mu, CRHBYTES);
    shake256_absorb(&state, buf, K*POLYW1_PACKEDBYTES);
    shake256_finalize(&state);
    shake256_squeeze(c2, CTILDEBYTES, &state);
    for (unsigned int i = 0; i < CTILDEBYTES; i++) if (c[i]!=c2[i]) return -1;
    return 0;
}

static int load_u8(const char *fn, uint8_t *arr, int n) {
    FILE *f = fopen(fn, "r");
    for (int i = 0; i < n; i++) { int v; fscanf(f, "%d", &v); arr[i]=(uint8_t)v; }
    fclose(f); return 1;
}

int main(void) {
    uint8_t sk[CRYPTO_SECRETKEYBYTES], pk[CRYPTO_PUBLICKEYBYTES];
    load_u8("keypair_sk_golden.txt", sk, CRYPTO_SECRETKEYBYTES);
    load_u8("keypair_pk_golden.txt", pk, CRYPTO_PUBLICKEYBYTES);

    const char *msg = "AetherContinuity ML-DSA-65 taysi API-testi";
    unsigned int mlen = strlen(msg);
    uint8_t pre[2] = {0, 0};  /* ctx tyhja */
    uint8_t rnd[RNDBYTES];
    for (int i = 0; i < RNDBYTES; i++) rnd[i] = (uint8_t)(i*11+5);

    uint8_t sig[CRYPTO_BYTES];
    int rc_sign = sign_det(sig, (const uint8_t*)msg, mlen, pre, 2, sk, rnd);
    printf("sign rc=%d (odotettu 0)\n", rc_sign);

    int rc_verify = verify_det(sig, (const uint8_t*)msg, mlen, pre, 2, pk);
    printf("verify (oikea): rc=%d (odotettu 0)\n", rc_verify);

    uint8_t bad_msg_buf[100];
    strcpy((char*)bad_msg_buf, msg);
    bad_msg_buf[0] ^= 1;
    int rc_verify_bad = verify_det(sig, bad_msg_buf, mlen, pre, 2, pk);
    printf("verify (turmeltu viesti): rc=%d (odotettu -1)\n", rc_verify_bad);

    FILE *f = fopen("fullsig_msg.txt", "w");
    fprintf(f, "%s", msg); fclose(f);
    f = fopen("fullsig_msglen.txt", "w"); fprintf(f, "%u\n", mlen); fclose(f);
    f = fopen("fullsig_rnd.txt", "w"); for(int i=0;i<RNDBYTES;i++) fprintf(f,"%d\n",rnd[i]); fclose(f);
    f = fopen("fullsig_golden.txt", "w"); for(int i=0;i<CRYPTO_BYTES;i++) fprintf(f,"%u\n",sig[i]); fclose(f);

    return 0;
}
