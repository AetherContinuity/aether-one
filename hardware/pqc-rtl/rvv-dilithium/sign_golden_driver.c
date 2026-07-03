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
    /* Synteettiset mutta ETA-rajatut s1/s2 (ei oikea satunnainen keypair,
     * mutta kelvollinen signeeraustestille). t0 EI ole mielivaltainen -
     * se lasketaan oikeasti t=As+e:sta samalla s1/s2/mat:lla, jotta
     * signeerauksen ja verifioinnin julkinen avain on sama avainpari. */
    for (int i = 0; i < L; i++) for (int n = 0; n < N; n++) s1.vec[i].coeffs[n] = (n % 9) - 4;
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) s2.vec[i].coeffs[n] = ((n*3) % 9) - 4;

    polyveck t1_pub;
    {
        polyvecl s1hat_for_t = s1;
        polyvecl_ntt(&s1hat_for_t);
        for (int i = 0; i < K; i++) {
            poly tmp;
            poly_pointwise_montgomery(&t0.vec[i], &mat[i].vec[0], &s1hat_for_t.vec[0]);
            for (int j = 1; j < L; j++) {
                poly_pointwise_montgomery(&tmp, &mat[i].vec[j], &s1hat_for_t.vec[j]);
                poly_add(&t0.vec[i], &t0.vec[i], &tmp);
            }
        }
        polyveck_reduce(&t0);
        polyveck_invntt_tomont(&t0);
        polyveck_add(&t0, &t0, &s2);
        polyveck_caddq(&t0);
        polyveck_power2round(&t1_pub, &t0, &t0);
        /* HUOM: power2round(&t1_pub, &t0, &t0) kirjoittaa a0:n takaisin
         * t0:aan (sallittu, poly-per-poly ei limity). Nyt t0 = LowBits,
         * t1_pub = HighBits - oikea Power2Round-pari. */
    }

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

    /* SISAINEN ITSEVERIFIOINTI heti muistissa, ei tiedostokierrätysta. */
    {
        polyveck w1_self, t1_self_copy, h_self_copy;
        polyvecl z_self_copy;
        poly cp_self;
        uint8_t buf_self[K*POLYW1_PACKEDBYTES];
        uint8_t c2_self[CTILDEBYTES];

        z_self_copy = z;
        h_self_copy = h;
        t1_self_copy = t1_pub;

        poly_challenge(&cp_self, ctilde);
        polyvecl mat2[K];
        polyvec_matrix_expand(mat2, rho);
        polyvecl_ntt(&z_self_copy);
        polyvec_matrix_pointwise_montgomery(&w1_self, mat2, &z_self_copy);
        poly_ntt(&cp_self);
        polyveck_shiftl(&t1_self_copy);
        polyveck_ntt(&t1_self_copy);
        polyveck_pointwise_poly_montgomery(&t1_self_copy, &cp_self, &t1_self_copy);
        polyveck_sub(&w1_self, &w1_self, &t1_self_copy);
        polyveck_reduce(&w1_self);
        polyveck_invntt_tomont(&w1_self);
        polyveck_caddq(&w1_self);
        polyveck_use_hint(&w1_self, &w1_self, &h_self_copy);
        polyveck_pack_w1(buf_self, &w1_self);

        keccak_state st_self;
        shake256_init(&st_self);
        shake256_absorb(&st_self, mu, CRHBYTES);
        shake256_absorb(&st_self, buf_self, K*POLYW1_PACKEDBYTES);
        shake256_finalize(&st_self);
        shake256_squeeze(c2_self, CTILDEBYTES, &st_self);

        int self_ok = 1;
        for (int i = 0; i < CTILDEBYTES; i++) if (ctilde[i] != c2_self[i]) self_ok = 0;
        printf("SISAINEN ITSEVERIFIOINTI: %s\n", self_ok ? "OK (c==c2)" : "EPAONNISTUI (c!=c2)");
    }

    FILE *f;
    f = fopen("ver_ctilde.txt", "w");
    for (int i = 0; i < CTILDEBYTES; i++) fprintf(f, "%d\n", ctilde[i]);
    fclose(f);
    f = fopen("ver_t1.txt", "w");
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) fprintf(f, "%d\n", t1_pub.vec[i].coeffs[n]);
    fclose(f);
    f = fopen("ver_h.txt", "w");
    for (int i = 0; i < K; i++) for (int n = 0; n < N; n++) fprintf(f, "%u\n", h.vec[i].coeffs[n]);
    fclose(f);

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
