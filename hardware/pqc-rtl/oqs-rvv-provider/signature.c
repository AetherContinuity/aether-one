/* signature.c - OSSL_FUNC_SIGNATURE_* -toteutus ML-DSA-65-RVV:lle.
 * Signatuurit luettu suoraan core_dispatch.h:sta, ei arvattu. */
#include <openssl/core.h>
#include <openssl/core_dispatch.h>
#include <openssl/rand.h>
#include <openssl/evp.h>
#include <string.h>
#include <stdlib.h>

#define MLDSA_K 6
#define MLDSA_L 5
#define SEEDBYTES 32
#define CRHBYTES 64
#define RNDBYTES 32
#define CTILDEBYTES 48
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + MLDSA_K*320)
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + 64 + MLDSA_L*128 + MLDSA_K*128 + MLDSA_K*416)
#define CRYPTO_BYTES (CTILDEBYTES + MLDSA_L*640 + 55 + MLDSA_K)

/* Sama avainlayout kuin keymgmt.c:ssa. */
typedef struct {
    uint8_t pk[CRYPTO_PUBLICKEYBYTES];
    uint8_t sk[CRYPTO_SECRETKEYBYTES];
    int has_pub;
    int has_priv;
} MLDSA_RVV_KEY;

extern int crypto_sign_signature_rvv(uint8_t*, const uint8_t*, unsigned int,
    const uint8_t*, unsigned int, const uint8_t*, uint8_t*,
    void (*)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*)(const uint8_t**, const unsigned int*, int, uint8_t*, unsigned int),
    void (*)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*));
extern int crypto_sign_verify_rvv(const uint8_t*, const uint8_t*, unsigned int,
    const uint8_t*, unsigned int, const uint8_t*,
    void (*)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*)(const uint8_t*, unsigned int, uint8_t*, unsigned int),
    void (*)(const uint8_t**, const unsigned int*, int, uint8_t*, unsigned int),
    void (*)(const uint8_t*, const uint8_t*, unsigned int, uint8_t*));

/* SHAKE-sidonnat, sama toteutus kuin keymgmt.c:ssa - yksi EVP_DigestFinalXOF-
 * kutsu per tarve, ei toistuvaa (todettu ei-jatkuvaksi aiemmin). */
static void shake128_fn(uint8_t *rho, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[SEEDBYTES + 2];
    memcpy(input, rho, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF;
    input[SEEDBYTES + 1] = (nonce >> 8) & 0xFF;
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake128(), NULL);
    EVP_DigestUpdate(ctx, input, sizeof(input));
    EVP_DigestFinalXOF(ctx, out, outlen);
    EVP_MD_CTX_free(ctx);
}
static void shake256_seedlen(const uint8_t *input, unsigned int inlen, uint8_t *out, unsigned int outlen) {
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake256(), NULL);
    EVP_DigestUpdate(ctx, input, inlen);
    EVP_DigestFinalXOF(ctx, out, outlen);
    EVP_MD_CTX_free(ctx);
}
static void shake256_multi(const uint8_t **parts, const unsigned int *partlens, int nparts,
                            uint8_t *out, unsigned int outlen) {
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake256(), NULL);
    for (int i = 0; i < nparts; i++) EVP_DigestUpdate(ctx, parts[i], partlens[i]);
    EVP_DigestFinalXOF(ctx, out, outlen);
    EVP_MD_CTX_free(ctx);
}
static void gamma1_shake(uint8_t *seed, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF;
    input[CRHBYTES + 1] = (nonce >> 8) & 0xFF;
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake256(), NULL);
    EVP_DigestUpdate(ctx, input, sizeof(input));
    EVP_DigestFinalXOF(ctx, out, outlen);
    EVP_MD_CTX_free(ctx);
}
static void challenge_hash(const uint8_t *mu, const uint8_t *w1, unsigned int w1len, uint8_t *ctilde) {
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake256(), NULL);
    EVP_DigestUpdate(ctx, mu, CRHBYTES);
    EVP_DigestUpdate(ctx, w1, w1len);
    EVP_DigestFinalXOF(ctx, ctilde, CTILDEBYTES);
    EVP_MD_CTX_free(ctx);
}

typedef struct {
    MLDSA_RVV_KEY *key;  /* lainattu KEYMGMT:lta, ei omisteta */
} MLDSA_RVV_SIGCTX;

static void *mldsa_rvv_sig_newctx(void *provctx, const char *propq) {
    (void)provctx; (void)propq;
    return calloc(1, sizeof(MLDSA_RVV_SIGCTX));
}

static void mldsa_rvv_sig_freectx(void *ctx) {
    free(ctx);
}

static int mldsa_rvv_sig_sign_init(void *ctx, void *provkey, const OSSL_PARAM params[]) {
    (void)params;
    MLDSA_RVV_SIGCTX *sctx = (MLDSA_RVV_SIGCTX *)ctx;
    sctx->key = (MLDSA_RVV_KEY *)provkey;
    return sctx->key != NULL && sctx->key->has_priv;
}

static int mldsa_rvv_sig_verify_init(void *ctx, void *provkey, const OSSL_PARAM params[]) {
    (void)params;
    MLDSA_RVV_SIGCTX *sctx = (MLDSA_RVV_SIGCTX *)ctx;
    sctx->key = (MLDSA_RVV_KEY *)provkey;
    return sctx->key != NULL && sctx->key->has_pub;
}

/* sign: OpenSSL-konventio - jos sig==NULL, palauta vain koko *siglen:iin
 * (kutsuja kysyy puskurin kokoa ensin). rnd oikealla RAND_bytes:lla. */
static int mldsa_rvv_sig_sign(void *ctx, unsigned char *sig, size_t *siglen, size_t sigsize,
                               const unsigned char *tbs, size_t tbslen) {
    MLDSA_RVV_SIGCTX *sctx = (MLDSA_RVV_SIGCTX *)ctx;
    if (sig == NULL) {
        *siglen = CRYPTO_BYTES;
        return 1;
    }
    if (sigsize < CRYPTO_BYTES) return 0;

    uint8_t rnd[RNDBYTES];
    if (RAND_bytes(rnd, RNDBYTES) != 1) return 0;

    static const uint8_t empty_ctx[1] = {0};
    int rc = crypto_sign_signature_rvv(sig, tbs, (unsigned int)tbslen, empty_ctx, 0,
                                        sctx->key->sk, rnd, shake128_fn, shake256_multi,
                                        gamma1_shake, challenge_hash);
    if (rc != 0) return 0;
    *siglen = CRYPTO_BYTES;
    return 1;
}

static int mldsa_rvv_sig_verify(void *ctx, const unsigned char *sig, size_t siglen,
                                 const unsigned char *tbs, size_t tbslen) {
    MLDSA_RVV_SIGCTX *sctx = (MLDSA_RVV_SIGCTX *)ctx;
    if (siglen != CRYPTO_BYTES) return 0;
    static const uint8_t empty_ctx[1] = {0};
    int rc = crypto_sign_verify_rvv(sig, tbs, (unsigned int)tbslen, empty_ctx, 0,
                                     sctx->key->pk, shake128_fn, shake256_seedlen,
                                     shake256_multi, challenge_hash);
    return rc == 0;
}

const OSSL_DISPATCH mldsa_rvv_signature_functions[] = {
    { OSSL_FUNC_SIGNATURE_NEWCTX, (void (*)(void))mldsa_rvv_sig_newctx },
    { OSSL_FUNC_SIGNATURE_FREECTX, (void (*)(void))mldsa_rvv_sig_freectx },
    { OSSL_FUNC_SIGNATURE_SIGN_INIT, (void (*)(void))mldsa_rvv_sig_sign_init },
    { OSSL_FUNC_SIGNATURE_SIGN, (void (*)(void))mldsa_rvv_sig_sign },
    { OSSL_FUNC_SIGNATURE_VERIFY_INIT, (void (*)(void))mldsa_rvv_sig_verify_init },
    { OSSL_FUNC_SIGNATURE_VERIFY, (void (*)(void))mldsa_rvv_sig_verify },
    { 0, NULL }
};
