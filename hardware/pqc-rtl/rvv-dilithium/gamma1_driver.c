#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "fips202.h"

#define N 256
#define CRHBYTES 64
#define GAMMA1 (1 << 19)
#define POLYZ_PACKEDBYTES 640
#define SHAKE256_RATE 136
#define POLY_UNIFORM_GAMMA1_NBLOCKS ((POLYZ_PACKEDBYTES + SHAKE256_RATE - 1) / SHAKE256_RATE)

static void polyz_unpack_ref(int32_t *r, const uint8_t *a) {
    for (unsigned int i = 0; i < N/2; i++) {
        r[2*i+0]  = a[5*i+0];
        r[2*i+0] |= (uint32_t)a[5*i+1] << 8;
        r[2*i+0] |= (uint32_t)a[5*i+2] << 16;
        r[2*i+0] &= 0xFFFFF;

        r[2*i+1]  = a[5*i+2] >> 4;
        r[2*i+1] |= (uint32_t)a[5*i+3] << 4;
        r[2*i+1] |= (uint32_t)a[5*i+4] << 12;

        r[2*i+0] = GAMMA1 - r[2*i+0];
        r[2*i+1] = GAMMA1 - r[2*i+1];
    }
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
    uint8_t buf[POLY_UNIFORM_GAMMA1_NBLOCKS * SHAKE256_RATE];
    shake256_squeezeblocks(buf, POLY_UNIFORM_GAMMA1_NBLOCKS, &st);

    int32_t out[N];
    polyz_unpack_ref(out, buf);

    FILE *f = fopen("gamma1_golden.txt", "w");
    for (int i = 0; i < N; i++) fprintf(f, "%d\n", out[i]);
    fclose(f);
    FILE *fb = fopen("gamma1_buf.txt", "w");
    for (unsigned int i = 0; i < sizeof(buf); i++) fprintf(fb, "%u\n", buf[i]);
    fclose(fb);

    printf("out[0..5]: %d %d %d %d %d %d\n", out[0],out[1],out[2],out[3],out[4],out[5]);
    printf("buflen=%zu\n", sizeof(buf));
    return 0;
}
