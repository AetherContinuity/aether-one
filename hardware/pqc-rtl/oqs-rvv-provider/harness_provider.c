#include <stdio.h>
#include <string.h>
#include <openssl/core.h>
#include <openssl/core_dispatch.h>
#include <openssl/params.h>

extern int OSSL_provider_init(const OSSL_CORE_HANDLE *handle,
                               const OSSL_DISPATCH *in,
                               const OSSL_DISPATCH **out,
                               void **provctx);

int main(void) {
    const OSSL_DISPATCH *out = NULL;
    void *provctx = NULL;
    int rc = OSSL_provider_init(NULL, NULL, &out, &provctx);
    if (!rc || out == NULL) {
        printf("FAIL: OSSL_provider_init epaonnistui (rc=%d)\n", rc);
        return 1;
    }

    OSSL_FUNC_provider_get_params_fn *get_params = NULL;
    OSSL_FUNC_provider_gettable_params_fn *gettable_params = NULL;
    for (const OSSL_DISPATCH *d = out; d->function_id != 0; d++) {
        if (d->function_id == OSSL_FUNC_PROVIDER_GET_PARAMS)
            get_params = (OSSL_FUNC_provider_get_params_fn *)d->function;
        if (d->function_id == OSSL_FUNC_PROVIDER_GETTABLE_PARAMS)
            gettable_params = (OSSL_FUNC_provider_gettable_params_fn *)d->function;
    }

    if (!get_params || !gettable_params) {
        printf("FAIL: dispatch-taulukosta puuttuu get_params tai gettable_params\n");
        return 1;
    }

    const OSSL_PARAM *types = gettable_params(provctx);
    (void)types;  /* ei kaytossa suoraan tassa yksinkertaistetussa testissa */

    const char *name_ptr = NULL, *ver_ptr = NULL, *build_ptr = NULL;
    int status_val = 0;
    OSSL_PARAM real_params[] = {
        OSSL_PARAM_utf8_ptr("name", (char **)&name_ptr, 0),
        OSSL_PARAM_utf8_ptr("version", (char **)&ver_ptr, 0),
        OSSL_PARAM_utf8_ptr("buildinfo", (char **)&build_ptr, 0),
        OSSL_PARAM_int("status", &status_val),
        OSSL_PARAM_END
    };

    int gr = get_params(provctx, real_params);
    if (!gr) {
        printf("FAIL: get_params palautti 0\n");
        return 1;
    }

    printf("name=%s version=%s status=%d\n", name_ptr, ver_ptr, status_val);
    printf("buildinfo=%s\n", build_ptr);

    int ok = (name_ptr && strcmp(name_ptr, "oqs_rvv") == 0 &&
              ver_ptr && strcmp(ver_ptr, "0.1-skeleton") == 0 &&
              status_val == 1);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
