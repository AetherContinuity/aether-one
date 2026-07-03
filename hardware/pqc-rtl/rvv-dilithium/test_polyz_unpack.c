#include <stdio.h>
#include <stdint.h>

#define BUFLEN 680

extern void polyz_unpack_rvv(int32_t *r, const uint8_t *a);

int main(void) {
    uint8_t buf[BUFLEN];
    int32_t expected[256];

    FILE *fb = fopen("gamma1_buf.txt", "r");
    FILE *fg = fopen("gamma1_golden.txt", "r");
    if (!fb || !fg) { printf("FAIL: tiedostoja ei loydy\n"); return 1; }
    for (int i = 0; i < BUFLEN; i++) { int v; if(fscanf(fb,"%d",&v)!=1) return 1; buf[i]=(uint8_t)v; }
    for (int i = 0; i < 256; i++) if(fscanf(fg, "%d", &expected[i]) != 1) return 1;
    fclose(fb); fclose(fg);

    int32_t out[256];
    polyz_unpack_rvv(out, buf);

    int errors = 0;
    for (int i = 0; i < 256; i++) if (out[i] != expected[i]) {
        errors++;
        if (errors <= 5) printf("[FAIL] i=%d got=%d expected=%d\n", i, out[i], expected[i]);
    }
    printf("%s (%d virhetta/256)\n", errors == 0 ? "PASS" : "FAIL", errors);
    return errors == 0 ? 0 : 1;
}
