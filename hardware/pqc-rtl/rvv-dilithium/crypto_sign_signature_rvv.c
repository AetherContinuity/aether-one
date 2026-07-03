#include <stdint.h>
#include <string.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define TRBYTES 64
#define RNDBYTES 32
#define CTILDEBYTES 48
#define CRYPTO_BYTES (CTILDEBYTES + L*640 + 55 + K)

extern void unpack_sk_rvv(uint8_t rho[SEEDBYTES], uint8_t tr[TRBYTES], uint8_t key[SEEDBYTES],
                           int32_t t0[K][N], int32_t s1[L][N], int32_t s2[K][N],
                           const uint8_t *sk);
extern void matrix_expand_rvv(int32_t mat[K][L][N], uint8_t rho[SEEDBYTES],
                               void (*shake128_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int));
extern void ntt_rvv(int32_t *a);
extern unsigned int sign_core_rvv(
    int32_t z_out[L][N], uint32_t h_out[K][N], unsigned int *n_hints_out,
    int32_t mat[K][L][N], int32_t s1hat[L][N], int32_t s2hat[K][N], int32_t t0hat[K][N],
    uint8_t rhoprime[CRHBYTES], uint8_t mu[CRHBYTES],
    void (*gamma1_shake)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*challenge_hash)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*),
    uint8_t ctilde_out[CTILDEBYTES]);
extern void pack_sig_rvv(uint8_t *sig, uint8_t ctilde[CTILDEBYTES], int32_t z[L][N], uint32_t h[K][N]);

typedef void (*shake128_fn_t)(uint8_t*, uint16_t, uint8_t*, unsigned int);
/* shake256_multi_fn_t: absorboi nparts osaa peräkkäin, squeeze outlen ulos.
 * Kutsuja hoitaa oikean SHAKE256-tilan (fips202/OpenSSL) - RVV-koodi ei
 * tieda mitaan hajautusfunktion sisäisesta toteutuksesta. */
typedef void (*shake256_multi_fn_t)(const uint8_t **parts, const unsigned int *partlens, int nparts,
                                     uint8_t *out, unsigned int outlen);
typedef void (*gamma1_shake_fn_t)(uint8_t*, uint16_t, uint8_t*, unsigned int);
typedef void (*challenge_hash_fn_t)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*);

/* crypto_sign_signature. ctx voi olla tyhja (ctxlen=0). rnd annetaan
 * parametrina (ei randombytes-kutsua - deterministinen testattavuus). */
int crypto_sign_signature_rvv(uint8_t sig[CRYPTO_BYTES], const uint8_t *m, unsigned int mlen,
                               const uint8_t *ctx, unsigned int ctxlen,
                               const uint8_t *sk, uint8_t rnd[RNDBYTES],
                               shake128_fn_t shake128_fn,
                               shake256_multi_fn_t shake256_multi,
                               gamma1_shake_fn_t gamma1_shake,
                               challenge_hash_fn_t challenge_hash) {
    if (ctxlen > 255) return -1;
    uint8_t pre[257];
    pre[0] = 0;
    pre[1] = (uint8_t)ctxlen;
    memcpy(pre + 2, ctx, ctxlen);
    unsigned int prelen = 2 + ctxlen;

    uint8_t rho[SEEDBYTES], tr[TRBYTES], key[SEEDBYTES];
    int32_t t0[K][N], s1[L][N], s2[K][N];
    unpack_sk_rvv(rho, tr, key, t0, s1, s2, sk);

    uint8_t mu[CRHBYTES];
    {
        const uint8_t *parts[3] = { tr, pre, m };
        unsigned int lens[3] = { TRBYTES, prelen, mlen };
        shake256_multi(parts, lens, 3, mu, CRHBYTES);
    }

    uint8_t rhoprime[CRHBYTES];
    {
        const uint8_t *parts[3] = { key, rnd, mu };
        unsigned int lens[3] = { SEEDBYTES, RNDBYTES, CRHBYTES };
        shake256_multi(parts, lens, 3, rhoprime, CRHBYTES);
    }

    int32_t mat[K][L][N];
    matrix_expand_rvv(mat, rho, shake128_fn);

    int32_t s1hat[L][N], s2hat[K][N], t0hat[K][N];
    for (unsigned int i = 0; i < L; i++) { memcpy(s1hat[i], s1[i], sizeof(s1[i])); ntt_rvv(s1hat[i]); }
    for (unsigned int i = 0; i < K; i++) { memcpy(s2hat[i], s2[i], sizeof(s2[i])); ntt_rvv(s2hat[i]); }
    for (unsigned int i = 0; i < K; i++) { memcpy(t0hat[i], t0[i], sizeof(t0[i])); ntt_rvv(t0hat[i]); }

    int32_t z[L][N];
    uint32_t h[K][N];
    unsigned int n_hints;
    uint8_t ctilde[CTILDEBYTES];
    sign_core_rvv(z, h, &n_hints, mat, s1hat, s2hat, t0hat, rhoprime, mu,
                  gamma1_shake, challenge_hash, ctilde);

    pack_sig_rvv(sig, ctilde, z, h);
    return 0;
}
