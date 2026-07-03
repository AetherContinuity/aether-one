#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define CRHBYTES 64
#define SHAKE256_RATE 136

extern void poly_uniform_gamma1_rvv(int32_t *a, void (*squeeze)(uint8_t*, unsigned int, void*), void *ctx);

static void real_squeeze(uint8_t *out, unsigned int nblocks, void *vctx) {
    shake256_squeezeblocks(out, nblocks, (keccak_state*)vctx);
}

int main(void) {
    uint8_t seed[CRHBYTES];
    for (int i = 0; i < CRHBYTES; i++) seed[i] = (uint8_t)(i * 61 + 13);
    uint16_t nonce = 7;

    uint8_t input[CRHBYTES + 2];
    memcpy(input, seed, CRHBYTES);
    input[CRHBYTES] = nonce & 0xFF;
    input[CRHBYTES+1] = (nonce >> 8) & 0xFF;

    keccak_state st;
    shake256_absorb_once(&st, input, sizeof(input));

    int32_t expected[256];
    FILE *fg = fopen("gamma1_golden.txt", "r");
    for (int i = 0; i < 256; i++) if(fscanf(fg,"%d",&expected[i])!=1) return 1;
    fclose(fg);

    int32_t out[256];
    poly_uniform_gamma1_rvv(out, real_squeeze, &st);

    int errors = 0;
    for (int i = 0; i < 256; i++) if (out[i] != expected[i]) { errors++; if(errors<=5) printf("[FAIL] i=%d got=%d exp=%d\n",i,out[i],expected[i]); }
    printf("%s (%d virhetta/256)\n", errors==0?"PASS":"FAIL", errors);
    return errors==0?0:1;
}
