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
#define OMEGA 55
#define POLYW1_PACKEDBYTES 128
#define SHAKE256_RATE 136

extern void ntt_rvv(int32_t *a);
extern void invntt_rvv(int32_t *a);
extern void poly_add_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_sub_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_reduce32_rvv(int32_t*);
extern void poly_caddq_rvv(int32_t*);
extern void poly_pointwise_montgomery_rvv(int32_t*, const int32_t*, const int32_t*);
extern void polyvecl_pointwise_poly_montgomery_rvv(int32_t r[L][N], const int32_t *a, int32_t v[L][N]);
extern void polyveck_pointwise_poly_montgomery_rvv(int32_t r[K][N], const int32_t *a, int32_t v[K][N]);
extern void polyw1_pack_rvv(uint8_t *r, const int32_t *a);
extern void sample_in_ball_rvv(int32_t *c, const uint8_t *seed);
extern int polyvecl_chknorm_rvv(int32_t v[L][N], int32_t bound);
extern int polyveck_chknorm_rvv(int32_t v[K][N], int32_t bound);
extern void polyveck_decompose_rvv(int32_t v1[K][N], int32_t v0[K][N], int32_t v[K][N]);
extern unsigned int polyveck_make_hint_rvv(uint32_t h[K][N], int32_t v0[K][N], int32_t v1[K][N]);

typedef void (*squeeze_fn_t)(uint8_t *out, unsigned int nblocks, void *ctx);
extern void poly_uniform_gamma1_rvv(int32_t *a, squeeze_fn_t squeeze, void *ctx);

/* Kutsujan toimittama SHAKE256-alustin+squeeze polyvecl_uniform_gamma1:lle
 * (nonce riippuu i:sta, ei vain kerran alustettu tila). */
typedef void (*gamma1_shake_fn_t)(uint8_t *seed, uint16_t nonce, uint8_t *out, unsigned int outlen);
/* Kutsujan toimittama SHAKE256 mu||w1pack -> ctilde (CTILDEBYTES tavua) */
typedef void (*challenge_hash_fn_t)(const uint8_t *mu, const uint8_t *sig_w1, unsigned int w1len, uint8_t *ctilde_out);

typedef struct { gamma1_shake_fn_t fn; uint8_t *seed; uint16_t nonce; } gamma1_ctx_t;

static void gamma1_adapter(uint8_t *out, unsigned int nblocks, void *vctx) {
    gamma1_ctx_t *c = (gamma1_ctx_t *)vctx;
    c->fn(c->seed, c->nonce, out, nblocks * SHAKE256_RATE);
}

/* Koko allekirjoituksen sisaydin, vastaa ref/sign.c:n
 * crypto_sign_signature_internal:ia "Expand matrix"-kohdasta alkaen.
 * EI kata: sk-purkua, mu:n laskentaa viestista, rnd/key-kasittelya -
 * ne ovat oma, tekemtaon kerroksensa. Tama testaa matemaattisen ytimen
 * ja hylkayssilmukan kontrollivuon.
 *
 * Palauttaa yritysten maaran (>=1). z_out/h_out taytetaan onnistuneella
 * allekirjoituksella. gamma1_shake ja challenge_hash ovat kutsujan
 * toimittamia SHAKE-sidontoja (RVV-koodi ei tieda mitaan SHAKE:sta itse -
 * sama periaate kuin poly_uniform_rvv:ssa). */
unsigned int sign_core_rvv(
    int32_t z_out[L][N], uint32_t h_out[K][N], unsigned int *n_hints_out,
    int32_t mat[K][L][N], int32_t s1hat[L][N], int32_t s2hat[K][N], int32_t t0hat[K][N],
    uint8_t rhoprime[CRHBYTES], uint8_t mu[CRHBYTES],
    gamma1_shake_fn_t gamma1_shake, challenge_hash_fn_t challenge_hash,
    uint8_t ctilde_out[CTILDEBYTES])
{
    uint16_t nonce = 0;
    unsigned int attempts = 0;
    int32_t y[L][N], z[L][N];
    int32_t w1[K][N], w0[K][N], w_tmp[K][N];
    int32_t cp[N];
    uint8_t sig_w1[K * POLYW1_PACKEDBYTES];
    uint8_t ctilde[CTILDEBYTES];

    for (;;) {
        attempts++;

        /* y = poly_uniform_gamma1 jokaiselle L:lle, nonce=i (kutsujan
         * gamma1_shake hoitaa SHAKE256-alustuksen per i - sama rakenne
         * kuin poly_uniform_gamma1_rvv:n oma testi, mutta nyt nonce-arvo
         * vaihtelee joka yrityksella koska se on tama-tason nonce, ei i). */
        for (unsigned int i = 0; i < L; i++) {
            gamma1_ctx_t ctx = { gamma1_shake, rhoprime, (uint16_t)(L * nonce + i) };
            poly_uniform_gamma1_rvv(y[i], gamma1_adapter, &ctx);
        }
        nonce++;

        /* z = NTT(y) (kopio, y sailytetaan) */
        for (unsigned int i = 0; i < L; i++) memcpy(z[i], y[i], sizeof(z[i]));
        for (unsigned int i = 0; i < L; i++) ntt_rvv(z[i]);

        /* w = matrix * z, sama rakenne kuin compute_t_rvv:n matriisikertolasku */
        for (unsigned int i = 0; i < K; i++) {
            int32_t acc[N], tmp[N];
            poly_pointwise_montgomery_rvv(acc, mat[i][0], z[0]);
            for (unsigned int j = 1; j < L; j++) {
                poly_pointwise_montgomery_rvv(tmp, mat[i][j], z[j]);
                poly_add_rvv(acc, acc, tmp);
            }
            poly_reduce32_rvv(acc);
            invntt_rvv(acc);
            memcpy(w_tmp[i], acc, sizeof(acc));
        }
        for (unsigned int i = 0; i < K; i++) poly_caddq_rvv(w_tmp[i]);
        polyveck_decompose_rvv(w1, w0, w_tmp);
        for (unsigned int i = 0; i < K; i++) polyw1_pack_rvv(sig_w1 + i * POLYW1_PACKEDBYTES, w1[i]);

        challenge_hash(mu, sig_w1, K * POLYW1_PACKEDBYTES, ctilde);
        sample_in_ball_rvv(cp, ctilde);
        ntt_rvv(cp);

        polyvecl_pointwise_poly_montgomery_rvv(z, cp, s1hat);
        for (unsigned int i = 0; i < L; i++) invntt_rvv(z[i]);
        for (unsigned int i = 0; i < L; i++) poly_add_rvv(z[i], z[i], y[i]);
        for (unsigned int i = 0; i < L; i++) poly_reduce32_rvv(z[i]);
        if (polyvecl_chknorm_rvv(z, GAMMA1 - BETA)) continue;

        int32_t h_tmp[K][N];
        polyveck_pointwise_poly_montgomery_rvv(h_tmp, cp, s2hat);
        for (unsigned int i = 0; i < K; i++) invntt_rvv(h_tmp[i]);
        for (unsigned int i = 0; i < K; i++) poly_sub_rvv(w0[i], w0[i], h_tmp[i]);
        for (unsigned int i = 0; i < K; i++) poly_reduce32_rvv(w0[i]);
        if (polyveck_chknorm_rvv(w0, GAMMA2 - BETA)) continue;

        polyveck_pointwise_poly_montgomery_rvv(h_tmp, cp, t0hat);
        for (unsigned int i = 0; i < K; i++) invntt_rvv(h_tmp[i]);
        for (unsigned int i = 0; i < K; i++) poly_reduce32_rvv(h_tmp[i]);
        if (polyveck_chknorm_rvv(h_tmp, GAMMA2)) continue;

        for (unsigned int i = 0; i < K; i++) poly_add_rvv(w0[i], w0[i], h_tmp[i]);
        unsigned int n_hints = polyveck_make_hint_rvv(h_out, w0, w1);
        if (n_hints > OMEGA) continue;

        memcpy(z_out, z, sizeof(z));
        memcpy(ctilde_out, ctilde, CTILDEBYTES);
        *n_hints_out = n_hints;
        return attempts;
    }
}
