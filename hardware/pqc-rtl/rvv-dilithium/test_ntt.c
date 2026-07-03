#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

extern void ntt_rvv(int32_t *a);

int main(void) {
    int32_t a[256];
    int32_t expected[256];

    FILE *fin = fopen("ntt_input.txt", "r");
    FILE *fexp = fopen("ntt_golden.txt", "r");
    if (!fin || !fexp) { printf("FAIL: syotetiedostoja ei loydy\n"); return 1; }
    for (int i = 0; i < 256; i++) {
        if (fscanf(fin, "%d", &a[i]) != 1) { printf("FAIL: syote loppui kesken\n"); return 1; }
        if (fscanf(fexp, "%d", &expected[i]) != 1) { printf("FAIL: golden loppui kesken\n"); return 1; }
    }
    fclose(fin); fclose(fexp);

    ntt_rvv(a);

    int errors = 0;
    for (int i = 0; i < 256; i++) {
        if (a[i] != expected[i]) {
            errors++;
            if (errors <= 5) printf("[FAIL] i=%d got=%d expected=%d\n", i, a[i], expected[i]);
        }
    }
    printf("%s: %d/256 oikein (%d virhetta)\n", errors == 0 ? "PASS" : "FAIL", 256 - errors, errors);
    return errors == 0 ? 0 : 1;
}
