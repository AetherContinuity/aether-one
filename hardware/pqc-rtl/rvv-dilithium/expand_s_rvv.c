#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define K 6
#define L 5
#define N 256
#define CRHBYTES 64

extern unsigned int poly_uniform_eta_rvv(int32_t *a,
                                          void (*squeeze)(uint8_t*, unsigned int, void*),
                                          void *ctx);

static void eta_squeeze(uint8_t *out, unsigned int nblocks, void *vctx) {
    keccak_state *state = (keccak_state *)vctx;
    shake256_squeezeblocks(out, nblocks, state);
}

/* ExpandS: s1 (L polynomia, nonce 0..L-1) + s2 (K polynomia, nonce L..L+K-1).
 * Sama nonce-jarjestys kuin ref/sign.c: polyvecl_uniform_eta(&s1,rp,0),
 * polyveck_uniform_eta(&s2,rp,L). Jokaiselle nonce-arvolle oma, pysyva
 * Keccak-tila (absorb kerran, squeeze niin monta kertaa kuin
 * poly_uniform_eta_rvv tarvitsee). */
void expand_s_rvv(int32_t s1[L][N], int32_t s2[K][N], uint8_t seed[CRHBYTES]) {
    for (unsigned int i = 0; i < L; i++) {
        uint8_t input[CRHBYTES + 2];
        memcpy(input, seed, CRHBYTES);
        input[CRHBYTES] = (uint8_t)(i & 0xFF);
        input[CRHBYTES + 1] = (uint8_t)((i >> 8) & 0xFF);
        keccak_state state;
        shake256_absorb_once(&state, input, sizeof(input));
        poly_uniform_eta_rvv(s1[i], eta_squeeze, &state);
    }
    for (unsigned int i = 0; i < K; i++) {
        unsigned int nonce = L + i;
        uint8_t input[CRHBYTES + 2];
        memcpy(input, seed, CRHBYTES);
        input[CRHBYTES] = (uint8_t)(nonce & 0xFF);
        input[CRHBYTES + 1] = (uint8_t)((nonce >> 8) & 0xFF);
        keccak_state state;
        shake256_absorb_once(&state, input, sizeof(input));
        poly_uniform_eta_rvv(s2[i], eta_squeeze, &state);
    }
}
