/* keymgmt.c - OSSL_FUNC_KEYMGMT_* -toteutus ML-DSA-65-RVV-avaimille.
 *
 * Kayttaa oikeaa RAND_bytes:ia siemenelle (linkitetty libcrypto:hen jo
 * muutenkin), oikeaa EVP-pohjaista SHAKE128/256:ta (yksi squeeze-kutsu
 * per tarve - EI toistuvaa EVP_DigestFinalXOF-kutsua samalle kontekstille,
 * joka todettiin EI-jatkuvaksi aiemmin tassa hakemistossa). */
#include <openssl/core.h>
#include <openssl/core_dispatch.h>
#include <openssl/core_names.h>
#include <openssl/params.h>
#include <openssl/rand.h>
#include <openssl/evp.h>
#include <string.h>
#include <stdlib.h>

#define K 6
#define L 5
#define N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + K*320)
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + 64 + L*128 + K*128 + K*416)

extern void crypto_sign_keypair_rvv(
    uint8_t pk[CRYPTO_PUBLICKEYBYTES], uint8_t *sk, uint8_t random_seed[SEEDBYTES],
    void (*shake128_fn)(uint8_t*, uint16_t, uint8_t*, unsigned int),
    void (*shake256_fn)(const uint8_t*, unsigned int, uint8_t*, unsigned int));

typedef struct {
    uint8_t pk[CRYPTO_PUBLICKEYBYTES];
    uint8_t sk[CRYPTO_SECRETKEYBYTES];
    int has_pub;
    int has_priv;
} MLDSA_RVV_KEY;

static void shake128_for_provider(uint8_t *rho, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[SEEDBYTES + 2];
    memcpy(input, rho, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF;
    input[SEEDBYTES + 1] = (nonce >> 8) & 0xFF;
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake128(), NULL);
    EVP_DigestUpdate(ctx, input, sizeof(input));
    EVP_DigestFinalXOF(ctx, out, outlen);  /* YKSI kutsu, ei toistuva */
    EVP_MD_CTX_free(ctx);
}

static void shake256_for_provider(const uint8_t *input, unsigned int inlen, uint8_t *out, unsigned int outlen) {
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_shake256(), NULL);
    EVP_DigestUpdate(ctx, input, inlen);
    EVP_DigestFinalXOF(ctx, out, outlen);  /* YKSI kutsu, ei toistuva */
    EVP_MD_CTX_free(ctx);
}

static void *mldsa_rvv_keymgmt_new(void *provctx) {
    (void)provctx;
    return calloc(1, sizeof(MLDSA_RVV_KEY));
}

static void mldsa_rvv_keymgmt_free(void *keydata) {
    free(keydata);
}

static void *mldsa_rvv_keymgmt_gen_init(void *provctx, int selection, const OSSL_PARAM params[]) {
    (void)selection; (void)params;
    /* Genctx on tassa sama kuin key-olio itse - ei erillista valitilaa
     * tarvita, koska crypto_sign_keypair_rvv on yksi suora kutsu ilman
     * useampivaiheista neuvottelua (toisin kuin esim. DH). */
    return mldsa_rvv_keymgmt_new(provctx);
}

static void *mldsa_rvv_keymgmt_gen(void *genctx, OSSL_CALLBACK *cb, void *cbarg) {
    (void)cb; (void)cbarg;
    MLDSA_RVV_KEY *key = (MLDSA_RVV_KEY *)genctx;

    uint8_t seed[SEEDBYTES];
    if (RAND_bytes(seed, SEEDBYTES) != 1) return NULL;  /* oikea satunnaisuus, ei kiinnitetty */

    crypto_sign_keypair_rvv(key->pk, key->sk, seed, shake128_for_provider, shake256_for_provider);
    key->has_pub = 1;
    key->has_priv = 1;
    return key;
}

static void mldsa_rvv_keymgmt_gen_cleanup(void *genctx) {
    (void)genctx;  /* genctx == key, jonka omistus siirtyy kutsujalle gen():n paluuarvona - ei vapauteta tassa */
}

static int mldsa_rvv_keymgmt_has(const void *keydata, int selection) {
    const MLDSA_RVV_KEY *key = (const MLDSA_RVV_KEY *)keydata;
    if (key == NULL) return 0;
    int ok = 1;
    if (selection & OSSL_KEYMGMT_SELECT_PUBLIC_KEY) ok = ok && key->has_pub;
    if (selection & OSSL_KEYMGMT_SELECT_PRIVATE_KEY) ok = ok && key->has_priv;
    return ok;
}

#define CTILDEBYTES_FOR_PARAM 3309  /* CRYPTO_BYTES: max allekirjoituksen koko */

static int mldsa_rvv_keymgmt_get_params(void *keydata, OSSL_PARAM params[]) {
    MLDSA_RVV_KEY *key = (MLDSA_RVV_KEY *)keydata;
    OSSL_PARAM *p;
    p = OSSL_PARAM_locate(params, OSSL_PKEY_PARAM_BITS);
    if (p != NULL && !OSSL_PARAM_set_int(p, 8 * CRYPTO_PUBLICKEYBYTES)) return 0;
    p = OSSL_PARAM_locate(params, OSSL_PKEY_PARAM_SECURITY_BITS);
    if (p != NULL && !OSSL_PARAM_set_int(p, 192)) return 0;  /* ML-DSA-65: NIST-taso 3 */
    p = OSSL_PARAM_locate(params, OSSL_PKEY_PARAM_MAX_SIZE);
    if (p != NULL && !OSSL_PARAM_set_int(p, CTILDEBYTES_FOR_PARAM)) return 0;
    (void)key;
    return 1;
}

static const OSSL_PARAM *mldsa_rvv_keymgmt_gettable_params(void *provctx) {
    (void)provctx;
    static const OSSL_PARAM table[] = {
        OSSL_PARAM_int(OSSL_PKEY_PARAM_BITS, NULL),
        OSSL_PARAM_int(OSSL_PKEY_PARAM_SECURITY_BITS, NULL),
        OSSL_PARAM_int(OSSL_PKEY_PARAM_MAX_SIZE, NULL),
        OSSL_PARAM_END
    };
    return table;
}

const OSSL_DISPATCH mldsa_rvv_keymgmt_functions[] = {
    { OSSL_FUNC_KEYMGMT_NEW, (void (*)(void))mldsa_rvv_keymgmt_new },
    { OSSL_FUNC_KEYMGMT_FREE, (void (*)(void))mldsa_rvv_keymgmt_free },
    { OSSL_FUNC_KEYMGMT_GEN_INIT, (void (*)(void))mldsa_rvv_keymgmt_gen_init },
    { OSSL_FUNC_KEYMGMT_GEN, (void (*)(void))mldsa_rvv_keymgmt_gen },
    { OSSL_FUNC_KEYMGMT_GEN_CLEANUP, (void (*)(void))mldsa_rvv_keymgmt_gen_cleanup },
    { OSSL_FUNC_KEYMGMT_HAS, (void (*)(void))mldsa_rvv_keymgmt_has },
    { OSSL_FUNC_KEYMGMT_GET_PARAMS, (void (*)(void))mldsa_rvv_keymgmt_get_params },
    { OSSL_FUNC_KEYMGMT_GETTABLE_PARAMS, (void (*)(void))mldsa_rvv_keymgmt_gettable_params },
    { 0, NULL }
};
