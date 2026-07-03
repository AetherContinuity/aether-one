#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define SHAKE128_RATE 168

extern unsigned int poly_uniform_rvv(int32_t *a,
                                      void (*squeeze)(uint8_t*, unsigned int, void*),
                                      void *ctx);

static int block_num = 0;
static void fake_squeezeblocks(uint8_t *out, unsigned int nblocks, void *ctx) {
    (void)ctx;
    for (unsigned int b = 0; b < nblocks; b++) {
        uint8_t val = (block_num == 0) ? 0xFF : 0x00;
        for (int i = 0; i < SHAKE128_RATE; i++) out[b*SHAKE128_RATE+i] = val;
        block_num++;
    }
}

int main(void) {
    int32_t out[256];
    int32_t expected[256];

    FILE *f = fopen("poly_uniform_golden.txt", "r");
    if (!f) { printf("FAIL: golden-tiedostoa ei loydy\n"); return 1; }
    for (int i = 0; i < 256; i++) {
        if (fscanf(f, "%d", &expected[i]) != 1) { printf("FAIL: golden loppui kesken\n"); return 1; }
    }
    fclose(f);

    block_num = 0;
    unsigned int ctr = poly_uniform_rvv(out, fake_squeezeblocks, NULL);

    int errors = (ctr != 256) ? 1 : 0;
    if (errors) printf("[FAIL] ctr=%u, odotettu 256\n", ctr);
    for (int i = 0; i < 256; i++) {
        if (out[i] != expected[i]) {
            errors++;
            if (errors <= 5) printf("[FAIL] i=%d got=%d expected=%d\n", i, out[i], expected[i]);
        }
    }
    printf("%s (%d virhetta), ctr=%u\n", errors == 0 ? "PASS" : "FAIL", errors, ctr);
    return errors == 0 ? 0 : 1;
}
