#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <openssl/core.h>
#include <openssl/core_dispatch.h>

#define MLDSA_K 6
#define MLDSA_L 5
#define MLDSA_N 256
#define SEEDBYTES 32
#define CRHBYTES 64
#define RNDBYTES 32
#define CTILDEBYTES 48
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + MLDSA_K*320)
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + 64 + MLDSA_L*128 + MLDSA_K*128 + MLDSA_K*416)
#define CRYPTO_BYTES (CTILDEBYTES + MLDSA_L*640 + 55 + MLDSA_K)

/* Sama layout kuin keymgmt.c:ssa - testissa saa tuntea sen, tuotannossa
 * avainolio on opaakki OpenSSL:n omalle kutsujalle. */
typedef struct {
    uint8_t pk[CRYPTO_PUBLICKEYBYTES];
    uint8_t sk[CRYPTO_SECRETKEYBYTES];
    int has_pub;
    int has_priv;
} MLDSA_RVV_KEY;

extern const OSSL_DISPATCH mldsa_rvv_keymgmt_functions[];

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

#include <openssl/evp.h>
static void shake128_fn(uint8_t *rho, uint16_t nonce, uint8_t *out, unsigned int outlen) {
    uint8_t input[SEEDBYTES + 2];
    memcpy(input, rho, SEEDBYTES);
    input[SEEDBYTES] = nonce & 0xFF; input[SEEDBYTES+1] = (nonce >> 8) & 0xFF;
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
    input[CRHBYTES] = nonce & 0xFF; input[CRHBYTES+1] = (nonce >> 8) & 0xFF;
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

int main(void) {
    /* Etsi funktiot dispatch-taulukosta ID:n perusteella - TASMALLEEN
     * niin kuin OpenSSL:n oma ydin tekisi providerin lataamisen jalkeen. */
    void *(*new_fn)(void *) = NULL;
    void *(*gen_init_fn)(void *, int, const OSSL_PARAM[]) = NULL;
    void *(*gen_fn)(void *, OSSL_CALLBACK *, void *) = NULL;
    int (*has_fn)(const void *, int) = NULL;
    void (*free_fn)(void *) = NULL;

    for (const OSSL_DISPATCH *d = mldsa_rvv_keymgmt_functions; d->function_id != 0; d++) {
        switch (d->function_id) {
            case OSSL_FUNC_KEYMGMT_NEW: new_fn = (void *(*)(void*))d->function; break;
            case OSSL_FUNC_KEYMGMT_GEN_INIT: gen_init_fn = (void *(*)(void*,int,const OSSL_PARAM[]))d->function; break;
            case OSSL_FUNC_KEYMGMT_GEN: gen_fn = (void *(*)(void*,OSSL_CALLBACK*,void*))d->function; break;
            case OSSL_FUNC_KEYMGMT_HAS: has_fn = (int (*)(const void*,int))d->function; break;
            case OSSL_FUNC_KEYMGMT_FREE: free_fn = (void (*)(void*))d->function; break;
        }
    }

    if (!new_fn || !gen_init_fn || !gen_fn || !has_fn || !free_fn) {
        printf("FAIL: dispatch-taulukosta puuttuu funktioita\n");
        return 1;
    }
    printf("Kaikki tarvittavat KEYMGMT-funktiot loytyivat dispatch-taulukosta\n");

    void *genctx = gen_init_fn(NULL, OSSL_KEYMGMT_SELECT_KEYPAIR, NULL);
    if (!genctx) { printf("FAIL: gen_init palautti NULL\n"); return 1; }

    void *keydata = gen_fn(genctx, NULL, NULL);
    if (!keydata) { printf("FAIL: gen palautti NULL\n"); return 1; }

    int has_both = has_fn(keydata, OSSL_KEYMGMT_SELECT_KEYPAIR);
    printf("has(KEYPAIR) = %d (odotettu 1)\n", has_both);

    MLDSA_RVV_KEY *key = (MLDSA_RVV_KEY *)keydata;
    printf("pk[0..3]: %u %u %u %u\n", key->pk[0], key->pk[1], key->pk[2], key->pk[3]);

    /* OIKEA TESTI: kaytetaanko providerin tuottamaa avainta oikeasti
     * allekirjoitukseen ja verifiointiin - ei vain tarkisteta etta
     * muistissa on jotain. */
    const char *msg = "provider-kytkennan lapi tuotettu avain";
    unsigned int mlen = strlen(msg);
    uint8_t ctx_empty[1] = {0};
    uint8_t rnd[RNDBYTES];
    memset(rnd, 0x42, RNDBYTES);

    uint8_t sig[CRYPTO_BYTES];
    int rc_sign = crypto_sign_signature_rvv(sig, (const uint8_t*)msg, mlen, ctx_empty, 0,
                                             key->sk, rnd, shake128_fn, shake256_multi,
                                             gamma1_shake, challenge_hash);
    printf("sign rc=%d (odotettu 0)\n", rc_sign);

    int rc_verify = crypto_sign_verify_rvv(sig, (const uint8_t*)msg, mlen, ctx_empty, 0,
                                            key->pk, shake128_fn, shake256_seedlen,
                                            shake256_multi, challenge_hash);
    printf("verify (oikea) rc=%d (odotettu 0)\n", rc_verify);

    char bad_msg[64]; strcpy(bad_msg, msg); bad_msg[0] ^= 1;
    int rc_verify_bad = crypto_sign_verify_rvv(sig, (const uint8_t*)bad_msg, mlen, ctx_empty, 0,
                                                key->pk, shake128_fn, shake256_seedlen,
                                                shake256_multi, challenge_hash);
    printf("verify (turmeltu) rc=%d (odotettu -1)\n", rc_verify_bad);

    free_fn(keydata);

    int ok = (has_both == 1 && rc_sign == 0 && rc_verify == 0 && rc_verify_bad == -1);
    printf("%s\n", ok ? "PASS: provider-KEYMGMT tuottaa oikeasti toimivan ML-DSA-65-avaimen" : "FAIL");
    return ok ? 0 : 1;
}
