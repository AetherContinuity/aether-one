#include <stdio.h>
#include <stdint.h>

extern void invntt_rvv(int32_t *a);

int main(void) {
    int32_t a[256], expected[256];
    FILE *fin = fopen("invntt_input.txt", "r");
    FILE *fg = fopen("invntt_golden.txt", "r");
    if (!fin || !fg) { printf("FAIL: tiedostoja ei loydy\n"); return 1; }
    for (int i = 0; i < 256; i++) { fscanf(fin, "%d", &a[i]); fscanf(fg, "%d", &expected[i]); }
    fclose(fin); fclose(fg);

    invntt_rvv(a);

    int errors = 0;
    for (int i = 0; i < 256; i++)
        if (a[i] != expected[i]) {
            errors++;
            if (errors <= 5) printf("[FAIL] i=%d got=%d expected=%d\n", i, a[i], expected[i]);
        }
    printf("%s (%d virhetta/256)\n", errors == 0 ? "PASS" : "FAIL", errors);
    return errors == 0 ? 0 : 1;
}
