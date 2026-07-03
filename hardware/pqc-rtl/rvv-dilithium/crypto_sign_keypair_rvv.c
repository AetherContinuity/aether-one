#include <stdint.h>
#include <string.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define TRBYTES 64
#define POLYT1_PACKEDBYTES 320
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + K*POLYT1_PACKEDBYTES)

extern void matrix_expand_rvv(int32_t mat[K][L][N], uint8_t rho[SEEDBYTES],
                               void (*shake128_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int));
extern void expand_s_rvv(int32_t s1[L][N], int32_t s2[K][N], uint8_t seed[CRHBYTES]);
extern void compute_t_rvv(int32_t t1_out[K][N], int32_t t0_out[K][N],
                           int32_t mat[K][L][N], int32_t s1[L][N], int32_t s2[K][N]);
extern void pack_pk_rvv(uint8_t pk[CRYPTO_PUBLICKEYBYTES], uint8_t rho[SEEDBYTES], int32_t t1[K][N]);
extern void pack_sk_rvv(uint8_t *sk, uint8_t rho[SEEDBYTES], uint8_t tr[TRBYTES], uint8_t key[SEEDBYTES],
                         int32_t t0[K][N], int32_t s1[L][N], int32_t s2[K][N]);

typedef void (*shake128_fn_t)(uint8_t*, uint16_t, uint8_t*, unsigned int);
/* shake256_fn: absorboi input[inlen], squeeze outlen tavua ulos. Kutsuja
 * toimittaa (sama periaate kuin muuallakin tassa hakemistossa - RVV-koodi
 * ei tieda mitaan SHAKE:sta itse). */
typedef void (*shake256_fn_t)(const uint8_t *input, unsigned int inlen, uint8_t *out, unsigned int outlen);

/* crypto_sign_keypair, vastaa ref/sign.c:ta. EI kutsu randombytes:ia -
 * kutsuja antaa "satunnaisen" 32-tavuisen seedin valmiiksi (deterministinen
 * testattavuus, sama periaate kuin koko tama hakemisto on noudattanut). */
void crypto_sign_keypair_rvv(uint8_t pk[CRYPTO_PUBLICKEYBYTES], uint8_t *sk,
                              uint8_t random_seed[SEEDBYTES],
                              shake128_fn_t shake128_fn, shake256_fn_t shake256_fn) {
    uint8_t seedbuf_in[SEEDBYTES + 2];
    uint8_t seedbuf_out[2*SEEDBYTES + CRHBYTES];
    memcpy(seedbuf_in, random_seed, SEEDBYTES);
    seedbuf_in[SEEDBYTES + 0] = K;
    seedbuf_in[SEEDBYTES + 1] = L;
    shake256_fn(seedbuf_in, SEEDBYTES + 2, seedbuf_out, sizeof(seedbuf_out));

    uint8_t *rho = seedbuf_out;
    uint8_t *rhoprime = rho + SEEDBYTES;
    uint8_t *key = rhoprime + CRHBYTES;

    int32_t mat[K][L][N];
    matrix_expand_rvv(mat, rho, shake128_fn);

    int32_t s1[L][N], s2[K][N];
    expand_s_rvv(s1, s2, rhoprime);

    int32_t t1[K][N], t0[K][N];
    compute_t_rvv(t1, t0, mat, s1, s2);

    pack_pk_rvv(pk, rho, t1);

    uint8_t tr[TRBYTES];
    shake256_fn(pk, CRYPTO_PUBLICKEYBYTES, tr, TRBYTES);

    pack_sk_rvv(sk, rho, tr, key, t0, s1, s2);
}
