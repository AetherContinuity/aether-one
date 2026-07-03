#include <stdint.h>
#include <string.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define CTILDEBYTES 48
#define GAMMA1 (1 << 19)
#define GAMMA2 ((8380417 - 1) / 32)
#define BETA 196
#define POLYW1_PACKEDBYTES 128

extern void ntt_rvv(int32_t *a);
extern void invntt_rvv(int32_t *a);
extern void poly_add_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_sub_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_reduce32_rvv(int32_t*);
extern void poly_caddq_rvv(int32_t*);
extern void poly_shiftl_rvv(int32_t*);
extern void poly_use_hint_rvv(int32_t *out_a1, const int32_t *a, const uint32_t *hint);
extern void poly_pointwise_montgomery_rvv(int32_t*, const int32_t*, const int32_t*);
extern void polyveck_pointwise_poly_montgomery_rvv(int32_t r[K][N], const int32_t *a, int32_t v[K][N]);
extern void polyw1_pack_rvv(uint8_t *r, const int32_t *a);
extern void sample_in_ball_rvv(int32_t *c, const uint8_t *seed);
extern int polyvecl_chknorm_rvv(int32_t v[L][N], int32_t bound);
extern void matrix_expand_rvv(int32_t mat[K][L][N], uint8_t rho[SEEDBYTES],
                               void (*shake_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int));

typedef void (*challenge_hash_fn_t)(const uint8_t *mu, const uint8_t *sig_w1, unsigned int w1len, uint8_t *ctilde_out);
typedef void (*shake128_fn_t)(uint8_t*, uint16_t, uint8_t*, unsigned int);

/* Verifioinnin sisaydin, vastaa ref/sign.c:n crypto_sign_verify_internal:ia
 * "Matrix-vector multiplication"-kohdasta alkaen. Palauttaa 0 jos kelvollinen,
 * -1 jos ei. EI kata unpack_pk/unpack_sig:ia (koodaus, oma kerroksensa). */
int verify_core_rvv(uint8_t rho[SEEDBYTES], int32_t t1[K][N],
                     uint8_t ctilde[CTILDEBYTES], int32_t z[L][N], uint32_t h[K][N],
                     uint8_t mu[CRHBYTES],
                     shake128_fn_t shake128_fn, challenge_hash_fn_t challenge_hash)
{
    if (polyvecl_chknorm_rvv(z, GAMMA1 - BETA)) return -1;

    int32_t cp[N];
    sample_in_ball_rvv(cp, ctilde);

    int32_t mat[K][L][N];
    matrix_expand_rvv(mat, rho, shake128_fn);

    for (unsigned int i = 0; i < L; i++) ntt_rvv(z[i]);

    int32_t w1[K][N];
    for (unsigned int i = 0; i < K; i++) {
        int32_t acc[N], tmp[N];
        poly_pointwise_montgomery_rvv(acc, mat[i][0], z[0]);
        for (unsigned int j = 1; j < L; j++) {
            poly_pointwise_montgomery_rvv(tmp, mat[i][j], z[j]);
            poly_add_rvv(acc, acc, tmp);
        }
        memcpy(w1[i], acc, sizeof(acc));
    }

    ntt_rvv(cp);
    int32_t t1_local[K][N];
    memcpy(t1_local, t1, sizeof(t1_local));
    for (unsigned int i = 0; i < K; i++) poly_shiftl_rvv(t1_local[i]);
    for (unsigned int i = 0; i < K; i++) ntt_rvv(t1_local[i]);
    polyveck_pointwise_poly_montgomery_rvv(t1_local, cp, t1_local);

    for (unsigned int i = 0; i < K; i++) poly_sub_rvv(w1[i], w1[i], t1_local[i]);
    for (unsigned int i = 0; i < K; i++) poly_reduce32_rvv(w1[i]);
    for (unsigned int i = 0; i < K; i++) invntt_rvv(w1[i]);

    for (unsigned int i = 0; i < K; i++) poly_caddq_rvv(w1[i]);
    int32_t w1_final[K][N];
    for (unsigned int i = 0; i < K; i++) poly_use_hint_rvv(w1_final[i], w1[i], h[i]);

    uint8_t buf[K * POLYW1_PACKEDBYTES];
    for (unsigned int i = 0; i < K; i++) polyw1_pack_rvv(buf + i * POLYW1_PACKEDBYTES, w1_final[i]);

    uint8_t c2[CTILDEBYTES];
    challenge_hash(mu, buf, K * POLYW1_PACKEDBYTES, c2);

    for (unsigned int i = 0; i < CTILDEBYTES; i++)
        if (ctilde[i] != c2[i]) return -1;
    return 0;
}
