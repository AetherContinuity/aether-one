/* provider.c - minimaalinen, spesifikaation mukainen OpenSSL 3.0 provider.
 * Ei vielä ML-DSA/Kyber-algoritmeja - todistaa vain etta provider-runko
 * on validi ja OpenSSL:n oma provider-loader hyvaksyy sen.
 * RVV-kytkenta (mont_rvv.c) seuraava askel, ei tehty tassa. */
#include <openssl/core.h>
#include <openssl/core_dispatch.h>
#include <openssl/core_names.h>
#include <openssl/params.h>
#include <string.h>

static const char *PROVIDER_NAME = "oqs_rvv";
static const char *PROVIDER_VERSION = "0.1-skeleton";

static OSSL_FUNC_provider_teardown_fn provider_teardown;
static OSSL_FUNC_provider_gettable_params_fn provider_gettable_params;
static OSSL_FUNC_provider_get_params_fn provider_get_params;
static OSSL_FUNC_provider_query_operation_fn provider_query;

static void provider_teardown(void *provctx) {
    (void)provctx;
}

static const OSSL_PARAM *provider_gettable_params(void *provctx) {
    (void)provctx;
    static const OSSL_PARAM param_types[] = {
        OSSL_PARAM_DEFN(OSSL_PROV_PARAM_NAME, OSSL_PARAM_UTF8_PTR, NULL, 0),
        OSSL_PARAM_DEFN(OSSL_PROV_PARAM_VERSION, OSSL_PARAM_UTF8_PTR, NULL, 0),
        OSSL_PARAM_DEFN(OSSL_PROV_PARAM_BUILDINFO, OSSL_PARAM_UTF8_PTR, NULL, 0),
        OSSL_PARAM_DEFN(OSSL_PROV_PARAM_STATUS, OSSL_PARAM_INTEGER, NULL, 0),
        OSSL_PARAM_END
    };
    return param_types;
}

static int provider_get_params(void *provctx, OSSL_PARAM params[]) {
    (void)provctx;
    OSSL_PARAM *p;
    p = OSSL_PARAM_locate(params, OSSL_PROV_PARAM_NAME);
    if (p != NULL && !OSSL_PARAM_set_utf8_ptr(p, PROVIDER_NAME)) return 0;
    p = OSSL_PARAM_locate(params, OSSL_PROV_PARAM_VERSION);
    if (p != NULL && !OSSL_PARAM_set_utf8_ptr(p, PROVIDER_VERSION)) return 0;
    p = OSSL_PARAM_locate(params, OSSL_PROV_PARAM_BUILDINFO);
    if (p != NULL && !OSSL_PARAM_set_utf8_ptr(p, "RVV-skeleton, ei algoritmeja viela")) return 0;
    p = OSSL_PARAM_locate(params, OSSL_PROV_PARAM_STATUS);
    if (p != NULL && !OSSL_PARAM_set_int(p, 1)) return 0;
    return 1;
}

/* Ei viela yhtaan algoritmia - palautetaan NULL jokaiselle operaatiolle.
 * Tama on rehellinen tila: provider on validi mutta tyhja runko. */
static const OSSL_ALGORITHM *provider_query(void *provctx, int operation_id, int *no_cache) {
    (void)provctx; (void)operation_id;
    *no_cache = 0;
    return NULL;
}

static const OSSL_DISPATCH provider_dispatch_table[] = {
    { OSSL_FUNC_PROVIDER_TEARDOWN, (void (*)(void))provider_teardown },
    { OSSL_FUNC_PROVIDER_GETTABLE_PARAMS, (void (*)(void))provider_gettable_params },
    { OSSL_FUNC_PROVIDER_GET_PARAMS, (void (*)(void))provider_get_params },
    { OSSL_FUNC_PROVIDER_QUERY_OPERATION, (void (*)(void))provider_query },
    { 0, NULL }
};

int OSSL_provider_init(const OSSL_CORE_HANDLE *handle,
                        const OSSL_DISPATCH *in,
                        const OSSL_DISPATCH **out,
                        void **provctx) {
    (void)handle; (void)in;
    *out = provider_dispatch_table;
    *provctx = NULL;
    return 1;
}
