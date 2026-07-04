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

int OSSL_provider_init(const OSSL_CORE_HANDLE *handle, const OSSL_DISPATCH *in,
                        const OSSL_DISPATCH **out, void **provctx);

int main(void) {
    const OSSL_DISPATCH *out = NULL;
    void *provctx = NULL;
    if (!OSSL_provider_init(NULL, NULL, &out, &provctx)) { printf("FAIL: init\n"); return 1; }

    const OSSL_ALGORITHM *(*query)(void*, int, int*) = NULL;
    for (const OSSL_DISPATCH *d = out; d->function_id != 0; d++)
        if (d->function_id == OSSL_FUNC_PROVIDER_QUERY_OPERATION)
            query = (const OSSL_ALGORITHM *(*)(void*,int,int*))d->function;
    if (!query) { printf("FAIL: query_operation puuttuu\n"); return 1; }

    int no_cache;
    const OSSL_ALGORITHM *km_algs = query(provctx, OSSL_OP_KEYMGMT, &no_cache);
    if (!km_algs || !km_algs[0].algorithm_names) { printf("FAIL: KEYMGMT-algoritmia ei loydy\n"); return 1; }
    printf("KEYMGMT loytyi: nimi=%s propdef=%s\n", km_algs[0].algorithm_names, km_algs[0].property_definition);

    const OSSL_ALGORITHM *sig_algs = query(provctx, OSSL_OP_SIGNATURE, &no_cache);
    if (!sig_algs || !sig_algs[0].algorithm_names) { printf("FAIL: SIGNATURE-algoritmia ei loydy\n"); return 1; }
    printf("SIGNATURE loytyi: nimi=%s propdef=%s\n", sig_algs[0].algorithm_names, sig_algs[0].property_definition);

    const OSSL_ALGORITHM *kex_algs = query(provctx, OSSL_OP_KEYEXCH, &no_cache);
    printf("KEYEXCH (ei pitaisi loytya): %s\n", kex_algs == NULL ? "NULL, oikein" : "LOYTYI, VAARIN");

    /* Poimi KEYMGMT+SIGNATURE-funktiot LOYDETYISTA OSSL_ALGORITHM-riveista,
     * ei suoraan mldsa_rvv_*_functions-symboleista - tama todistaa etta
     * provider_query on oikea reitti, ei ohitettu. */
    void *(*km_gen_init)(void*, int, const OSSL_PARAM[]) = NULL;
    void *(*km_gen)(void*, OSSL_CALLBACK*, void*) = NULL;
    void (*km_free)(void*) = NULL;
    for (const OSSL_DISPATCH *d = km_algs[0].implementation; d->function_id != 0; d++) {
        if (d->function_id == OSSL_FUNC_KEYMGMT_GEN_INIT) km_gen_init = (void*(*)(void*,int,const OSSL_PARAM[]))d->function;
        if (d->function_id == OSSL_FUNC_KEYMGMT_GEN) km_gen = (void*(*)(void*,OSSL_CALLBACK*,void*))d->function;
        if (d->function_id == OSSL_FUNC_KEYMGMT_FREE) km_free = (void(*)(void*))d->function;
    }

    int (*sig_newctx_ok)(void) = NULL; (void)sig_newctx_ok;
    void *(*sig_newctx)(void*, const char*) = NULL;
    void (*sig_freectx)(void*) = NULL;
    int (*sig_sign_init)(void*, void*, const OSSL_PARAM[]) = NULL;
    int (*sig_sign)(void*, unsigned char*, size_t*, size_t, const unsigned char*, size_t) = NULL;
    int (*sig_verify_init)(void*, void*, const OSSL_PARAM[]) = NULL;
    int (*sig_verify)(void*, const unsigned char*, size_t, const unsigned char*, size_t) = NULL;
    for (const OSSL_DISPATCH *d = sig_algs[0].implementation; d->function_id != 0; d++) {
        if (d->function_id == OSSL_FUNC_SIGNATURE_NEWCTX) sig_newctx = (void*(*)(void*,const char*))d->function;
        if (d->function_id == OSSL_FUNC_SIGNATURE_FREECTX) sig_freectx = (void(*)(void*))d->function;
        if (d->function_id == OSSL_FUNC_SIGNATURE_SIGN_INIT) sig_sign_init = (int(*)(void*,void*,const OSSL_PARAM[]))d->function;
        if (d->function_id == OSSL_FUNC_SIGNATURE_SIGN) sig_sign = (int(*)(void*,unsigned char*,size_t*,size_t,const unsigned char*,size_t))d->function;
        if (d->function_id == OSSL_FUNC_SIGNATURE_VERIFY_INIT) sig_verify_init = (int(*)(void*,void*,const OSSL_PARAM[]))d->function;
        if (d->function_id == OSSL_FUNC_SIGNATURE_VERIFY) sig_verify = (int(*)(void*,const unsigned char*,size_t,const unsigned char*,size_t))d->function;
    }

    if (!km_gen_init || !km_gen || !km_free || !sig_newctx || !sig_freectx ||
        !sig_sign_init || !sig_sign || !sig_verify_init || !sig_verify) {
        printf("FAIL: dispatch-funktioita puuttuu OSSL_ALGORITHM-rivin kautta haettuna\n");
        return 1;
    }

    void *genctx = km_gen_init(provctx, OSSL_KEYMGMT_SELECT_KEYPAIR, NULL);
    void *keydata = km_gen(genctx, NULL, NULL);
    if (!keydata) { printf("FAIL: keygen provider_query-reitin kautta\n"); return 1; }
    printf("Avain generoitu TAYSIN provider_query -> OSSL_ALGORITHM -> dispatch -reitin lapi\n");

    void *signctx = sig_newctx(provctx, NULL);
    sig_sign_init(signctx, keydata, NULL);
    const char *msg = "taysi provider_query-reitti testattu";
    size_t mlen = strlen(msg);
    unsigned char sig[CRYPTO_BYTES];
    size_t siglen;
    int rc_sign = sig_sign(signctx, sig, &siglen, sizeof(sig), (const unsigned char*)msg, mlen);
    sig_freectx(signctx);

    void *verifyctx = sig_newctx(provctx, NULL);
    sig_verify_init(verifyctx, keydata, NULL);
    int rc_verify = sig_verify(verifyctx, sig, siglen, (const unsigned char*)msg, mlen);
    char bad[64]; strcpy(bad, msg); bad[0] ^= 1;
    int rc_verify_bad = sig_verify(verifyctx, sig, siglen, (const unsigned char*)bad, mlen);
    sig_freectx(verifyctx);

    km_free(keydata);

    printf("sign rc=%d verify(oikea) rc=%d verify(turmeltu) rc=%d\n", rc_sign, rc_verify, rc_verify_bad);
    int ok = (kex_algs == NULL && rc_sign == 1 && rc_verify == 1 && rc_verify_bad == 0);
    printf("%s\n", ok ? "PASS: taysi provider_query-reitti OSSL_provider_init:sta lahtien toimii" : "FAIL");
    return ok ? 0 : 1;
}
