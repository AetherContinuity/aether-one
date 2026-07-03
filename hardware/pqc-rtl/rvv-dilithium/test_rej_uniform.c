#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

extern unsigned int rej_uniform_rvv(int32_t *a, unsigned int len,
                                     const uint8_t *buf, unsigned int buflen);

int main(void) {
    FILE *fbuf = fopen("rej_input_buf.txt", "r");
    FILE *fgold = fopen("rej_golden.txt", "r");
    if (!fbuf || !fgold) { printf("FAIL: tiedostoja ei loydy\n"); return 1; }

    unsigned int buflen = 840;
    uint8_t *buf = malloc(buflen);
    for (unsigned int i = 0; i < buflen; i++) {
        int v;
        fscanf(fbuf, "%d", &v);
        buf[i] = (uint8_t)v;
    }
    fclose(fbuf);

    unsigned int expected_ctr;
    fscanf(fgold, "%u", &expected_ctr);
    int32_t *expected = malloc(expected_ctr * sizeof(int32_t));
    for (unsigned int i = 0; i < expected_ctr; i++) fscanf(fgold, "%d", &expected[i]);
    fclose(fgold);

    int32_t out[256] = {0};
    unsigned int ctr = rej_uniform_rvv(out, 256, buf, buflen);

    printf("ctr=%u expected_ctr=%u\n", ctr, expected_ctr);
    int errors = (ctr != expected_ctr) ? 1 : 0;
    unsigned int check_n = (ctr < expected_ctr) ? ctr : expected_ctr;
    for (unsigned int i = 0; i < check_n; i++) {
        if (out[i] != expected[i]) {
            errors++;
            if (errors <= 5) printf("[FAIL] i=%u got=%d expected=%d\n", i, out[i], expected[i]);
        }
    }
    printf("%s (%u virhetta)\n", errors == 0 ? "PASS" : "FAIL", errors);
    return errors == 0 ? 0 : 1;
}
