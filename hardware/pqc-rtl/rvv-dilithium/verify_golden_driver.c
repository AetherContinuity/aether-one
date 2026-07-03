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

/* Vastaa crypto_sign_verify_internal:ia "Matrix-vector multiplication"-
 * kohdasta alkaen (unpack_pk/unpack_sig ohitettu - annetaan valmiiksi
 * puretut arvot suoraan, sama periaate kuin sign_core:ssa). */
static int verify_core_ref(uint8_t rho[SEEDBYTES], polyveck *t1,
                            uint8_t c[CTILDEBYTES], polyvecl *z, polyveck *h,
                            uint8_t mu[CRHBYTES]) {
    uint8_t buf[K*POLYW1_PACKEDBYTES];
    uint8_t c2[CTILDEBYTES];
    poly cp;
    polyvecl mat[K];
    polyveck w1, t1_local;

    if (polyvecl_chknorm(z, GAMMA1 - BETA)) return -1;

    poly_challenge(&cp, c);
    polyvec_matrix_expand(mat, rho);

    polyvecl_ntt(z);
    polyvec_matrix_pointwise_montgomery(&w1, mat, z);

    poly_ntt(&cp);
    t1_local = *t1;
    polyveck_shiftl(&t1_local);
    polyveck_ntt(&t1_local);
    polyveck_pointwise_poly_montgomery(&t1_local, &cp, &t1_local);

    polyveck_sub(&w1, &w1, &t1_local);
    polyveck_reduce(&w1);
    polyveck_invntt_tomont(&w1);

    polyveck_caddq(&w1);
    polyveck_use_hint(&w1, &w1, h);
    polyveck_pack_w1(buf, &w1);

    keccak_state state;
    shake256_init(&state);
    shake256_absorb(&state, mu, CRHBYTES);
    shake256_absorb(&state, buf, K*POLYW1_PACKEDBYTES);
    shake256_finalize(&state);
    shake256_squeeze(c2, CTILDEBYTES, &state);

    for (unsigned int i = 0; i < CTILDEBYTES; i++)
        if (c[i] != c2[i]) return -1;
    return 0;
}

int main(void) {
    uint8_t rho[SEEDBYTES], mu[CRHBYTES], ctilde[CTILDEBYTES];
    load_u8("sig_inputs_rho.txt", rho, SEEDBYTES);
    load_u8("sig_inputs_mu.txt", mu, CRHBYTES);
    load_u8("ver_ctilde.txt", ctilde, CTILDEBYTES);

    polyveck t1; load_i32("ver_t1.txt", (int32_t*)&t1, K*N);
    polyvecl z; load_i32("sig_z.txt", (int32_t*)&z, L*N);
    polyveck h; load_u32("ver_h.txt", (uint32_t*)&h, K*N);

    int result = verify_core_ref(rho, &t1, ctilde, &z, &h, mu);
    printf("verify result (oikea allekirjoitus): %d (odotettu 0)\n", result);

    FILE *f = fopen("ver_result_valid.txt", "w");
    fprintf(f, "%d\n", result);
    fclose(f);

    /* Negatiivikontrolli referenssin OMASSA logiikassa: turmeltu z */
    polyvecl z2; load_i32("sig_z.txt", (int32_t*)&z2, L*N);
    z2.vec[0].coeffs[0] += 12345;
    int result_bad = verify_core_ref(rho, &t1, ctilde, &z2, &h, mu);
    printf("verify result (turmeltu z): %d (odotettu -1)\n", result_bad);

    return 0;
}
