#include <stdio.h>
#include <stdint.h>

extern void poly_pointwise_montgomery_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_add_rvv(int32_t*, const int32_t*, const int32_t*);
extern void poly_reduce32_rvv(int32_t*);
extern void poly_caddq_rvv(int32_t*);
extern void poly_power2round_rvv(int32_t*, int32_t*, const int32_t*);

static int load(const char *fn, int32_t *arr) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < 256; i++) if (fscanf(f, "%d", &arr[i]) != 1) { fclose(f); return 0; }
    fclose(f);
    return 1;
}

static int check(const char *name, int32_t *got, int32_t *exp) {
    int errors = 0;
    for (int i = 0; i < 256; i++) if (got[i] != exp[i]) {
        errors++;
        if (errors <= 3) printf("[FAIL] %s[%d] got=%d expected=%d\n", name, i, got[i], exp[i]);
    }
    printf("%s: %s (%d virhetta)\n", name, errors == 0 ? "PASS" : "FAIL", errors);
    return errors;
}

int main(void) {
    int32_t a[256], b[256], exp_pw[256], exp_add[256], exp_red[256], exp_cad[256], exp_a1[256], exp_a0[256];
    load("ops_a.txt", a); load("ops_b.txt", b);
    load("ops_pw.txt", exp_pw); load("ops_add.txt", exp_add);
    load("ops_red.txt", exp_red); load("ops_cad.txt", exp_cad);
    load("ops_a1.txt", exp_a1); load("ops_a0.txt", exp_a0);

    int total_errors = 0;
    int32_t pw[256]; poly_pointwise_montgomery_rvv(pw, a, b);
    total_errors += check("pointwise_montgomery", pw, exp_pw);

    int32_t add[256]; poly_add_rvv(add, a, b);
    total_errors += check("add", add, exp_add);

    int32_t red[256]; for (int i=0;i<256;i++) red[i]=a[i]; poly_reduce32_rvv(red);
    total_errors += check("reduce32", red, exp_red);

    int32_t cad[256]; for (int i=0;i<256;i++) cad[i]=exp_red[i]; poly_caddq_rvv(cad);
    total_errors += check("caddq", cad, exp_cad);

    int32_t a1[256], a0[256]; poly_power2round_rvv(a1, a0, exp_cad);
    total_errors += check("power2round_a1", a1, exp_a1);
    total_errors += check("power2round_a0", a0, exp_a0);

    printf("%s (yhteensa %d virhetta)\n", total_errors == 0 ? "KAIKKI PASS" : "FAIL", total_errors);
    return total_errors == 0 ? 0 : 1;
}
