#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define CRHBYTES 64
#define SHAKE256_RATE 136

extern unsigned int poly_uniform_eta_rvv(int32_t *a,
                                          void (*squeeze)(uint8_t*, unsigned int, void*),
                                          void *ctx);

static void real_squeeze(uint8_t *out, unsigned int nblocks, void *vctx) {
    keccak_state *state = (keccak_state *)vctx;
    shake256_squeezeblocks(out, nblocks, state);
}

int main(void) {
    FILE *fs = fopen("poly_eta_seed.txt", "r");
    FILE *fg = fopen("poly_eta_golden.txt", "r");
    if (!fs || !fg) { printf("FAIL: tiedostoja ei loydy\n"); return 1; }

    uint8_t seed[CRHBYTES];
    for (int i = 0; i < CRHBYTES; i++) { int v; if(fscanf(fs, "%d", &v)!=1) return 1; seed[i] = (uint8_t)v; }
    fclose(fs);

    int32_t expected[256];
    for (int i = 0; i < 256; i++) if(fscanf(fg, "%d", &expected[i])!=1) return 1;
    fclose(fg);

    uint16_t nonce = 0;
    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF;
    input[CRHBYTES+1] = (nonce >> 8) & 0xFF;

    keccak_state state;
    shake256_absorb_once(&state, input, sizeof(input));

    int32_t out[256];
    unsigned int ctr = poly_uniform_eta_rvv(out, real_squeeze, &state);

    int errors = (ctr != 256) ? 1 : 0;
    for (int i = 0; i < 256; i++) {
        if (out[i] != expected[i]) {
            errors++;
            if (errors <= 5) printf("[FAIL] i=%d got=%d expected=%d\n", i, out[i], expected[i]);
        }
    }
    printf("%s (%d virhetta), ctr=%u\n", errors == 0 ? "PASS" : "FAIL", errors, ctr);
    return errors == 0 ? 0 : 1;
}
