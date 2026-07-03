#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define DILITHIUM_MODE 3
#include "params.h"
#include "poly.h"
#include "polyvec.h"
#include "reduce.h"
#include "ntt.h"
#include "rounding.h"
#include "fips202.h"

int main(void) {
    /* Kiinteat syotteet, samat kuin aiemmissa keypair-testeissa periaatteessa,
     * mutta uudet arvot jottei sekoitu vanhaan */
    uint8_t rho[SEEDBYTES], rhoprime[CRHBYTES], mu[CRHBYTES];
    for (int i = 0; i < SEEDBYTES; i++) rho[i] = (uint8_t)(i * 71 + 19);
    for (int i = 0; i < CRHBYTES; i++) rhoprime[i] = (uint8_t)(i * 37 + 101);
    for (int i = 0; i < CRHBYTES; i++) mu[i] = (uint8_t)(i * 53 + 7);

    polyvecl mat[K];
    polyvecl s1, s1hat, y, z;
    polyveck s2, s2hat, t0, t0hat, w1, w0, h;
    poly cp;
    uint16_t nonce = 0;
    uint8_t sig_w1[K * POLYW1_PACKEDBYTES];
    uint8_t ctilde[CTILDEBYTES];

    polyvec_matrix_expand(mat, rho);

    /* Synteettiset mutta ETA-rajatut s1/s2/t0 (ei oikea keypair, mutta
     * kelvollinen signeeraustestille - sama periaate kuin compute_t:n
     * synteettinen testidata). */
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) s1.vec[i].coeffs[n] = (n % 9) - 4;
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) s2.vec[i].coeffs[n] = ((n*3) % 9) - 4;
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) t0.vec[i].coeffs[n] = ((n*5) % 17) - 8;

    s1hat = s1; polyvecl_ntt(&s1hat);
    s2hat = s2; polyveck_ntt(&s2hat);
    t0hat = t0; polyveck_ntt(&t0hat);

    int attempts = 0;
rej:
    attempts++;
    polyvecl_uniform_gamma1(&y, rhoprime, nonce++);

    z = y;
    polyvecl_ntt(&z);
    polyvec_matrix_pointwise_montgomery(&w1, mat, &z);
    polyveck_reduce(&w1);
    polyveck_invntt_tomont(&w1);

    polyveck_caddq(&w1);
    polyveck_decompose(&w1, &w0, &w1);
    for (int i = 0; i < K; i++) polyw1_pack(sig_w1 + i*POLYW1_PACKEDBYTES, &w1.vec[i]);

    keccak_state state;
    shake256_init(&state);
    shake256_absorb(&state, mu, CRHBYTES);
    shake256_absorb(&state, sig_w1, K*POLYW1_PACKEDBYTES);
    shake256_finalize(&state);
    shake256_squeeze(ctilde, CTILDEBYTES, &state);
    poly_challenge(&cp, ctilde);
    poly_ntt(&cp);

    polyvecl_pointwise_poly_montgomery(&z, &cp, &s1hat);
    polyvecl_invntt_tomont(&z);
    polyvecl_add(&z, &z, &y);
    polyvecl_reduce(&z);
    if (polyvecl_chknorm(&z, GAMMA1 - BETA)) goto rej;

    polyveck_pointwise_poly_montgomery(&h, &cp, &s2hat);
    polyveck_invntt_tomont(&h);
    polyveck_sub(&w0, &w0, &h);
    polyveck_reduce(&w0);
    if (polyveck_chknorm(&w0, GAMMA2 - BETA)) goto rej;

    polyveck_pointwise_poly_montgomery(&h, &cp, &t0hat);
    polyveck_invntt_tomont(&h);
    polyveck_reduce(&h);
    if (polyveck_chknorm(&h, GAMMA2)) goto rej;

    polyveck_add(&w0, &w0, &h);
    unsigned int n_hints = polyveck_make_hint(&h, &w0, &w1);
    if (n_hints > OMEGA) goto rej;

    printf("attempts=%d nonce_final=%u n_hints=%u\n", attempts, nonce, n_hints);

    FILE *f;
    f = fopen("sig_z.txt", "w");
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", z.vec[i].coeffs[n]);
    fclose(f);
    f = fopen("sig_h.txt", "w");
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", h.vec[i].coeffs[n]);
    fclose(f);
    f = fopen("sig_meta.txt", "w");
    fprintf(f, "%d\n%u\n%u\n", attempts, nonce, n_hints);
    fclose(f);
    f = fopen("sig_inputs_rho.txt", "w");
    for (int i = 0; i < SEEDBYTES; i++) fprintf(f, "%d\n", rho[i]);
    fclose(f);
    f = fopen("sig_inputs_rhoprime.txt", "w");
    for (int i = 0; i < CRHBYTES; i++) fprintf(f, "%d\n", rhoprime[i]);
    fclose(f);
    f = fopen("sig_inputs_mu.txt", "w");
    for (int i = 0; i < CRHBYTES; i++) fprintf(f, "%d\n", mu[i]);
    fclose(f);
    f = fopen("sig_inputs_s1.txt", "w");
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", s1.vec[i].coeffs[n]);
    fclose(f);
    f = fopen("sig_inputs_s2.txt", "w");
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", s2.vec[i].coeffs[n]);
    fclose(f);
    f = fopen("sig_inputs_t0.txt", "w");
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", t0.vec[i].coeffs[n]);
    fclose(f);

    return 0;
}
