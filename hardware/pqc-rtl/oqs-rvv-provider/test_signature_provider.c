#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <openssl/core.h>
#include <openssl/core_dispatch.h>

#define MLDSA_K 6
#define MLDSA_L 5
#define SEEDBYTES 32
#define CRYPTO_PUBLICKEYBYTES (SEEDBYTES + MLDSA_K*320)
#define CRYPTO_SECRETKEYBYTES (2*SEEDBYTES + 64 + MLDSA_L*128 + MLDSA_K*128 + MLDSA_K*416)
#define CRYPTO_BYTES (48 + MLDSA_L*640 + 55 + MLDSA_K)

typedef struct {
    uint8_t pk[CRYPTO_PUBLICKEYBYTES];
    uint8_t sk[CRYPTO_SECRETKEYBYTES];
    int has_pub;
    int has_priv;
} MLDSA_RVV_KEY;

extern const OSSL_DISPATCH mldsa_rvv_keymgmt_functions[];
extern const OSSL_DISPATCH mldsa_rvv_signature_functions[];

int main(void) {
    void *(*km_new)(void *) = NULL;
    void *(*km_gen_init)(void *, int, const OSSL_PARAM[]) = NULL;
    void *(*km_gen)(void *, OSSL_CALLBACK *, void *) = NULL;
    void (*km_free)(void *) = NULL;

    for (const OSSL_DISPATCH *d = mldsa_rvv_keymgmt_functions; d->function_id != 0; d++) {
        switch (d->function_id) {
            case OSSL_FUNC_KEYMGMT_NEW: km_new = (void *(*)(void*))d->function; break;
            case OSSL_FUNC_KEYMGMT_GEN_INIT: km_gen_init = (void *(*)(void*,int,const OSSL_PARAM[]))d->function; break;
            case OSSL_FUNC_KEYMGMT_GEN: km_gen = (void *(*)(void*,OSSL_CALLBACK*,void*))d->function; break;
            case OSSL_FUNC_KEYMGMT_FREE: km_free = (void (*)(void*))d->function; break;
        }
    }
    (void)km_new;

    void *(*sig_newctx)(void *, const char *) = NULL;
    void (*sig_freectx)(void *) = NULL;
    int (*sig_sign_init)(void *, void *, const OSSL_PARAM[]) = NULL;
    int (*sig_sign)(void *, unsigned char *, size_t *, size_t, const unsigned char *, size_t) = NULL;
    int (*sig_verify_init)(void *, void *, const OSSL_PARAM[]) = NULL;
    int (*sig_verify)(void *, const unsigned char *, size_t, const unsigned char *, size_t) = NULL;

    for (const OSSL_DISPATCH *d = mldsa_rvv_signature_functions; d->function_id != 0; d++) {
        switch (d->function_id) {
            case OSSL_FUNC_SIGNATURE_NEWCTX: sig_newctx = (void *(*)(void*,const char*))d->function; break;
            case OSSL_FUNC_SIGNATURE_FREECTX: sig_freectx = (void (*)(void*))d->function; break;
            case OSSL_FUNC_SIGNATURE_SIGN_INIT: sig_sign_init = (int (*)(void*,void*,const OSSL_PARAM[]))d->function; break;
            case OSSL_FUNC_SIGNATURE_SIGN: sig_sign = (int (*)(void*,unsigned char*,size_t*,size_t,const unsigned char*,size_t))d->function; break;
            case OSSL_FUNC_SIGNATURE_VERIFY_INIT: sig_verify_init = (int (*)(void*,void*,const OSSL_PARAM[]))d->function; break;
            case OSSL_FUNC_SIGNATURE_VERIFY: sig_verify = (int (*)(void*,const unsigned char*,size_t,const unsigned char*,size_t))d->function; break;
        }
    }

    if (!km_gen_init || !km_gen || !km_free || !sig_newctx || !sig_freectx ||
        !sig_sign_init || !sig_sign || !sig_verify_init || !sig_verify) {
        printf("FAIL: dispatch-taulukoista puuttuu funktioita\n");
        return 1;
    }
    printf("Kaikki KEYMGMT+SIGNATURE-funktiot loytyivat\n");

    void *genctx = km_gen_init(NULL, OSSL_KEYMGMT_SELECT_KEYPAIR, NULL);
    void *keydata = km_gen(genctx, NULL, NULL);
    if (!keydata) { printf("FAIL: keygen\n"); return 1; }
    printf("Avain generoitu KEYMGMT-dispatchin lapi\n");

    /* Allekirjoitus taysin OpenSSL-konvention mukaisesti: kysy koko ensin. */
    void *signctx = sig_newctx(NULL, NULL);
    if (!sig_sign_init(signctx, keydata, NULL)) { printf("FAIL: sign_init\n"); return 1; }

    const char *msg = "OSSL_FUNC_SIGNATURE-rajapinnan lapi testattu viesti";
    size_t mlen = strlen(msg);

    size_t siglen = 0;
    sig_sign(signctx, NULL, &siglen, 0, (const unsigned char*)msg, mlen);
    printf("kysytty siglen=%zu (odotettu %d)\n", siglen, CRYPTO_BYTES);

    unsigned char sig[CRYPTO_BYTES];
    int rc_sign = sig_sign(signctx, sig, &siglen, sizeof(sig), (const unsigned char*)msg, mlen);
    printf("sign rc=%d siglen=%zu\n", rc_sign, siglen);
    sig_freectx(signctx);

    /* Verifiointi taysin OpenSSL-konvention mukaisesti. */
    void *verifyctx = sig_newctx(NULL, NULL);
    if (!sig_verify_init(verifyctx, keydata, NULL)) { printf("FAIL: verify_init\n"); return 1; }
    int rc_verify = sig_verify(verifyctx, sig, siglen, (const unsigned char*)msg, mlen);
    printf("verify (oikea) rc=%d (odotettu 1)\n", rc_verify);

    char bad_msg[64]; strcpy(bad_msg, msg); bad_msg[0] ^= 1;
    int rc_verify_bad = sig_verify(verifyctx, sig, siglen, (const unsigned char*)bad_msg, mlen);
    printf("verify (turmeltu) rc=%d (odotettu 0)\n", rc_verify_bad);
    sig_freectx(verifyctx);

    km_free(keydata);

    int ok = (rc_sign == 1 && siglen == CRYPTO_BYTES && rc_verify == 1 && rc_verify_bad == 0);
    printf("%s\n", ok ? "PASS: OSSL_FUNC_SIGNATURE lapi toimiva ML-DSA-65 sign+verify" : "FAIL");
    return ok ? 0 : 1;
}
