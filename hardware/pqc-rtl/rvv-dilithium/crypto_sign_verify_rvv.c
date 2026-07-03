#include <stdint.h>
#include <string.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define TRBYTES 64
#define CTILDEBYTES 48
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + K*320)
#define CRYPTO_BYTES (CTILDEBYTES + L*640 + 55 + K)

extern void unpack_pk_rvv(uint8_t rho[SEEDBYTES], int32_t t1[K][N], const uint8_t *pk);
extern int unpack_sig_rvv(uint8_t ctilde[CTILDEBYTES], int32_t z[L][N], uint32_t h[K][N],
                           const uint8_t *sig);
extern int verify_core_rvv(uint8_t rho[SEEDBYTES], int32_t t1[K][N],
                            uint8_t ctilde[CTILDEBYTES], int32_t z[L][N], uint32_t h[K][N],
                            uint8_t mu[CRHBYTES],
                            void (*shake128_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int),
                            void (*challenge_hash)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*));

typedef void (*shake128_fn_t)(uint8_t*, uint16_t, uint8_t*, unsigned int);
typedef void (*shake256_multi_fn_t)(const uint8_t **parts, const unsigned int *partlens, int nparts,
                                     uint8_t *out, unsigned int outlen);
typedef void (*shake256_fn_t)(const uint8_t *input, unsigned int inlen, uint8_t *out, unsigned int outlen);
typedef void (*challenge_hash_fn_t)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*);

/* crypto_sign_verify. Palauttaa 0 jos kelvollinen, -1 jos ei
 * (mukaan lukien rakenteellisesti virheellinen allekirjoitus). */
int crypto_sign_verify_rvv(const uint8_t sig[CRYPTO_BYTES], const uint8_t *m, unsigned int mlen,
                            const uint8_t *ctx, unsigned int ctxlen,
                            const uint8_t pk[CRYPTO_PUBLICKEYBYTES],
                            shake128_fn_t shake128_fn,
                            shake256_fn_t shake256_fn,
                            shake256_multi_fn_t shake256_multi,
                            challenge_hash_fn_t challenge_hash) {
    if (ctxlen > 255) return -1;
    uint8_t pre[257];
    pre[0] = 0;
    pre[1] = (uint8_t)ctxlen;
    memcpy(pre + 2, ctx, ctxlen);
    unsigned int prelen = 2 + ctxlen;

    uint8_t rho[SEEDBYTES];
    int32_t t1[K][N];
    unpack_pk_rvv(rho, t1, pk);

    uint8_t ctilde[CTILDEBYTES];
    int32_t z[L][N];
    uint32_t h[K][N];
    if (unpack_sig_rvv(ctilde, z, h, sig)) return -1;

    /* mu = SHAKE256(SHAKE256(pk, TRBYTES) || pre || m) */
    uint8_t tr[TRBYTES];
    shake256_fn(pk, CRYPTO_PUBLICKEYBYTES, tr, TRBYTES);

    uint8_t mu[CRHBYTES];
    {
        const uint8_t *parts[3] = { tr, pre, m };
        unsigned int lens[3] = { TRBYTES, prelen, mlen };
        shake256_multi(parts, lens, 3, mu, CRHBYTES);
    }

    return verify_core_rvv(rho, t1, ctilde, z, h, mu, shake128_fn, challenge_hash);
}
