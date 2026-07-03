#include <stdio.h>
#include <stdint.h>
#include "fips202.h"

#define N 256
#define TAU 49
#define CTILDEBYTES 48
#define SHAKE256_RATE 136

static void poly_challenge_ref(int32_t *c, const uint8_t *seed) {
    unsigned int i, b, pos;
    uint64_t signs;
    uint8_t buf[SHAKE256_RATE];
    keccak_state state;

    shake256_init(&state);
    shake256_absorb(&state, seed, CTILDEBYTES);
    shake256_finalize(&state);
    shake256_squeezeblocks(buf, 1, &state);

    signs = 0;
    for (i = 0; i < 8; i++) signs |= (uint64_t)buf[i] << 8*i;
    pos = 8;

    for (i = 0; i < N; i++) c[i] = 0;
    for (i = N-TAU; i < N; i++) {
        do {
            if (pos >= SHAKE256_RATE) { shake256_squeezeblocks(buf, 1, &state); pos = 0; }
            b = buf[pos++];
        } while (b > i);
        c[i] = c[b];
        c[b] = 1 - 2*(signs & 1);
        signs >>= 1;
    }
}

int main(void) {
    uint8_t seed[CTILDEBYTES];
    for (int i = 0; i < CTILDEBYTES; i++) seed[i] = (uint8_t)(i * 17 + 5);

    int32_t c[N];
    poly_challenge_ref(c, seed);

    int nonzero = 0;
    for (int i = 0; i < N; i++) if (c[i] != 0) nonzero++;
    printf("nonzero=%d (odotettu %d = TAU)\n", nonzero, TAU);

    FILE *f = fopen("sib_golden.txt", "w");
    for (int i = 0; i < N; i++) fprintf(f, "%d\n", c[i]);
    fclose(f);
    FILE *fs = fopen("sib_seed.txt", "w");
    for (int i = 0; i < CTILDEBYTES; i++) fprintf(fs, "%d\n", seed[i]);
    fclose(fs);
    return 0;
}
