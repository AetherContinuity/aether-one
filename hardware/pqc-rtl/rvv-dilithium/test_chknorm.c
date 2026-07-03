#include <stdio.h>
#include <stdint.h>

extern int poly_chknorm_rvv(const int32_t *a, int32_t B);

static int load(const char *fn, int32_t *arr) {
    FILE *f = fopen(fn, "r");
    if (!f) return 0;
    for (int i = 0; i < 256; i++) if (fscanf(f, "%d", &arr[i]) != 1) { fclose(f); return 0; }
    fclose(f);
    return 1;
}

int main(void) {
    int32_t a1[256], a2[256];
    load("chk_a1.txt", a1);
    load("chk_a2.txt", a2);

    int errors = 0;
    struct { int32_t *a; int32_t B; int expect; const char *label; } tests[] = {
        { a1, 150, 0, "a1,150" },
        { a1, 50, 1, "a1,50" },
        { a2, 199, 1, "a2,199" },
        { a2, 201, 0, "a2,201" },
    };
    for (int i = 0; i < 4; i++) {
        int got = poly_chknorm_rvv(tests[i].a, tests[i].B);
        int ok = (got == tests[i].expect);
        if (!ok) errors++;
        printf("[%s] %s: got=%d expected=%d\n", ok ? "OK" : "FAIL", tests[i].label, got, tests[i].expect);
    }
    printf("%s (%d/4)\n", errors == 0 ? "PASS" : "FAIL", 4 - errors);
    return errors == 0 ? 0 : 1;
}
